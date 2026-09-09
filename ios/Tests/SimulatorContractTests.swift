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
        try files.saveDraft(.init(text:"synthetic draft"),account:"u1",workspace:"w1",agent:"mika")
        let preview = try files.preview(Data("sample".utf8), filename:"fixture.txt")
        let stored = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("draft-") }
        for path in stored + [preview] {
            XCTAssertEqual(try path.resourceValues(forKeys:[.isExcludedFromBackupKey]).isExcludedFromBackup,true)
        }
        try files.cleanupExpired(now: Date().addingTimeInterval(3601))
        XCTAssertFalse(FileManager.default.fileExists(atPath:preview.path))
        try files.clearAll()
        XCTAssertEqual(try files.draft(account:"u1",workspace:"w1",agent:"mika").text, "")
    }
}
