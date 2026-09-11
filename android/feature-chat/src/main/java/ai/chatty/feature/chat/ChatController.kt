package ai.chatty.feature.chat

import ai.chatty.core.model.*
import ai.chatty.core.network.ChatApi
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.json.*
import retrofit2.HttpException
import okhttp3.MultipartBody

interface ChatDrafts {
    suspend fun read(key: String): String
    suspend fun write(key: String, value: String)
    /** Project selection is persisted alongside the draft. null means "never set"; fall back to the session. */
    suspend fun readProject(key: String): String? = null
    suspend fun writeProject(key: String, value: String?) {}
}
data class ChatState(
    val sessions: List<ChatSession> = emptyList(), val agents: List<ChatAgent> = emptyList(),
    val userId: String? = null, val role: String? = null,
    val session: ChatSession? = null, val agent: ChatAgent? = null,
    val messages: List<ChatMessage> = emptyList(), val cursor: MessageCursor? = null, val hasMore: Boolean = false,
    val pending: PendingTask = PendingTask(), val traces: Map<String, List<TaskTrace>> = emptyMap(),
    val generic: List<String> = emptyList(), val draft: String = "", val attachments: List<Attachment> = emptyList(),
    val projects: List<Project> = emptyList(), val selectedProjectId: String? = null, val projectError: String? = null,
    val loading: Boolean = true, val loadingOlder: Boolean = false, val sending: Boolean = false,
    val uncertain: Boolean = false, val connected: Boolean = false, val notice: String? = null, val error: String? = null,
    val capabilitiesCurrent: Boolean = false
) {
    val canSend get() = capabilitiesCurrent && !loading && !sending && !uncertain && (pending.task_id == null || pending.supports_queue) &&
        session?.status != "archived" &&
        agent?.let { it.archived_at == null && it.runtime_bound != false && it.runtime_id.isNotBlank() && canChat(it, userId, role) } == true &&
        (draft.isNotBlank() || attachments.isNotEmpty())
    val canStop get() = pending.task_id != null && !sending
    val queuedTasks get() = pending.queued_tasks.orEmpty()
    val selectedProjectName get() = selectedProjectId?.let { id -> projects.find { it.id == id }?.title } ?: "不指定项目"
}

class ChatController(private val api: ChatApi, private val drafts: ChatDrafts, private val workspace: Workspace,
    private val scope: CoroutineScope, private val events: (() -> Flow<JsonObject>)? = null) {
    private val mutable = MutableStateFlow(ChatState())
    val state = mutable.asStateFlow()
    private var generation = 0
    private val refreshLock = Mutex()
    private var stream: Job? = null
    private var fallback: Job? = null
    private var refreshJob: Job? = null
    private var contentJob: Job? = null
    private var refreshAgain = false
    private var selectedAgentId: String? = null
    private val json = Json { ignoreUnknownKeys = true }
    private fun draftKey() = "${workspace.id}:${state.value.session?.id ?: "new:" + selectedAgentId}"
    private fun launch(block: suspend () -> Unit) = scope.launch {
        try { block() } catch (e: CancellationException) { throw e } catch (e: Exception) { mutable.update { it.copy(error = errorText(e), loading = false) } }
    }
    suspend fun initialize() {
        try {
            val (sessions, agents, user, members) = readContext()
            val role = members.find { it.user_id == user.id }?.role
            val available = agents.filter { it.archived_at == null && canChat(it, user.id, role) }
            val mika = available.find { it.system_key == "mika" } ?: available.find { it.system_key == null && it.name.equals("Mika", true) }
            mutable.update { it.copy(sessions = orderedSessions(sessions), agents = agents, userId = user.id, role = role, agent = mika, capabilitiesCurrent = true, loading = false, error = if (mika == null) "此工作区尚未配置可用的 Mika，请在设置中检查 Agents。" else null) }
            loadProjects()
            val initial = sessions.filter { it.status != "archived" && it.agent_id == mika?.id }.maxByOrNull { it.updated_at }
            if (initial != null) open(initial) else newChat(state.value.agent)
        } catch (e: CancellationException) { throw e } catch (e: Exception) { mutable.update { it.copy(loading = false, error = errorText(e)) } }
    }
    private data class Bootstrap(val sessions: List<ChatSession>, val agents: List<ChatAgent>, val user: ChatUser, val members: List<ChatMember>)
    private suspend fun readContext() = coroutineScope {
        val s = async { api.sessions() }; val a = async { api.agents() }; val u = async { api.me() }; val m = async { api.members(workspace.id) }
        Bootstrap(s.await(), a.await(), u.await(), m.await())
    }
    fun start() {
        if (stream?.isActive == true || fallback?.isActive == true) return
        stream = scope.launch {
            var attempt = 0
            while (isActive && events != null) {
                try { events.invoke().collect { frame ->
                    if (frame["type"]?.jsonPrimitive?.contentOrNull == "auth_ack") { attempt = 0; mutable.update { it.copy(connected = true) }; refresh() }
                    else onEvent(frame)
                } } catch (e: CancellationException) { throw e } catch (_: Exception) { }
                mutable.update { it.copy(connected = false) }
                delay((1000L shl attempt.coerceAtMost(5)) + kotlin.random.Random.nextLong(300)); attempt++
            }
        }
        // No periodic full refresh. When connected, WebSocket events drive the UI; REST is only a
        // reconciliation fallback while disconnected or while a task is pending.
        fallback = scope.launch {
            while (isActive) {
                delay(15000)
                val s = state.value
                if (s.session == null) continue
                if (!s.connected || s.pending.task_id != null) refreshContent()
            }
        }
        if (!state.value.loading) refresh()
    }
    fun stop() { stream?.cancel(); fallback?.cancel(); stream = null; fallback = null; mutable.update { it.copy(connected = false) } }
    fun open(session: ChatSession) {
        if (state.value.sending) return
        selectedAgentId = session.agent_id
        generation++; val g = generation
        mutable.update { it.copy(session = session, agent = it.agents.find { a -> a.id == session.agent_id }, messages = emptyList(), pending = PendingTask(), cursor = null, hasMore = false, generic = emptyList(), draft = "", attachments = emptyList(), loading = true, loadingOlder = false, traces = emptyMap(), uncertain = false, notice = null, error = null) }
        launch {
            val draft = drafts.read(draftKey())
            val savedProject = drafts.readProject(draftKey())
            if (g == generation) mutable.update { it.copy(draft = draft, selectedProjectId = savedProject ?: session.project_id) }
            refreshNow(g)
            if (g == generation && session.has_unread) {
                api.markRead(session.id)
                mutable.update { it.copy(sessions = it.sessions.map { s -> if (s.id == session.id) s.copy(has_unread = false, unread_count = 0) else s }) }
            }
        }
    }
    fun newChat(agent: ChatAgent?) {
        if (state.value.sending || agent == null) return
        selectedAgentId = agent.id
        generation++; val g = generation
        mutable.update { it.copy(session = null, agent = agent, messages = emptyList(), pending = PendingTask(), generic = emptyList(), cursor = null, hasMore = false, loading = false, loadingOlder = false, traces = emptyMap(), draft = "", attachments = emptyList(), uncertain = false, notice = null, error = null) }
        launch { val text = drafts.read(draftKey()); val project = drafts.readProject(draftKey()); if (g == generation) mutable.update { it.copy(draft = text, selectedProjectId = project) } }
    }
    fun draft(text: String) {
        mutable.update { it.copy(draft = text) }; val key = draftKey()
        launch { drafts.write(key, text) }
    }
    fun loadProjects() {
        launch {
            try { val page = api.projects(); mutable.update { it.copy(projects = page.projects, projectError = null) } }
            catch (e: CancellationException) { throw e } catch (e: Exception) { mutable.update { it.copy(projectError = "项目列表暂时无法加载，请重试。") } }
        }
    }
    fun selectProject(id: String?) {
        if (id != null && state.value.projects.none { it.id == id }) return
        val key = draftKey()
        mutable.update { it.copy(selectedProjectId = id, notice = null) }
        launch { drafts.writeProject(key, id) }
    }
    /** Seed a Mika discussion for an issue without discarding an existing draft. */
    fun prepareIssueDiscussion(issue: Issue) {
        val link = "关于 [${issue.identifier} · ${issue.title}](mention://issue/${issue.id})：\n"
        if (state.value.draft.isNotBlank()) { mutable.update { it.copy(notice = "草稿已有内容，未覆盖。") }; return }
        val key = draftKey()
        val project = issue.project_id
        mutable.update { it.copy(draft = link, selectedProjectId = project, notice = null) }
        launch { drafts.write(key, link); drafts.writeProject(key, project) }
    }
    fun removeAttachment(id: String) { mutable.update { it.copy(attachments = it.attachments.filterNot { a -> a.id == id }) } }
    fun upload(file: MultipartBody.Part) {
        if (state.value.sending) return
        mutable.update { it.copy(sending = true, error = null) }
        launch { try { val a = api.upload(file); mutable.update { it.copy(attachments = (it.attachments + a).distinctBy { a -> a.id }) } } finally { mutable.update { it.copy(sending = false) } } }
    }
    fun acknowledgeUncertain() { mutable.update { it.copy(uncertain = false, notice = null, error = null) } }
    fun refresh() {
        refreshAgain = true
        mutable.update { it.copy(capabilitiesCurrent = false) }
        if (refreshJob?.isActive == true) return
        refreshJob = launch {
            while (refreshAgain) {
                refreshAgain = false
                if (state.value.userId == null) initialize() else {
                    val g = generation
                    mutable.update { it.copy(capabilitiesCurrent = false) }
                    val (sessions, agents, user, members) = readContext()
                    if (g != generation) { refreshAgain = true; continue }
                    val role = members.find { it.user_id == user.id }?.role
                    // Retain the conversation identity even if its Agent temporarily disappears.
                    val id = state.value.session?.agent_id ?: selectedAgentId
                    val available = agents.filter { it.archived_at == null && canChat(it, user.id, role) }
                    val agent = if (id != null) agents.find { it.id == id } else
                        available.find { it.system_key == "mika" } ?: available.find { it.system_key == null && it.name.equals("Mika", true) }
                    if (selectedAgentId == null) selectedAgentId = agent?.id
                    mutable.update { it.copy(sessions = orderedSessions(sessions), session = sessions.find { s -> s.id == it.session?.id } ?: it.session,
                        agents = agents, agent = agent, userId = user.id, role = role) }
                    refreshNow(g)
                    if (g == generation) mutable.update { it.copy(capabilitiesCurrent = true,
                        error = if (it.uncertain) it.error else if (agent == null) "此工作区尚未配置可用的 Mika，请在设置中检查 Agents。" else null) }
                    else refreshAgain = true
                }
            }
        }
    }
    /**
     * Content-only reconciliation (messages + pending). Identity, permission and capability
     * checks stay in refresh(); polling and task events must not re-read them.
     */
    fun refreshContent() {
        if (refreshJob?.isActive == true || contentJob?.isActive == true) return
        val g = generation
        contentJob = launch {
            try { refreshNow(g) } finally { contentJob = null }
        }
    }
    private suspend fun refreshNow(g: Int) = refreshLock.withLock {
        if (g != generation) return@withLock
        val session = state.value.session ?: return@withLock
        val (page, pending) = coroutineScope { val p = async { api.messages(session.id) }; val t = async { api.pending(session.id) }; p.await() to t.await() }
        if (g != generation) return@withLock
        mutable.update { old ->
            val first = page.messages.firstOrNull()
            val earlier = if (first == null) emptyList() else old.messages.filter { it.created_at < first.created_at || (it.created_at == first.created_at && it.id < first.id) }
            old.copy(messages = (earlier + page.messages).distinctBy { it.id }.filterNot { it.message_kind == "onboarding_kickoff" },
                pending = pending, loading = false, error = if (old.uncertain) old.error else null,
                cursor = if (earlier.isEmpty()) page.next_cursor else old.cursor, hasMore = if (earlier.isEmpty()) page.has_more else old.hasMore)
        }
        pending.task_id?.let { loadTrace(it) }
    }
    fun older() {
        val s = state.value; val cursor = s.cursor ?: return; val session = s.session ?: return
        if (s.loadingOlder) return
        val g = generation; mutable.update { it.copy(loadingOlder = true) }
        launch { try {
            val p = api.messages(session.id, beforeTime = cursor.created_at, beforeId = cursor.id)
            if (g == generation) mutable.update { it.copy(messages = (p.messages + it.messages).distinctBy { m -> m.id }, cursor = p.next_cursor, hasMore = p.has_more) }
        } finally { if (g == generation) mutable.update { it.copy(loadingOlder = false) } } }
    }
    fun loadTrace(taskId: String) = launch {
        val rows = api.trace(taskId)
        mutable.update { it.copy(traces = it.traces + (taskId to (rows + it.traces[taskId].orEmpty()).associateBy { r -> r.seq }.values.sortedBy { r -> r.seq })) }
    }
    fun send() {
        val s = state.value; if (!s.canSend) return
        val key = draftKey(); val text = s.draft.trim(); val g = generation
        mutable.update { it.copy(sending = true, error = null) }
        launch {
            var posted = false
            var accepted = false
            try {
                // The sent message keeps the project snapshot captured at send time.
                val projectId = s.selectedProjectId
                var session = s.session ?: api.create(NewChat(s.agent!!.id, projectId)).also { created -> mutable.update { it.copy(session = created, sessions = orderedSessions(it.sessions + created)) } }
                if (session.project_id != projectId) {
                    val confirmed = api.updateSession(session.id, ChatSessionUpdate(projectId))
                    session = confirmed
                    if (g == generation) mutable.update { it.copy(session = confirmed, sessions = orderedSessions(it.sessions.map { row -> if (row.id == confirmed.id) confirmed else row })) }
                    if (confirmed.project_id != projectId) {
                        // Never post under an unconfirmed project.
                        mutable.update { it.copy(error = "项目归属未能确认，消息没有提交。") }
                        return@launch
                    }
                }
                posted = true
                val receipt = api.send(session.id, SendMessage(text, s.attachments.map { it.id }))
                check(receipt.task_id.isNotBlank() && receipt.message_id.isNotBlank())
                accepted = true
                val boundIds = receipt.attachment_ids
                val dropped = if (boundIds == null) emptyList() else s.attachments.filterNot { it.id in boundIds }
                val bound = s.attachments.filterNot { a -> dropped.any { it.id == a.id } }
                if (g == generation) mutable.update {
                    // A send while a task is already in flight becomes a FIFO follow-up,
                    // never a replacement for the active turn.
                    val queued = it.pending.task_id != null && it.pending.task_id != receipt.task_id
                    val merged = enqueuePending(it.pending, QueuedTask(receipt.task_id, "queued", receipt.created_at, receipt.message_id, text), queued)
                    it.copy(draft = "", attachments = dropped, notice = dropped.takeIf { it.isNotEmpty() }?.let { "这些附件未随消息发送：" + it.joinToString { a -> a.filename } }, messages = (it.messages + ChatMessage(receipt.message_id, session.id, "user", text, receipt.task_id, receipt.created_at, bound)).distinctBy { m -> m.id },
                        pending = if (receipt.supports_queue) merged.copy(supports_queue = true) else merged)
                }
                drafts.write(key, ""); drafts.write("${workspace.id}:${session.id}", "")
                drafts.writeProject(key, null); drafts.writeProject("${workspace.id}:${session.id}", null)
                // A failed refresh after an accepted send never changes it into a failed POST.
                refresh()
            } catch (e: CancellationException) { throw e }
            catch (e: Exception) {
                val uncertain = posted && !accepted && !(e is HttpException && e.code() in 400..499)
                mutable.update { it.copy(uncertain = uncertain, error = if (uncertain) "发送结果尚未确认，请先刷新核对消息，避免重复发送。" else if (accepted) "消息已发送，本地草稿清理失败，请刷新核对。" else errorText(e)) }
                // Session creation may have succeeded before the send failed: keep draft under its new key.
                if (!accepted) drafts.write(draftKey(), text) else refresh()
            } finally { mutable.update { it.copy(sending = false) } }
        }
    }
    fun stopCurrent() {
        val s = state.value; val taskId = s.pending.task_id ?: return
        if (s.sending) return
        val g = generation
        mutable.update { it.copy(sending = true, error = null) }
        launch {
            try {
                val result = api.cancelTask(taskId)
                if (g == generation) {
                    val restored = result.cancelled_chat_message
                    mutable.update { old -> old.copy(pending = removePending(old.pending, taskId),
                        messages = restored?.let { r -> old.messages.filterNot { it.id == r.message_id } } ?: old.messages) }
                    restored?.takeIf { it.restore_to_input }?.let { restoreDraft(it.content, it.attachments.orEmpty()) }
                    refresh()
                }
            } catch (e: CancellationException) { throw e }
            catch (e: Exception) { if (g == generation) { mutable.update { it.copy(error = errorText(e)) }; refresh() } }
            finally { mutable.update { it.copy(sending = false) } }
        }
    }
    fun sendQueuedNow(taskId: String) {
        val s = state.value; val session = s.session ?: return
        if (s.sending) return
        val g = generation
        mutable.update { it.copy(sending = true, error = null, pending = prioritizePending(it.pending, taskId)) }
        launch {
            try {
                val result = api.prioritize(session.id, taskId)
                if (result.task_id != taskId) error("invalid prioritize response")
                val active = result.active_task_id
                if (active != null) {
                    val cancelled = api.cancelTask(active)
                    if (g == generation) {
                        val restored = cancelled.cancelled_chat_message
                        mutable.update { old -> old.copy(pending = removePending(old.pending, active),
                            messages = restored?.let { r -> old.messages.filterNot { it.id == r.message_id } } ?: old.messages) }
                        restored?.takeIf { it.restore_to_input }?.let { restoreDraft(it.content, it.attachments.orEmpty()) }
                    }
                }
                if (g == generation) refresh()
            } catch (e: CancellationException) { throw e }
            catch (e: Exception) { if (g == generation) { mutable.update { it.copy(error = errorText(e)) }; refresh() } }
            finally { mutable.update { it.copy(sending = false) } }
        }
    }
    fun editQueued(taskId: String) = cancelQueued(taskId, "edit")
    fun removeQueued(taskId: String) = cancelQueued(taskId, "remove")
    private fun cancelQueued(taskId: String, action: String) {
        val s = state.value; val session = s.session ?: return
        if (s.sending) return
        val g = generation
        mutable.update { it.copy(sending = true, error = null, pending = removePending(it.pending, taskId)) }
        launch {
            try {
                // The daemon may have claimed the task after our cached queued snapshot;
                // fall back to a plain stop so the action still lands.
                val result = try { api.cancelTask(taskId, expectedStatus = "queued", chatSessionId = session.id, queueAction = action) }
                    catch (e: HttpException) { if (e.code() == 409) api.cancelTask(taskId) else throw e }
                if (g == generation) {
                    val restored = result.cancelled_chat_message
                    mutable.update { old -> old.copy(messages = restored?.let { r -> old.messages.filterNot { it.id == r.message_id } } ?: old.messages) }
                    if (action == "edit") restored?.takeIf { it.restore_to_input }?.let { restoreDraft(it.content, it.attachments.orEmpty()) }
                    refresh()
                }
            } catch (e: CancellationException) { throw e }
            catch (e: Exception) { if (g == generation) { mutable.update { it.copy(error = errorText(e)) }; refresh() } }
            finally { mutable.update { it.copy(sending = false) } }
        }
    }
    fun clearQueued() {
        val s = state.value; val session = s.session ?: return
        if (s.sending || s.queuedTasks.isEmpty()) return
        val g = generation
        val ids = s.queuedTasks.mapNotNull { it.message_id }.toSet()
        mutable.update { it.copy(sending = true, error = null, pending = it.pending.copy(queued_tasks = emptyList()),
            messages = it.messages.filterNot { m -> m.id in ids }) }
        launch {
            try { api.clearQueued(session.id); if (g == generation) refresh() }
            catch (e: CancellationException) { throw e }
            catch (e: Exception) { if (g == generation) { mutable.update { it.copy(error = errorText(e)) }; refresh() } }
            finally { mutable.update { it.copy(sending = false) } }
        }
    }
    // Editing a queued message appends to whatever the user already typed; nothing is discarded.
    private fun restoreDraft(content: String, attachments: List<Attachment>) {
        val text = content.trim(); if (text.isEmpty() && attachments.isEmpty()) return
        val merged = listOf(state.value.draft.trim(), text).filter { it.isNotEmpty() }.joinToString("\n\n")
        mutable.update { it.copy(draft = merged, attachments = (it.attachments + attachments).distinctBy { a -> a.id }) }
        val key = draftKey()
        launch { drafts.write(key, merged) }
    }
    fun onEvent(frame: JsonObject) {
        val type = frame["type"]?.jsonPrimitive?.contentOrNull ?: return
        val p = frame["payload"] as? JsonObject ?: return
        val sessionId = p["chat_session_id"]?.jsonPrimitive?.contentOrNull
        val taskId = p["task_id"]?.jsonPrimitive?.contentOrNull
        if (type == "chat:session_deleted" && (p["id"]?.jsonPrimitive?.contentOrNull == state.value.session?.id || sessionId == state.value.session?.id && sessionId != null)) newChat(state.value.agent)
        val mine = sessionId == state.value.session?.id && sessionId != null || taskId != null && taskId == state.value.pending.task_id
        if (type.startsWith("chat:session_")) { refresh(); return }
        if (!mine) return
        when (type) {
            "task:message" -> runCatching { json.decodeFromJsonElement(TaskTrace.serializer(), p) }.onSuccess { row ->
                mutable.update { old -> old.copy(traces = old.traces + (row.task_id to (old.traces[row.task_id].orEmpty() + row).associateBy { it.seq }.values.sortedBy { it.seq })) }
            }
            // Converge the queue optimistically from sparse lifecycle hints; content refresh stays authoritative.
            "task:queued" -> { taskId?.let { id -> mutable.update { old -> old.copy(pending = enqueuePending(old.pending,
                QueuedTask(id, p["status"]?.jsonPrimitive?.contentOrNull ?: "queued", p["created_at"]?.jsonPrimitive?.contentOrNull.orEmpty()))) } }; refreshContent() }
            "task:dispatch", "task:running" -> { taskId?.let { id -> mutable.update { old -> old.copy(pending = promotePending(old.pending, id,
                p["status"]?.jsonPrimitive?.contentOrNull ?: "running", p["created_at"]?.jsonPrimitive?.contentOrNull,
                p["wait_reason"]?.jsonPrimitive?.contentOrNull)) } }; refreshContent() }
            "chat:done", "chat:message", "chat:quick_actions", "chat:cancel_finalized",
            "task:completed", "task:failed", "task:cancelled", "task:deferred" -> { taskId?.let { id -> mutable.update { old -> old.copy(pending = removePending(old.pending, id)) } }; refreshContent() }
            else -> mutable.update { it.copy(generic = (it.generic + frame.toString()).distinct().takeLast(30)) }
        }
    }
    private fun errorText(e: Exception) = when {
        e is HttpException && e.code() == 401 -> "登录已失效，请重新登录。"
        e is HttpException && e.code() == 403 -> "没有访问或调用这个 Agent 的权限。"
        e is HttpException && e.code() == 404 -> "会话或资源已不存在，请刷新会话列表。"
        e is HttpException && e.code() == 409 -> "Agent 当前无法接受请求，请刷新任务状态后重试。"
        else -> "暂时无法连接，请重试。草稿已保留。"
    }
}
