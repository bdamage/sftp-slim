import Foundation

@MainActor
final class MainViewModel: ObservableObject {
    enum DeleteOrigin {
        case local
        case remote
    }

    @Published var localPane: FilePaneViewModel
    @Published var remotePane: FilePaneViewModel
    @Published var showDeleteConfirm = false
    @Published var pendingDeleteItem: FileItem?
    @Published var pendingDeleteOrigin: DeleteOrigin = .local
    @Published var showCreateFolderSheet = false
    @Published var showRenameSheet = false
    @Published var showMoveSheet = false

    @Published var pendingCreateRemote = false
    @Published var pendingFolderName = ""

    @Published var pendingRenameItem: FileItem?
    @Published var pendingRenameRemote = false
    @Published var pendingRenameValue = ""

    @Published var pendingMoveItem: FileItem?
    @Published var pendingMoveRemote = false
    @Published var pendingMoveDestination = ""

    @Published private(set) var lastLocalPathByServer: [UUID: String] = [:]
    @Published private(set) var lastRemotePathByServer: [UUID: String] = [:]

    private let defaults = UserDefaults.standard
    private let localService = LocalFileService()
    private let fileManager = FileManager.default

    init(connectionManager: ConnectionManager) {
        let start = FileManager.default.homeDirectoryForCurrentUser.path
        self.localPane = FilePaneViewModel(kind: .local, initialPath: start, connectionManager: connectionManager)
        self.remotePane = FilePaneViewModel(kind: .remote, initialPath: "/", connectionManager: connectionManager)
        loadPersistedState()
    }

    func loadPaneData() async {
        await localPane.refresh()
        await remotePane.refresh()
    }

    func saveLastPaths(for server: ServerProfile?) {
        guard let server else { return }
        lastLocalPathByServer[server.id] = localPane.currentPath
        lastRemotePathByServer[server.id] = remotePane.currentPath
        persistState()
    }

    func restoreLastPaths(for server: ServerProfile?) {
        guard let server else { return }
        if let local = lastLocalPathByServer[server.id] {
            localPane.currentPath = local
        }
        if let remote = lastRemotePathByServer[server.id] {
            remotePane.currentPath = remote
        } else {
            remotePane.currentPath = server.defaultRemotePath
        }
    }

    func createLocalFolder(path: String) async {
        do {
            try localService.createFolder(path: path)
            await localPane.refresh()
        } catch {
            localPane.errorMessage = error.localizedDescription
        }
    }

    func createRemoteFolder(path: String, connection: ConnectionManager) async {
        do {
            try await connection.createRemoteFolder(path: path)
            await remotePane.refresh()
        } catch {
            remotePane.errorMessage = error.localizedDescription
        }
    }

    func requestCreateFolder(isRemote: Bool) {
        pendingCreateRemote = isRemote
        pendingFolderName = ""
        showCreateFolderSheet = true
    }

    func confirmCreateFolder(connection: ConnectionManager) async {
        let trimmed = pendingFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let basePath = pendingCreateRemote ? remotePane.currentPath : localPane.currentPath
        let fullPath = URL(fileURLWithPath: basePath).appendingPathComponent(trimmed).path

        if pendingCreateRemote {
            await createRemoteFolder(path: fullPath, connection: connection)
        } else {
            await createLocalFolder(path: fullPath)
        }
        showCreateFolderSheet = false
        pendingFolderName = ""
    }

    func requestRename(item: FileItem, isRemote: Bool) {
        pendingRenameItem = item
        pendingRenameRemote = isRemote
        pendingRenameValue = item.name
        showRenameSheet = true
    }

    func confirmRename(connection: ConnectionManager) async {
        guard let item = pendingRenameItem else { return }
        let trimmed = pendingRenameValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let parent = URL(fileURLWithPath: item.path).deletingLastPathComponent().path
        let newPath = URL(fileURLWithPath: parent).appendingPathComponent(trimmed).path

        do {
            if pendingRenameRemote {
                try await connection.renameRemote(path: item.path, newPath: newPath)
                await remotePane.refresh()
            } else {
                try localService.rename(path: item.path, newPath: newPath)
                await localPane.refresh()
            }
        } catch {
            if pendingRenameRemote {
                remotePane.errorMessage = error.localizedDescription
            } else {
                localPane.errorMessage = error.localizedDescription
            }
        }

        pendingRenameItem = nil
        pendingRenameValue = ""
        showRenameSheet = false
    }

    func requestMove(item: FileItem, isRemote: Bool) {
        pendingMoveItem = item
        pendingMoveRemote = isRemote
        pendingMoveDestination = item.path
        showMoveSheet = true
    }

    func confirmMove(connection: ConnectionManager) async {
        guard let item = pendingMoveItem else { return }
        let destination = pendingMoveDestination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !destination.isEmpty else { return }

        do {
            if pendingMoveRemote {
                try await connection.moveRemote(path: item.path, newPath: destination)
                await remotePane.refresh()
            } else {
                try localService.move(path: item.path, newPath: destination)
                await localPane.refresh()
            }
        } catch {
            if pendingMoveRemote {
                remotePane.errorMessage = error.localizedDescription
            } else {
                localPane.errorMessage = error.localizedDescription
            }
        }

        pendingMoveItem = nil
        pendingMoveDestination = ""
        showMoveSheet = false
    }

    func uploadSelected(connection: ConnectionManager, transfer: TransferManager) {
        guard let item = localPane.selectedItem else { return }
        let destination = URL(fileURLWithPath: remotePane.currentPath).appendingPathComponent(item.name).path
        transfer.enqueueUpload(localPath: item.path, remotePath: destination, size: max(item.size, 1), connection: connection)
    }

    func downloadSelected(connection: ConnectionManager, transfer: TransferManager) {
        guard let item = remotePane.selectedItem else { return }
        let destination = URL(fileURLWithPath: localPane.currentPath).appendingPathComponent(item.name).path
        transfer.enqueueDownload(remotePath: item.path, localPath: destination, size: max(item.size, 1), connection: connection)
    }

    func requestUpload(item: FileItem, connection: ConnectionManager, transfer: TransferManager) {
        Task {
            if item.isDirectory {
                await enqueueRecursiveUpload(localRoot: item.path, remoteRoot: URL(fileURLWithPath: remotePane.currentPath).appendingPathComponent(item.name).path, connection: connection, transfer: transfer)
            } else {
                let destination = URL(fileURLWithPath: remotePane.currentPath).appendingPathComponent(item.name).path
                transfer.enqueueUpload(localPath: item.path, remotePath: destination, size: max(item.size, 1), connection: connection)
            }
        }
    }

    func requestDownload(item: FileItem, connection: ConnectionManager, transfer: TransferManager) {
        Task {
            if item.isDirectory {
                await enqueueRecursiveDownload(remoteRoot: item.path, localRoot: URL(fileURLWithPath: localPane.currentPath).appendingPathComponent(item.name).path, connection: connection, transfer: transfer)
            } else {
                let destination = URL(fileURLWithPath: localPane.currentPath).appendingPathComponent(item.name).path
                transfer.enqueueDownload(remotePath: item.path, localPath: destination, size: max(item.size, 1), connection: connection)
            }
        }
    }

    private func enqueueRecursiveUpload(localRoot: String, remoteRoot: String, connection: ConnectionManager, transfer: TransferManager) async {
        let rootURL = URL(fileURLWithPath: localRoot)
        guard let enumerator = fileManager.enumerator(at: rootURL, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey]) else {
            return
        }

        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            if values?.isDirectory == true {
                continue
            }
            let relative = fileURL.path.replacingOccurrences(of: localRoot, with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let remotePath = URL(fileURLWithPath: remoteRoot).appendingPathComponent(relative).path
            transfer.enqueueUpload(
                localPath: fileURL.path,
                remotePath: remotePath,
                size: Int64(values?.fileSize ?? 1),
                connection: connection
            )
        }
    }

    private func enqueueRecursiveDownload(remoteRoot: String, localRoot: String, connection: ConnectionManager, transfer: TransferManager) async {
        do {
            try fileManager.createDirectory(atPath: localRoot, withIntermediateDirectories: true)
            try await enqueueRemoteDirectory(remotePath: remoteRoot, localPath: localRoot, connection: connection, transfer: transfer)
        } catch {
            localPane.errorMessage = error.localizedDescription
        }
    }

    private func enqueueRemoteDirectory(remotePath: String, localPath: String, connection: ConnectionManager, transfer: TransferManager) async throws {
        let children = try await connection.listRemote(path: remotePath)
        for child in children {
            let localChild = URL(fileURLWithPath: localPath).appendingPathComponent(child.name).path
            if child.isDirectory {
                try fileManager.createDirectory(atPath: localChild, withIntermediateDirectories: true)
                try await enqueueRemoteDirectory(remotePath: child.path, localPath: localChild, connection: connection, transfer: transfer)
            } else {
                transfer.enqueueDownload(remotePath: child.path, localPath: localChild, size: max(child.size, 1), connection: connection)
            }
        }
    }

    func requestDelete(item: FileItem, isRemote: Bool) {
        pendingDeleteItem = item
        pendingDeleteOrigin = isRemote ? .remote : .local
        showDeleteConfirm = true
    }

    func confirmDelete(connection: ConnectionManager) async {
        guard let item = pendingDeleteItem else { return }

        do {
            switch pendingDeleteOrigin {
            case .local:
                try localService.delete(path: item.path)
                await localPane.refresh()
            case .remote:
                try await connection.deleteRemote(path: item.path, recursive: item.isDirectory)
                await remotePane.refresh()
            }
        } catch {
            switch pendingDeleteOrigin {
            case .local:
                localPane.errorMessage = error.localizedDescription
            case .remote:
                remotePane.errorMessage = error.localizedDescription
            }
        }

        pendingDeleteItem = nil
        showDeleteConfirm = false
    }

    private func loadPersistedState() {
        if let localData = defaults.data(forKey: "lastLocalPathByServer"),
           let local = try? JSONDecoder().decode([UUID: String].self, from: localData) {
            lastLocalPathByServer = local
        }
        if let remoteData = defaults.data(forKey: "lastRemotePathByServer"),
           let remote = try? JSONDecoder().decode([UUID: String].self, from: remoteData) {
            lastRemotePathByServer = remote
        }
    }

    private func persistState() {
        if let localData = try? JSONEncoder().encode(lastLocalPathByServer) {
            defaults.set(localData, forKey: "lastLocalPathByServer")
        }
        if let remoteData = try? JSONEncoder().encode(lastRemotePathByServer) {
            defaults.set(remoteData, forKey: "lastRemotePathByServer")
        }
    }
}
