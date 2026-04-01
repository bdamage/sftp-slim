import Foundation

@MainActor
final class ServerStore: ObservableObject {
    @Published private(set) var servers: [ServerProfile] = []

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("SFTPSlim", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("servers.json")
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            servers = []
            return
        }
        do {
            servers = try decoder.decode([ServerProfile].self, from: data)
        } catch {
            servers = []
        }
    }

    func upsert(_ server: ServerProfile) {
        if let idx = servers.firstIndex(where: { $0.id == server.id }) {
            servers[idx] = server
        } else {
            servers.append(server)
        }
        save()
    }

    func delete(_ server: ServerProfile) {
        servers.removeAll { $0.id == server.id }
        save()
    }

    private func save() {
        do {
            let data = try encoder.encode(servers)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Intentionally silent in MVP; hook into logger/alerts in production.
        }
    }
}
