import Foundation

actor MockSFTPClient: SFTPClientProtocol {
    private var connected = false
    private var filesByPath: [String: [FileItem]] = [:]

    init() {
        let now = Date()
        filesByPath["/"] = [
            FileItem(path: "/var", isDirectory: true, size: 0, modifiedAt: now),
            FileItem(path: "/home", isDirectory: true, size: 0, modifiedAt: now),
            FileItem(path: "/readme.txt", isDirectory: false, size: 4_096, modifiedAt: now)
        ]
        filesByPath["/home"] = [
            FileItem(path: "/home/deploy", isDirectory: true, size: 0, modifiedAt: now),
            FileItem(path: "/home/logs", isDirectory: true, size: 0, modifiedAt: now)
        ]
        filesByPath["/home/deploy"] = [
            FileItem(path: "/home/deploy/app.tar.gz", isDirectory: false, size: 24_000_000, modifiedAt: now)
        ]
    }

    func connect(profile: ServerProfile, secrets: ServerSecrets) async throws {
        try await Task.sleep(for: .milliseconds(300))
        if profile.authMethod == .password, (secrets.password ?? "").isEmpty {
            throw SFTPError.authenticationFailed
        }
        connected = true
    }

    func disconnect() async {
        connected = false
    }

    func testConnection(profile: ServerProfile, secrets: ServerSecrets) async throws {
        try await connect(profile: profile, secrets: secrets)
        await disconnect()
    }

    func listDirectory(path: String) async throws -> [FileItem] {
        guard connected else { throw SFTPError.notConnected }
        return filesByPath[path] ?? []
    }

    func createFolder(path: String) async throws {
        guard connected else { throw SFTPError.notConnected }
        filesByPath[path] = []
    }

    func rename(path: String, to newPath: String) async throws {
        guard connected else { throw SFTPError.notConnected }
        let parent = URL(fileURLWithPath: path).deletingLastPathComponent().path
        guard var siblings = filesByPath[parent], let idx = siblings.firstIndex(where: { $0.path == path }) else {
            throw SFTPError.operationFailed("Item not found")
        }
        let old = siblings[idx]
        siblings[idx] = FileItem(path: newPath, isDirectory: old.isDirectory, size: old.size, modifiedAt: Date())
        filesByPath[parent] = siblings
    }

    func move(path: String, to newPath: String) async throws {
        try await rename(path: path, to: newPath)
    }

    func delete(path: String, recursive: Bool) async throws {
        guard connected else { throw SFTPError.notConnected }
        let parent = URL(fileURLWithPath: path).deletingLastPathComponent().path
        guard var siblings = filesByPath[parent] else { return }
        siblings.removeAll { $0.path == path }
        filesByPath[parent] = siblings
        if recursive {
            filesByPath.removeValue(forKey: path)
        }
    }

    func upload(localPath: String, remotePath: String, progress: @escaping (Int64, Int64) -> Void) async throws {
        guard connected else { throw SFTPError.notConnected }
        try await simulateTransfer(progress: progress)
        let parent = URL(fileURLWithPath: remotePath).deletingLastPathComponent().path
        var siblings = filesByPath[parent] ?? []
        siblings.append(FileItem(path: remotePath, isDirectory: false, size: 2_000_000, modifiedAt: Date()))
        filesByPath[parent] = siblings
    }

    func download(remotePath: String, localPath: String, progress: @escaping (Int64, Int64) -> Void) async throws {
        guard connected else { throw SFTPError.notConnected }
        try await simulateTransfer(progress: progress)
    }

    private func simulateTransfer(progress: @escaping (Int64, Int64) -> Void) async throws {
        let total: Int64 = 8_000_000
        var transferred: Int64 = 0
        while transferred < total {
            try await Task.sleep(for: .milliseconds(120))
            transferred = min(total, transferred + 550_000)
            progress(transferred, total)
            if Task.isCancelled { throw CancellationError() }
        }
    }

}
