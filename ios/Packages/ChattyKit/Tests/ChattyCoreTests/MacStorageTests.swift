#if os(macOS)
import XCTest
@testable import ChattyCore

final class MacStorageTests: XCTestCase {
    @MainActor func testPrivatePermissionsSurviveAtomicReplacementAndAccountIsolation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try ProtectedStorage(identifier: "mac-storage-test", root: root)
        try store.saveDraft(DraftRecord(text: "private A"), account: "a", workspace: "w", agent: "m")
        try store.saveDraft(DraftRecord(text: "private B"), account: "b", workspace: "w", agent: "m")
        try store.saveDraft(DraftRecord(text: "replacement"), account: "a", workspace: "w", agent: "m")
        XCTAssertEqual(try store.draft(account: "a", workspace: "w", agent: "m").text, "replacement")
        XCTAssertEqual(try store.draft(account: "b", workspace: "w", agent: "m").text, "private B")
        XCTAssertEqual(try store.draft(account: "a", workspace: "other", agent: "m").text, "")
        let preview = try store.preview(Data("private attachment".utf8), filename: "../../sample.txt")
        XCTAssertEqual(preview.deletingLastPathComponent(), store.temporary)
        let urls = [root, store.temporary] + (try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)).filter { $0 != store.temporary } + [preview]
        for url in urls {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let mode = try XCTUnwrap(attributes[.posixPermissions] as? NSNumber).intValue
            XCTAssertEqual(mode & 0o077, 0, url.lastPathComponent)
        }
        try store.clearAll()
        XCTAssertEqual(try store.draft(account: "a", workspace: "w", agent: "m").text, "")
        XCTAssertFalse(FileManager.default.fileExists(atPath: preview.path))
    }
}
#endif
