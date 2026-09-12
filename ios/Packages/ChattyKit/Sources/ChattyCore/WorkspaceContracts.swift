import Foundation

public struct User: Decodable, Sendable {
    public let id: String
    public let name: String?
    public let email: String?
}
public struct Member: Decodable, Sendable {
    public let userId: String
    public let role: String
}
public struct InvocationTarget: Decodable, Sendable {
    public let targetType: String
    public let targetId: String
}
public enum AgentPermission {
    public static func canChat(_ agent: ChatAgent, userId: String, role: String?) -> Bool {
        guard agent.archivedAt == nil else { return false }
        if agent.ownerId == userId { return true }
        return agent.permissionMode == "public_to" && (agent.invocationTargets ?? []).contains {
            ($0.targetType == "workspace" && role != nil) || ($0.targetType == "member" && $0.targetId == userId)
        }
    }
}
public struct TaskTrace: Decodable, Identifiable, Sendable {
    public let taskId: String
    public let seq: Int
    public let type: String
    public let tool: String?
    public let content: String?
    public let input: JSONValue?
    public let output: String?
    public var id: String { "\(taskId):\(seq)" }
}
public enum TraceRows {
    public static func merge(_ old: [TaskTrace], _ new: [TaskTrace]) -> [TaskTrace] {
        var rows: [String: TaskTrace] = [:]
        for row in old + new { rows[row.id] = row }
        return rows.values.sorted { $0.seq < $1.seq }
    }
}
public struct Issue: Decodable, Identifiable, Sendable {
    public let id: String
    public let identifier: String
    public let title: String
    public let status: String
    public let statusCategory: String?
    public let priority: String?
    public let description: String?
    public let projectId: String?
    public let assigneeId: String?
    public let assigneeType: String?
    public let dueDate: String?
    public let revision: Int?
    public var creatorId: String? = nil
    public var creatorType: String? = nil
    public var updatedAt: String? = nil
    public var lastActivityAt: String? = nil
}

public struct IssueTimelineEntry: Decodable, Identifiable, Sendable {
    public let id: String
    public let type: String
    public let createdAt: String
    public let actorType: String?
    public let actorId: String?
    public let action: String?
    public let content: String?
    public let details: JSONValue?
}
public struct IssuePage: Decodable, Sendable { public let issues: [Issue]; public let total: Int }
/// `POST /api/issues/batch-update` returns only a count. It never names the ids
/// it skipped, so callers must not treat `updated` as a per-item receipt.
public struct BatchUpdateReply: Decodable, Sendable { public let updated: Int }
public struct IssueStatus: Decodable, Identifiable, Sendable {
    public let key: String
    public let name: String
    public let category: String
    public let archivedAt: String?
    public var id: String { key }
}
public struct StatusCatalog: Decodable, Sendable { public let statuses: [IssueStatus] }

public enum DisplayText {
    public static func error(_ error: Error) -> String {
        if let value = error as? APIError { return value.errorDescription ?? "请求失败，请重试。" }
        if error is DecodingError { return "服务返回的数据不完整，请刷新重试。" }
        if error is CancellationError || (error as? URLError)?.code == .cancelled { return "操作已取消。" }
        return "暂时无法连接，请重试。已加载的内容和草稿会保留。"
    }
    public static func status(_ key: String) -> String {
        ["queued":"排队中", "running":"执行中", "in_progress":"进行中", "done":"已完成", "completed":"已完成", "failed":"执行失败", "cancelled":"已取消", "todo":"待开始", "blocked":"受阻", "in_review":"待审核", "planned":"已规划", "online":"在线", "offline":"离线"][key] ?? key
    }
    public static func failure(_ reason: String) -> String {
        switch reason {
        case "timeout", "runtime_cli_timeout", "codex_semantic_inactivity": "任务等待超时，可以稍后重试。"
        case "runtime_offline", "runtime_recovery": "执行设备暂时离线，请等待设备恢复。"
        case "manual", "cancelled": "任务已停止。"
        case "agent_error.provider_auth_or_access": "模型服务需要重新验证登录或权限。"
        case "agent_error.provider_quota_limit": "模型服务额度不足，请检查账号额度。"
        case "agent_error.provider_capacity_or_rate_limit": "模型服务繁忙，请稍后重试。"
        case "agent_error.provider_network": "连接模型服务失败，请检查网络后重试。"
        case "agent_error.context_overflow": "对话内容超过模型容量，请在 Multica 中整理上下文后重试。"
        default: "这次任务未能完成，可以展开执行过程查看详情。"
        }
    }
    /// Align with the Android trace presentation boundary; never log raw traces.
    public static func redactTrace(_ source: String) -> String {
        let patterns = [
            #"(?i)\bBearer\s+[A-Za-z0-9\-._~+/]+=*"#,
            #"\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9_]{36,255}\b|\bgithub_pat_[A-Za-z0-9_]{20,255}\b"#,
            #"\b(?:sk-|glpat-)[A-Za-z0-9_-]{20,}\b|\bAIza[0-9A-Za-z_-]{35}\b|\bAKIA[0-9A-Z]{16}\b"#,
            #"\bxox[bporas]-[A-Za-z0-9-]{10,}\b|\bey[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b"#,
            #"-----BEGIN[A-Z\s]*PRIVATE KEY-----[\s\S]*?-----END[A-Z\s]*PRIVATE KEY-----"#,
            #"(?i)(?:postgres|mysql|mongodb|redis|amqp)(?:ql)?://[^:\s]+:[^@\s]+@"#,
            #"(?i)(?:API_KEY|API_SECRET|SECRET_KEY|SECRET|ACCESS_TOKEN|AUTH_TOKEN|PRIVATE_KEY|DATABASE_URL|DB_PASSWORD|DB_URL|REDIS_URL|PASSWORD|TOKEN)\s*[=:]\s*\S+"#
        ]
        return patterns.reduce(source) { $0.replacingOccurrences(of: $1, with: "[已隐藏凭据]", options: .regularExpression) }
    }
    public static func redactInput(_ value: JSONValue) -> JSONValue {
        switch value {
        case .object(let object):
            let sensitive: Set<String> = ["apikey", "apisecret", "secretkey", "secret", "token", "accesstoken", "authtoken", "authorization", "password", "dbpassword", "privatekey", "databasurl", "databaseurl", "dburl", "redisurl", "awssecretaccesskey"]
            return .object(object.mapValues { redactInput($0) }.merging(object.filter { sensitive.contains($0.key.lowercased().replacingOccurrences(of: "_", with: "").replacingOccurrences(of: "-", with: "")) }.mapValues { _ in .string("[已隐藏凭据]") }) { _, new in new })
        case .array(let values): return .array(values.map(redactInput))
        case .string(let value): return .string(redactTrace(value))
        default: return value
        }
    }
    public static func message(_ source: String) -> String {
        guard let range = source.range(of: "```quick-actions", options: .backwards) else { return source }
        let suffix = source[range.upperBound...]
        if let end = suffix.range(of: "```"), !suffix[end.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return source }
        return String(source[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
