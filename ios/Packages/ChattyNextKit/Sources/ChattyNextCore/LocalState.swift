import Foundation
import CryptoKit
import Security

public struct NextAttachment: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var localFile: String
    public var mediaType: String?
    public init(id: String = UUID().uuidString, name: String, localFile: String, mediaType: String? = nil) { self.id = id; self.name = name; self.localFile = localFile; self.mediaType = mediaType }
}
public struct NextDraft: Codable, Equatable, Sendable {
    public var text = ""
    public var revision = 0
    public var workspace: Wire = .null
    public var model: Wire = .null
    public var attachments: [NextAttachment] = []
    public init() {}
}
public struct PendingSend: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var sessionID: String
    public var draft: NextDraft
    public var state: String
    public var content: [Wire]?
    public init(sessionID: String, draft: NextDraft, id: String = UUID().uuidString) { self.sessionID = sessionID; self.draft = draft; self.id = id; state = "prepared" }
}
public struct NextLocalState: Codable, Sendable {
    public var drafts: [String: NextDraft] = [:]
    public var pending: [PendingSend] = []
    public var lastSession: String?
    public var readPositions: [String: String] = [:]
    public init() {}
    /// Make the source-to-session move and outbox snapshot one disk transaction.
    public mutating func stage(source: String, sessionID: String, draft: NextDraft) -> PendingSend {
        let send = PendingSend(sessionID: sessionID, draft: draft)
        var empty = draft; empty.text = ""; empty.attachments = []; empty.revision += 1
        drafts[source] = empty; drafts[sessionID] = empty; lastSession = sessionID; pending.append(send)
        return send
    }
}

@MainActor public final class NextStorage {
    public let root: URL
    public init(identifier: String, root: URL? = nil) throws {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(identifier, isDirectory: true)
        try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
        try protect(self.root)
    }
    public func load(origin: DSHOrigin) throws -> NextLocalState {
        let path = stateURL(origin); guard FileManager.default.fileExists(atPath: path.path) else { return NextLocalState() }
        return try JSONDecoder().decode(NextLocalState.self, from: Data(contentsOf: path))
    }
    public func save(_ state: NextLocalState, origin: DSHOrigin) throws { try write(JSONEncoder().encode(state), to: stateURL(origin)) }
    public func importFile(_ data: Data, name: String, mediaType: String? = nil) throws -> NextAttachment {
        let id = UUID().uuidString; try write(data, to: root.appendingPathComponent(id))
        return NextAttachment(id: id, name: name, localFile: id, mediaType: mediaType)
    }
    public func file(_ attachment: NextAttachment) throws -> Data {
        guard attachment.localFile == attachment.id, UUID(uuidString: attachment.id) != nil else { throw NextError.storage }
        return try Data(contentsOf: root.appendingPathComponent(attachment.localFile))
    }
    private func stateURL(_ origin: DSHOrigin) -> URL { root.appendingPathComponent(SHA256.hash(data: Data(origin.key.utf8)).map { String(format: "%02x", $0) }.joined() + ".json") }
    private func write(_ data: Data, to path: URL) throws {
        #if os(iOS)
        try data.write(to: path, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: path, options: .atomic)
        #endif
        try protect(path)
    }
    private func protect(_ path: URL) throws {
        var p = path; var values = URLResourceValues(); values.isExcludedFromBackup = true; try p.setResourceValues(values)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: path.path)
        #else
        try FileManager.default.setAttributes([.posixPermissions: path.hasDirectoryPath ? 0o700 : 0o600], ofItemAtPath: path.path)
        #endif
    }
}

@MainActor public final class NextVault {
    private let service: String
    public init(service: String) { self.service = service }
    private var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "dsh-origin-cookie", kSecAttrSynchronizable as String: false] }
    public func read() throws -> DSHCredential? {
        var q = query; q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?; let status = SecItemCopyMatching(q as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw NextError.storage }
        return try JSONDecoder().decode(DSHCredential.self, from: data)
    }
    public func save(_ credential: DSHCredential) throws {
        let data = try JSONEncoder().encode(credential)
        let values: [String: Any] = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let result = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if result == errSecItemNotFound { guard SecItemAdd(query.merging(values) { _, v in v } as CFDictionary, nil) == errSecSuccess else { throw NextError.storage } }
        else if result != errSecSuccess { throw NextError.storage }
    }
    public func clear() throws { let result = SecItemDelete(query as CFDictionary); guard result == errSecSuccess || result == errSecItemNotFound else { throw NextError.storage } }
}
