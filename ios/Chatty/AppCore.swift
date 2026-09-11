import SwiftUI
import ChattyCore

/// Stable identifier of the app's `WindowGroup`, used by `openWindow`.
enum AppWindow {
    static let main = "main"
}

/// Value carried by a window. A fresh token per request guarantees that asking
/// for a new window twice actually creates two windows instead of focusing the
/// existing one, and lets SwiftUI restore windows with their original target.
struct AppRoute: Codable, Hashable, Sendable {
    var tab: AppTab
    var token: UUID

    init(tab: AppTab) {
        self.tab = tab
        self.token = UUID()
    }
}

/// Process-wide application state.
///
/// Multi-window must not duplicate the login session, the outbox or the
/// network. Everything that owns server state lives here once and every scene
/// renders it; only view state (selected tab, navigation, scroll) is per
/// window. The struct lives in `@State` on the `App`, which SwiftUI creates once
/// per process, so every `WindowGroup` scene observes the same instance.
@MainActor
@Observable
final class AppCore {
    let configuration: AppConfiguration
    private(set) var session: SessionModel?
    private(set) var failure: String?
    @ObservationIgnored private var prepared = false

    init(configuration: AppConfiguration) { self.configuration = configuration }

    /// Idempotent: every window calls it, the first one builds the shared core.
    func prepare() {
        guard !prepared else { return }
        do {
            let identity = Bundle.main.bundleIdentifier ?? "ai.chatty.ios"
            let files = try ProtectedStorage(identifier: identity)
            session = SessionModel(baseURL: configuration.baseURL, vault: KeychainVault(service: identity), files: files)
            failure = nil
            prepared = true
        } catch { failure = error.localizedDescription }
    }
}
