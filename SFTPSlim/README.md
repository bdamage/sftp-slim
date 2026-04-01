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

The project now uses `OpenSSHSFTPClient` (system `ssh`/`scp`) as the active transport backend.
`MockSFTPClient` remains in the source tree for UI development and isolated testing.

Authentication support:
- Private key auth via key path or key material stored in Keychain
- Password auth via temporary `SSH_ASKPASS` helper
- Optional key passphrase support via `SSH_ASKPASS`

This avoids third-party binary dependencies and works on standard macOS installations with OpenSSH.

## Security Notes

- Password/private key/passphrase are stored only in Keychain.
- Secrets are not written to logs.
- Host trust prompt is implemented with trust-on-first-use behavior backed by the local `known_hosts` workflow.
- Fingerprints are obtained via `ssh-keyscan` and displayed from `ssh-keygen -lf` before trust.
- Host key verification is now integrated with `~/.ssh/known_hosts` using `ssh-keyscan` and `ssh-keygen -lf` fingerprint display.

## Suggested Next Steps

- Replace mock client with real SFTP transport
- Add known_hosts parser/serializer compatibility
- Add resumable transfer support
- Add Quick Look for local files
- Add menu bar recent connections
