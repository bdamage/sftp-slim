import SwiftUI

struct ServerListSidebarView: View {
    @ObservedObject var viewModel: ServerListViewModel

    var body: some View {
        VStack(spacing: 8) {
            List(selection: $viewModel.selectedServerID) {
                ForEach(viewModel.servers) { server in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(server.displayName)
                            .font(.headline)
                        Text("\(server.username)@\(server.host):\(server.port)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(server.id)
                    .contextMenu {
                        Button("Edit") { viewModel.editingServer = server; viewModel.isPresentingEditor = true }
                        Button("Delete", role: .destructive) {
                            viewModel.requestDelete(server: server)
                        }
                    }
                }
            }

            HStack {
                Button("Add") { viewModel.addServer() }
                Button("Edit") { viewModel.editSelected() }
                    .disabled(viewModel.selectedServer == nil)
                Button("Delete", role: .destructive) { viewModel.requestDeleteSelected() }
                    .disabled(viewModel.selectedServer == nil)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .navigationTitle("Servers")
        .confirmationDialog(
            "Delete Server",
            isPresented: $viewModel.showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                viewModel.confirmDeleteSelected()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \(viewModel.pendingDeleteServerName ?? "this server")?")
        }
    }
}
