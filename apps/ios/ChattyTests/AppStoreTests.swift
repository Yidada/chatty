import Foundation
import Testing
@testable import Chatty

@MainActor
struct AppStoreTests {
    private func makeStore() -> AppStore {
        let store = AppStore()
        store.stepDelayMilliseconds = 0
        return store
    }

    @Test("新会话发送消息后创建会话并进入审批") func sendFromNewSessionCreatesSessionAndAwaitsApproval() async throws {
        let store = makeStore()
        store.startNewSession()
        let before = store.sessions.count

        store.send("修复失败的测试")
        let session = try #require(store.currentSession)
        #expect(store.sessions.count == before + 1)
        #expect(session.items.first?.text == "修复失败的测试")

        await store.waitForRunningTask(session.id)
        let updated = try #require(store.currentSession)
        #expect(updated.state == .awaitingApproval)
        #expect(updated.approval?.command == "npm test")
    }

    @Test("同意后本轮结束并生成改动卡片") func approveFinishesTurnWithChangesCard() async throws {
        let store = makeStore()
        store.send("修复失败的测试")
        let sessionID = try #require(store.currentSessionID)
        await store.waitForRunningTask(sessionID)

        store.respond(.approve)
        await store.waitForRunningTask(sessionID)

        let session = try #require(store.currentSession)
        #expect(session.state == .idle)
        #expect(session.approval == nil)
        #expect(session.items.last?.kind == .changes)
    }

    @Test("拒绝并说明会预填输入框") func rejectWithNotePrefillsDraft() async throws {
        let store = makeStore()
        let pending = try #require(store.sessions.first(where: { $0.approval != nil }))
        store.select(pending.id)

        store.respond(.rejectWithNote)
        #expect(store.currentSession?.approval == nil)
        #expect(store.draft.isEmpty == false)

        await store.waitForRunningTask(pending.id)
        #expect(store.currentSession?.state == .idle)
    }

    @Test("切换引擎插入摘要迁移提示") func switchingHarnessAddsMigrationNotice() throws {
        let store = makeStore()
        let session = try #require(store.sessions.first(where: { $0.harnessID == "claude-code" && $0.state == .idle }))
        store.select(session.id)

        store.switchEngine(harnessID: "opencode", modelID: "opencode/big-pickle")

        let updated = try #require(store.currentSession)
        #expect(updated.harnessID == "opencode")
        #expect(updated.items.last?.text == "已切换引擎，上下文已通过摘要迁移")
    }

    @Test("只换模型不触发摘要迁移") func switchingModelOnlySkipsMigration() throws {
        let store = makeStore()
        let session = try #require(store.sessions.first(where: { $0.harnessID == "claude-code" && $0.state == .idle }))
        store.select(session.id)

        store.switchEngine(harnessID: "claude-code", modelID: "opus")

        let updated = try #require(store.currentSession)
        #expect(updated.items.last?.text == "已切换模型为 Opus 5.5")
    }

    @Test("每个引擎只列出自己的模型") func harnessListsOnlyItsOwnModels() {
        let store = makeStore()
        let openCodeModels = store.harness("opencode")?.models.map(\.id) ?? []
        #expect(openCodeModels.allSatisfy { $0.contains("/") })
        #expect(store.harness("codex")?.isAvailable == false)
    }

    @Test("删除当前会话后回到新会话") func deletingCurrentSessionReturnsToNewSession() throws {
        let store = makeStore()
        let session = try #require(store.sessions.first)
        store.select(session.id)

        store.delete(session.id)

        #expect(store.currentSessionID == nil)
        #expect(store.sessions.contains { $0.id == session.id } == false)
    }

    @Test("搜索按标题过滤并按仓库分组") func searchFiltersByTitleAndGroupsByRepo() {
        let store = makeStore()
        let groups = store.groupedSessions(matching: "README")
        #expect(groups.count == 1)
        #expect(groups.first?.repo == "docs")
    }
}
