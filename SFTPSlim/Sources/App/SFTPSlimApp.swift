import SwiftUI

@main
struct SFTPSlimApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            MainWindowView(container: container)
                .frame(minWidth: 1100, minHeight: 700)
        }
        .windowStyle(.titleBar)
    }
}
