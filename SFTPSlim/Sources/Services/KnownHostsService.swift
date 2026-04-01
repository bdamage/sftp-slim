import Foundation

struct HostKeyVerification {
    let host: String
    let fingerprint: String
    let knownHostsLine: String
}

final class KnownHostsService {
    let knownHostsPath: String

    init() {
        let sshDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh", isDirectory: true)
        try? FileManager.default.createDirectory(at: sshDir, withIntermediateDirectories: true)
        self.knownHostsPath = sshDir.appendingPathComponent("known_hosts").path
        if !FileManager.default.fileExists(atPath: knownHostsPath) {
            FileManager.default.createFile(atPath: knownHostsPath, contents: nil)
        }
    }

    func verificationNeeded(host: String, port: Int) async throws -> HostKeyVerification? {
        if try isKnownHost(host: host, port: port) {
            return nil
        }

        let scan = try await CommandRunner.runAsync(
            executable: "/usr/bin/ssh-keyscan",
            arguments: ["-p", String(port), host]
        )

        guard scan.exitCode == 0 else {
            throw SFTPError.networkFailure
        }

        let line = scan.stdout
            .split(separator: "\n")
            .map(String.init)
            .first { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#") && !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard let knownHostsLine = line else {
            throw SFTPError.operationFailed("Unable to obtain host key from server.")
        }

        let fingerprint = try await fingerprintForLine(knownHostsLine)
        return HostKeyVerification(host: host, fingerprint: fingerprint, knownHostsLine: knownHostsLine)
    }

    func trust(knownHostsLine: String) throws {
        let payload = knownHostsLine.hasSuffix("\n") ? knownHostsLine : knownHostsLine + "\n"
        let data = Data(payload.utf8)
        if let handle = FileHandle(forWritingAtPath: knownHostsPath) {
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
        } else {
            try data.write(to: URL(fileURLWithPath: knownHostsPath), options: .atomic)
        }
    }

    private func isKnownHost(host: String, port: Int) throws -> Bool {
        guard let content = try? String(contentsOfFile: knownHostsPath, encoding: .utf8) else {
            return false
        }

        let hostToken = port == 22 ? host : "[\(host)]:\(port)"
        for line in content.split(separator: "\n") {
            let value = String(line)
            if value.hasPrefix("#") || value.isEmpty { continue }
            if value.hasPrefix(hostToken + " ") || value.hasPrefix(host + ",") || value.hasPrefix(host + " ") {
                return true
            }
        }
        return false
    }

    private func fingerprintForLine(_ line: String) async throws -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("sftpslim-hostkey-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempFile) }

        try (line + "\n").write(to: tempFile, atomically: true, encoding: .utf8)

        let result = try await CommandRunner.runAsync(
            executable: "/usr/bin/ssh-keygen",
            arguments: ["-lf", tempFile.path]
        )

        guard result.exitCode == 0 else {
            throw SFTPError.operationFailed("Failed to compute host key fingerprint.")
        }

        // Example: 256 SHA256:abc... host (ED25519)
        let parts = result.stdout.split(separator: " ").map(String.init)
        if parts.count > 1 {
            return parts[1]
        }
        return "Unknown"
    }
}
