import Foundation

/// Local-only multi-selection over the rows currently loaded in one activity
/// list. It never holds server truth: every id in it must also be present in
/// the loaded page, which `prune(keeping:)` enforces after each refresh.
public struct SelectionSet: Equatable, Sendable {
    public private(set) var ids: Set<String>
    public init(_ ids: Set<String> = []) { self.ids = ids }
    public var isEmpty: Bool { ids.isEmpty }
    public var count: Int { ids.count }
    public func contains(_ id: String) -> Bool { ids.contains(id) }
    public mutating func toggle(_ id: String) {
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
    }
    public mutating func insert(_ id: String) { ids.insert(id) }
    public mutating func removeAll() { ids.removeAll() }
    /// Drop anything that left the loaded page so a batch can never act on a
    /// row the user can no longer see.
    public mutating func prune(keeping available: [String]) { ids.formIntersection(Set(available)) }
    public mutating func setAll(_ available: [String], selected: Bool) {
        if selected { ids = Set(available) } else { ids.subtract(available) }
    }
    public func allSelected(_ available: [String]) -> Bool { !available.isEmpty && ids == Set(available) }
    /// Sorted only for deterministic assertions; submission order always comes
    /// from the loaded rows, never from this.
    public var ordered: [String] { ids.sorted() }
}

/// The `updates` object of `POST /api/issues/batch-update`. Fields mirror the
/// server's `UpdateIssueRequest` subset that the batch handler honours
/// (multica-ai/multica `server/internal/handler/issue.go` BatchUpdateIssues).
public struct IssueBatchUpdate: Equatable, Sendable {
    public var status: String?
    public var priority: String?
    public var assigneeType: String?
    public var assigneeID: String?
    public var projectID: String?
    public var dueDate: String?
    public var stage: Int?
    /// Batch-wide "apply the change but skip the agent run it would trigger",
    /// matching the single-issue status write. Not itself a mutation.
    public var suppressRun: Bool?

    public init(status: String? = nil, priority: String? = nil, assigneeType: String? = nil, assigneeID: String? = nil,
                projectID: String? = nil, dueDate: String? = nil, stage: Int? = nil, suppressRun: Bool? = nil) {
        self.status = status; self.priority = priority; self.assigneeType = assigneeType; self.assigneeID = assigneeID
        self.projectID = projectID; self.dueDate = dueDate; self.stage = stage; self.suppressRun = suppressRun
    }

    /// The server short-circuits to `{"updated": 0}` when no mutation field is
    /// present, so the client must never submit such a request and report it as
    /// a no-op success.
    public var hasMutation: Bool {
        status != nil || priority != nil || assigneeType != nil || assigneeID != nil
            || projectID != nil || dueDate != nil || stage != nil
    }

    public var json: [String: JSONValue] {
        var values: [String: JSONValue] = [:]
        if let status { values["status"] = .string(status) }
        if let priority { values["priority"] = .string(priority) }
        if let assigneeType { values["assignee_type"] = .string(assigneeType) }
        if let assigneeID { values["assignee_id"] = .string(assigneeID) }
        if let projectID { values["project_id"] = .string(projectID) }
        if let dueDate { values["due_date"] = .string(dueDate) }
        if let stage { values["stage"] = .number(Double(stage)) }
        if let suppressRun { values["suppress_run"] = .bool(suppressRun) }
        return values
    }

    /// Done / todo are server-validated status keys when the workspace catalog
    /// carries them; the ids are the built-in defaults the Android client uses.
    public static func completion(suppressRun: Bool = true) -> IssueBatchUpdate { .init(status: "done", suppressRun: suppressRun) }
    public static func returnToTodo(suppressRun: Bool = true) -> IssueBatchUpdate { .init(status: "todo", suppressRun: suppressRun) }
}

/// Honest accounting of one batch submission.
///
/// `updated` is the only number the endpoint returns (`{"updated": N}`); the
/// server silently `continue`s over ids it cannot resolve or is not allowed to
/// touch, so it never names which ones those were. `skipped` is therefore an
/// aggregate, and `retryIDs` holds entire chunks rather than individual ids:
/// re-submitting a chunk is the smallest honest retry, because the status write
/// is idempotent.
public struct BatchResult: Equatable, Sendable {
    public let requested: Int
    public let updated: Int
    public let skipped: Int
    public let failed: Int
    public let retryIDs: [String]
    public let messages: [String]

    public init(requested: Int, updated: Int, skipped: Int, failed: Int, retryIDs: [String], messages: [String]) {
        self.requested = requested; self.updated = updated; self.skipped = skipped
        self.failed = failed; self.retryIDs = retryIDs; self.messages = messages
    }

    public var isFullSuccess: Bool { failed == 0 && skipped == 0 && updated == requested }
    public var unfinished: Int { skipped + failed }
    public var canRetry: Bool { !retryIDs.isEmpty }

    public var summary: String {
        guard requested > 0 else { return "没有可提交的事项。" }
        if isFullSuccess { return "已提交 \(requested) 项，全部成功。" }
        var parts = ["已提交 \(requested) 项：成功 \(updated)"]
        if skipped > 0 { parts.append("未生效 \(skipped)") }
        if failed > 0 { parts.append("失败 \(failed)") }
        return parts.joined(separator: "，") + "。"
    }
}

/// Folds each chunk reply into the batch totals. Pure, so the partial-failure
/// and clamping rules are unit-testable without a server.
public struct BatchAccumulator: Sendable {
    public private(set) var requested = 0
    public private(set) var updated = 0
    public private(set) var skipped = 0
    public private(set) var failed = 0
    public private(set) var retryIDs: [String] = []
    public private(set) var messages: [String] = []
    private var acceptedIDs: [String] = []

    public init() {}

    /// A chunk the server accepted with HTTP 2xx. `reported` is clamped to the
    /// chunk size: a server that over-reports must never inflate the totals.
    public mutating func record(chunk: [String], updated reported: Int) {
        requested += chunk.count
        let accepted = max(0, min(reported, chunk.count))
        updated += accepted
        skipped += chunk.count - accepted
        // Only a chunk that actually changed something counts as reached: an
        // all-skipped chunk leaves every row's state and red dot untouched, so
        // the caller must not treat it as reviewed.
        if accepted > 0 { acceptedIDs.append(contentsOf: chunk) }
        if accepted < chunk.count { retryIDs.append(contentsOf: chunk) }
    }

    /// A chunk rejected as a whole (HTTP error, transport failure, or a 409
    /// status race that aborted mid-loop). The applied subset is unknown, so
    /// every id stays retryable and the caller must re-read from the server.
    public mutating func recordFailure(chunk: [String], message: String) {
        requested += chunk.count
        failed += chunk.count
        retryIDs.append(contentsOf: chunk)
        if !messages.contains(message) { messages.append(message) }
    }

    public var hasAccepted: Bool { !acceptedIDs.isEmpty }

    /// Ids from chunks in which at least one write landed, i.e. the rows whose
    /// server state actually moved. Used to mirror `ActivityModel.apply`'s
    /// mark-read side effect after the lists are refreshed.
    public var acceptedIssueIDs: [String] { acceptedIDs }

    public func result() -> BatchResult {
        var seen = Set<String>()
        return BatchResult(requested: requested, updated: updated, skipped: skipped, failed: failed,
                           retryIDs: retryIDs.filter { seen.insert($0).inserted }, messages: messages)
    }
}

public enum BatchChunking {
    /// Small batches keep one bad status or a mid-loop 409 from wasting a large
    /// submission and keep the retry surface small.
    public static let size = 20

    public static func unique(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    public static func chunks(_ ids: [String], size: Int = BatchChunking.size) -> [[String]] {
        guard size > 0 else { return ids.isEmpty ? [] : [ids] }
        var result: [[String]] = []
        var index = 0
        while index < ids.count {
            let end = min(index + size, ids.count)
            result.append(Array(ids[index..<end]))
            index = end
        }
        return result
    }
}
