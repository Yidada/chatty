import XCTest
import ChattyCore
import Security

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
}
