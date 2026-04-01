import Foundation

enum AuthMethod: String, Codable, CaseIterable, Identifiable {
    case password
    case privateKey

    var id: String { rawValue }
}

struct ServerProfile: Identifiable, Codable, Hashable {
    var id: UUID
    var displayName: String
    var host: String
    var port: Int
    var username: String
    var authMethod: AuthMethod
    var privateKeyPath: String?
    var defaultRemotePath: String

    init(
        id: UUID = UUID(),
        displayName: String,
        host: String,
        port: Int = 22,
        username: String,
        authMethod: AuthMethod = .password,
        privateKeyPath: String? = nil,
        defaultRemotePath: String = "/"
    ) {
        self.id = id
        self.displayName = displayName
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.privateKeyPath = privateKeyPath
        self.defaultRemotePath = defaultRemotePath
    }
}

struct ServerSecrets {
    var password: String?
    var privateKey: String?
    var passphrase: String?
}
