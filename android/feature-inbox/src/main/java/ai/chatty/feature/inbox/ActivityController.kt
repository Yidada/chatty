package ai.chatty.feature.inbox

import ai.chatty.core.model.Issue
import ai.chatty.core.model.IssueStatusEntry
import ai.chatty.core.model.Project
import ai.chatty.core.network.WorkspaceApi
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import retrofit2.HttpException

/** Workspace-wide attention feed. Personal inbox recipient filters deliberately do not apply. */
data class ActivityState(
    val recent: List<Issue> = emptyList(), val actions: List<Issue> = emptyList(),
    val projects: List<Project> = emptyList(), val statuses: List<IssueStatusEntry> = emptyList(),
    val recentTotal: Int = 0, val actionTotal: Int = 0,
    val loading: Boolean = false, val loadingMore: Boolean = false,
    val error: String? = null, val actionError: String? = null, val readError: String? = null,
    val reads: Map<String, String> = emptyMap()
) {
    val unreadCount get() = (recent + actions).distinctBy { it.id }.count { activityUnread(it, reads) }
    val hasAttention get() = unreadCount > 0
}

/** Semantic activity is preferred over bookkeeping timestamps; status covers older servers. */
fun activityFingerprint(issue: Issue): String =
    "${issue.last_activity_at ?: issue.updated_at ?: (issue.revision ?: 0)}|${issue.status}"

fun activityUnread(issue: Issue, reads: Map<String, String>): Boolean = reads[issue.id] != activityFingerprint(issue)

fun activityCategory(issue: Issue, statuses: List<IssueStatusEntry>): String =
    issue.status_category ?: statuses.find { it.key == issue.status }?.category ?: issue.status

fun activityNeedsAction(issue: Issue, statuses: List<IssueStatusEntry>): Boolean =
    activityCategory(issue, statuses) in setOf("in_review", "blocked")

fun activityActionKeys(statuses: List<IssueStatusEntry>): String =
    (statuses.filter { it.category == "in_review" || it.category == "blocked" }.map { it.key } + listOf("in_review", "blocked"))
        .toSet().sorted().joinToString(",")

fun activityStatusName(key: String, catalog: List<IssueStatusEntry>): String = catalog.find { it.key == key }?.name ?: when (key) {
    "backlog" -> "待规划"; "todo" -> "待开始"; "planned" -> "已规划"; "in_progress" -> "进行中"; "in_review" -> "待审核"
    "done", "completed" -> "已完成"; "blocked" -> "受阻"; "cancelled" -> "已取消"; "paused" -> "已暂停"; else -> key
}

fun activitySummary(issue: Issue, statuses: List<IssueStatusEntry>): String = when (activityCategory(issue, statuses)) {
    "in_review" -> "结果已提交，等待验收。"
    "blocked" -> "当前受阻，需要进一步处理。"
    "done" -> "事项已完成。"
    "cancelled" -> "事项已取消。"
    "in_progress" -> "事项正在推进。"
    "todo" -> "事项已记录，等待开始。"
    else -> "当前状态：${activityStatusName(issue.status, statuses)}"
}

fun activityRequestError(e: Exception): String = when ((e as? HttpException)?.code()) {
    401 -> "登录已失效，请重新登录。"; 403 -> "没有访问权限。"; 404 -> "资源已不存在，请刷新。"
    else -> "暂时无法连接，请重试。"
}

class ActivityController(
    private val api: WorkspaceApi, private val reads: ActivityReads,
    private val workspaceId: String, private val scope: CoroutineScope
) {
    private val mutable = MutableStateFlow(ActivityState())
    val state = mutable.asStateFlow()
    private var generation = 0
    private var recentOffset = 0
    private var actionOffset = 0
    private var load: Job? = null
    private var restore: Job? = null

    init {
        restore = scope.launch {
            try {
                val saved = reads.read(workspaceId)
                mutable.update { it.copy(reads = saved) }
            } catch (e: CancellationException) { throw e } catch (e: Exception) { mutable.update { it.copy(readError = "已读状态暂时无法恢复，请重试。") } }
        }
    }

    fun hasMore(actions: Boolean): Boolean = if (actions) actionOffset < state.value.actionTotal else recentOffset < state.value.recentTotal

    fun refresh() {
        val s = state.value
        if (s.loading) return
        load?.cancel()
        val g = ++generation
        mutable.update { it.copy(loading = true, error = null) }
        load = scope.launch {
            try {
                val projectDeferred = async { api.projects() }
                val catalogDeferred = async { runCatching { api.statuses() } }
                val recentDeferred = async { api.issues(limit = 50, offset = 0, sort = "last_activity", direction = "desc") }
                val projectPage = projectDeferred.await()
                if (g != generation) return@launch
                val catalog = catalogDeferred.await()
                val statuses = catalog.getOrNull()?.statuses.orEmpty().filter { it.archived_at == null }
                val recentPage = recentDeferred.await()
                if (g != generation) return@launch
                recentOffset = if (recentPage.issues.isEmpty()) recentPage.total else recentPage.issues.size
                mutable.update {
                    it.copy(projects = projectPage.projects, statuses = statuses,
                        recent = recentPage.issues.distinctBy { i -> i.id }, recentTotal = recentPage.total, error = null,
                        actionError = if (catalog.isFailure) "待关注状态目录未能更新，请稍后重试。" else null)
                }
                if (catalog.isFailure) return@launch
                try {
                    val pending = api.issues(limit = 50, offset = 0, statuses = activityActionKeys(statuses), sort = "last_activity", direction = "desc")
                    if (g != generation) return@launch
                    actionOffset = if (pending.issues.isEmpty()) pending.total else pending.issues.size
                    mutable.update { it.copy(actions = pending.issues.filter { i -> activityNeedsAction(i, statuses) }.distinctBy { i -> i.id }, actionTotal = pending.total, actionError = null) }
                } catch (e: CancellationException) { throw e } catch (e: Exception) { if (g == generation) mutable.update { it.copy(actionError = activityRequestError(e)) } }
            } catch (e: CancellationException) { throw e } catch (e: Exception) {
                if (g == generation) mutable.update { it.copy(error = activityRequestError(e)) }
            } finally {
                if (g == generation) mutable.update { it.copy(loading = false) }
            }
        }
    }

    fun more(actions: Boolean) {
        val s = state.value
        if (s.loading || s.loadingMore) return
        val offset = if (actions) actionOffset else recentOffset
        val total = if (actions) s.actionTotal else s.recentTotal
        if (offset >= total) return
        val g = generation
        mutable.update { it.copy(loadingMore = true) }
        scope.launch {
            try {
                val page = api.issues(limit = 50, offset = offset, statuses = activityActionKeys(s.statuses).takeIf { actions }, sort = "last_activity", direction = "desc")
                if (g != generation) return@launch
                if (actions) {
                    actionOffset = if (page.issues.isEmpty()) page.total else offset + page.issues.size
                    mutable.update { it.copy(actions = (it.actions + page.issues).distinctBy { i -> i.id }.filter { i -> activityNeedsAction(i, it.statuses) }, actionTotal = page.total, actionError = null) }
                } else {
                    recentOffset = if (page.issues.isEmpty()) page.total else offset + page.issues.size
                    mutable.update { it.copy(recent = (it.recent + page.issues).distinctBy { i -> i.id }, recentTotal = page.total, error = null) }
                }
            } catch (e: CancellationException) { throw e } catch (e: Exception) {
                if (g == generation) mutable.update { if (actions) it.copy(actionError = activityRequestError(e)) else it.copy(error = activityRequestError(e)) }
            } finally {
                if (g == generation) mutable.update { it.copy(loadingMore = false) }
            }
        }
    }

    /** Viewing an item only advances the local read fingerprint; business status is unchanged. */
    fun markRead(issue: Issue) {
        val next = state.value.reads + (issue.id to activityFingerprint(issue))
        mutable.update { it.copy(reads = next, readError = null) }
        scope.launch {
            try { reads.write(workspaceId, next) }
            catch (e: CancellationException) { throw e } catch (e: Exception) { mutable.update { it.copy(readError = "已读状态未保存，请重试。") } }
        }
    }

    /** A confirmed business-status change moves the item between 最近动态 and 待关注. */
    fun apply(issue: Issue) {
        val s = state.value
        val needs = activityNeedsAction(issue, s.statuses)
        val recent = s.recent.map { if (it.id == issue.id) issue else it }
        var actions = s.actions
        var total = s.actionTotal
        if (needs) {
            if (actions.any { it.id == issue.id }) actions = actions.map { if (it.id == issue.id) issue else it }
            else { actions = listOf(issue) + actions; total += 1; actionOffset += 1 }
        } else if (actions.any { it.id == issue.id }) {
            actions = actions.filterNot { it.id == issue.id }; total = (total - 1).coerceAtLeast(0); actionOffset = (actionOffset - 1).coerceAtLeast(0)
        }
        mutable.update { it.copy(recent = recent, actions = actions, actionTotal = total) }
        markRead(issue)
    }
}
