import Foundation
import Observation

/// The feed is workspace-wide. Personal inbox recipient filters deliberately
/// do not determine which project work can appear here.
@MainActor @Observable public final class ActivityModel {
    public private(set) var recent: [Issue] = []
    public private(set) var actions: [Issue] = []
    public private(set) var projects: [Project] = []
    public private(set) var statuses: [IssueStatus] = []
    public private(set) var recentTotal = 0
    public private(set) var actionTotal = 0
    public private(set) var loading = false
    public private(set) var loadingMore = false
    public private(set) var error: String?
    public private(set) var actionError: String?
    public private(set) var readError: String?
    public private(set) var reads: [String: String] = [:]
    /// True while a batch submission owns the wire. Guards double submission;
    /// the status write itself is idempotent, so a lost reply is retryable.
    public private(set) var batching = false
    public private(set) var batchProgress = 0
    public private(set) var batchProgressTotal = 0
    public private(set) var batchResult: BatchResult?
    @ObservationIgnored private var lastBatch: (ids: [String], update: IssueBatchUpdate)?
    @ObservationIgnored private let context: WorkspaceContext
    @ObservationIgnored private var recentOffset = 0
    @ObservationIgnored private var actionOffset = 0
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var poll: Task<Void, Never>?
    @ObservationIgnored private var refreshJob: Task<Void, Never>?

    init(context: WorkspaceContext) {
        self.context = context
        do { reads = try context.files.activityReads(account: context.user.id, workspace: context.workspace.id) }
        catch { readError = "已读状态暂时无法恢复，请重试。" }
    }
    public var hasAttention: Bool { actionTotal > 0 || recent.contains(where: isUnread) }
    public func hasMore(actions: Bool) -> Bool { actions ? actionOffset < actionTotal : recentOffset < recentTotal }
    public func projectName(_ id: String?) -> String { projects.first { $0.id == id }?.title ?? "未归属项目" }
    public func statusName(_ issue: Issue) -> String { statuses.first { $0.key == issue.status }?.name ?? DisplayText.status(issue.status) }
    public func category(_ issue: Issue) -> String { issue.statusCategory ?? statuses.first { $0.key == issue.status }?.category ?? issue.status }
    public func needsAction(_ issue: Issue) -> Bool { ["in_review", "blocked"].contains(category(issue)) }
    public func summary(_ issue: Issue) -> String {
        switch category(issue) {
        case "in_review": "已进入审核，等待确认。"
        case "blocked": "当前受阻，需要进一步处理。"
        case "done": "事项已完成。"
        case "cancelled": "事项已取消。"
        case "in_progress": "事项正在推进。"
        case "todo": "事项已记录，等待开始。"
        default: "当前状态：\(statusName(issue))"
        }
    }
    public static func fingerprint(_ issue: Issue) -> String {
        // Semantic activity is preferred over bookkeeping timestamps. Status is
        // included for older servers without last_activity_at.
        "\(issue.lastActivityAt ?? issue.updatedAt ?? String(issue.revision ?? 0))|\(issue.status)"
    }
    public func isUnread(_ issue: Issue) -> Bool { reads[issue.id] != Self.fingerprint(issue) }
    public func markRead(_ issue: Issue) { _ = store([issue]) }
    /// Batch read: one protected-storage write for the whole selection, so a
    /// partially written red-dot state cannot appear.
    public func markRead(_ issues: [Issue]) { _ = store(issues) }
    /// Mark the loaded rows whose ids are selected. Ids that left the page are
    /// skipped rather than guessed: the fingerprint needs the current row.
    @discardableResult
    public func markRead(ids: Set<String>) -> Int {
        guard context.active, !ids.isEmpty else { return 0 }
        return store(Self.unique(recent + actions).filter { ids.contains($0.id) })
    }
    private func store(_ issues: [Issue]) -> Int {
        guard context.active, !issues.isEmpty else { return 0 }
        var next = reads
        for issue in issues { next[issue.id] = Self.fingerprint(issue) }
        do {
            try context.files.saveActivityReads(next, account: context.user.id, workspace: context.workspace.id)
            reads = next; readError = nil
            return issues.count
        } catch { readError = "已读状态未保存，请重试。"; return 0 }
    }
    public func apply(_ issue: Issue) {
        guard context.active else { return }
        recent = recent.map { $0.id == issue.id ? issue : $0 }
        if needsAction(issue) {
            if actions.contains(where: { $0.id == issue.id }) { actions = actions.map { $0.id == issue.id ? issue : $0 } }
            else { actions.insert(issue, at: 0); actionTotal += 1; actionOffset += 1 }
        } else if actions.contains(where: { $0.id == issue.id }) {
            actions.removeAll { $0.id == issue.id }; actionTotal = max(0, actionTotal - 1); actionOffset = max(0, actionOffset - 1)
        }
        markRead(issue)
        scheduleRefresh()
    }
    /// `POST /api/issues/batch-update`, one small chunk at a time.
    ///
    /// The endpoint answers `{"updated": N}` and silently skips ids it cannot
    /// resolve or is not allowed to touch, so the result tracks success /
    /// skip / failure separately and never reports a partial write as a full
    /// one. Neither list is updated optimistically: after submitting, the model
    /// re-reads from the server and only then mirrors `apply`'s mark-read side
    /// effect for the chunks the server answered.
    @discardableResult
    public func batchUpdate(ids: [String], update: IssueBatchUpdate) async -> BatchResult? {
        guard context.active, !batching, update.hasMutation else { return nil }
        let ordered = BatchChunking.unique(ids)
        guard !ordered.isEmpty else { return nil }
        batching = true; batchResult = nil
        let chunks = BatchChunking.chunks(ordered)
        batchProgressTotal = chunks.count; batchProgress = 0
        defer { batching = false; batchProgress = 0; batchProgressTotal = 0 }
        var accumulator = BatchAccumulator()
        for chunk in chunks {
            if !context.active { return nil }
            do {
                let reply: BatchUpdateReply = try await context.api.write(
                    "/api/issues/batch-update",
                    body: ["issue_ids": .array(chunk.map { .string($0) }), "updates": .object(update.json)]
                )
                try context.check()
                accumulator.record(chunk: chunk, updated: reply.updated)
            } catch {
                guard context.active, !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return nil }
                let message = await context.report(error) ?? DisplayText.error(error)
                accumulator.recordFailure(chunk: chunk, message: message)
            }
            batchProgress += 1
        }
        let result = accumulator.result()
        batchResult = result
        lastBatch = (result.retryIDs, update)
        await refresh(force: true)
        if accumulator.hasAccepted { _ = markRead(ids: Set(accumulator.acceptedIssueIDs)) }
        return result
    }
    /// Re-submit the chunks that were not confirmed. Each chunk is idempotent,
    /// so a retry can never double-apply a status change.
    @discardableResult
    public func retryLastBatch() async -> BatchResult? {
        guard let last = lastBatch, !last.ids.isEmpty else { return nil }
        return await batchUpdate(ids: last.ids, update: last.update)
    }
    public func clearBatchOutcome() {
        batchResult = nil; lastBatch = nil; batchProgress = 0; batchProgressTotal = 0
    }
    private var actionKeys: String { Array(Set(statuses.filter { ["in_review", "blocked"].contains($0.category) }.map(\.key) + ["in_review", "blocked"])).sorted().joined(separator: ",") }
    private func page(offset: Int, actions: Bool) async throws -> IssuePage {
        var query = [URLQueryItem(name: "limit", value: "50"), .init(name: "offset", value: String(offset)), .init(name: "sort", value: "last_activity"), .init(name: "direction", value: "desc")]
        if actions { query.append(.init(name: "statuses", value: actionKeys)) }
        return try await context.api.get("/api/issues", query: query)
    }
    public func refresh() async { await refresh(force: false) }
    /// `force` lets a batch discard an in-flight poll refresh (its generation
    /// stops matching) so the lists converge on the state the batch just wrote
    /// instead of on a snapshot taken before it.
    public func refresh(force: Bool) async {
        guard context.active, force || !loading else { return }
        generation += 1; let g = generation
        loading = true; defer { if g == generation { loading = false } }
        do {
            async let projectRequest: ProjectPage = context.api.get("/api/projects")
            async let catalogRequest: StatusCatalog = context.api.get("/api/issue-statuses")
            async let recentRequest: IssuePage = page(offset: 0, actions: false)
            let projectPage = try await projectRequest; try context.check()
            guard g == generation else { return }; projects = projectPage.projects
            do {
                let catalog = try await catalogRequest; try context.check()
                statuses = catalog.statuses.filter { $0.archivedAt == nil }; actionError = nil
            } catch {
                actionError = await context.report(error).map { "待处理状态目录未能更新：" + $0 }
            }
            let first = try await recentRequest; try context.check()
            guard g == generation else { return }
            recent = Self.unique(first.issues); recentTotal = first.total; recentOffset = first.issues.count
            if first.issues.isEmpty { recentOffset = first.total }
            self.error = nil
            guard actionError == nil else { return }
            do {
                let pending = try await page(offset: 0, actions: true); try context.check()
                guard g == generation else { return }
                actions = Self.unique(pending.issues).filter(needsAction); actionTotal = pending.total
                actionOffset = pending.issues.isEmpty ? pending.total : pending.issues.count
            } catch { actionError = await context.report(error) }
        } catch { if g == generation { self.error = await context.report(error) } }
    }
    public func more(actions pending: Bool) async {
        guard context.active, !loading, !loadingMore, hasMore(actions: pending) else { return }
        let g = generation, offset = pending ? actionOffset : recentOffset
        loadingMore = true; defer { loadingMore = false }
        do {
            let next = try await page(offset: offset, actions: pending); try context.check()
            guard g == generation else { return }
            if pending {
                actions = Self.unique(actions + next.issues).filter(needsAction); actionTotal = next.total
                actionOffset = next.issues.isEmpty ? next.total : offset + next.issues.count; actionError = nil
            } else {
                recent = Self.unique(recent + next.issues); recentTotal = next.total
                recentOffset = next.issues.isEmpty ? next.total : offset + next.issues.count; error = nil
            }
        } catch { if pending { actionError = await context.report(error) } else { self.error = await context.report(error) } }
    }
    private static func unique(_ values: [Issue]) -> [Issue] {
        var ids = Set<String>(); return values.filter { ids.insert($0.id).inserted }
    }
    public func start() {
        guard context.active, poll == nil else { return }
        refreshJob = Task { [weak self] in await self?.refresh() }
        poll = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)) } catch { break }
                guard let self, self.context.active else { return }
                await self.refresh()
            }
        }
    }
    public func stop() { poll?.cancel(); poll = nil; refreshJob?.cancel(); refreshJob = nil }
    public func scheduleRefresh() {
        guard context.active, poll != nil else { return }
        refreshJob?.cancel()
        refreshJob = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            await self?.refresh()
        }
    }
}
