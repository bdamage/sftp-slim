import Foundation

struct HostKeyChallenge: Identifiable {
    let id = UUID()
    let host: String
    let fingerprint: String
}

@MainActor
final class ConnectionManager: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var activeServer: ServerProfile?
    @Published var lastError: String?
    @Published var pendingHostKeyChallenge: HostKeyChallenge?

    private let knownHostsService: KnownHostsService
    private let client: SFTPClientProtocol
    private var hostKeyDecisionContinuation: CheckedContinuation<Bool, Never>?
    private var pendingKnownHostsLine: String?

    init(knownHostsService: KnownHostsService, client: SFTPClientProtocol = MockSFTPClient()) {
        self.knownHostsService = knownHostsService
        self.client = client
    }

    func testConnection(profile: ServerProfile, secrets: ServerSecrets) async -> Bool {
        do {
            try await verifyHostTrust(for: profile)
            try await client.testConnection(profile: profile, secrets: secrets)
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func connect(profile: ServerProfile, secrets: ServerSecrets) async {
        do {
            try await verifyHostTrust(for: profile)
            try await client.connect(profile: profile, secrets: secrets)
            isConnected = true
            activeServer = profile
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            isConnected = false
            activeServer = nil
        }
    }

    func disconnect() async {
        await client.disconnect()
        isConnected = false
        activeServer = nil
    }

    func reconnectIfNeeded(secrets: ServerSecrets) async {
        guard let server = activeServer, !isConnected else { return }
        await connect(profile: server, secrets: secrets)
    }

    func listRemote(path: String) async throws -> [FileItem] {
        try await client.listDirectory(path: path)
    }

    func createRemoteFolder(path: String) async throws {
        try await client.createFolder(path: path)
    }

    func renameRemote(path: String, newPath: String) async throws {
        try await client.rename(path: path, to: newPath)
    }

    func moveRemote(path: String, newPath: String) async throws {
        try await client.move(path: path, to: newPath)
    }

    func deleteRemote(path: String, recursive: Bool) async throws {
        try await client.delete(path: path, recursive: recursive)
    }

    func upload(localPath: String, remotePath: String, progress: @escaping (Int64, Int64) -> Void) async throws {
        try await client.upload(localPath: localPath, remotePath: remotePath, progress: progress)
    }

    func download(remotePath: String, localPath: String, progress: @escaping (Int64, Int64) -> Void) async throws {
        try await client.download(remotePath: remotePath, localPath: localPath, progress: progress)
    }

    func acceptPendingHostKey() {
        if let line = pendingKnownHostsLine {
            try? knownHostsService.trust(knownHostsLine: line)
        }
        hostKeyDecisionContinuation?.resume(returning: true)
        hostKeyDecisionContinuation = nil
        pendingHostKeyChallenge = nil
        pendingKnownHostsLine = nil
    }

    func rejectPendingHostKey() {
        hostKeyDecisionContinuation?.resume(returning: false)
        hostKeyDecisionContinuation = nil
        pendingHostKeyChallenge = nil
        pendingKnownHostsLine = nil
    }

    private func verifyHostTrust(for profile: ServerProfile) async throws {
        let needed = try await knownHostsService.verificationNeeded(host: profile.host, port: profile.port)
        guard let needed else {
            return
        }

        pendingKnownHostsLine = needed.knownHostsLine
        pendingHostKeyChallenge = HostKeyChallenge(host: needed.host, fingerprint: needed.fingerprint)
        let accepted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            hostKeyDecisionContinuation = continuation
        }

        if !accepted {
            throw SFTPError.hostKeyUntrusted
        }
    }
}
