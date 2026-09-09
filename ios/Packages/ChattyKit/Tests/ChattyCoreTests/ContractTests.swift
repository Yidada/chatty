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
}
