import XCTest
import ChattyCore
import Security
import SwiftUI
import UIKit
@testable import ChattyFixture

final class SimulatorContractTests: XCTestCase {
    // MARK: - Theme contrast (spec §2.3, criterion A7)

    private func luminance(_ color: UIColor) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ value: CGFloat) -> Double {
            let v = Double(value)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }
    private func ratio(_ foreground: Color, on background: Color, _ style: UIUserInterfaceStyle) -> Double {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let front = luminance(UIColor(foreground).resolvedColor(with: traits))
        let back = luminance(UIColor(background).resolvedColor(with: traits))
        return (max(front, back) + 0.05) / (min(front, back) + 0.05)
    }

    /// Body copy must clear WCAG AA for small text in both appearances. The
    /// secondary tone carries captions and the process block, so it is held to the
    /// same bar rather than being treated as decorative.
    func testThemeBodyTextMeetsContrastInBothAppearances() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let name = style == .light ? "light" : "dark"
            let pairs: [(String, Double)] = [
                ("textPrimary/background", ratio(ChattyTheme.textPrimary, on: ChattyTheme.background, style)),
                ("textPrimary/surface", ratio(ChattyTheme.textPrimary, on: ChattyTheme.surface, style)),
                ("textSecondary/background", ratio(ChattyTheme.textSecondary, on: ChattyTheme.background, style)),
                ("bubbleUserText/bubbleUser", ratio(ChattyTheme.bubbleUserText, on: ChattyTheme.bubbleUser, style)),
            ]
            for (label, value) in pairs {
                XCTAssertGreaterThanOrEqual(value, 4.5, "\(name) \(label) = \(String(format: "%.2f", value))")
            }
        }
    }

    /// Accent-on-tint and icon-on-accent are graphics and short labels. They are
    /// held to 3:1 (WCAG AA non-text), **not** 4.5:1: the accent is DeepSeek's
    /// published brand token (`#4D6BFE`) and the reference design uses exactly this
    /// pairing, so darkening it to reach AA-for-small-text would move away from the
    /// thing this change exists to align with (spec §2.1, decisions D1).
    func testThemeAccentPairingsMeetNonTextContrast() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let name = style == .light ? "light" : "dark"
            let pairs: [(String, Double)] = [
                ("onAccent/accent", ratio(ChattyTheme.onAccent, on: ChattyTheme.accent, style)),
                ("chipActiveText/chipActiveFill", ratio(ChattyTheme.chipActiveText, on: ChattyTheme.chipActiveFill, style)),
            ]
            for (label, value) in pairs {
                XCTAssertGreaterThanOrEqual(value, 3.0, "\(name) \(label) = \(String(format: "%.2f", value))")
            }
        }
    }

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
    /// The conversation-scoped record (spec §7.4) must carry the same backup
    /// exclusion as the record it replaces, including the one written by the
    /// upgrade path — that path had only been exercised on the macOS file layout.
    @MainActor func testConversationScopedDraftKeepsBackupExclusion() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let files = try ProtectedStorage(identifier: "scoped", root: root)
        defer { try? FileManager.default.removeItem(at: root) }
        let attachment = try Contracts.decode(Attachment.self, from: Data("""
        {"id":"a1","filename":"note.txt","content_type":"text/plain","size_bytes":12}
        """.utf8))
        try files.saveDraft(.init(text:"scoped draft", projectId:"p2", projectSelectionSet:true, attachments:[attachment]),
                            account:"u1", workspace:"w1", agent:"mika", session:"s9")
        let restored = try XCTUnwrap(try files.draft(account:"u1", workspace:"w1", agent:"mika", session:"s9"))
        XCTAssertEqual(restored.text, "scoped draft")
        XCTAssertEqual(restored.attachments, [attachment])

        // Upgrade path: adopting the legacy record writes a new conversation-scoped
        // file, which must be protected the same way as a directly saved one.
        try files.saveDraft(.init(text:"legacy draft"), account:"u1", workspace:"w1", agent:"mika")
        let adopted = try XCTUnwrap(try files.adoptLegacyDraft(account:"u1", workspace:"w1", agent:"mika", session:"s10"))
        XCTAssertEqual(adopted.text, "legacy draft")
        XCTAssertEqual(try files.draft(account:"u1", workspace:"w1", agent:"mika").text, "", "采纳后旧键清空")

        let stored = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }
        XCTAssertGreaterThanOrEqual(stored.count, 2)
        for path in stored {
            XCTAssertEqual(try path.resourceValues(forKeys:[.isExcludedFromBackupKey]).isExcludedFromBackup, true, path.lastPathComponent)
        }
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
