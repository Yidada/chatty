import SwiftUI
import ChattyCore

@main
struct ChattyApp: App {
    // Created once per process: every window scene renders this same core, so
    // logging in (or opening the outbox) in one window is visible in the others
    // and never starts a second poller or socket.
    @State private var core = AppCore(configuration: .current)
    @State private var activity = SceneActivityMonitor.shared

    var body: some Scene {
        WindowGroup(id: AppWindow.main, for: AppRoute.self) { route in
            root(route: route.wrappedValue)
                .background(ChattyTheme.background)
                .tint(ChattyTheme.accent)
                .task { activity.start() }
        }
    }

    @ViewBuilder private func root(route: AppRoute?) -> some View {
        #if CHATTY_FIXTURE
        if ProcessInfo.processInfo.arguments.contains("--p0-preview") { FixtureRootView() }
        else { AppBootstrap(core: core, route: route) }
        #else
        AppBootstrap(core: core, route: route)
        #endif
    }
}
