import Foundation

/// Which lifecycle action a shared workspace poller/connection should take.
public enum SceneActivityDecision: Equatable, Sendable {
    case start
    case keep
    case pause
}

/// Multi-window keeps one shared data core, so polling and the realtime socket
/// must be driven by *all* scenes rather than by the life cycle of a single
/// view. `onDisappear` is the wrong signal: closing one of two windows would
/// otherwise stop the connection the other window is still using.
///
/// The tracker is a pure reducer over "which scenes are currently foreground
/// active" so the decision can be unit tested without UIKit.
public struct SceneActivityTracker: Equatable, Sendable {
    public private(set) var activeSceneIds: Set<String> = []
    public private(set) var running = false

    public init() {}

    /// Replaces the set of foreground-active scenes and returns what the shared
    /// core should do about it. Callers feed the same set repeatedly (every
    /// scene notification recomputes it); `keep` covers the no-op case.
    public mutating func update(activeSceneIds ids: Set<String>) -> SceneActivityDecision {
        activeSceneIds = ids
        let shouldRun = !ids.isEmpty
        defer { running = shouldRun }
        if shouldRun == running { return .keep }
        return shouldRun ? .start : .pause
    }
}
