import SwiftUI

struct ServerEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String
    @State private var host: String
    @State private var port: String
    @State private var username: String
    @State private var authMethod: AuthMethod
    @State private var password: String
    @State private var privateKeyPath: String
    @State private var privateKeyContent: String
    @State private var passphrase: String
    @State private var defaultRemotePath: String

    private let existingID: UUID?
    private let onSave: (ServerProfile, ServerSecrets) -> Void

    init(existing: ServerProfile?, existingSecrets: ServerSecrets, onSave: @escaping (ServerProfile, ServerSecrets) -> Void) {
        _displayName = State(initialValue: existing?.displayName ?? "")
        _host = State(initialValue: existing?.host ?? "")
        _port = State(initialValue: String(existing?.port ?? 22))
        _username = State(initialValue: existing?.username ?? "")
        _authMethod = State(initialValue: existing?.authMethod ?? .password)
        _password = State(initialValue: existingSecrets.password ?? "")
        _privateKeyPath = State(initialValue: existing?.privateKeyPath ?? "")
        _privateKeyContent = State(initialValue: existingSecrets.privateKey ?? "")
        _passphrase = State(initialValue: existingSecrets.passphrase ?? "")
        _defaultRemotePath = State(initialValue: existing?.defaultRemotePath ?? "/")
        self.existingID = existing?.id
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Server Profile")
                .font(.title2.bold())

            Form {
                TextField("Display name", text: $displayName)
                TextField("Hostname or IP", text: $host)
                TextField("Port", text: $port)
                TextField("Username", text: $username)
                Picker("Authentication", selection: $authMethod) {
                    ForEach(AuthMethod.allCases) { method in
                        Text(method.rawValue.capitalized).tag(method)
                    }
                }
                if authMethod == .password {
                    SecureField("Password", text: $password)
                } else {
                    TextField("Private key path", text: $privateKeyPath)
                    TextEditor(text: $privateKeyContent)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(height: 90)
                    SecureField("Passphrase (optional)", text: $passphrase)
                }
                TextField("Default remote path", text: $defaultRemotePath)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    let server = ServerProfile(
                        id: existingID ?? UUID(),
                        displayName: displayName.isEmpty ? host : displayName,
                        host: host,
                        port: Int(port) ?? 22,
                        username: username,
                        authMethod: authMethod,
                        privateKeyPath: privateKeyPath.isEmpty ? nil : privateKeyPath,
                        defaultRemotePath: defaultRemotePath.isEmpty ? "/" : defaultRemotePath
                    )

                    let secrets = ServerSecrets(
                        password: authMethod == .password ? password : nil,
                        privateKey: authMethod == .privateKey ? privateKeyContent : nil,
                        passphrase: authMethod == .privateKey ? passphrase : nil
                    )
                    onSave(server, secrets)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(host.isEmpty || username.isEmpty)
            }
        }
        .padding(16)
        .frame(minWidth: 500, minHeight: 520)
    }
}
