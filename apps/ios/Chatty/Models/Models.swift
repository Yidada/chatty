import Foundation

// 领域模型。命名与 docs/architecture.md 保持一致：Harness、Model、Context、Agent、Session。
// 原型阶段由 DemoData 提供数据；接入 Runner 后改为由协议生成的类型填充。

struct ModelInfo: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
}

struct HarnessInfo: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let isAvailable: Bool
    /// 不可用时显示的说明，例如“第二阶段”
    let note: String?
    let models: [ModelInfo]
    let defaultModelID: String?

    func model(_ modelID: String) -> ModelInfo? {
        models.first { $0.id == modelID }
    }
}

struct AgentConfig: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var harnessID: String
    var modelID: String
    /// Context 的简化表示：仓库名
    var repo: String
}

struct RunnerInfo: Hashable, Sendable {
    var name: String
    var address: String
    var isConnected: Bool
}

enum SessionState: Hashable, Sendable {
    case idle
    case running
    case awaitingApproval
}

enum PermissionMode: String, CaseIterable, Identifiable, Sendable {
    case ask
    case acceptEdits
    case plan

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ask: "需审批"
        case .acceptEdits: "自动编辑"
        case .plan: "只规划"
        }
    }
}

struct ToolStep: Identifiable, Hashable, Sendable {
    let id: UUID
    let icon: String
    let title: String

    init(icon: String, title: String) {
        self.id = UUID()
        self.icon = icon
        self.title = title
    }
}

struct FileChange: Identifiable, Hashable, Sendable {
    let id: UUID
    let path: String
    let added: Int
    let removed: Int

    init(path: String, added: Int, removed: Int) {
        self.id = UUID()
        self.path = path
        self.added = added
        self.removed = removed
    }
}

struct ApprovalRequest: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let command: String

    init(title: String, command: String) {
        self.id = UUID()
        self.title = title
        self.command = command
    }
}

enum ApprovalDecision: Sendable {
    case approve
    case approveForSession
    case reject
    case rejectWithNote
}

/// 时间线条目。对应协议草案中的 Timeline Item。
struct TimelineItem: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case user
        case agent
        case tools
        case changes
        case notice
    }

    let id: UUID
    let kind: Kind
    var text: String
    var steps: [ToolStep]
    var isRunning: Bool
    var changes: [FileChange]

    init(kind: Kind, text: String = "", steps: [ToolStep] = [], isRunning: Bool = false, changes: [FileChange] = []) {
        self.id = UUID()
        self.kind = kind
        self.text = text
        self.steps = steps
        self.isRunning = isRunning
        self.changes = changes
    }

    static func user(_ text: String) -> TimelineItem { TimelineItem(kind: .user, text: text) }
    static func agent(_ text: String) -> TimelineItem { TimelineItem(kind: .agent, text: text) }
    static func notice(_ text: String) -> TimelineItem { TimelineItem(kind: .notice, text: text) }
    static func tools(_ steps: [ToolStep], running: Bool = false) -> TimelineItem {
        TimelineItem(kind: .tools, steps: steps, isRunning: running)
    }
    static func changes(_ files: [FileChange]) -> TimelineItem { TimelineItem(kind: .changes, changes: files) }
}

struct ChatSession: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var repo: String
    var branch: String
    var harnessID: String
    var modelID: String
    var state: SessionState
    var updatedAt: Date
    var items: [TimelineItem]
    var approval: ApprovalRequest?

    init(
        title: String,
        repo: String,
        harnessID: String,
        modelID: String,
        state: SessionState = .idle,
        updatedAt: Date = .now,
        items: [TimelineItem] = [],
        approval: ApprovalRequest? = nil
    ) {
        let id = UUID()
        self.id = id
        self.title = title
        self.repo = repo
        self.branch = "chatty/s-" + id.uuidString.prefix(4).lowercased()
        self.harnessID = harnessID
        self.modelID = modelID
        self.state = state
        self.updatedAt = updatedAt
        self.items = items
        self.approval = approval
    }
}

/// 抽屉中按仓库分组的会话
struct SessionGroup: Identifiable, Sendable {
    let repo: String
    let sessions: [ChatSession]

    var id: String { repo }
}
