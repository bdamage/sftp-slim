import Foundation

actor OpenSSHSFTPClient: SFTPClientProtocol {
    private var connectedProfile: ServerProfile?
    private var connectedSecrets: ServerSecrets?
    private let knownHostsPath: String

    init(knownHostsPath: String) {
        self.knownHostsPath = knownHostsPath
    }

    func connect(profile: ServerProfile, secrets: ServerSecrets) async throws {
        _ = try await runSSH(profile: profile, secrets: secrets, remoteCommand: "echo connected")
        connectedProfile = profile
        connectedSecrets = secrets
    }

    func disconnect() async {
        connectedProfile = nil
        connectedSecrets = nil
    }

    func testConnection(profile: ServerProfile, secrets: ServerSecrets) async throws {
        _ = try await runSSH(profile: profile, secrets: secrets, remoteCommand: "echo test")
    }

    func listDirectory(path: String) async throws -> [FileItem] {
        let (profile, secrets) = try requireConnection()
        let escapedPath = shellQuote(path)
        let command = "LC_ALL=C ls -la \(escapedPath)"
        let result = try await runSSH(profile: profile, secrets: secrets, remoteCommand: command)

        let lines = result.split(separator: "\n").map(String.init)
        var items: [FileItem] = []
        for line in lines {
            if line.hasPrefix("total") { continue }
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            if fields.count < 9 { continue }

            let name = fields[8...].joined(separator: " ")
            if name == "." || name == ".." { continue }

            let isDirectory = fields[0].first == "d"
            let size = Int64(fields[4]) ?? 0
            let fullPath = URL(fileURLWithPath: path).appendingPathComponent(name).path
            items.append(FileItem(path: fullPath, isDirectory: isDirectory, size: size, modifiedAt: Date()))
        }
        return items
    }

    func createFolder(path: String) async throws {
        let (profile, secrets) = try requireConnection()
        let command = "mkdir -p \(shellQuote(path))"
        _ = try await runSSH(profile: profile, secrets: secrets, remoteCommand: command)
    }

    func rename(path: String, to newPath: String) async throws {
        let (profile, secrets) = try requireConnection()
        let command = "mv \(shellQuote(path)) \(shellQuote(newPath))"
        _ = try await runSSH(profile: profile, secrets: secrets, remoteCommand: command)
    }

    func move(path: String, to newPath: String) async throws {
        try await rename(path: path, to: newPath)
    }

    func delete(path: String, recursive: Bool) async throws {
        let (profile, secrets) = try requireConnection()
        let flag = recursive ? "-rf" : "-f"
        let command = "rm \(flag) \(shellQuote(path))"
        _ = try await runSSH(profile: profile, secrets: secrets, remoteCommand: command)
    }

    func upload(localPath: String, remotePath: String, progress: @escaping (Int64, Int64) -> Void) async throws {
        let (profile, secrets) = try requireConnection()

        let attributes = try? FileManager.default.attributesOfItem(atPath: localPath)
        let total = Int64((attributes?[.size] as? NSNumber)?.int64Value ?? 1)
        progress(0, max(total, 1))

        let destination = "\(profile.username)@\(profile.host):\(remotePath)"
        var args = [
            "-P", String(profile.port),
            "-o", "StrictHostKeyChecking=yes",
            "-o", "UserKnownHostsFile=\(knownHostsPath)"
        ]
        let auth = try buildAuth(profile: profile, secrets: secrets)
        args.append(contentsOf: auth.arguments)
        if isDirectory(localPath) {
            args.append("-r")
        }
        args.append(localPath)
        args.append(destination)

        let result = try await CommandRunner.runAsync(
            executable: "/usr/bin/scp",
            arguments: args,
            environment: auth.environment
        )
        auth.cleanup()

        guard result.exitCode == 0 else {
            throw mapProcessError(result.stderr)
        }

        progress(max(total, 1), max(total, 1))
    }

    func download(remotePath: String, localPath: String, progress: @escaping (Int64, Int64) -> Void) async throws {
        let (profile, secrets) = try requireConnection()
        progress(0, 1)

        var args = [
            "-P", String(profile.port),
            "-o", "StrictHostKeyChecking=yes",
            "-o", "UserKnownHostsFile=\(knownHostsPath)"
        ]
        let auth = try buildAuth(profile: profile, secrets: secrets)
        args.append(contentsOf: auth.arguments)

        let source = "\(profile.username)@\(profile.host):\(remotePath)"
        if remotePath.hasSuffix("/") {
            args.append("-r")
        }
        args.append(source)
        args.append(localPath)

        let result = try await CommandRunner.runAsync(
            executable: "/usr/bin/scp",
            arguments: args,
            environment: auth.environment
        )
        auth.cleanup()

        guard result.exitCode == 0 else {
            throw mapProcessError(result.stderr)
        }

        progress(1, 1)
    }

    private func runSSH(profile: ServerProfile, secrets: ServerSecrets, remoteCommand: String) async throws -> String {
        var args = [
            "-p", String(profile.port),
            "-o", "StrictHostKeyChecking=yes",
            "-o", "UserKnownHostsFile=\(knownHostsPath)"
        ]

        let auth = try buildAuth(profile: profile, secrets: secrets)
        args.append(contentsOf: auth.arguments)
        args.append("\(profile.username)@\(profile.host)")
        args.append(remoteCommand)

        let result = try await CommandRunner.runAsync(
            executable: "/usr/bin/ssh",
            arguments: args,
            environment: auth.environment
        )
        auth.cleanup()

        guard result.exitCode == 0 else {
            throw mapProcessError(result.stderr)
        }

        return result.stdout
    }

    private func requireConnection() throws -> (ServerProfile, ServerSecrets) {
        guard let profile = connectedProfile, let secrets = connectedSecrets else {
            throw SFTPError.notConnected
        }
        return (profile, secrets)
    }

    private func mapProcessError(_ stderr: String) -> Error {
        let value = stderr.lowercased()
        if value.contains("permission denied") {
            return SFTPError.permissionDenied
        }
        if value.contains("host key verification failed") {
            return SFTPError.hostKeyUntrusted
        }
        if value.contains("could not resolve hostname") || value.contains("connection timed out") || value.contains("no route to host") {
            return SFTPError.networkFailure
        }
        if value.contains("authentication failed") || value.contains("permission denied (publickey") {
            return SFTPError.authenticationFailed
        }
        return SFTPError.operationFailed(stderr.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func buildAuth(profile: ServerProfile, secrets: ServerSecrets) throws -> (arguments: [String], environment: [String: String], cleanup: () -> Void) {
        var args: [String] = []
        var environment: [String: String] = [:]
        var cleanupPaths: [String] = []

        switch profile.authMethod {
        case .privateKey:
            if let path = profile.privateKeyPath, !path.isEmpty {
                args += ["-i", path]
            } else if let privateKey = secrets.privateKey, !privateKey.isEmpty {
                let tempPath = FileManager.default.temporaryDirectory.appendingPathComponent("sftpslim-key-\(UUID().uuidString)").path
                try privateKey.write(toFile: tempPath, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tempPath)
                args += ["-i", tempPath]
                cleanupPaths.append(tempPath)
            } else {
                throw SFTPError.authenticationFailed
            }

            if let passphrase = secrets.passphrase, !passphrase.isEmpty {
                let askpass = try makeAskpassScript()
                args += ["-o", "BatchMode=no"]
                environment["SSH_ASKPASS"] = askpass
                environment["SSH_ASKPASS_REQUIRE"] = "force"
                environment["DISPLAY"] = "1"
                environment["SFTPSLIM_ASKPASS_VALUE"] = passphrase
                cleanupPaths.append(askpass)
            } else {
                args += ["-o", "BatchMode=yes"]
            }

        case .password:
            guard let password = secrets.password, !password.isEmpty else {
                throw SFTPError.authenticationFailed
            }
            let askpass = try makeAskpassScript()
            args += ["-o", "BatchMode=no", "-o", "PreferredAuthentications=password,keyboard-interactive"]
            environment["SSH_ASKPASS"] = askpass
            environment["SSH_ASKPASS_REQUIRE"] = "force"
            environment["DISPLAY"] = "1"
            environment["SFTPSLIM_ASKPASS_VALUE"] = password
            cleanupPaths.append(askpass)
        }

        let cleanup = {
            for path in cleanupPaths {
                try? FileManager.default.removeItem(atPath: path)
            }
        }

        return (args, environment, cleanup)
    }

    private func makeAskpassScript() throws -> String {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("sftpslim-askpass-\(UUID().uuidString).sh").path
        let script = "#!/bin/sh\necho \"$SFTPSLIM_ASKPASS_VALUE\"\n"
        try script.write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: path)
        return path
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func isDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return isDir.boolValue
    }
}
