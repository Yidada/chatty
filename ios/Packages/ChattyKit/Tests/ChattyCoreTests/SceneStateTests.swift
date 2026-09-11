import XCTest
@testable import ChattyCore

/// Multi-window and scene restoration: the pure decisions behind the shared
/// app core. The UIKit wiring lives in the app target; these are the rules it
/// must obey.
final class SceneStateTests: XCTestCase {

    // MARK: - Scene activity drives the shared poller/socket

    func testIdleLaunchDoesNotStartNetworking() {
        var tracker = SceneActivityTracker()
        XCTAssertEqual(tracker.update(activeSceneIds: []), .keep)
        XCTAssertFalse(tracker.running)
    }

    func testFirstActiveSceneStartsAndExtraWindowsKeepRunning() {
        var tracker = SceneActivityTracker()
        XCTAssertEqual(tracker.update(activeSceneIds: ["a"]), .start)
        XCTAssertTrue(tracker.running)
        XCTAssertEqual(tracker.update(activeSceneIds: ["a", "b"]), .keep)
        XCTAssertTrue(tracker.running)
    }

    func testClosingOneOfTwoWindowsKeepsTheSharedConnectionAlive() {
        var tracker = SceneActivityTracker()
        _ = tracker.update(activeSceneIds: ["a", "b"])
        XCTAssertEqual(tracker.update(activeSceneIds: ["b"]), .keep)
        XCTAssertTrue(tracker.running, "the remaining window still needs polling and the socket")
    }

    func testLastWindowLeavingPausesAndReturningRestarts() {
        var tracker = SceneActivityTracker()
        _ = tracker.update(activeSceneIds: ["a", "b"])
        XCTAssertEqual(tracker.update(activeSceneIds: ["b"]), .keep)
        XCTAssertEqual(tracker.update(activeSceneIds: []), .pause)
        XCTAssertFalse(tracker.running)
        XCTAssertEqual(tracker.update(activeSceneIds: ["b"]), .start)
        XCTAssertTrue(tracker.running)
    }

    // MARK: - Restoring the conversation

    private func sessions(_ json: String) throws -> [ChatSession] {
        try Contracts.decode([ChatSession].self, from: Data(json.utf8))
    }

    func testRememberedConversationWinsOverNewerTimestamp() throws {
        let rows = try sessions("""
        [{"id":"s1","agent_id":"mika","updated_at":"2026-09-05"},
         {"id":"s2","agent_id":"mika","updated_at":"2026-09-09"}]
        """)
        XCTAssertEqual(ChatSessions.latest(for: "mika", in: rows)?.id, "s2")
        XCTAssertEqual(ChatSessions.restored(for: "mika", rememberedId: "s1", in: rows)?.id, "s1")
    }

    func testRememberedConversationFallsBackWhenGoneArchivedOrForeign() throws {
        let rows = try sessions("""
        [{"id":"s1","agent_id":"mika","updated_at":"2026-09-05"},
         {"id":"s2","agent_id":"mika","status":"archived","updated_at":"2026-09-09"},
         {"id":"s3","agent_id":"another","updated_at":"2026-09-10"}]
        """)
        XCTAssertEqual(ChatSessions.restored(for: "mika", rememberedId: nil, in: rows)?.id, "s1")
        XCTAssertEqual(ChatSessions.restored(for: "mika", rememberedId: "deleted", in: rows)?.id, "s1")
        XCTAssertEqual(ChatSessions.restored(for: "mika", rememberedId: "s2", in: rows)?.id, "s1")
        XCTAssertEqual(ChatSessions.restored(for: "mika", rememberedId: "s3", in: rows)?.id, "s1")
    }

    // MARK: - Persisted state

    @MainActor
    func testRememberedConversationIsScopedAndClearedWithTheAccount() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let files = try ProtectedStorage(identifier: "scene", root: root)
        try files.saveLastSession("s7", account: "u1", workspace: "w1", agent: "mika")
        XCTAssertEqual(try files.lastSession(account: "u1", workspace: "w1", agent: "mika"), "s7")
        XCTAssertNil(try files.lastSession(account: "u1", workspace: "w2", agent: "mika"))
        XCTAssertNil(try files.lastSession(account: "u2", workspace: "w1", agent: "mika"))
        try files.saveLastSession(nil, account: "u1", workspace: "w1", agent: "mika")
        XCTAssertNil(try files.lastSession(account: "u1", workspace: "w1", agent: "mika"))
        try files.clearAll()
        try files.saveLastSession("s8", account: "u1", workspace: "w1", agent: "mika")
        try files.clearAll()
        XCTAssertNil(try files.lastSession(account: "u1", workspace: "w1", agent: "mika"),
                     "sign out must not restore a conversation from the previous account")
    }

    @MainActor
    func testEachWindowKeepsItsOwnRestoredTab() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let files = try ProtectedStorage(identifier: "scene", root: root)
        try files.saveSceneTab("projects", window: "window-a")
        try files.saveSceneTab("chat", window: "window-b")
        XCTAssertEqual(try files.sceneTab(window: "window-a"), "projects")
        XCTAssertEqual(try files.sceneTab(window: "window-b"), "chat", "one window must not overwrite the other")
        XCTAssertNil(try files.sceneTab(window: "window-c"), "a freshly opened window starts from its route")
    }
}
