import XCTest
@testable import ChattyCore

/// Spec §7.4: one protected record per conversation. Before this change a single
/// record per agent held the composer, the outbox and the project selection, so
/// switching conversations moved another conversation's unsent text along with it.
@MainActor
final class DraftScopeTests: XCTestCase {
    private func makeStore() throws -> (store: ProtectedStorage, root: URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return (try ProtectedStorage(identifier: "draft-scope", root: root), root)
    }

    func testDraftsAreScopedPerConversationAndPerAccount() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        try store.saveDraft(DraftRecord(text: "会话 A 的草稿"), account: "u", workspace: "w", agent: "mika", session: "a")
        try store.saveDraft(DraftRecord(text: "会话 B 的草稿"), account: "u", workspace: "w", agent: "mika", session: "b")

        XCTAssertEqual(try store.draft(account: "u", workspace: "w", agent: "mika", session: "a")?.text, "会话 A 的草稿")
        XCTAssertEqual(try store.draft(account: "u", workspace: "w", agent: "mika", session: "b")?.text, "会话 B 的草稿")
        XCTAssertNil(try store.draft(account: "u", workspace: "w", agent: "mika", session: "c"))
        XCTAssertNil(try store.draft(account: "u2", workspace: "w", agent: "mika", session: "a"), "草稿必须按账号隔离")
        XCTAssertNil(try store.draft(account: "u", workspace: "other", agent: "mika", session: "a"), "草稿必须按工作区隔离")
    }

    func testPendingConversationDraftMovesOntoTheCreatedSession() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let pending = ProtectedStorage.pendingSessionKey
        try store.saveDraft(DraftRecord(text: "还没发送", projectId: "p1", projectSelectionSet: true), account: "u", workspace: "w", agent: "mika", session: pending)

        let moved = try store.migrateDraft(account: "u", workspace: "w", agent: "mika", from: pending, to: "s9")
        XCTAssertEqual(moved?.text, "还没发送")
        XCTAssertEqual(moved?.projectId, "p1")
        XCTAssertEqual(try store.draft(account: "u", workspace: "w", agent: "mika", session: "s9")?.text, "还没发送")
        XCTAssertNil(try store.draft(account: "u", workspace: "w", agent: "mika", session: pending), "迁移后不得留在原键")

        XCTAssertNil(try store.migrateDraft(account: "u", workspace: "w", agent: "mika", from: pending, to: "s9"), "重复迁移是幂等的")
        XCTAssertEqual(try store.draft(account: "u", workspace: "w", agent: "mika", session: "s9")?.text, "还没发送")
    }

    func testMigrationNeverOverwritesTheTargetConversation() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        try store.saveDraft(DraftRecord(text: "目标已有内容"), account: "u", workspace: "w", agent: "mika", session: "s9")
        try store.saveDraft(DraftRecord(text: "来源内容"), account: "u", workspace: "w", agent: "mika", session: ProtectedStorage.pendingSessionKey)

        XCTAssertNil(try store.migrateDraft(account: "u", workspace: "w", agent: "mika", from: ProtectedStorage.pendingSessionKey, to: "s9"))
        XCTAssertEqual(try store.draft(account: "u", workspace: "w", agent: "mika", session: "s9")?.text, "目标已有内容")
    }

    /// An install upgrading from the pre-session-scoped build has exactly one
    /// record, under the old agent-level key. It must land in the conversation the
    /// user restores into, exactly once.
    func testLegacyAgentScopedDraftIsAdoptedOnceAndCannotLeak() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        try store.saveDraft(DraftRecord(text: "旧版遗留草稿", uncertain: true), account: "u", workspace: "w", agent: "mika")
        XCTAssertEqual(try store.draft(account: "u", workspace: "w", agent: "mika").text, "旧版遗留草稿", "旧键在迁移前保持可读")

        let adopted = try store.adoptLegacyDraft(account: "u", workspace: "w", agent: "mika", session: "s1")
        XCTAssertEqual(adopted?.text, "旧版遗留草稿")
        XCTAssertEqual(adopted?.uncertain, true)
        XCTAssertEqual(try store.draft(account: "u", workspace: "w", agent: "mika", session: "s1")?.text, "旧版遗留草稿")
        XCTAssertEqual(try store.draft(account: "u", workspace: "w", agent: "mika").text, "", "采纳后旧键必须清空")

        XCTAssertNil(try store.adoptLegacyDraft(account: "u", workspace: "w", agent: "mika", session: "s2"), "重复采纳是幂等的")
        XCTAssertNil(try store.draft(account: "u", workspace: "w", agent: "mika", session: "s2"), "旧草稿不得泄漏到其它会话")
    }

    func testExistingConversationRecordWinsOverTheLegacyDraft() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        try store.saveDraft(DraftRecord(text: "旧版遗留草稿"), account: "u", workspace: "w", agent: "mika")
        try store.saveDraft(DraftRecord(text: "本会话已有内容"), account: "u", workspace: "w", agent: "mika", session: "s1")

        XCTAssertNil(try store.adoptLegacyDraft(account: "u", workspace: "w", agent: "mika", session: "s1"))
        XCTAssertEqual(try store.draft(account: "u", workspace: "w", agent: "mika", session: "s1")?.text, "本会话已有内容")
        XCTAssertEqual(try store.draft(account: "u", workspace: "w", agent: "mika").text, "", "已存在目标记录时旧键也要清掉，避免以后串味")
    }

    func testOutboxRecordsWrittenBeforeSessionScopingStillDecode() throws {
        let withSession = OutgoingMessage(content: "新记录", attachments: [], projectId: "p1", sessionId: "s1")
        XCTAssertEqual(withSession.sessionId, "s1")
        let encoded = try JSONEncoder().encode(withSession)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(object["sessionId"] as? String, "s1")

        // A record from an older build has no sessionId key at all. It must decode
        // (the migration adopts it into the restored conversation) rather than throw.
        object.removeValue(forKey: "sessionId")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let legacy = try JSONDecoder().decode(OutgoingMessage.self, from: legacyData)
        XCTAssertNil(legacy.sessionId)
        XCTAssertEqual(legacy.content, "新记录")
        XCTAssertEqual(legacy.projectId, "p1")

        // Writing a record with no session yet must not emit the key either, so the
        // protected record stays readable by the previous build.
        let pending = OutgoingMessage(content: "新会话首条", attachments: [], projectId: nil)
        XCTAssertNil(pending.sessionId)
        let pendingObject = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(pending)) as? [String: Any])
        XCTAssertNil(pendingObject["sessionId"])
    }
}
