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

interface ChatDrafts { suspend fun read(key: String): String; suspend fun write(key: String, value: String) }
data class ChatState(
    val sessions: List<ChatSession> = emptyList(), val agents: List<ChatAgent> = emptyList(),
    val userId: String? = null, val role: String? = null,
    val session: ChatSession? = null, val agent: ChatAgent? = null,
    val messages: List<ChatMessage> = emptyList(), val cursor: MessageCursor? = null, val hasMore: Boolean = false,
    val pending: PendingTask = PendingTask(), val traces: Map<String, List<TaskTrace>> = emptyMap(),
    val generic: List<String> = emptyList(), val draft: String = "", val attachments: List<Attachment> = emptyList(),
    val loading: Boolean = true, val loadingOlder: Boolean = false, val sending: Boolean = false,
    val uncertain: Boolean = false, val connected: Boolean = false, val notice: String? = null, val error: String? = null
) {
    val canSend get() = !loading && !sending && !uncertain && pending.task_id == null && session?.status != "archived" &&
        agent?.let { it.archived_at == null && it.runtime_bound != false && it.runtime_id.isNotBlank() && canChat(it, userId, role) } == true &&
        (draft.isNotBlank() || attachments.isNotEmpty())
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
    private var refreshAgain = false
    private val json = Json { ignoreUnknownKeys = true }
    private fun draftKey() = "${workspace.id}:${state.value.session?.id ?: "new:" + state.value.agent?.id}"
    private fun launch(block: suspend () -> Unit) = scope.launch {
        try { block() } catch (e: CancellationException) { throw e } catch (e: Exception) { mutable.update { it.copy(error = errorText(e), loading = false) } }
    }
    suspend fun initialize() {
        try {
            val (sessions, agents, user, members) = coroutineScope {
                val s = async { api.sessions() }; val a = async { api.agents() }; val u = async { api.me() }; val m = async { api.members(workspace.id) }
                Bootstrap(s.await(), a.await(), u.await(), m.await())
            }
            val role = members.find { it.user_id == user.id }?.role
            val available = agents.filter { it.archived_at == null && canChat(it, user.id, role) }
            val mika = available.find { it.system_key == "mika" } ?: available.find { it.name.equals("Mika", true) }
            mutable.update { it.copy(sessions = orderedSessions(sessions), agents = agents, userId = user.id, role = role, agent = mika ?: available.firstOrNull(), loading = false, error = null) }
            val initial = orderedSessions(sessions).firstOrNull { it.status != "archived" && it.agent_id == mika?.id }
            if (initial != null) open(initial) else newChat(state.value.agent)
        } catch (e: CancellationException) { throw e } catch (e: Exception) { mutable.update { it.copy(loading = false, error = errorText(e)) } }
    }
    private data class Bootstrap(val sessions: List<ChatSession>, val agents: List<ChatAgent>, val user: ChatUser, val members: List<ChatMember>)
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
        fallback = scope.launch {
            while (isActive) { delay(5000); if ((!state.value.connected || state.value.pending.task_id != null || state.value.error != null) && state.value.session != null) refresh() }
        }
        if (!state.value.loading) refresh()
    }
    fun stop() { stream?.cancel(); fallback?.cancel(); stream = null; fallback = null; mutable.update { it.copy(connected = false) } }
    fun open(session: ChatSession) {
        if (state.value.sending) return
        generation++; val g = generation
        mutable.update { it.copy(session = session, agent = it.agents.find { a -> a.id == session.agent_id }, messages = emptyList(), pending = PendingTask(), cursor = null, hasMore = false, generic = emptyList(), draft = "", attachments = emptyList(), loading = true, loadingOlder = false, traces = emptyMap(), uncertain = false, notice = null, error = null) }
        launch {
            val draft = drafts.read(draftKey())
            if (g == generation) mutable.update { it.copy(draft = draft) }
            refreshNow(g)
            if (g == generation && session.has_unread) {
                api.markRead(session.id)
                mutable.update { it.copy(sessions = it.sessions.map { s -> if (s.id == session.id) s.copy(has_unread = false, unread_count = 0) else s }) }
            }
        }
    }
    fun newChat(agent: ChatAgent?) {
        if (state.value.sending || agent == null) return
        generation++; val g = generation
        mutable.update { it.copy(session = null, agent = agent, messages = emptyList(), pending = PendingTask(), generic = emptyList(), cursor = null, hasMore = false, loading = false, loadingOlder = false, traces = emptyMap(), draft = "", attachments = emptyList(), uncertain = false, notice = null, error = null) }
        launch { val text = drafts.read(draftKey()); if (g == generation) mutable.update { it.copy(draft = text) } }
    }
    fun draft(text: String) {
        mutable.update { it.copy(draft = text) }; val key = draftKey()
        launch { drafts.write(key, text) }
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
        if (refreshJob?.isActive == true) return
        refreshJob = launch {
            while (refreshAgain) {
                refreshAgain = false
                if (state.value.agents.isEmpty()) initialize() else {
                    val g = generation
                    val sessions = api.sessions()
                    if (g != generation) continue
                    mutable.update { it.copy(sessions = orderedSessions(sessions), session = sessions.find { s -> s.id == it.session?.id } ?: it.session) }
                    refreshNow(g)
                }
            }
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
                val session = s.session ?: api.create(NewChat(s.agent!!.id)).also { created -> mutable.update { it.copy(session = created, sessions = orderedSessions(it.sessions + created)) } }
                posted = true
                val receipt = api.send(session.id, SendMessage(text, s.attachments.map { it.id }))
                check(receipt.task_id.isNotBlank() && receipt.message_id.isNotBlank())
                accepted = true
                val boundIds = receipt.attachment_ids
                val dropped = if (boundIds == null) emptyList() else s.attachments.filterNot { it.id in boundIds }
                val bound = s.attachments.filterNot { a -> dropped.any { it.id == a.id } }
                if (g == generation) mutable.update {
                    it.copy(draft = "", attachments = dropped, notice = dropped.takeIf { it.isNotEmpty() }?.let { "这些附件未随消息发送：" + it.joinToString { a -> a.filename } }, messages = (it.messages + ChatMessage(receipt.message_id, session.id, "user", text, receipt.task_id, receipt.created_at, bound)).distinctBy { m -> m.id },
                        pending = PendingTask(receipt.task_id, "queued", receipt.created_at))
                }
                drafts.write(key, ""); drafts.write("${workspace.id}:${session.id}", "")
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
            "chat:done", "chat:message", "chat:quick_actions", "chat:cancel_finalized",
            "task:queued", "task:dispatch", "task:running", "task:completed", "task:failed", "task:cancelled", "task:deferred" -> refresh()
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
