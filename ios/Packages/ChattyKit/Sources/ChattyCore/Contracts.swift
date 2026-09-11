import Foundation

/// Wire contracts mirror Multica 1cc46b269 and the Android fixture. Optional wire
/// values remain optional; presentation decides the appropriate fallback.
public enum Contracts {
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(type, from: data)
    }

    public static func receipt(from data: Data) throws -> SendReceipt {
        let receipt = try decode(SendReceipt.self, from: data)
        guard !receipt.messageId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !receipt.taskId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ContractError.invalidReceipt
        }
        return receipt
    }
}

public enum ContractError: Error, Equatable { case invalidReceipt }

public struct Workspace: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let slug: String
    public let name: String
}

public struct ChatAgent: Decodable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let systemKey: String?
    public let status: String?
    public let ownerId: String?
    public let archivedAt: String?
    public let runtimeId: String?
    public let runtimeBound: Bool?
    public let permissionMode: String?
    public let invocationTargets: [InvocationTarget]?
}

public struct ChatSession: Decodable, Identifiable, Sendable {
    public let id: String
    public let agentId: String
    public let title: String?
    public let status: String?
    public let updatedAt: String?
    public var projectId: String? = nil
}

public enum ChatSessions {
    /// Keep the server's first record when update timestamps tie, matching the
    /// Android fixture baseline. Display names never determine Mika identity.
    public static func latest(for agentId: String, in sessions: [ChatSession]) -> ChatSession? {
        sessions.filter { $0.agentId == agentId && $0.status != "archived" }
            .reduce(nil) { selected, candidate in
                guard let selected else { return candidate }
                return (candidate.updatedAt ?? "") > (selected.updatedAt ?? "") ? candidate : selected
            }
    }

    /// Scene restoration entry point: the conversation the user was last in wins
    /// over "most recently updated", which two clients can tie on or which can
    /// move because of work started elsewhere. Falls back to `latest` when the
    /// remembered conversation is gone, archived, or belongs to another agent.
    public static func restored(for agentId: String, rememberedId: String?, in sessions: [ChatSession]) -> ChatSession? {
        guard let rememberedId,
              let remembered = sessions.first(where: { $0.id == rememberedId && $0.agentId == agentId && $0.status != "archived" })
        else { return latest(for: agentId, in: sessions) }
        return remembered
    }
}

public struct ChatMessage: Decodable, Identifiable, Sendable {
    public let id: String
    public let chatSessionId: String
    public let role: String
    public let content: String?
    public let taskId: String?
    public let createdAt: String?
    public let attachments: [Attachment]?
    public let messageKind: String?
    public let failureReason: String?
    public let elapsedMs: Int?
    public let quickActions: [QuickAction]?
}

public struct QuickAction: Decodable, Sendable {
    public let label: String
    public let prompt: String
    public let primary: Bool?
}

public struct Attachment: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let filename: String
    public let contentType: String?
    public let sizeBytes: Int?
    public let downloadUrl: String?
    public let markdownUrl: String?
    public let url: String?
}

public struct MessageCursor: Decodable, Equatable, Sendable {
    public let id: String
    public let createdAt: String
}

public struct MessagePage: Decodable, Sendable {
    public let messages: [ChatMessage]
    public let hasMore: Bool?
    public let nextCursor: MessageCursor?
}

public struct SendReceipt: Decodable, Sendable {
    public let messageId: String
    public let taskId: String
    public let createdAt: String
    public let attachmentIds: [String]?
    public let queued: Bool?
    public let supportsQueue: Bool?
}

public struct PendingTask: Decodable, Sendable {
    public let taskId: String?
    public let status: String?
    public let waitReason: String?
    public let supportsQueue: Bool?
    public var queuedTasks: [QueuedChatTask]? = nil
}

public struct QueuedChatTask: Decodable, Identifiable, Sendable {
    public let taskId: String
    public let status: String
    public let createdAt: String
    public let messageId: String?
    public let content: String?
    public var id: String { taskId }
}

public struct Project: Decodable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let status: String?
    public let issueCount: Int?
    public let doneCount: Int?
    public let description: String?
    public let priority: String?
    public let dueDate: String?
    public var progress: Double {
        guard let total = issueCount, total > 0 else { return 0 }
        return min(1, max(0, Double(doneCount ?? 0) / Double(total)))
    }
}

public struct ProjectPage: Decodable, Sendable {
    public let projects: [Project]
    public let total: Int
}

public struct RuntimeDevice: Decodable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let customName: String?
    public let status: String?
    public let deviceInfo: String?
    public let provider: String?
    public let runtimeMode: String?
    public let lastSeenAt: String?
    public var displayName: String {
        guard let customName, !customName.isEmpty else { return name }
        return customName
    }
}

public struct Squad: Decodable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let memberCount: Int?
    public let leaderId: String?
    public let archivedAt: String?
}

/// Preserve unrecognised server payloads, including nested objects and nulls.
public enum JSONValue: Codable, Equatable, Sendable {
    case null, bool(Bool), number(Double), string(String)
    case array([JSONValue]), object([String: JSONValue])

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }
    public var string: String? { if case .string(let value) = self { return value }; return nil }
    public var object: [String: JSONValue]? { if case .object(let value) = self { return value }; return nil }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }
}

public struct SocketEvent: Decodable, Sendable {
    public let type: String
    public let payload: JSONValue?
}

public enum MessagePages {
    /// Older records keep server order. A repeated ID is replaced by its newest
    /// fetched version; equal timestamps are never used as message identity.
    public static func merge(older: [ChatMessage], newer: [ChatMessage]) -> [ChatMessage] {
        var order: [String] = []
        var values: [String: ChatMessage] = [:]
        for message in older + newer {
            if values[message.id] == nil { order.append(message.id) }
            values[message.id] = message
        }
        return order.compactMap { values[$0] }
    }
}
