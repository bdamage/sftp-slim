# SFTPSlim

Native-feeling macOS SFTP client MVP built with SwiftUI and MVVM.

## Features (MVP)

- Saved server profiles with Keychain-backed secrets
- Test connection and quick connect flow
- Dual-pane browser UI (local + remote)
- Sorting, navigation, refresh, context menus
- Upload/download actions and transfer queue
- Recursive folder upload/download queueing
- Transfer progress, speed, ETA, status, and cancellation
- Remote/local operations: mkdir, rename, move, delete
- Confirmation for destructive actions (server and file delete)
- First-connect host-key trust prompt (TOFU)
- Persistent app state for last local/remote directory per server
- Keyboard shortcuts for common actions
- Basic structured logging with secret redaction discipline

## Build and Run (Xcode)

1. Open `SFTPSlim/Package.swift` in Xcode 15+.
2. Select the `SFTPSlim` scheme.
3. Build and run.

## Notes on SFTP Library

The project ships with `MockSFTPClient` so the UI and architecture are fully testable.
For production SFTP, wire `ConnectionManager` to a real client implementation using a Swift/macOS-compatible SSH/SFTP library such as Citadel or a libssh2 wrapper.

## Security Notes

- Password/private key/passphrase are stored only in Keychain.
- Secrets are not written to logs.
- Host trust prompt is implemented with trust-on-first-use behavior backed by `HostKeyTrustStore`.
- For production, replace demo fingerprints with real server key fingerprints and persist in known_hosts-compatible storage.

## Suggested Next Steps

- Replace mock client with real SFTP transport
- Add known_hosts parser/serializer compatibility
- Add resumable transfer support
- Add Quick Look for local files
- Add menu bar recent connections
