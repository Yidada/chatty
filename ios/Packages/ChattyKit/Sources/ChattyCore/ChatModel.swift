import Foundation
import Observation

@MainActor @Observable public final class ChatModel {
    public private(set) var agent: ChatAgent?
    public private(set) var session: ChatSession?
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
    @ObservationIgnored private let context: WorkspaceContext
    @ObservationIgnored private var visible = false
    @ObservationIgnored private var foreground = true
    @ObservationIgnored private var markingRead = false
    @ObservationIgnored private var markedMessage: String?
    @ObservationIgnored private var cursor: MessageCursor?
    @ObservationIgnored private var role: String?
    @ObservationIgnored private var draftLoaded = false
    @ObservationIgnored private var refreshing = false
    @ObservationIgnored private var refreshAgain = false
    @ObservationIgnored private var refreshJob: Task<Void, Never>?
    @ObservationIgnored private var polling: Task<Void, Never>?
    @ObservationIgnored private let connection = RealtimeConnection()

    init(context: WorkspaceContext) { self.context = context }
    public var canSend: Bool {
        guard context.active, initialized, !loading, !sending, !uploading, !uncertain, !attachmentBindingUncertain,
              pending?.taskId == nil, let agent, agent.runtimeBound != false, !(agent.runtimeId ?? "").isEmpty,
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
            if let existing = session, let fresh = allSessions.first(where: { $0.id == existing.id && $0.status != "archived" }) { session = fresh }
            else { session = ChatSessions.latest(for: agent.id, in: allSessions) }
            if !draftLoaded {
                let saved = try context.files.draft(account: context.user.id, workspace: context.workspace.id, agent: agent.id)
                draft = saved.text; uncertain = saved.uncertain; draftLoaded = true
            }
            initialized = true
            try await syncMessages()
            scrollRequest = UUID()
        } catch { self.error = await context.report(error) }
    }
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
                if !self.connected || self.pending?.taskId != nil || self.error != nil { await self.refresh() }
            }
        }
        refreshJob = Task { [weak self] in await self?.refresh() }
    }
    public func stop() { foreground = false; connection.stop(); polling?.cancel(); polling = nil; refreshJob?.cancel(); refreshJob = nil; connected = false }
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
                    if let current = session {
                        guard let fresh = all.first(where: { $0.id == current.id && $0.status != "archived" }) else {
                            session = nil; messages = []; pending = nil; cursor = nil; hasMore = false; traces = [:]
                            notice = "原对话已归档或删除，下次发送将创建新的 Mika 对话。"; continue
                        }
                        session = fresh
                    } else if let agent { session = ChatSessions.latest(for: agent.id, in: all) }
                    try await syncMessages()
                    error = nil
                } catch { self.error = await context.report(error) }
            }
        } while refreshAgain && context.active && !Task.isCancelled
    }
    private func syncMessages() async throws {
        guard let session else { return }
        let path = "/api/chat/sessions/\(APIClient.segment(session.id))"
        async let pageRequest: MessagePage = context.api.get(path + "/messages/page", query: [.init(name: "limit", value: "50")])
        async let pending: PendingTask = context.api.get(path + "/pending-task")
        let (page, task) = try await (pageRequest, pending); try context.check()
        let earlier = page.messages.first.map { first in messages.filter { ($0.createdAt ?? "", $0.id) < (first.createdAt ?? "", first.id) } } ?? []
        messages = MessagePages.merge(older: earlier, newer: page.messages).filter { $0.messageKind != "onboarding_kickoff" }
        if earlier.isEmpty { cursor = page.nextCursor; hasMore = page.hasMore ?? false }
        self.pending = task
        if let taskId = task.taskId { await loadTrace(taskId) }
        await markRead()
    }
    public func setVisible(_ value: Bool) async { visible = value; if value { await markRead() } }
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
        do {
            let page: MessagePage = try await context.api.get("/api/chat/sessions/\(APIClient.segment(session.id))/messages/page", query: [.init(name: "limit", value: "50"), .init(name: "before_created_at", value: cursor.createdAt), .init(name: "before_id", value: cursor.id)])
            try context.check()
            messages = MessagePages.merge(older: page.messages, newer: messages).filter { $0.messageKind != "onboarding_kickoff" }
            self.cursor = page.nextCursor; hasMore = page.hasMore ?? false
        } catch { self.error = await context.report(error) }
    }
    public func setDraft(_ text: String) {
        guard context.active else { return }
        draft = String(text.prefix(100_000))
        do { try persistDraft() } catch { self.error = "草稿暂时无法保存到本机，请保持应用打开。" }
    }
    private func persistDraft() throws {
        guard let agent else { return }
        try context.files.saveDraft(DraftRecord(text: draft, uncertain: uncertain), account: context.user.id, workspace: context.workspace.id, agent: agent.id)
    }
    public func acknowledgeUncertain() {
        guard context.active, !sending else { return }
        uncertain = false; notice = nil
        do { try persistDraft() } catch { self.error = "无法保存核对状态，请重试。"; uncertain = true }
    }
    public func removeAttachment(_ id: String) {
        guard !sending else { return }
        attachments.removeAll { $0.id == id }
        if attachments.isEmpty { attachmentBindingUncertain = false }
    }
    public func upload(data: Data, filename: String, contentType: String) async {
        guard context.active, !sending, !uploading else { return }
        uploading = true; error = nil; defer { uploading = false }
        do {
            let file = try await context.api.upload(data: data, filename: filename, contentType: contentType); try context.check()
            if !attachments.contains(where: { $0.id == file.id }) { attachments.append(file) }
        } catch { self.error = await context.report(error) }
    }
    public func send() async {
        guard canSend, let agent else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines); let files = attachments
        sending = true; error = nil; notice = nil
        var submitted = false; var accepted = false
        defer { sending = false }
        do {
            // Persist ambiguity before any write so suspension/crash cannot silently resend.
            uncertain = true; try persistDraft(); submitted = true
            if session == nil {
                let created: ChatSession = try await context.api.write("/api/chat/sessions", body: ["agent_id": .string(agent.id)])
                try context.check(); session = created
            }
            guard let session else { throw APIError.http(404) }
            let bytes = try await context.api.data("/api/chat/sessions/\(APIClient.segment(session.id))/messages", method: "POST", body: ["content": .string(text), "attachment_ids": .array(files.map { .string($0.id) })])
            let receipt = try Contracts.receipt(from: bytes); accepted = true; try context.check()
            uncertain = false; draft = ""
            if let bound = receipt.attachmentIds { attachments = files.filter { !bound.contains($0.id) } }
            else { attachments = files; attachmentBindingUncertain = !files.isEmpty }
            if !attachments.isEmpty { notice = "部分附件绑定尚未确认，请核对消息并移除已发送的附件。" }
            pending = PendingTask(taskId: receipt.taskId, status: "queued", waitReason: nil, supportsQueue: receipt.supportsQueue)
            let bound = files.filter { file in receipt.attachmentIds?.contains(file.id) ?? false }
            let row = ChatMessage(id: receipt.messageId, chatSessionId: session.id, role: "user", content: text, taskId: receipt.taskId, createdAt: receipt.createdAt, attachments: bound, messageKind: "message", failureReason: nil, elapsedMs: nil, quickActions: nil)
            messages = MessagePages.merge(older: messages, newer: [row]); scrollRequest = UUID()
            try persistDraft()
            await refresh()
        } catch {
            guard context.active else { return }
            let definite = (error as? APIError).map { if case .http(let code) = $0 { return (400..<500).contains(code) }; return false } ?? false
            uncertain = submitted && !accepted && !definite
            if accepted { notice = "消息已接受，本地更新尚未完成，请刷新核对。" }
            else if uncertain { notice = "发送结果待确认。请先刷新核对消息，避免重复发送。" }
            self.error = await context.report(error)
            if context.active { do { try persistDraft() } catch { self.error = "草稿无法保存，请保持应用打开并先核对消息。" } }
        }
    }
    public func loadTrace(_ taskId: String) async {
        do {
            let rows: [TaskTrace] = try await context.api.get("/api/tasks/\(APIClient.segment(taskId))/messages"); try context.check()
            traces[taskId] = TraceRows.merge(traces[taskId] ?? [], rows)
        } catch { self.error = await context.report(error) }
    }
    private func onEvent(_ event: SocketEvent) {
        guard context.active else { return }
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
