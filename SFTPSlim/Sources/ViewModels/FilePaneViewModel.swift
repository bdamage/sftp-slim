import Foundation

@MainActor
final class FilePaneViewModel: ObservableObject {
    enum PaneKind {
        case local
        case remote
    }

    @Published var currentPath: String
    @Published var items: [FileItem] = []
    @Published var selectedItemID: String?
    @Published var sortBy: FileSort = .name
    @Published var ascending: Bool = true
    @Published var filter: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let kind: PaneKind
    private let localService: LocalFileService
    private unowned let connectionManager: ConnectionManager

    init(kind: PaneKind, initialPath: String, localService: LocalFileService = LocalFileService(), connectionManager: ConnectionManager) {
        self.kind = kind
        self.currentPath = initialPath
        self.localService = localService
        self.connectionManager = connectionManager
    }

    var selectedItem: FileItem? {
        guard let id = selectedItemID else { return nil }
        return items.first(where: { $0.id == id })
    }

    var displayedItems: [FileItem] {
        let filtered: [FileItem]
        if filter.isEmpty {
            filtered = items
        } else {
            filtered = items.filter { $0.name.localizedCaseInsensitiveContains(filter) }
        }

        let sorted = filtered.sorted { a, b in
            let cmp: Bool
            switch sortBy {
            case .name:
                cmp = a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .size:
                cmp = a.size < b.size
            case .type:
                cmp = a.fileExtension < b.fileExtension
            case .modified:
                cmp = a.modifiedAt < b.modifiedAt
            }
            return ascending ? cmp : !cmp
        }
        return sorted
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            switch kind {
            case .local:
                items = try localService.listDirectory(path: currentPath)
            case .remote:
                items = try await connectionManager.listRemote(path: currentPath)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            items = []
        }
    }

    func navigate(into item: FileItem) async {
        guard item.isDirectory else { return }
        currentPath = item.path
        await refresh()
    }

    func navigateUp() async {
        let parent = URL(fileURLWithPath: currentPath).deletingLastPathComponent().path
        currentPath = parent.isEmpty ? "/" : parent
        await refresh()
    }
}
