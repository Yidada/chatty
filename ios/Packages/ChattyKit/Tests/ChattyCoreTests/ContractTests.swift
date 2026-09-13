import XCTest
@testable import ChattyCore

final class ContractTests: XCTestCase {
    private func data(_ text: String) -> Data { Data(text.utf8) }
    private func sample(_ name: String) throws -> Data {
        try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")))
    }

    func testExistingAndroidFixturePageRetainsCursorAndRichAttachment() throws {
        let page = try Contracts.decode(MessagePage.self, from: sample("messages"))
        XCTAssertEqual(page.messages.count, 50)
        XCTAssertEqual(page.nextCursor?.id, "m006")
        XCTAssertEqual(page.hasMore, true)
        XCTAssertEqual(page.messages.last?.attachments?.first?.filename, "fixture-note.txt")
        XCTAssertEqual(page.messages.last?.quickActions?.first?.prompt, "继续测试格式")
    }

    func testMissingOptionalFieldsAndNullAttachmentsRemainCompatible() throws {
        let message = try Contracts.decode(ChatMessage.self, from: data("""
        {"id":"m1","chat_session_id":"s1","role":"assistant","attachments":null,"future_field":true}
        """))
        XCTAssertNil(message.attachments)
        XCTAssertNil(message.content)
        XCTAssertNil(message.taskId)
        let pending = try Contracts.decode(PendingTask.self, from: data("{}"))
        XCTAssertNil(pending.taskId)
    }

    func testLatestMikaSessionExcludesArchiveAndKeepsServerOrderOnTies() throws {
        let sessions = try Contracts.decode([ChatSession].self, from: data("""
        [{"id":"s1","agent_id":"mika","updated_at":"2026-09-05"},
         {"id":"s2","agent_id":"mika","updated_at":"2026-09-05"},
         {"id":"s3","agent_id":"mika","status":"archived","updated_at":"2026-09-06"},
         {"id":"s4","agent_id":"another","updated_at":"2026-09-07"}]
        """))
        XCTAssertEqual(ChatSessions.latest(for: "mika", in: sessions)?.id, "s1")
        XCTAssertNil(ChatSessions.latest(for: "missing", in: sessions))
    }

    func testReceiptRequiresServerIdentifiersAndPreservesUnboundAttachments() throws {
        let receipt = try Contracts.receipt(from: data("""
        {"message_id":"m1","task_id":"t1","created_at":"2026-09-05T00:00:00Z","attachment_ids":null}
        """))
        XCTAssertEqual(receipt.taskId, "t1")
        XCTAssertNil(receipt.attachmentIds)
        XCTAssertThrowsError(try Contracts.receipt(from: data("""
        {"message_id":"m1","task_id":" ","created_at":"now"}
        """)))
        XCTAssertThrowsError(try Contracts.receipt(from: data("""
        {"message_id":"m1","created_at":"now"}
        """)))
    }

    func testEqualTimestampsDoNotCollapseDifferentMessageIDs() throws {
        let first = try Contracts.decode([ChatMessage].self, from: data("""
        [{"id":"a","chat_session_id":"s","role":"user","content":"old","created_at":"same"},
         {"id":"b","chat_session_id":"s","role":"assistant","created_at":"same"}]
        """))
        let next = try Contracts.decode([ChatMessage].self, from: data("""
        [{"id":"a","chat_session_id":"s","role":"user","content":"new","created_at":"same"},
         {"id":"c","chat_session_id":"s","role":"assistant","created_at":"same"}]
        """))
        let merged = MessagePages.merge(older: first, newer: next)
        XCTAssertEqual(merged.map(\.id), ["a", "b", "c"])
        XCTAssertEqual(merged.first?.content, "new")
    }

    func testProjectTotalsUseServiceCountsAndHandleEmptyProjects() throws {
        let page = try Contracts.decode(ProjectPage.self, from: sample("projects"))
        XCTAssertEqual(page.projects[0].issueCount, 55)
        XCTAssertEqual(page.projects[0].progress, 25.0 / 55.0, accuracy: 0.00001)
        XCTAssertEqual(page.projects[1].progress, 0)
    }

    func testUnknownSocketEventPreservesPayloadAndWireKeys() throws {
        let event = try Contracts.decode(SocketEvent.self, from: data("""
        {"type":"task:future_event","payload":{"task_id":"t1","extra":[null,true,3]}}
        """))
        XCTAssertEqual(event.type, "task:future_event")
        XCTAssertEqual(event.payload, .object(["task_id": .string("t1"), "extra": .array([.null, .bool(true), .number(3)])]))
    }

    func testMarkdownTableTaskListAndCodeRemainStructured() {
        let blocks = MarkdownContent.blocks("""
        ## 格式验证

        | 项目 | 状态 |
        | --- | --- |
        | 对话 | OK |

        - [x] 已完成
        - [ ] 待完成

        ```swift
        print("Chatty")
        ```
        """)
        XCTAssertTrue(blocks.contains(.heading(2, "格式验证")))
        XCTAssertTrue(blocks.contains(.table(["项目", "状态"], [["对话", "OK"]])))
        XCTAssertTrue(blocks.contains(.listItem("已完成", true)))
        XCTAssertTrue(blocks.contains(.listItem("待完成", false)))
        XCTAssertTrue(blocks.contains { if case .code("swift", _) = $0 { true } else { false } })
    }

    func testHTMLRemainsLiteralContent() {
        let blocks = MarkdownContent.blocks("<script>alert('example')</script>\n")
        XCTAssertTrue(blocks.contains { if case .literal(let value) = $0 { value.contains("<script>") } else { false } })
    }

    func testHistorySessionFieldsDecodeAndOlderBackendsStayCompatible() throws {
        let sessions = try Contracts.decode([ChatSession].self, from: data("""
        [{"id":"s1","agent_id":"mika","title":"上周复盘","created_at":"2026-09-09T01:00:00Z","updated_at":"2026-09-10T02:00:00Z",
          "pinned":true,"has_unread":true,"unread_count":2,
          "last_message":{"content":"已完成","role":"assistant","created_at":"2026-09-10T02:00:00Z","future":1}},
         {"id":"s2","agent_id":"mika"}]
        """))
        XCTAssertEqual(sessions[0].pinned, true)
        XCTAssertEqual(sessions[0].hasUnread, true)
        XCTAssertEqual(sessions[0].unreadCount, 2)
        XCTAssertEqual(sessions[0].lastMessage?.content, "已完成")
        XCTAssertEqual(sessions[0].lastMessage?.role, "assistant")
        XCTAssertEqual(sessions[0].createdAt, "2026-09-09T01:00:00Z")
        XCTAssertNil(sessions[1].pinned)
        XCTAssertNil(sessions[1].title)
        XCTAssertNil(sessions[1].lastMessage)
    }

    func testHistoryOrderPutsPinnedFirstThenNewestAndKeepsServerOrderOnTies() throws {
        let sessions = try Contracts.decode([ChatSession].self, from: data("""
        [{"id":"a","agent_id":"mika","updated_at":"2026-09-01"},
         {"id":"b","agent_id":"mika","updated_at":"2026-09-05"},
         {"id":"c","agent_id":"mika","updated_at":"2026-09-03","pinned":true},
         {"id":"d","agent_id":"mika","updated_at":"2026-09-05"},
         {"id":"e","agent_id":"mika","status":"archived","updated_at":"2026-09-09"},
         {"id":"f","agent_id":"other","updated_at":"2026-09-09"}]
        """))
        XCTAssertEqual(ChatSessions.ordered(for: "mika", in: sessions).map(\.id), ["c", "b", "d", "a"])
        XCTAssertTrue(ChatSessions.ordered(for: "missing", in: sessions).isEmpty)
    }

    func testHistoryTitlePrefersServerTitleThenFirstMessageThenPlaceholder() {
        XCTAssertEqual(ChatSessions.displayTitle("高考出题趋势", firstUserMessage: "2025年以来高考出题的趋势和特点"), "高考出题趋势")
        XCTAssertEqual(ChatSessions.displayTitle("   ", firstUserMessage: "  帮我梳理一下项目进度。  "), "帮我梳理一下项目进度。")
        XCTAssertEqual(ChatSessions.displayTitle(nil, firstUserMessage: String(repeating: "长", count: 30)), String(repeating: "长", count: 20))
        XCTAssertEqual(ChatSessions.displayTitle(nil, firstUserMessage: "   "), ChatSessions.newConversationTitle)
        XCTAssertEqual(ChatSessions.displayTitle(nil, firstUserMessage: nil), "新的对话")
    }

    func testCancelAndPrioritizeResponsesDecodeServerPayloads() throws {
        let cancelled = try Contracts.decode(CancelTaskResponse.self, from: data("""
        {"cancelled_chat_message":{"chat_session_id":"s1","message_id":"m9","content":"帮我梳理","restore_to_input":true,
          "attachments":[{"id":"file1","filename":"note.txt"}]}}
        """))
        XCTAssertEqual(cancelled.cancelledChatMessage?.messageId, "m9")
        XCTAssertEqual(cancelled.cancelledChatMessage?.content, "帮我梳理")
        XCTAssertEqual(cancelled.cancelledChatMessage?.restoreToInput, true)
        XCTAssertEqual(cancelled.cancelledChatMessage?.attachments?.first?.filename, "note.txt")
        XCTAssertNil(try Contracts.decode(CancelTaskResponse.self, from: data("{}")).cancelledChatMessage)

        let prioritized = try Contracts.decode(PrioritizeQueuedResponse.self, from: data("""
        {"task_id":"t2","active_task_id":"t1"}
        """))
        XCTAssertEqual(prioritized.taskId, "t2")
        XCTAssertEqual(prioritized.activeTaskId, "t1")
    }
}
