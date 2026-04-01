import Foundation

protocol SFTPClientProtocol {
    func connect(profile: ServerProfile, secrets: ServerSecrets) async throws
    func disconnect() async
    func testConnection(profile: ServerProfile, secrets: ServerSecrets) async throws

    func listDirectory(path: String) async throws -> [FileItem]
    func createFolder(path: String) async throws
    func rename(path: String, to newPath: String) async throws
    func move(path: String, to newPath: String) async throws
    func delete(path: String, recursive: Bool) async throws

    func upload(localPath: String, remotePath: String, progress: @escaping (Int64, Int64) -> Void) async throws
    func download(remotePath: String, localPath: String, progress: @escaping (Int64, Int64) -> Void) async throws
}

enum SFTPError: LocalizedError {
    case notConnected
    case authenticationFailed
    case permissionDenied
    case networkFailure
    case hostKeyUntrusted
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Not connected to server."
        case .authenticationFailed: return "Authentication failed."
        case .permissionDenied: return "Permission denied."
        case .networkFailure: return "Network error occurred."
        case .hostKeyUntrusted: return "Host key is not trusted."
        case .operationFailed(let msg): return msg
        }
    }
}
