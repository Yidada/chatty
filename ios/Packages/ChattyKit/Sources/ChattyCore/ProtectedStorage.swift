import Foundation
import Security
import CryptoKit

@MainActor public protocol CredentialVault {
    func read() throws -> String?
    func save(_ token: String?) throws
}

@MainActor public final class KeychainVault: CredentialVault {
    private let service: String
    public init(service: String) { self.service = service }
    private var pendingLogoutKey: String { service + ".pending-local-logout" }
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: "multica-token", kSecAttrSynchronizable as String: false]
    }
    public func read() throws -> String? {
        // A failed keychain delete must never resurrect a session on cold start.
        guard !UserDefaults.standard.bool(forKey: pendingLogoutKey) else { return nil }
        var query = query
        query[kSecReturnData as String] = true; query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data, let value = String(data: data, encoding: .utf8) else { throw VaultError.unavailable }
        return value
    }
    public func save(_ token: String?) throws {
        guard let token else {
            UserDefaults.standard.set(true, forKey: pendingLogoutKey)
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw VaultError.unavailable }
            UserDefaults.standard.removeObject(forKey: pendingLogoutKey)
            return
        }
        let attributes: [String: Any] = [kSecValueData as String: Data(token.utf8), kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let update = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if update == errSecItemNotFound {
            let status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
            guard status == errSecSuccess else { throw VaultError.unavailable }
        } else if update != errSecSuccess { throw VaultError.unavailable }
        UserDefaults.standard.removeObject(forKey: pendingLogoutKey)
    }
}
public enum VaultError: Error, LocalizedError {
    case unavailable
    public var errorDescription: String? { "无法访问安全存储，请解锁设备后重试。" }
}

public struct DraftRecord: Codable, Equatable, Sendable {
    public var text: String
    public var uncertain: Bool
    public var projectId: String?
    public var projectSelectionSet: Bool?
    public var outbox: [OutgoingMessage]?
    /// Attachments staged in the composer. Scoped to the conversation like the
    /// text and the outbox (spec §7.4), so switching conversations no longer
    /// carries one conversation's uploads into another.
    public var attachments: [Attachment]?
    /// True when the record holds no composer content. A conversation that was
    /// opened and left without typing still gets a record written (the composer,
    /// the outbox and the project selection are saved together), so "a record
    /// exists" must not be mistaken for "the user has something here".
    public var isEmpty: Bool {
        text.isEmpty && !uncertain && (outbox?.isEmpty ?? true) && (attachments?.isEmpty ?? true)
    }
    public init(text: String = "", uncertain: Bool = false, projectId: String? = nil, projectSelectionSet: Bool? = nil, outbox: [OutgoingMessage]? = nil, attachments: [Attachment]? = nil) {
        self.text = text; self.uncertain = uncertain; self.projectId = projectId; self.projectSelectionSet = projectSelectionSet
        self.outbox = outbox
        self.attachments = attachments
    }
}

public struct DraftRecoveryScope: Codable, Sendable {
    public let credentialHash: String
    public let accountId: String
    public let workspace: Workspace
    public let agentId: String
    /// Conversation whose composer is being recovered. Absent on records written
    /// before the composer became conversation-scoped; those fall back to the
    /// pre-session-scoped record.
    public let sessionId: String?
}

@MainActor public final class ProtectedStorage {
    public let root: URL
    public let temporary: URL
    private let manager = FileManager.default
    public init(identifier: String, root: URL? = nil) throws {
        self.root = root ?? manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(identifier, isDirectory: true)
        self.temporary = self.root.appendingPathComponent("previews", isDirectory: true)
        try prepare(self.root); try prepare(temporary)
        try cleanupExpired()
    }
    private func prepare(_ url: URL) throws {
        try manager.createDirectory(at: url, withIntermediateDirectories: true)
        var path = url; var values = URLResourceValues(); values.isExcludedFromBackup = true
        try path.setResourceValues(values)
        #if os(iOS)
        try manager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        #elseif os(macOS)
        try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        #endif
    }
    private func key(_ source: String) -> String { SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined() }
    private func write(_ data: Data, to url: URL) throws {
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: .atomic)
        #if os(macOS)
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        #endif
        #endif
        var url = url; var values = URLResourceValues(); values.isExcludedFromBackup = true; try url.setResourceValues(values)
    }
    /// Draft key used before a conversation exists. `⌘N` starts here, and the first
    /// successful send moves the record onto the server-generated session id.
    public static let pendingSessionKey = "new"

    private func legacyDraftURL(account: String, workspace: String, agent: String) -> URL {
        root.appendingPathComponent("draft-" + key("\(account)/\(workspace)/\(agent)") + ".json")
    }
    private func draftURL(account: String, workspace: String, agent: String, session: String) -> URL {
        root.appendingPathComponent("draft-" + key("\(account)/\(workspace)/\(agent)/\(session)") + ".json")
    }
    private func readDraft(at url: URL) throws -> DraftRecord? {
        guard manager.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(DraftRecord.self, from: Data(contentsOf: url))
    }

    /// Pre-session-scoped draft (one record per agent). Kept readable so an
    /// upgrade can adopt it; new writes go to `saveDraft(_:account:workspace:agent:session:)`.
    public func draft(account: String, workspace: String, agent: String) throws -> DraftRecord {
        try readDraft(at: legacyDraftURL(account: account, workspace: workspace, agent: agent)) ?? DraftRecord()
    }
    public func saveDraft(_ value: DraftRecord, account: String, workspace: String, agent: String) throws {
        try write(JSONEncoder().encode(value), to: legacyDraftURL(account: account, workspace: workspace, agent: agent))
    }

    /// Session-scoped draft. `nil` means "this conversation has no saved record",
    /// which is different from "the user cleared it" — the composer, the outbox and
    /// the project selection all live in one record (spec §7.4).
    public func draft(account: String, workspace: String, agent: String, session: String) throws -> DraftRecord? {
        try readDraft(at: draftURL(account: account, workspace: workspace, agent: agent, session: session))
    }
    public func saveDraft(_ value: DraftRecord, account: String, workspace: String, agent: String, session: String) throws {
        try write(JSONEncoder().encode(value), to: draftURL(account: account, workspace: workspace, agent: agent, session: session))
    }
    public func removeDraft(account: String, workspace: String, agent: String, session: String) throws {
        let url = draftURL(account: account, workspace: workspace, agent: agent, session: session)
        if manager.fileExists(atPath: url.path) { try manager.removeItem(at: url) }
    }
    /// Move a record between conversation keys, e.g. `new` → the session id the
    /// server created for the first send. Never overwrites an existing target and
    /// never removes the source until the copy is written, so it is safe to retry.
    @discardableResult
    public func migrateDraft(account: String, workspace: String, agent: String, from source: String, to target: String) throws -> DraftRecord? {
        guard source != target else { return try draft(account: account, workspace: workspace, agent: agent, session: target) }
        let sourceURL = draftURL(account: account, workspace: workspace, agent: agent, session: source)
        let targetURL = draftURL(account: account, workspace: workspace, agent: agent, session: target)
        guard let record = try readDraft(at: sourceURL) else { return nil }
        guard !manager.fileExists(atPath: targetURL.path) else { return nil }
        try write(JSONEncoder().encode(record), to: targetURL)
        try manager.removeItem(at: sourceURL)
        return record
    }
    /// One-shot adoption of the pre-session-scoped draft into the conversation the
    /// user actually restores into. Idempotent: after the first call the legacy
    /// record is gone, so a second call returns `nil`. A target that still holds
    /// composer content always wins; an empty target record is replaced, because
    /// otherwise simply opening and leaving a conversation would strand the
    /// upgraded draft. The legacy record is dropped either way so it cannot
    /// surface later in an unrelated conversation.
    @discardableResult
    public func adoptLegacyDraft(account: String, workspace: String, agent: String, session: String) throws -> DraftRecord? {
        let legacyURL = legacyDraftURL(account: account, workspace: workspace, agent: agent)
        guard let record = try readDraft(at: legacyURL) else { return nil }
        let targetURL = draftURL(account: account, workspace: workspace, agent: agent, session: session)
        defer { try? manager.removeItem(at: legacyURL) }
        if let existing = try readDraft(at: targetURL), !existing.isEmpty { return nil }
        try write(JSONEncoder().encode(record), to: targetURL)
        return record
    }
    public func activityReads(account: String, workspace: String) throws -> [String: String] {
        let url = root.appendingPathComponent("activity-read-" + key("\(account)/\(workspace)") + ".json")
        guard manager.fileExists(atPath: url.path) else { return [:] }
        return try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
    }
    public func saveActivityReads(_ reads: [String: String], account: String, workspace: String) throws {
        try write(JSONEncoder().encode(reads), to: root.appendingPathComponent("activity-read-" + key("\(account)/\(workspace)") + ".json"))
    }
    public func rememberRecovery(token: String, account: String, workspace: Workspace, agent: String, session: String?) throws {
        let scope = DraftRecoveryScope(credentialHash: key(token), accountId: account, workspace: workspace, agentId: agent, sessionId: session)
        try write(JSONEncoder().encode(scope), to: root.appendingPathComponent("draft-recovery.json"))
    }
    public func recovery(token: String) throws -> DraftRecoveryScope? {
        let path = root.appendingPathComponent("draft-recovery.json")
        guard manager.fileExists(atPath: path.path) else { return nil }
        let scope = try JSONDecoder().decode(DraftRecoveryScope.self, from: Data(contentsOf: path))
        return scope.credentialHash == key(token) ? scope : nil
    }
    public func lastWorkspace(account: String) throws -> String? {
        let path = root.appendingPathComponent("workspace-" + key(account))
        guard manager.fileExists(atPath: path.path) else { return nil }
        return try String(contentsOf: path, encoding: .utf8)
    }
    public func saveWorkspace(_ id: String, account: String) throws {
        try write(Data(id.utf8), to: root.appendingPathComponent("workspace-" + key(account)))
    }
    /// Restores the conversation the user was last in, so relaunch and window
    /// restoration return to the same Mika session instead of guessing from
    /// `updated_at` (which two devices can tie on).
    public func lastSession(account: String, workspace: String, agent: String) throws -> String? {
        let path = root.appendingPathComponent("session-" + key("\(account)/\(workspace)/\(agent)"))
        guard manager.fileExists(atPath: path.path) else { return nil }
        let value = try String(contentsOf: path, encoding: .utf8)
        return value.isEmpty ? nil : value
    }
    public func saveLastSession(_ id: String?, account: String, workspace: String, agent: String) throws {
        try write(Data((id ?? "").utf8), to: root.appendingPathComponent("session-" + key("\(account)/\(workspace)/\(agent)")))
    }
    /// Per-window scene state (which tab a window was last on). Keyed by the
    /// window the system restored, so two windows keep independent selections.
    public func sceneTab(window: String) throws -> String? {
        let path = root.appendingPathComponent("scene-tab-" + key(window))
        guard manager.fileExists(atPath: path.path) else { return nil }
        let value = try String(contentsOf: path, encoding: .utf8)
        return value.isEmpty ? nil : value
    }
    public func saveSceneTab(_ value: String, window: String) throws {
        try write(Data(value.utf8), to: root.appendingPathComponent("scene-tab-" + key(window)))
    }
    public func preview(_ data: Data, filename: String) throws -> URL {
        try cleanupExpired()
        let name = URL(fileURLWithPath: filename).lastPathComponent
        let ext = URL(fileURLWithPath: name).pathExtension.filter { $0.isLetter || $0.isNumber }.prefix(12)
        let url = temporary.appendingPathComponent(UUID().uuidString).appendingPathExtension(String(ext))
        try write(data, to: url); return url
    }
    public func removePreview(_ url: URL) throws {
        guard url.deletingLastPathComponent().standardizedFileURL == temporary.standardizedFileURL else { return }
        if manager.fileExists(atPath: url.path) { try manager.removeItem(at: url) }
    }
    public func clearPreviews() throws {
        if manager.fileExists(atPath: temporary.path) { try manager.removeItem(at: temporary) }
        try prepare(temporary)
    }
    public func clearAll() throws {
        if manager.fileExists(atPath: root.path) { try manager.removeItem(at: root) }
        try prepare(root); try prepare(temporary)
    }
    public func cleanupExpired(now: Date = Date()) throws {
        for url in try manager.contentsOfDirectory(at: temporary, includingPropertiesForKeys: [.contentModificationDateKey]) {
            let date = try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            if now.timeIntervalSince(date) > 3600 { try manager.removeItem(at: url) }
        }
    }
}
