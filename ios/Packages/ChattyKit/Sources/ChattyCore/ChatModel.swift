import Foundation
import Observation

@MainActor @Observable public final class ChatModel {
    public private(set) var agent: ChatAgent?
    public private(set) var session: ChatSession?
    /// Every non-archived conversation with Mika, newest first, pinned on top.
    /// The history list renders this; the top bar titles the current one.
    public private(set) var sessions: [ChatSession] = []
    public private(set) var messages: [ChatMessage] = []
    public private(set) var pending: PendingTask?
    public private(set) var traces: [String: [TaskTrace]] = [:]
    public private(set) var unknownEvents: [String] = []
    public private(set) var draft = ""
    public private(set) var attachments: [Attachment] = []
    public private(set) var loading = false
    public private(set) var initialized = false
    public private(set) var loadingOlder = false
    public private(set) var sending = false
    public private(set) var uploading = false
    public private(set) var uncertain = false
    public private(set) var connected = false
    public private(set) var hasMore = false
    public private(set) var error: String?
    public private(set) var notice: String?
    public private(set) var attachmentBindingUncertain = false
    public private(set) var scrollRequest: UUID?
    public private(set) var outbox: [OutgoingMessage] = []
    public private(set) var projects: [Project] = []
    public private(set) var selectedProjectId: String?
    public private(set) var projectError: String?
    /// A stop / queue request is in flight. Drives the disabled state of every
    /// control that would otherwise be tapped twice into two server writes.
    public private(set) var stopping = false
    @ObservationIgnored public var onWorkspaceEvent: ((SocketEvent) -> Void)?
    @ObservationIgnored private let context: WorkspaceContext
    @ObservationIgnored private var visible = false
    @ObservationIgnored private var visibleCount = 0
    @ObservationIgnored private var foreground = true
    @ObservationIgnored private var markingRead = false
    @ObservationIgnored private var markedMessage: String?
    @ObservationIgnored private var cursor: MessageCursor?
    @ObservationIgnored private var role: String?
    @ObservationIgnored private var legacyAdoptionDone = false
    @ObservationIgnored private var newSessionPending = false
    @ObservationIgnored private var refreshing = false
    @ObservationIgnored private var refreshAgain = false
    @ObservationIgnored private var refreshJob: Task<Void, Never>?
    @ObservationIgnored private var polling: Task<Void, Never>?
    @ObservationIgnored private var receiptRows: [String: ChatMessage] = [:]
    /// Bumped whenever the displayed conversation changes. Every async path that
    /// resumes after an await compares its captured value before touching state,
    /// so a slow stop / send / page response cannot land in another conversation.
    @ObservationIgnored private var conversation = 0
    @ObservationIgnored private let connection = RealtimeConnection()

    init(context: WorkspaceContext) { self.context = context }

    /// Protected record key for the conversation on screen. A conversation the
    /// server has not created yet keeps its composer under a placeholder key, and
    /// the record moves onto the real id once the first send creates it.
    public var conversationKey: String { session?.id ?? ProtectedStorage.pendingSessionKey }
    /// Title for the navigation bar: the server's generated title, else the first
    /// user message, else the placeholder.
    public var sessionTitle: String {
        ChatSessions.displayTitle(session?.title, firstUserMessage: messages.first(where: { $0.role == "user" })?.content)
    }
    public var queuedTasks: [QueuedChatTask] { pending?.queuedTasks ?? [] }
    /// Stop is offered while a task is running, including while followers queue.
    public var canStop: Bool { pending?.taskId != nil && !stopping && !sending }

    public var canSend: Bool {
        guard context.active, initialized, !loading, !uploading, !attachmentBindingUncertain, !stopping, outbox.count < 100,
              let agent, agent.runtimeBound != false, !(agent.runtimeId ?? "").isEmpty,
              session?.status != "archived", AgentPermission.canChat(agent, userId: context.user.id, role: role) else { return false }
        return !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty
    }
    public func initialize() async {
        guard !loading, context.active else { return }
        loading = true; error = nil; defer { loading = false }
        do {
            async let agents: [ChatAgent] = context.api.get("/api/agents")
            async let members: [Member] = context.api.get("/api/workspaces/\(APIClient.segment(context.workspace.id))/members")
            async let sessions: [ChatSession] = context.api.get("/api/chat/sessions")
            let (allAgents, allMembers, allSessions) = try await (agents, members, sessions); try context.check()
            role = allMembers.first(where: { $0.userId == context.user.id })?.role
            agent = allAgents.first { $0.systemKey == "mika" && AgentPermission.canChat($0, userId: context.user.id, role: role) }
            guard let agent else { initialized = true; error = "此工作区没有可调用的 Mika。你可以在设置中切换工作区。"; return }
            self.sessions = ChatSessions.ordered(for: agent.id, in: allSessions)
            let remembered = try? context.files.lastSession(account: context.user.id, workspace: context.workspace.id, agent: agent.id)
            if let existing = session, let fresh = allSessions.first(where: { $0.id == existing.id && $0.status != "archived" }) { session = fresh }
            // Stage C remembers the conversation the user was actually in; Stage B
            // must not adopt the previous "latest" session while ⌘N is pending.
            else if !newSessionPending { session = ChatSessions.restored(for: agent.id, rememberedId: remembered ?? nil, in: allSessions) }
            rememberSession(agentId: agent.id)
            await loadDraft(allowLegacyAdoption: true)
            initialized = true
            await loadProjects()
            try await syncMessages()
            scrollRequest = UUID()
        } catch { self.error = await context.report(error) }
    }
    /// ⌘N: leave the current conversation and start a fresh one. The draft and
    /// attachments stay in the composer; the session itself is created by the
    /// next send, so cancelling costs nothing. Until then refresh must not adopt
    /// the previous "latest" session again.
    public func startNewSession() {
        guard context.active, initialized, agent != nil else { return }
        guard !sending, !uncertain, !stopping else { notice = "有正在发送或待核对的消息，先处理后再新建对话。"; return }
        flushDraft()
        newSessionPending = true
        conversation += 1
        session = nil
        messages = []; pending = nil; cursor = nil; hasMore = false; traces = [:]; receiptRows = [:]
        error = nil
        notice = "已开始新的对话，发送后会创建会话。"
        Task { [weak self] in await self?.loadDraft(allowLegacyAdoption: false) }
        scrollRequest = UUID()
    }
    /// Switch to a conversation from the history list. Everything the composer
    /// holds belongs to the conversation being left, so the record is flushed
    /// first and the target's own record is loaded before any network read.
    public func open(_ target: ChatSession) async {
        guard context.active, initialized, target.id != session?.id,
              target.agentId == agent?.id, target.status != "archived" else { return }
        flushDraft()
        conversation += 1
        session = target
        newSessionPending = false
        messages = []; pending = nil; cursor = nil; hasMore = false; traces = [:]; receiptRows = [:]
        error = nil
        rememberSession(agentId: target.agentId)
        await loadDraft(allowLegacyAdoption: false)
        do { try await syncMessages() } catch { self.error = await context.report(error) }
        scrollRequest = UUID()
    }
    public var isStartingNewSession: Bool { newSessionPending }
    public func start() {
        foreground = true
        guard context.active, polling == nil else { return }
        connection.start(api: context.api, onConnection: { [weak self] value in
            guard let self, self.context.active else { return }; self.connected = value
        }, onEvent: { [weak self] event in self?.onEvent(event) })
        polling = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(5)) } catch { break }
                guard let self, self.context.active else { break }
                if !self.connected || self.pending?.taskId != nil || self.error != nil || self.outbox.first?.status == .queued { await self.refresh() }
            }
        }
        refreshJob = Task { [weak self] in await self?.refresh() }
    }
    public func stop() {
        foreground = false; connection.stop(); polling?.cancel(); polling = nil; refreshJob?.cancel(); refreshJob = nil; connected = false
        outbox = outbox.map { var value = $0; if value.status == .queued { value.status = .held }; return value }
        flushDraft(failure: "未发送消息暂时无法保存，请保持应用打开。")
    }
    public func refresh() async {
        guard context.active else { return }
        if refreshing { refreshAgain = true; return }
        refreshing = true; defer { refreshing = false }
        repeat {
            refreshAgain = false
            if !initialized || agent == nil { await initialize() }
            else {
                do {
                    let all: [ChatSession] = try await context.api.get("/api/chat/sessions"); try context.check()
                    if let agent { sessions = ChatSessions.ordered(for: agent.id, in: all) }
                    if let current = session {
                        guard let fresh = all.first(where: { $0.id == current.id && $0.status != "archived" }) else {
                            conversation += 1
                            session = nil; messages = []; pending = nil; cursor = nil; hasMore = false; traces = [:]; receiptRows = [:]
                            rememberSession(agentId: current.agentId)
                            notice = "原对话已归档或删除，下次发送将创建新的 Mika 对话。"
                            await loadDraft(allowLegacyAdoption: false)
                            continue
                        }
                        session = fresh
                    } else if let agent, !newSessionPending { session = ChatSessions.latest(for: agent.id, in: all); rememberSession(agentId: agent.id) }
                    try await syncMessages()
                    error = nil
                } catch { self.error = await context.report(error) }
            }
        } while refreshAgain && context.active && !Task.isCancelled
        await flushOutbox()
    }
    private func syncMessages() async throws {
        guard let session else { return }
        let path = "/api/chat/sessions/\(APIClient.segment(session.id))"
        let scope = conversation
        async let pageRequest: MessagePage = context.api.get(path + "/messages/page", query: [.init(name: "limit", value: "50")])
        async let pending: PendingTask = context.api.get(path + "/pending-task")
        let (page, task) = try await (pageRequest, pending); try context.check()
        guard self.session?.id == session.id, scope == conversation else { return }
        // The server may broadcast an accepted message before its POST receipt.
        // Until the receipt gives us its ID, keep the local row as the visible
        // source. Matching on text would incorrectly collapse repeated messages.
        if !sending {
            for row in page.messages { receiptRows.removeValue(forKey: row.id) }
            let earlier = page.messages.first.map { first in messages.filter { ($0.createdAt ?? "", $0.id) < (first.createdAt ?? "", first.id) } } ?? []
            messages = MessagePages.merge(older: earlier, newer: page.messages + receiptRows.values.filter { $0.chatSessionId == session.id }).filter { $0.messageKind != "onboarding_kickoff" }
            if earlier.isEmpty { cursor = page.nextCursor; hasMore = page.hasMore ?? false }
        }
        self.pending = task
        if let taskId = task.taskId { await loadTrace(taskId) }
        await markRead()
    }
    /// Reference counted: several windows can show the same shared conversation,
    /// so one window disappearing must not clear the read state for the others.
    public func setVisible(_ value: Bool) async {
        visibleCount = max(0, visibleCount + (value ? 1 : -1))
        visible = visibleCount > 0
        if visible { await markRead() }
    }
    private func markRead() async {
        guard foreground, visible, context.active, !markingRead, let session, let last = messages.last?.id, last != markedMessage else { return }
        markingRead = true; defer { markingRead = false }
        do {
            _ = try await context.api.data("/api/chat/sessions/\(APIClient.segment(session.id))/read", method: "POST")
            try context.check(); markedMessage = last
        } catch { if error as? APIError == .http(401) { self.error = await context.report(error) } }
    }
    public func older() async {
        guard context.active, !loadingOlder, let cursor, let session else { return }
        loadingOlder = true; defer { loadingOlder = false }
        let scope = conversation
        do {
            let page: MessagePage = try await context.api.get("/api/chat/sessions/\(APIClient.segment(session.id))/messages/page", query: [.init(name: "limit", value: "50"), .init(name: "before_created_at", value: cursor.createdAt), .init(name: "before_id", value: cursor.id)])
            try context.check()
            guard scope == conversation, self.session?.id == session.id else { return }
            messages = MessagePages.merge(older: page.messages, newer: messages).filter { $0.messageKind != "onboarding_kickoff" }
            self.cursor = page.nextCursor; hasMore = page.hasMore ?? false
        } catch { self.error = await context.report(error) }
    }
    public func setDraft(_ text: String) {
        guard context.active else { return }
        draft = String(text.prefix(100_000))
        flushDraft(failure: "草稿暂时无法保存到本机，请保持应用打开。")
    }
    // MARK: - Per-conversation protected record

    private func loadDraft(allowLegacyAdoption: Bool) async {
        guard let agent else { return }
        let key = conversationKey
        do {
            var record = try context.files.draft(account: context.user.id, workspace: context.workspace.id, agent: agent.id, session: key)
            // An empty record is not "the user has something here": leaving a
            // conversation flushes one, and that must not strand an upgraded draft.
            if (record == nil || record?.isEmpty == true), allowLegacyAdoption, !legacyAdoptionDone {
                legacyAdoptionDone = true
                if let adopted = try context.files.adoptLegacyDraft(account: context.user.id, workspace: context.workspace.id, agent: agent.id, session: key) {
                    record = adopted
                }
            }
            let saved = record ?? DraftRecord()
            draft = saved.text
            uncertain = saved.uncertain
            attachments = saved.attachments ?? []
            selectedProjectId = saved.projectSelectionSet == true ? saved.projectId : session?.projectId
            outbox = (saved.outbox ?? []).map { message in
                var restored = message
                // Records written before the outbox was conversation-scoped carry
                // no session and belong to whatever conversation adopted them.
                if restored.sessionId == nil { restored.sessionId = key }
                if restored.status == .submitting { restored.status = .uncertain }
                else if restored.status == .queued { restored.status = .held }
                return restored
            }
            // V1 kept an uncertain send in the composer. Migrate it to a
            // review record so upgrading cannot submit it as a new draft.
            if saved.uncertain, saved.outbox == nil, !saved.text.isEmpty {
                var previousSend = OutgoingMessage(content: saved.text, attachments: [], projectId: selectedProjectId, sessionId: key)
                previousSend.status = .uncertain
                outbox = [previousSend]; draft = ""
                try persistDraft()
            }
            uncertain = uncertain || outbox.contains { $0.status == .uncertain }
        } catch { self.error = "暂时无法读取本机草稿，请解锁设备后重试。" }
    }
    private func persistDraft() throws {
        guard let agent else { return }
        try context.files.saveDraft(DraftRecord(text: draft, uncertain: uncertain, projectId: selectedProjectId, projectSelectionSet: true, outbox: outbox, attachments: attachments), account: context.user.id, workspace: context.workspace.id, agent: agent.id, session: conversationKey)
    }
    private func flushDraft(failure: String? = nil) {
        do { try persistDraft() } catch { if let failure { self.error = failure } }
    }
    /// Scene restoration: keep the conversation the user is actually in.
    private func rememberSession(agentId: String) {
        do { try context.files.saveLastSession(session?.id, account: context.user.id, workspace: context.workspace.id, agent: agentId) }
        catch { self.error = "会话位置暂时无法保存，请保持应用打开。" }
    }
    // MARK: - Stop and queue

    /// Stop the running task. The server tells us whether the cancelled text goes
    /// back to the composer; we never guess, because a partially delivered message
    /// must not be silently dropped or duplicated.
    public func stopCurrent() async {
        guard context.active, let taskId = pending?.taskId, !sending, !stopping else { return }
        await cancel(taskId: taskId, query: [], applying: true)
    }
    /// Promote a queued message to the front. The task it displaces is cancelled
    /// and its text returns to the composer, matching the Android client.
    public func sendQueuedNow(_ taskId: String) async {
        guard context.active, let session, !sending, !stopping, pending?.queuedTasks?.contains(where: { $0.taskId == taskId }) == true else { return }
        stopping = true; defer { stopping = false }
        let scope = conversation
        do {
            let result: PrioritizeQueuedResponse = try await context.api.write("/api/chat/sessions/\(APIClient.segment(session.id))/queued-tasks/\(APIClient.segment(taskId))/prioritize", body: [:])
            guard scope == conversation else { return }
            try context.check()
            guard result.taskId == taskId else { throw DeliveryError.invalidResponse }
            if let active = result.activeTaskId, active != taskId {
                let response: CancelTaskResponse = try await context.api.write("/api/tasks/\(APIClient.segment(active))/cancel", body: [:])
                guard scope == conversation else { return }
                apply(response.cancelledChatMessage, taskId: active)
            }
            await refresh()
        } catch {
            guard scope == conversation else { return }
            self.error = await context.report(error); await refresh()
        }
    }
    /// `edit` returns the queued text to the composer, `remove` discards it.
    public func editQueued(_ taskId: String) async { await cancelQueued(taskId, action: .edit) }
    public func removeQueued(_ taskId: String) async { await cancelQueued(taskId, action: .remove) }
    private func cancelQueued(_ taskId: String, action: QueueCancelAction) async {
        guard context.active, let session, !sending, !stopping,
              pending?.queuedTasks?.contains(where: { $0.taskId == taskId }) == true else { return }
        let query = [URLQueryItem(name: "expected_status", value: "queued"),
                     URLQueryItem(name: "chat_session_id", value: session.id),
                     URLQueryItem(name: "queue_action", value: action.rawValue)]
        await cancel(taskId: taskId, query: query, applying: action == .edit)
    }
    private func cancel(taskId: String, query: [URLQueryItem], applying restore: Bool) async {
        guard context.active, !sending, !stopping else { return }
        stopping = true; defer { stopping = false }
        let scope = conversation
        func request(_ items: [URLQueryItem]) async throws -> CancelTaskResponse {
            try await context.api.write("/api/tasks/\(APIClient.segment(taskId))/cancel", body: [:], query: items)
        }
        do {
            var response: CancelTaskResponse
            do { response = try await request(query) }
            catch APIError.http(409) where !query.isEmpty {
                // The daemon may have claimed the task after our cached snapshot.
                // Fall back to a plain stop so the action still lands.
                response = try await request([])
            }
            guard scope == conversation else { return }
            try context.check()
            apply(response.cancelledChatMessage, taskId: taskId, restoringInput: restore)
            await refresh()
        } catch {
            guard scope == conversation else { return }
            self.error = await context.report(error); await refresh()
        }
    }
    private func apply(_ cancelled: CancelledChatMessage?, taskId: String, restoringInput: Bool = true) {
        if let messageId = cancelled?.messageId {
            messages.removeAll { $0.id == messageId }
            receiptRows.removeValue(forKey: messageId)
        }
        pending = pendingWithout(taskId)
        if restoringInput, cancelled?.restoreToInput == true {
            mergeRestoredDraft(cancelled?.content, attachments: cancelled?.attachments ?? [])
        }
        flushDraft(failure: "取消结果暂时无法保存，请保持应用打开。")
    }
    private func pendingWithout(_ taskId: String) -> PendingTask? {
        guard var current = pending else { return nil }
        if current.taskId == taskId {
            let queued = current.queuedTasks ?? []
            guard let next = queued.first else { return nil }
            return PendingTask(taskId: next.taskId, status: next.status, waitReason: nil, supportsQueue: current.supportsQueue, queuedTasks: Array(queued.dropFirst()))
        }
        current.queuedTasks = (current.queuedTasks ?? []).filter { $0.taskId != taskId }
        return current
    }
    /// Clearing the queue is optimistic: the rows are removed locally first so the
    /// list cannot flicker back, then the server confirms and `refresh()` converges.
    public func clearQueued() async {
        guard context.active, let session, !sending, !stopping, let queued = pending?.queuedTasks, !queued.isEmpty else { return }
        stopping = true; defer { stopping = false }
        let scope = conversation
        let removed = Set(queued.compactMap(\.messageId))
        pending?.queuedTasks = []
        messages.removeAll { removed.contains($0.id) }
        do {
            _ = try await context.api.data("/api/chat/sessions/\(APIClient.segment(session.id))/queued-tasks", method: "DELETE")
            guard scope == conversation else { return }
            try context.check()
            await refresh()
        } catch {
            guard scope == conversation else { return }
            self.error = await context.report(error); await refresh()
        }
    }
    /// Never discard what the user already typed: restored text is appended.
    private func mergeRestoredDraft(_ content: String?, attachments restored: [Attachment]) {
        let text = (content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            let existing = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            draft = [existing, text].filter { !$0.isEmpty }.joined(separator: "\n\n")
        }
        for file in restored where !attachments.contains(where: { $0.id == file.id }) { attachments.append(file) }
    }
    // MARK: - Composer

    public func acknowledgeUncertain() {
        guard context.active, !sending else { return }
        let previous = outbox
        outbox.removeAll { $0.status == .uncertain }
        uncertain = false; notice = nil
        do {
            try persistDraft(); error = nil
            Task { [weak self] in await self?.refresh() }
        } catch { outbox = previous; self.error = "无法保存核对状态，请重试。"; uncertain = true }
    }
    /// Explicit user decision after checking history; never called by refresh.
    public func retryUncertainAfterReview() async {
        guard context.active, !sending, let index = outbox.firstIndex(where: { $0.status == .uncertain }) else { return }
        let previous = outbox
        outbox[index].status = .queued; outbox[index].failure = nil
        uncertain = outbox.contains { $0.status == .uncertain }
        do { try persistDraft() }
        catch { outbox = previous; uncertain = true; self.error = "无法保存核对结果，请重试。"; return }
        error = nil; notice = nil
        await refresh()
    }
    public func removeAttachment(_ id: String) {
        guard context.active else { return }
        attachments.removeAll { $0.id == id }
        if attachments.isEmpty { attachmentBindingUncertain = false }
        flushDraft(failure: "附件状态暂时无法保存，请保持应用打开。")
    }
    public func upload(data: Data, filename: String, contentType: String) async {
        guard context.active, !uploading else { return }
        uploading = true; error = nil; defer { uploading = false }
        do {
            let file = try await context.api.upload(data: data, filename: filename, contentType: contentType); try context.check()
            if !attachments.contains(where: { $0.id == file.id }) { attachments.append(file); flushDraft() }
        } catch { self.error = await context.report(error) }
    }
    /// Composer drop target: Files / Photos / other apps. Validation lives in
    /// `AttachmentImport` so a drop cannot bypass the picker's limits.
    public func upload(fileURL: URL) async {
        do { await upload(imported: try AttachmentImport.read(fileURL: fileURL)) }
        catch { self.error = await context.report(error) }
    }
    public func upload(imported: ImportedAttachment) async {
        await upload(data: imported.data, filename: imported.filename, contentType: imported.contentType)
    }
    public var selectedProjectName: String {
        guard let selectedProjectId else { return "不指定项目" }
        return projects.first { $0.id == selectedProjectId }?.title ?? "原项目暂不可用"
    }
    public func loadProjects() async {
        do {
            let page: ProjectPage = try await context.api.get("/api/projects"); try context.check()
            projects = page.projects; projectError = nil
        } catch { projectError = await context.report(error) }
    }
    public func selectProject(_ id: String?) {
        guard context.active, id == nil || projects.contains(where: { $0.id == id }) else { return }
        let previous = selectedProjectId; selectedProjectId = id
        do { try persistDraft() }
        catch { selectedProjectId = previous; self.error = "项目选择暂时无法保存，请重试。" }
    }
    public func prepareIssueDiscussion(_ issue: Issue) {
        guard context.active else { return }
        guard draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty else {
            notice = "已保留当前草稿。发送后可从事项详情继续讨论。"; return
        }
        let previous = selectedProjectId
        selectedProjectId = issue.projectId
        draft = "关于 [\(issue.identifier) · \(issue.title)](mention://issue/\(APIClient.segment(issue.identifier)))：\n"
        do { try persistDraft() }
        catch { selectedProjectId = previous; draft = ""; self.error = "事项上下文暂时无法保存，请重试。" }
    }
    // MARK: - Sending

    public func send() async {
        guard canSend else { return }
        let previousDraft = draft, previousFiles = attachments
        let item = OutgoingMessage(content: draft.trimmingCharacters(in: .whitespacesAndNewlines), attachments: attachments, projectId: selectedProjectId, sessionId: session?.id)
        // One atomic protected record owns both composer and outbox: a crash
        // cannot restore the same text as an unsent draft and a queued message.
        outbox.append(item); draft = ""; attachments = []; error = nil; notice = nil
        do { try persistDraft() }
        catch {
            outbox.removeAll { $0.id == item.id }; draft = previousDraft; attachments = previousFiles
            self.error = "消息暂时无法保存，内容仍保留在输入框中。"; return
        }
        scrollRequest = UUID()
        await flushOutbox()
    }
    public func resumeOutbox() async {
        guard context.active, !sending, !uncertain else { return }
        let previous = outbox
        outbox = outbox.map { var item = $0; if item.status == .held { item.status = .queued }; return item }
        do { try persistDraft() }
        catch { outbox = previous; self.error = "无法恢复发送，请重试。"; return }
        error = nil
        // Recheck the server's pending state before resuming an old queue.
        await refresh()
    }
    public func retryOutgoing(_ id: UUID) async {
        guard context.active, !sending, let index = outbox.firstIndex(where: { $0.id == id }), outbox[index].status == .failed else { return }
        outbox[index].status = .queued; outbox[index].failure = nil; error = nil
        do { try persistDraft() }
        catch { outbox[index].status = .failed; self.error = "无法保存重试状态，请重试。"; return }
        await refresh()
    }
    public func editOutgoing(_ id: UUID) {
        guard context.active, let item = outbox.first(where: { $0.id == id }), [.failed, .held, .queued].contains(item.status) else { return }
        let oldDraft = draft, oldFiles = attachments, oldOutbox = outbox, oldProject = selectedProjectId
        // Different project requirements must not be silently combined.
        guard draft.isEmpty && attachments.isEmpty || selectedProjectId == item.projectId else {
            notice = "输入框已有其他项目的草稿，请先发送或保存后再编辑这条消息。"; return
        }
        draft = draft.isEmpty ? item.content : draft + "\n" + item.content
        selectedProjectId = item.projectId
        attachments += item.attachments.filter { file in !attachments.contains { $0.id == file.id } }
        outbox.removeAll { $0.id == id }
        do { try persistDraft() }
        catch { draft = oldDraft; attachments = oldFiles; outbox = oldOutbox; selectedProjectId = oldProject; self.error = "无法恢复编辑，请重试。" }
    }
    private var canDeliver: Bool {
        guard let agent else { return false }
        return context.active && foreground && initialized && !loading && !sending && !uncertain && error == nil &&
            agent.runtimeBound != false && !(agent.runtimeId ?? "").isEmpty && session?.status != "archived" &&
            AgentPermission.canChat(agent, userId: context.user.id, role: role) &&
            !(pending?.taskId != nil && pending?.supportsQueue != true)
    }
    private func flushOutbox() async {
        guard canDeliver, outbox.first?.status == .queued, let agent else { return }
        let scope = conversation
        do {
            sending = true
            defer { sending = false }
            while context.active && foreground && !uncertain, scope == conversation, let item = outbox.first, item.status == .queued {
                guard !(pending?.taskId != nil && pending?.supportsQueue != true) else { break }
                var posted = false, accepted = false
                do {
                    outbox[0].status = .submitting; try persistDraft()
                    if session == nil {
                        var body: [String: JSONValue] = ["agent_id": .string(agent.id)]
                        if let project = item.projectId { body["project_id"] = .string(project) }
                        let created: ChatSession = try await context.api.write("/api/chat/sessions", body: body)
                        try context.check()
                        guard scope == conversation else { return }
                        // The composer for this conversation lives under the pending
                        // key until now; move it so the record follows the real id.
                        try context.files.migrateDraft(account: context.user.id, workspace: context.workspace.id, agent: agent.id, from: ProtectedStorage.pendingSessionKey, to: created.id)
                        session = created; newSessionPending = false; rememberSession(agentId: agent.id)
                    }
                    guard var current = session else { throw APIError.http(404) }
                    // Refresh responses can race this loop. Reaffirm each snapshot
                    // on the server instead of trusting a cached session project.
                    current = try await context.api.write("/api/chat/sessions/\(APIClient.segment(current.id))", method: "PATCH", body: ["project_id": item.projectId.map(JSONValue.string) ?? .null])
                    try context.check()
                    guard scope == conversation else { return }
                    session = current
                    guard current.projectId == item.projectId else { throw DeliveryError.projectMismatch }
                    try context.check()
                    guard foreground, scope == conversation else {
                        if let index = outbox.firstIndex(where: { $0.id == item.id }) { outbox[index].status = .held }
                        try persistDraft(); return
                    }
                    posted = true
                    let bytes = try await context.api.data("/api/chat/sessions/\(APIClient.segment(current.id))/messages", method: "POST", body: ["content": .string(item.content), "attachment_ids": .array(item.attachments.map { .string($0.id) })])
                    let receipt = try Contracts.receipt(from: bytes); accepted = true; try context.check()
                    guard scope == conversation else { return }
                    let bound = item.attachments.filter { receipt.attachmentIds?.contains($0.id) == true }
                    let unbound = item.attachments.filter { receipt.attachmentIds?.contains($0.id) != true }
                    if !unbound.isEmpty {
                        attachments += unbound.filter { file in !attachments.contains { $0.id == file.id } }
                        attachmentBindingUncertain = receipt.attachmentIds == nil
                        notice = "部分附件绑定尚未确认，请核对后移除已发送的附件。"
                    }
                    let row = ChatMessage(id: receipt.messageId, chatSessionId: current.id, role: "user", content: item.content, taskId: receipt.taskId, createdAt: receipt.createdAt, attachments: bound, messageKind: "message", failureReason: nil, elapsedMs: nil, quickActions: nil)
                    receiptRows[row.id] = row
                    messages = MessagePages.merge(older: messages, newer: [row]); scrollRequest = UUID()
                    if let active = pending, let activeId = active.taskId, activeId != receipt.taskId {
                        var next = PendingTask(taskId: activeId, status: active.status, waitReason: active.waitReason, supportsQueue: receipt.supportsQueue ?? active.supportsQueue)
                        next.queuedTasks = (active.queuedTasks ?? []) + [QueuedChatTask(taskId: receipt.taskId, status: "queued", createdAt: receipt.createdAt, messageId: receipt.messageId, content: item.content)]
                        pending = next
                    } else { pending = PendingTask(taskId: receipt.taskId, status: "queued", waitReason: nil, supportsQueue: receipt.supportsQueue) }
                    outbox.removeAll { $0.id == item.id }
                    try persistDraft()
                } catch {
                    guard context.active, scope == conversation else { return }
                    let definite = (error as? APIError).map { if case .http(let code) = $0 { return (400..<500).contains(code) && code != 408 }; return false } ?? false
                    if let index = outbox.firstIndex(where: { $0.id == item.id }) {
                        outbox[index].status = posted && !accepted && !definite ? .uncertain : .failed
                        outbox[index].failure = error is DeliveryError ? "项目归属未能确认，请刷新项目后重试。" : DisplayText.error(error)
                    }
                    uncertain = outbox.contains { $0.status == .uncertain }
                    if accepted { notice = "消息已接受，本地保存尚未完成，请刷新核对。" }
                    self.error = error is DeliveryError ? "项目归属未能确认，消息没有提交。" : await context.report(error)
                    do { try persistDraft() } catch { self.error = "发送状态暂时无法保存，请保持应用打开并核对消息。" }
                    return
                }
            }
        }
        await refresh()
    }
    public func loadTrace(_ taskId: String) async {
        do {
            let rows: [TaskTrace] = try await context.api.get("/api/tasks/\(APIClient.segment(taskId))/messages"); try context.check()
            traces[taskId] = TraceRows.merge(traces[taskId] ?? [], rows)
        } catch { self.error = await context.report(error) }
    }
    private func onEvent(_ event: SocketEvent) {
        guard context.active else { return }
        onWorkspaceEvent?(event)
        if event.type == "auth_ack" || event.type.hasPrefix("chat:session_") {
            refreshJob = Task { [weak self] in await self?.refresh() }; return
        }
        let payload = event.payload?.object ?? [:]
        let taskId = payload["task_id"]?.string; let sid = payload["chat_session_id"]?.string
        guard sid != nil && sid == session?.id || taskId != nil && (taskId == pending?.taskId || messages.contains { $0.taskId == taskId }) else { return }
        if event.type == "task:message", let body = event.payload, let data = try? JSONEncoder().encode(body), let row = try? Contracts.decode(TaskTrace.self, from: data) {
            traces[row.taskId] = TraceRows.merge(traces[row.taskId] ?? [], [row])
        } else if event.type.hasPrefix("chat:") || event.type.hasPrefix("task:") {
            refreshJob = Task { [weak self] in await self?.refresh() }
        } else { unknownEvents = Array((unknownEvents + [event.type]).suffix(30)) }
    }
}

private enum DeliveryError: Error { case projectMismatch, invalidResponse }
