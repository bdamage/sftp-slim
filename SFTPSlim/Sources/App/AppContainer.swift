import Combine
import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let logger = Logger(subsystem: "com.example.sftpslim")
    let keychain = KeychainService()
    let knownHostsService = KnownHostsService()
    let serverStore: ServerStore
    let connectionManager: ConnectionManager
    let transferManager: TransferManager
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.serverStore = ServerStore()
        self.transferManager = TransferManager()
        let client = OpenSSHSFTPClient(knownHostsPath: knownHostsService.knownHostsPath)
        self.connectionManager = ConnectionManager(
            knownHostsService: knownHostsService, client: client)

        // Relay nested state changes (for example connection status) so views
        // observing AppContainer refresh when ConnectionManager updates.
        self.connectionManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}
