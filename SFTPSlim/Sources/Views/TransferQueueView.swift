import SwiftUI

struct TransferQueueView: View {
    @ObservedObject var transferManager: TransferManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Transfer Queue")
                    .font(.headline)
                Spacer()
                Button("Clear Finished") {
                    transferManager.clearFinished()
                }
            }

            if transferManager.transfers.isEmpty {
                ContentUnavailableView("No active transfers", systemImage: "tray")
            } else {
                List(transferManager.transfers) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.direction == .upload ? "Upload" : "Download")
                                .font(.subheadline.weight(.semibold))
                            Text(statusText(item.status))
                                .foregroundStyle(statusColor(item.status))
                            Spacer()
                            if item.status == .active || item.status == .queued {
                                Button("Cancel") { transferManager.cancel(item.id) }
                                    .buttonStyle(.bordered)
                            }
                        }
                        Text("\(item.sourcePath) → \(item.destinationPath)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ProgressView(value: item.progress)
                        HStack {
                            Text("\(Int(item.progress * 100))%")
                            Text("Speed: \(ByteCountFormatter.string(fromByteCount: Int64(item.speedBytesPerSecond), countStyle: .file))/s")
                            Text(etaText(item.estimatedTimeRemaining))
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        if let error = item.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
    }

    private func statusText(_ status: TransferStatus) -> String {
        status.rawValue.capitalized
    }

    private func statusColor(_ status: TransferStatus) -> Color {
        switch status {
        case .queued: return .orange
        case .active: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .secondary
        }
    }

    private func etaText(_ eta: TimeInterval) -> String {
        if eta.isInfinite {
            return "ETA: --"
        }
        return "ETA: \(Int(eta))s"
    }
}
