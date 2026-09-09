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
    public init(text: String = "", uncertain: Bool = false) { self.text = text; self.uncertain = uncertain }
}

public struct DraftRecoveryScope: Codable, Sendable {
    public let credentialHash: String
    public let accountId: String
    public let workspace: Workspace
    public let agentId: String
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
        #endif
    }
    private func key(_ source: String) -> String { SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined() }
    private func write(_ data: Data, to url: URL) throws {
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: .atomic)
        #endif
        var url = url; var values = URLResourceValues(); values.isExcludedFromBackup = true; try url.setResourceValues(values)
    }
    public func draft(account: String, workspace: String, agent: String) throws -> DraftRecord {
        let url = root.appendingPathComponent("draft-" + key("\(account)/\(workspace)/\(agent)") + ".json")
        guard manager.fileExists(atPath: url.path) else { return DraftRecord() }
        return try JSONDecoder().decode(DraftRecord.self, from: Data(contentsOf: url))
    }
    public func saveDraft(_ value: DraftRecord, account: String, workspace: String, agent: String) throws {
        try write(JSONEncoder().encode(value), to: root.appendingPathComponent("draft-" + key("\(account)/\(workspace)/\(agent)") + ".json"))
    }
    public func rememberRecovery(token: String, account: String, workspace: Workspace, agent: String) throws {
        let scope = DraftRecoveryScope(credentialHash: key(token), accountId: account, workspace: workspace, agentId: agent)
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
