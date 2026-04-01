import SwiftUI

struct MainWindowView: View {
    @ObservedObject private var container: AppContainer

    @StateObject private var serverVM: ServerListViewModel
    @StateObject private var mainVM: MainViewModel

    init(container: AppContainer) {
        self._container = ObservedObject(wrappedValue: container)
        _serverVM = StateObject(
            wrappedValue: ServerListViewModel(
                store: container.serverStore, keychain: container.keychain,
                connectionManager: container.connectionManager))
        _mainVM = StateObject(
            wrappedValue: MainViewModel(connectionManager: container.connectionManager))
    }

    var body: some View {
        NavigationSplitView {
            ServerListSidebarView(viewModel: serverVM)
                .frame(minWidth: 260)
        } detail: {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    FilePaneView(
                        title: "Local",
                        pane: mainVM.localPane,
                        isRemote: false,
                        onRefresh: { await mainVM.localPane.refresh() },
                        onRequestCreateFolder: { isRemote in
                            mainVM.requestCreateFolder(isRemote: isRemote)
                        },
                        onRequestTransfer: { item, isRemote in
                            guard container.connectionManager.isConnected else { return }
                            if isRemote {
                                mainVM.requestDownload(
                                    item: item, connection: container.connectionManager,
                                    transfer: container.transferManager)
                            } else {
                                mainVM.requestUpload(
                                    item: item, connection: container.connectionManager,
                                    transfer: container.transferManager)
                            }
                        },
                        onRequestRename: { item, isRemote in
                            mainVM.requestRename(item: item, isRemote: isRemote)
                        },
                        onRequestMove: { item, isRemote in
                            mainVM.requestMove(item: item, isRemote: isRemote)
                        },
                        onRequestDelete: { item, isRemote in
                            mainVM.requestDelete(item: item, isRemote: isRemote)
                        }
                    )

                    VStack(spacing: 12) {
                        Button("Upload →") {
                            mainVM.uploadSelected(
                                connection: container.connectionManager,
                                transfer: container.transferManager)
                        }
                        .disabled(!container.connectionManager.isConnected)
                        .keyboardShortcut("u", modifiers: [.command])

                        Button("← Download") {
                            mainVM.downloadSelected(
                                connection: container.connectionManager,
                                transfer: container.transferManager)
                        }
                        .disabled(!container.connectionManager.isConnected)
                        .keyboardShortcut("d", modifiers: [.command])
                    }
                    .frame(width: 120)

                    FilePaneView(
                        title: "Remote",
                        pane: mainVM.remotePane,
                        isRemote: true,
                        onRefresh: { await mainVM.remotePane.refresh() },
                        onRequestCreateFolder: { isRemote in
                            mainVM.requestCreateFolder(isRemote: isRemote)
                        },
                        onRequestTransfer: { item, isRemote in
                            guard container.connectionManager.isConnected else { return }
                            if isRemote {
                                mainVM.requestDownload(
                                    item: item, connection: container.connectionManager,
                                    transfer: container.transferManager)
                            } else {
                                mainVM.requestUpload(
                                    item: item, connection: container.connectionManager,
                                    transfer: container.transferManager)
                            }
                        },
                        onRequestRename: { item, isRemote in
                            mainVM.requestRename(item: item, isRemote: isRemote)
                        },
                        onRequestMove: { item, isRemote in
                            mainVM.requestMove(item: item, isRemote: isRemote)
                        },
                        onRequestDelete: { item, isRemote in
                            mainVM.requestDelete(item: item, isRemote: isRemote)
                        }
                    )
                }
                .padding()

                Divider()

                TransferQueueView(transferManager: container.transferManager)
                    .frame(height: 200)
            }
            .toolbar {
                ToolbarItemGroup {
                    Button("Test") {
                        Task { await serverVM.testSelectedConnection() }
                    }
                    .keyboardShortcut("t", modifiers: [.command])

                    if container.connectionManager.isConnected {
                        Button("Disconnect") {
                            Task { await container.connectionManager.disconnect() }
                        }
                        .keyboardShortcut(".", modifiers: [.command])
                    } else {
                        Button("Connect") {
                            Task {
                                await serverVM.connectSelected()
                                mainVM.restoreLastPaths(
                                    for: serverVM.selectedServer,
                                    preferProfileDefaultRemotePath: true
                                )
                                await mainVM.loadPaneData()
                            }
                        }
                        .keyboardShortcut("k", modifiers: [.command])
                    }

                    Button("Refresh") {
                        Task { await mainVM.loadPaneData() }
                    }
                    .keyboardShortcut("r", modifiers: [.command])
                }
            }
            .task {
                await mainVM.localPane.refresh()
            }
            .onChange(of: serverVM.selectedServerID) { _, _ in
                mainVM.saveLastPaths(for: serverVM.selectedServer)
            }
            .onChange(of: mainVM.localPane.currentPath) { _, _ in
                mainVM.saveLastPaths(for: serverVM.selectedServer)
            }
            .onChange(of: mainVM.remotePane.currentPath) { _, _ in
                mainVM.saveLastPaths(for: serverVM.selectedServer)
            }
            .alert(
                "Connection Error",
                isPresented: Binding(
                    get: { serverVM.uiError != nil },
                    set: { if !$0 { serverVM.uiError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(serverVM.uiError ?? "")
            }
            .sheet(isPresented: $serverVM.isPresentingEditor) {
                ServerEditorView(
                    existing: serverVM.editingServer,
                    existingSecrets: serverVM.editingServer.map { serverVM.secrets(for: $0) }
                        ?? ServerSecrets(),
                    onSave: { server, secrets in
                        serverVM.saveServer(server, secrets: secrets)
                    }
                )
            }
            .confirmationDialog(
                "Delete Item",
                isPresented: $mainVM.showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task { await mainVM.confirmDelete(connection: container.connectionManager) }
                }
                Button("Cancel", role: .cancel) {
                    mainVM.pendingDeleteItem = nil
                }
            } message: {
                Text(
                    "Are you sure you want to delete \(mainVM.pendingDeleteItem?.name ?? "this item")?"
                )
            }
            .alert(
                "Trust Server Host Key?",
                isPresented: Binding(
                    get: { container.connectionManager.pendingHostKeyChallenge != nil },
                    set: { _ in }
                )
            ) {
                Button("Trust") {
                    container.connectionManager.acceptPendingHostKey()
                }
                Button("Reject", role: .destructive) {
                    container.connectionManager.rejectPendingHostKey()
                }
            } message: {
                let challenge = container.connectionManager.pendingHostKeyChallenge
                Text("Host: \(challenge?.host ?? "")\nFingerprint: \(challenge?.fingerprint ?? "")")
            }
            .sheet(isPresented: $mainVM.showCreateFolderSheet) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Create Folder")
                        .font(.title3.bold())
                    TextField("Folder name", text: $mainVM.pendingFolderName)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Spacer()
                        Button("Cancel") { mainVM.showCreateFolderSheet = false }
                        Button("Create") {
                            Task {
                                await mainVM.confirmCreateFolder(
                                    connection: container.connectionManager)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(16)
                .frame(minWidth: 360)
            }
            .sheet(isPresented: $mainVM.showRenameSheet) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Rename")
                        .font(.title3.bold())
                    TextField("New name", text: $mainVM.pendingRenameValue)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Spacer()
                        Button("Cancel") { mainVM.showRenameSheet = false }
                        Button("Rename") {
                            Task {
                                await mainVM.confirmRename(connection: container.connectionManager)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(16)
                .frame(minWidth: 360)
            }
            .sheet(isPresented: $mainVM.showMoveSheet) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Move")
                        .font(.title3.bold())
                    TextField("Destination path", text: $mainVM.pendingMoveDestination)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Spacer()
                        Button("Cancel") { mainVM.showMoveSheet = false }
                        Button("Move") {
                            Task {
                                await mainVM.confirmMove(connection: container.connectionManager)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(16)
                .frame(minWidth: 420)
            }
        }
    }
}
