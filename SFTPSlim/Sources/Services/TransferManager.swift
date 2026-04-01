import Foundation

@MainActor
final class TransferManager: ObservableObject {
    @Published private(set) var transfers: [TransferItem] = []

    private var tasks: [UUID: Task<Void, Never>] = [:]

    func enqueueUpload(localPath: String, remotePath: String, size: Int64, connection: ConnectionManager) {
        let item = TransferItem(sourcePath: localPath, destinationPath: remotePath, direction: .upload, totalBytes: size)
        transfers.append(item)
        runTransfer(itemID: item.id) { progress in
            try await connection.upload(localPath: localPath, remotePath: remotePath, progress: progress)
        }
    }

    func enqueueDownload(remotePath: String, localPath: String, size: Int64, connection: ConnectionManager) {
        let item = TransferItem(sourcePath: remotePath, destinationPath: localPath, direction: .download, totalBytes: size)
        transfers.append(item)
        runTransfer(itemID: item.id) { progress in
            try await connection.download(remotePath: remotePath, localPath: localPath, progress: progress)
        }
    }

    func cancel(_ id: UUID) {
        tasks[id]?.cancel()
        tasks[id] = nil
        update(id: id) { $0.status = .cancelled }
    }

    func clearFinished() {
        transfers.removeAll { [.completed, .failed, .cancelled].contains($0.status) }
    }

    private func runTransfer(
        itemID: UUID,
        operation: @escaping (@escaping (Int64, Int64) -> Void) async throws -> Void
    ) {
        update(id: itemID) { $0.status = .active }

        let task = Task {
            let startedAt = Date()
            do {
                try await operation { transferred, total in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        let elapsed = max(Date().timeIntervalSince(startedAt), 0.001)
                        self.update(id: itemID) { item in
                            item.bytesTransferred = transferred
                            item.totalBytes = max(total, 1)
                            item.progress = Double(transferred) / Double(max(total, 1))
                            item.speedBytesPerSecond = Double(transferred) / elapsed
                        }
                    }
                }
                if Task.isCancelled {
                    update(id: itemID) { $0.status = .cancelled }
                } else {
                    update(id: itemID) {
                        $0.progress = 1
                        $0.status = .completed
                    }
                }
            } catch is CancellationError {
                update(id: itemID) { $0.status = .cancelled }
            } catch {
                update(id: itemID) {
                    $0.status = .failed
                    $0.errorMessage = error.localizedDescription
                }
            }
            tasks[itemID] = nil
        }

        tasks[itemID] = task
    }

    private func update(id: UUID, mutate: (inout TransferItem) -> Void) {
        guard let idx = transfers.firstIndex(where: { $0.id == id }) else { return }
        var item = transfers[idx]
        mutate(&item)
        transfers[idx] = item
    }
}
