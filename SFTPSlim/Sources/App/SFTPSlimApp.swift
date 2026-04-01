import AppKit
import SwiftUI

@main
struct SFTPSlimApp: App {
    @StateObject private var container = AppContainer()

    init() {
        // When launched from an integrated terminal, force app activation so
        // text input goes to the app window instead of the terminal.
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
            NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView(container: container)
                .frame(minWidth: 1100, minHeight: 700)
        }
        .windowStyle(.titleBar)
    }
}
