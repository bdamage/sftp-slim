import Foundation

struct LocalFileService {
    private let fm = FileManager.default

    func listDirectory(path: String) throws -> [FileItem] {
        let url = URL(fileURLWithPath: path)
        let keys: [URLResourceKey] = [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey]
        let urls = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: keys)

        return try urls.map { itemURL in
            let values = try itemURL.resourceValues(forKeys: Set(keys))
            let isDirectory = values.isDirectory ?? false
            return FileItem(
                path: itemURL.path,
                isDirectory: isDirectory,
                size: Int64(values.fileSize ?? 0),
                modifiedAt: values.contentModificationDate ?? .distantPast
            )
        }
    }

    func createFolder(path: String) throws {
        try fm.createDirectory(atPath: path, withIntermediateDirectories: true)
    }

    func rename(path: String, newPath: String) throws {
        try fm.moveItem(atPath: path, toPath: newPath)
    }

    func move(path: String, newPath: String) throws {
        try rename(path: path, newPath: newPath)
    }

    func delete(path: String) throws {
        try fm.removeItem(atPath: path)
    }
}
