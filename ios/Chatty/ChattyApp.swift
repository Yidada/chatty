import SwiftUI

@main
struct ChattyApp: App {
    var body: some Scene {
        WindowGroup {
            #if CHATTY_FIXTURE
            if ProcessInfo.processInfo.arguments.contains("--p0-preview") { FixtureRootView() }
            else { AppBootstrap(configuration: .fixture) }
            #else
            AppBootstrap(configuration: .production)
            #endif
        }
    }
}
