import SwiftUI

@main
struct ChattyApp: App {
    @StateObject private var commands = AppCommandCenter()

    var body: some Scene {
        WindowGroup {
            root.environmentObject(commands)
        }
        .commands { ChattyCommands(center: commands) }
    }

    @ViewBuilder private var root: some View {
        #if CHATTY_FIXTURE
        if ProcessInfo.processInfo.arguments.contains("--p0-preview") { FixtureRootView() }
        else { AppBootstrap(configuration: .fixture) }
        #else
        AppBootstrap(configuration: .production)
        #endif
    }
}
