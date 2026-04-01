import Foundation

@MainActor
final class ServerListViewModel: ObservableObject {
    @Published var selectedServerID: UUID?
    @Published var isPresentingEditor = false
    @Published var editingServer: ServerProfile?
    @Published var uiError: String?
    @Published var showDeleteConfirm = false
    @Published var pendingDeleteServerName: String?

    private let store: ServerStore
    private let keychain: KeychainService
    private let connectionManager: ConnectionManager

    init(store: ServerStore, keychain: KeychainService, connectionManager: ConnectionManager) {
        self.store = store
        self.keychain = keychain
        self.connectionManager = connectionManager
        self.selectedServerID = store.servers.first?.id
    }

    var servers: [ServerProfile] { store.servers }

    var selectedServer: ServerProfile? {
        guard let id = selectedServerID else { return nil }
        return store.servers.first(where: { $0.id == id })
    }

    func addServer() {
        editingServer = nil
        isPresentingEditor = true
    }

    func editSelected() {
        editingServer = selectedServer
        isPresentingEditor = true
    }

    func requestDeleteSelected() {
        guard let server = selectedServer else { return }
        pendingDeleteServerName = server.displayName
        showDeleteConfirm = true
    }

    func requestDelete(server: ServerProfile) {
        selectedServerID = server.id
        pendingDeleteServerName = server.displayName
        showDeleteConfirm = true
    }

    func confirmDeleteSelected() {
        deleteSelected()
        showDeleteConfirm = false
        pendingDeleteServerName = nil
    }

    func deleteSelected() {
        guard let server = selectedServer else { return }
        store.delete(server)
        try? keychain.delete(account: secretKey(server.id, "password"))
        try? keychain.delete(account: secretKey(server.id, "privateKey"))
        try? keychain.delete(account: secretKey(server.id, "passphrase"))
        selectedServerID = store.servers.first?.id
    }

    func saveServer(_ server: ServerProfile, secrets: ServerSecrets) {
        store.upsert(server)
        selectedServerID = server.id
        saveSecrets(secrets, serverID: server.id)
    }

    func secrets(for server: ServerProfile) -> ServerSecrets {
        let password = try? keychain.get(account: secretKey(server.id, "password"))
        let privateKey = try? keychain.get(account: secretKey(server.id, "privateKey"))
        let passphrase = try? keychain.get(account: secretKey(server.id, "passphrase"))
        return ServerSecrets(password: password ?? nil, privateKey: privateKey ?? nil, passphrase: passphrase ?? nil)
    }

    func testSelectedConnection() async {
        guard let server = selectedServer else { return }
        let ok = await connectionManager.testConnection(profile: server, secrets: secrets(for: server))
        if !ok {
            uiError = connectionManager.lastError ?? "Connection failed"
        }
    }

    func connectSelected() async {
        guard let server = selectedServer else { return }
        await connectionManager.connect(profile: server, secrets: secrets(for: server))
        if connectionManager.lastError != nil {
            uiError = connectionManager.lastError
        }
    }

    private func saveSecrets(_ secrets: ServerSecrets, serverID: UUID) {
        if let password = secrets.password {
            try? keychain.set(password, account: secretKey(serverID, "password"))
        }
        if let privateKey = secrets.privateKey {
            try? keychain.set(privateKey, account: secretKey(serverID, "privateKey"))
        }
        if let passphrase = secrets.passphrase {
            try? keychain.set(passphrase, account: secretKey(serverID, "passphrase"))
        }
    }

    private func secretKey(_ serverID: UUID, _ name: String) -> String {
        "\(serverID.uuidString).\(name)"
    }
}
