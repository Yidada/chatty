import XCTest
import ChattyCore
import SwiftUI
import UIKit
import Security
@testable import ChattyFixture

final class SimulatorContractTests: XCTestCase {
    func testSameServerReceiptOnIOS() throws {
        let receipt = try Contracts.receipt(from: Data("""
        {"message_id":"m1","task_id":"t1","created_at":"2026-09-05T00:00:00Z"}
        """.utf8))
        XCTAssertEqual(receipt.taskId, "t1")
        XCTAssertNil(receipt.attachmentIds)
    }
    func testMarkdownBlocksOnIOS() {
        let blocks = MarkdownContent.blocks("| 项目 | 状态 |\n| --- | --- |\n| iOS | OK |\n")
        XCTAssertEqual(blocks, [.table(["项目", "状态"], [["iOS", "OK"]])])
    }
    @MainActor func testRealKeychainRoundTripProtectionAndLogout() throws {
        let service = "ai.chatty.test." + UUID().uuidString
        let vault = KeychainVault(service: service)
        defer { try? vault.save(nil) }
        XCTAssertNil(try vault.read())
        try vault.save("synthetic-keychain-test")
        XCTAssertEqual(try KeychainVault(service: service).read(), "synthetic-keychain-test")
        let query: [String: Any] = [kSecClass as String:kSecClassGenericPassword, kSecAttrService as String:service, kSecReturnAttributes as String:true]
        var attributes: CFTypeRef?
        XCTAssertEqual(SecItemCopyMatching(query as CFDictionary, &attributes), errSecSuccess)
        let result = try XCTUnwrap(attributes as? [String: Any])
        XCTAssertEqual(result[kSecAttrAccessible as String] as? String, kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        XCTAssertEqual(result[kSecAttrSynchronizable as String] as? Bool, false)
        try vault.save("updated-synthetic-token")
        XCTAssertEqual(try vault.read(), "updated-synthetic-token")
        try vault.save(nil); XCTAssertNil(try vault.read())
    }
    @MainActor func testPhysicalFileProtectionAttribute() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let files = try ProtectedStorage(identifier: "protection", root: root)
        defer { try? FileManager.default.removeItem(at: root) }
        let preview = try files.preview(Data("sample".utf8), filename: "protected.txt")
        let attributes = try FileManager.default.attributesOfItem(atPath: preview.path)
        #if targetEnvironment(simulator)
        if attributes[.protectionKey] == nil { throw XCTSkip("Simulator does not expose file protection; physical iPhone validation remains required.") }
        #endif
        XCTAssertEqual(attributes[.protectionKey] as? FileProtectionType, .complete)
    }
    @MainActor func testDraftAndPreviewBackupExclusionAndExpiry() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let files = try ProtectedStorage(identifier: "test", root: root)
        defer { try? FileManager.default.removeItem(at: root) }
        let queued = OutgoingMessage(content: "queued snapshot", attachments: [], projectId: "p1")
        try files.saveDraft(.init(text:"synthetic draft", projectId:"p2", projectSelectionSet:true, outbox:[queued]),account:"u1",workspace:"w1",agent:"mika")
        try files.saveActivityReads(["i1":"activity-version|in_review"],account:"u1",workspace:"w1")
        let restored = try files.draft(account:"u1",workspace:"w1",agent:"mika")
        XCTAssertEqual(restored.text,"synthetic draft"); XCTAssertEqual(restored.projectId,"p2")
        XCTAssertEqual(restored.outbox,[queued])
        let preview = try files.preview(Data("sample".utf8), filename:"fixture.txt")
        let stored = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }
        for path in stored + [preview] {
            XCTAssertEqual(try path.resourceValues(forKeys:[.isExcludedFromBackupKey]).isExcludedFromBackup,true)
        }
        try files.cleanupExpired(now: Date().addingTimeInterval(3601))
        XCTAssertFalse(FileManager.default.fileExists(atPath:preview.path))
        try files.clearAll()
        XCTAssertEqual(try files.draft(account:"u1",workspace:"w1",agent:"mika").text, "")
        XCTAssertTrue(try files.activityReads(account:"u1",workspace:"w1").isEmpty)
    }
    // MARK: - Stage B (CLE-90): composer drops and shareable issue links

    func testAttachmentImportRejectsEmptyAndOversizedData() throws {
        XCTAssertThrowsError(try AttachmentImport.prepared(data: Data(), filename: "a.txt", contentType: "text/plain")) {
            XCTAssertEqual($0 as? APIError, .unsafeFile)
        }
        XCTAssertThrowsError(try AttachmentImport.prepared(data: Data(count: APIClient.maximumFileBytes + 1), filename: "b.bin", contentType: "")) {
            XCTAssertEqual($0 as? APIError, .oversizedFile)
        }
        let normalized = try AttachmentImport.prepared(data: Data("hi".utf8), filename: "", contentType: "")
        XCTAssertEqual(normalized.filename, "attachment")
        XCTAssertEqual(normalized.contentType, "application/octet-stream")
        let named = try AttachmentImport.prepared(data: Data("hi".utf8), filename: "note.txt", contentType: "text/plain")
        XCTAssertEqual(named.filename, "note.txt"); XCTAssertEqual(named.contentType, "text/plain")
    }

    func testAttachmentImportReadsDroppedFileURL() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dropped-\(UUID().uuidString).txt")
        try Data("dropped payload".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let imported = try AttachmentImport.read(fileURL: url)
        XCTAssertEqual(imported.data, Data("dropped payload".utf8))
        XCTAssertEqual(imported.filename, url.lastPathComponent)
        XCTAssertFalse(imported.contentType.isEmpty)
    }

    func testSharedIssueLinkResolvesBackToTheNativeRoute() throws {
        let link = NativeLink.issueLink(workspace: "one", identifier: "MUL-7")
        XCTAssertEqual(link, "https://app.multica.ai/one/issues/MUL-7")
        XCTAssertEqual(NativeLink.resolve(link, api: URL(string: "https://api.multica.ai")!, workspace: "one"), .issue("MUL-7"))
    }

    // MARK: - CLE-101: the composer's return key sends

    func testComposerReturnSendsOnlyOutsideComposition() {
        XCTAssertEqual(ComposerReturnKey.action(replacement: "\n", isComposing: false, keepsLineBreak: false), .send)
        // 输入法组词中的回车只上屏候选词。
        XCTAssertEqual(ComposerReturnKey.action(replacement: "\n", isComposing: true, keepsLineBreak: false), .insert)
        XCTAssertEqual(ComposerReturnKey.action(replacement: "你好", isComposing: true, keepsLineBreak: false), .insert)
        // 硬件键盘 ⇧↵ 保留手动换行，其他输入照常。
        XCTAssertEqual(ComposerReturnKey.action(replacement: "\n", isComposing: false, keepsLineBreak: true), .insert)
        XCTAssertEqual(ComposerReturnKey.action(replacement: "a", isComposing: false, keepsLineBreak: false), .insert)
    }

    @MainActor func testComposerFieldSendsOnReturnAndNeverInsertsTheNewline() throws {
        var draft = "", focused = false, sends = 0
        let field = ComposerText(text: Binding(get: { draft }, set: { draft = $0 }), focused: Binding(get: { focused }, set: { focused = $0 }),
                                 enabled: true, onSubmit: { sends += 1 })
        let view = ComposerText.makeTextView()
        let coordinator = field.makeCoordinator()
        view.delegate = coordinator
        // 组词状态由 UITextView 自己持有，这里直接建立候选词状态。
        view.setMarkedText("nihao", selectedRange: NSRange(location: 5, length: 0))
        XCTAssertNotNil(view.markedTextRange, "组词中的回车用例需要 marked text 状态")
        // 组词中的回车：候选词上屏（放行替换），不发送。
        XCTAssertTrue(coordinator.textView(view, shouldChangeTextIn: NSRange(location: 0, length: 5), replacementText: "你好"))
        XCTAssertEqual(sends, 0)
        view.unmarkText()
        view.text = "你好"
        // 不在组词中的回车：发送，并且换行符不进入草稿。
        XCTAssertFalse(coordinator.textView(view, shouldChangeTextIn: NSRange(location: 2, length: 0), replacementText: "\n"))
        XCTAssertEqual(sends, 1)
        XCTAssertEqual(view.text, "你好")
    }

    @MainActor func testComposerFieldGrowsToSixLinesThenScrolls() {
        let view = ComposerText.makeTextView()
        view.text = "one"
        let one = ComposerText.fittingHeight(of: view, width: 300)
        view.text = "one\ntwo\nthree"
        let three = ComposerText.fittingHeight(of: view, width: 300)
        view.text = Array(repeating: "line", count: 20).joined(separator: "\n")
        let many = ComposerText.fittingHeight(of: view, width: 300)
        let line = (view.font ?? .preferredFont(forTextStyle: .body)).lineHeight
        XCTAssertGreaterThan(three, one)
        // 六行封顶：再多也只在框内滚动。
        XCTAssertEqual(many, line * ComposerText.maximumLines + view.textContainerInset.top + view.textContainerInset.bottom, accuracy: 0.5)
        // 一行也不塌陷。
        XCTAssertGreaterThan(one, line + view.textContainerInset.top + view.textContainerInset.bottom - 1)
        XCTAssertLessThan(one, line * 2 + view.textContainerInset.top + view.textContainerInset.bottom)
    }
}
