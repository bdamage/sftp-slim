import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let logger = Logger(subsystem: "com.example.sftpslim")
    let keychain = KeychainService()
    let hostTrustStore = HostKeyTrustStore()
    let serverStore: ServerStore
    let connectionManager: ConnectionManager
    let transferManager: TransferManager

    init() {
        self.serverStore = ServerStore()
        self.transferManager = TransferManager()
        self.connectionManager = ConnectionManager(hostTrustStore: hostTrustStore)
    }
}
