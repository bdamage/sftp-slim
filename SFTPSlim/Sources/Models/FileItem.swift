import Foundation

struct FileItem: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modifiedAt: Date
    let fileExtension: String

    init(path: String, isDirectory: Bool, size: Int64, modifiedAt: Date) {
        self.path = path
        self.name = URL(fileURLWithPath: path).lastPathComponent
        self.id = path
        self.isDirectory = isDirectory
        self.size = size
        self.modifiedAt = modifiedAt
        self.fileExtension = URL(fileURLWithPath: path).pathExtension.lowercased()
    }
}

enum FileSort: String, CaseIterable, Identifiable {
    case name
    case size
    case type
    case modified

    var id: String { rawValue }
}
