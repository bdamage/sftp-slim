import Foundation

enum TransferDirection: String, Codable {
    case upload
    case download
}

enum TransferStatus: String, Codable {
    case queued
    case active
    case completed
    case failed
    case cancelled
}

struct TransferItem: Identifiable, Hashable {
    let id: UUID
    let sourcePath: String
    let destinationPath: String
    let direction: TransferDirection

    var progress: Double
    var bytesTransferred: Int64
    var totalBytes: Int64
    var speedBytesPerSecond: Double
    var status: TransferStatus
    var errorMessage: String?

    init(
        id: UUID = UUID(),
        sourcePath: String,
        destinationPath: String,
        direction: TransferDirection,
        totalBytes: Int64
    ) {
        self.id = id
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.direction = direction
        self.totalBytes = max(totalBytes, 1)
        self.progress = 0
        self.bytesTransferred = 0
        self.speedBytesPerSecond = 0
        self.status = .queued
        self.errorMessage = nil
    }

    var estimatedTimeRemaining: TimeInterval {
        guard speedBytesPerSecond > 0 else { return .infinity }
        let remaining = Double(max(totalBytes - bytesTransferred, 0))
        return remaining / speedBytesPerSecond
    }
}
