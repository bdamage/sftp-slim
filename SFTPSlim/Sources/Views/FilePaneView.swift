import SwiftUI

struct FilePaneView: View {
    let title: String
    @ObservedObject var pane: FilePaneViewModel
    let isRemote: Bool
    let onRefresh: () async -> Void
    let onRequestCreateFolder: (Bool) -> Void
    let onRequestTransfer: (FileItem, Bool) -> Void
    let onRequestRename: (FileItem, Bool) -> Void
    let onRequestMove: (FileItem, Bool) -> Void
    let onRequestDelete: (FileItem, Bool) -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                TextField("Filter", text: $pane.filter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                Button("Up") {
                    Task { await pane.navigateUp() }
                }
                Button("Refresh") {
                    Task { await onRefresh() }
                }
                Button("New Folder") {
                    onRequestCreateFolder(isRemote)
                }
            }

            HStack {
                TextField("Path", text: $pane.currentPath)
                    .textFieldStyle(.roundedBorder)
                Button("Go") {
                    Task { await pane.refresh() }
                }
            }

            HStack {
                Picker("Sort", selection: $pane.sortBy) {
                    ForEach(FileSort.allCases) { sort in
                        Text(sort.rawValue.capitalized).tag(sort)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Ascending", isOn: $pane.ascending)
                    .toggleStyle(.switch)
            }

            if pane.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = pane.errorMessage {
                ContentUnavailableView(
                    "Error", systemImage: "exclamationmark.triangle", description: Text(error)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if pane.displayedItems.isEmpty {
                ContentUnavailableView("Empty folder", systemImage: "folder")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(pane.displayedItems, selection: $pane.selectedItemID) {
                    TableColumn("Name") { item in
                        HStack {
                            Image(systemName: item.isDirectory ? "folder" : "doc")
                            Text(item.name)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            Task { await pane.navigate(into: item) }
                        }
                        .contextMenu {
                            if item.isDirectory {
                                Button("Open") { Task { await pane.navigate(into: item) } }
                            }
                            Button(isRemote ? "Download" : "Upload") {
                                onRequestTransfer(item, isRemote)
                            }
                            Button("Rename") {
                                onRequestRename(item, isRemote)
                            }
                            Button("Move") {
                                onRequestMove(item, isRemote)
                            }
                            Button("Delete", role: .destructive) {
                                onRequestDelete(item, isRemote)
                            }
                        }
                    }
                    TableColumn("Size") { item in
                        Text(
                            item.isDirectory
                                ? "-"
                                : ByteCountFormatter.string(
                                    fromByteCount: item.size, countStyle: .file))
                    }
                    TableColumn("Type") { item in
                        Text(
                            item.isDirectory
                                ? "Folder"
                                : (item.fileExtension.isEmpty
                                    ? "File" : item.fileExtension.uppercased()))
                    }
                    TableColumn("Modified") { item in
                        Text(item.modifiedAt, style: .date)
                    }
                }
            }
        }
        .padding(8)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
