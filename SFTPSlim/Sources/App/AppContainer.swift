import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let logger = Logger(subsystem: "com.example.sftpslim")
    let keychain = KeychainService()
    let knownHostsService = KnownHostsService()
    let serverStore: ServerStore
    let connectionManager: ConnectionManager
    let transferManager: TransferManager

    init() {
        self.serverStore = ServerStore()
        self.transferManager = TransferManager()
        let client = OpenSSHSFTPClient(knownHostsPath: knownHostsService.knownHostsPath)
        self.connectionManager = ConnectionManager(
            knownHostsService: knownHostsService, client: client)
    }
}
