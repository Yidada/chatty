import SwiftUI
import ChattyCore
import UIKit

/// Feeds "which scenes are foreground active" into the pure `SceneActivityTracker`.
///
/// Polling and the realtime socket are process wide, so they must follow the set
/// of live scenes instead of one view's `onDisappear`. With two windows open,
/// closing one has to leave the shared connection running for the other.
///
/// Pausing is debounced: swapping between windows briefly leaves *no* scene in
/// `foregroundActive` (the old one deactivates before the new one activates),
/// and reacting to that instantly would tear down and rebuild the socket on
/// every window change.
@MainActor
@Observable
final class SceneActivityMonitor {
    static let shared = SceneActivityMonitor()

    private(set) var activeSceneCount = 0
    /// Debounced answer to "should the shared workspace core be running".
    private(set) var shouldKeepRunning = false
    @ObservationIgnored private var tracker = SceneActivityTracker()
    @ObservationIgnored private var pendingPause: Task<Void, Never>?
    @ObservationIgnored private var observing = false

    static let pauseGrace: Duration = .seconds(2)

    func start() {
        guard !observing else { return }
        observing = true
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            UIScene.didActivateNotification,
            UIScene.willDeactivateNotification,
            UIScene.didEnterBackgroundNotification,
            UIScene.willEnterForegroundNotification,
            UIScene.didDisconnectNotification,
            UIScene.willConnectNotification,
        ]
        for name in names {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
        }
        refresh()
    }

    func refresh() {
        let ids = Self.foregroundActiveSceneIds()
        activeSceneCount = ids.count
        guard !ids.isEmpty else { schedulePause(); return }
        pendingPause?.cancel(); pendingPause = nil
        if tracker.update(activeSceneIds: ids) == .start { shouldKeepRunning = true }
    }

    private func schedulePause() {
        guard tracker.running, pendingPause == nil else { return }
        pendingPause = Task { [weak self] in
            try? await Task.sleep(for: Self.pauseGrace)
            guard let self, !Task.isCancelled else { return }
            self.pendingPause = nil
            let ids = Self.foregroundActiveSceneIds()
            self.activeSceneCount = ids.count
            guard ids.isEmpty else { _ = self.tracker.update(activeSceneIds: ids); return }
            if self.tracker.update(activeSceneIds: []) == .pause { self.shouldKeepRunning = false }
        }
    }

    static func foregroundActiveSceneIds() -> Set<String> {
        Set(UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .map { $0.session.persistentIdentifier })
    }
}
