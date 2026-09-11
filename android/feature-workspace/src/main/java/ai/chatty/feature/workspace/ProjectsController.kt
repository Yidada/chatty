package ai.chatty.feature.workspace
import ai.chatty.core.model.*
import ai.chatty.core.network.WorkspaceApi
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import retrofit2.HttpException

const val NO_PROJECT = "__none__"
fun progress(project: Project): Float = if (project.issue_count <= 0) 0f else (project.done_count.toFloat() / project.issue_count).coerceIn(0f, 1f)
fun statusName(key: String, catalog: List<IssueStatusEntry>) = catalog.find { it.key == key }?.name ?: when (key) {
    "backlog" -> "待规划"; "todo" -> "待开始"; "planned" -> "已规划"; "in_progress" -> "进行中"; "in_review" -> "待审核"
    "done", "completed" -> "已完成"; "blocked" -> "受阻"; "cancelled" -> "已取消"; "paused" -> "已暂停"; else -> key
}
fun requestError(e: Exception) = when ((e as? HttpException)?.code()) {
    401 -> "登录已失效，请重新登录。"; 403 -> "没有访问或修改权限。"; 404 -> "资源已不存在，请刷新。"
    409 -> "内容已被更新，请刷新后重试。"; else -> "暂时无法连接，请重试。"
}
data class ProjectsState(val projects: List<Project> = emptyList(), val statuses: List<IssueStatusEntry> = emptyList(), val selected: String? = null,
    val issues: List<Issue> = emptyList(), val total: Int = 0, val offset: Int = 0, val query: String = "", val filter: String? = null,
    val loading: Boolean = false, val loadingMore: Boolean = false, val error: String? = null, val detail: Issue? = null, val detailLoading: Boolean = false, val saving: Boolean = false, val detailError: String? = null, val actionNotice: String? = null)
class ProjectsController(private val api: WorkspaceApi, private val scope: CoroutineScope) {
    private val mutable = MutableStateFlow(ProjectsState()); val state = mutable.asStateFlow()
    private var generation = 0; private var load: Job? = null; private var detailGeneration = 0
    fun refresh() {
        val s = state.value
        if (s.saving) return
        when {
            s.detail != null -> detail(s.detail)
            s.selected == null -> overview()
            else -> loadIssues(s.selected, s.query, s.filter, retain = true)
        }
    }
    fun overview() {
        load?.cancel(); generation++; detailGeneration++
        mutable.update { it.copy(selected = null, issues = emptyList(), total = 0, loading = true, error = null, detail = null) }
        load = scope.launch {
            try {
                val (projects, statuses) = coroutineScope { val p = async { api.projects() }; val s = async { try { Result.success(api.statuses()) } catch (e: CancellationException) { throw e } catch (e: Exception) { Result.failure(e) } }; p.await() to s.await() }
                mutable.update { it.copy(projects = projects.projects, statuses = statuses.getOrNull()?.statuses.orEmpty().filter { s -> s.archived_at == null }, loading = false, error = if (statuses.isFailure) "状态目录暂不可用，状态编辑暂停。请刷新重试。" else null) }
            } catch (e: CancellationException) { throw e } catch (e: Exception) { mutable.update { it.copy(loading = false, error = requestError(e)) } }
        }
    }
    fun select(id: String?, query: String = "", status: String? = null) {
        if (id == null) { overview(); return }
        detailGeneration++
        mutable.update { it.copy(detail = null, detailLoading = false, detailError = null) }
        loadIssues(id, query, status, retain = false)
    }
    private fun loadIssues(id: String, query: String, status: String?, retain: Boolean) {
        load?.cancel(); generation++; val g = generation
        val targetOffset = if (retain) state.value.offset else 0
        mutable.update { it.copy(selected = id, issues = if (retain) it.issues else emptyList(), total = if (retain) it.total else 0, offset = if (retain) it.offset else 0, query = query, filter = status, loading = true, loadingMore = false, error = null) }
        load = scope.launch {
            try {
                val rows = mutableListOf<Issue>()
                var offset = 0
                var total: Int
                do {
                    val page = api.issues(project = id.takeUnless { it == NO_PROJECT }, noProject = true.takeIf { id == NO_PROJECT }, offset = offset, query = query.trim().takeIf { it.isNotEmpty() }, status = status)
                    rows.addAll(page.issues)
                    total = page.total
                    offset = if (page.issues.isEmpty()) total else offset + page.issues.size
                } while (offset < targetOffset && offset < total)
                if (g == generation) mutable.update { it.copy(issues = rows.distinctBy { i -> i.id }, total = total, offset = offset, loading = false) }
            } catch (e: CancellationException) { throw e } catch (e: Exception) { if (g == generation) mutable.update { it.copy(loading = false, error = requestError(e)) } }
        }
    }
    fun more() {
        val s = state.value; val id = s.selected ?: return
        if (s.loading || s.loadingMore || s.offset >= s.total) return
        val g = generation; mutable.update { it.copy(loadingMore = true) }
        scope.launch {
            try { val page = api.issues(project = id.takeUnless { it == NO_PROJECT }, noProject = true.takeIf { id == NO_PROJECT }, offset = s.offset, query = s.query.takeIf { it.isNotBlank() }, status = s.filter)
                if (g == generation) mutable.update { it.copy(issues = (it.issues + page.issues).distinctBy { i -> i.id }, total = page.total, offset = if (page.issues.isEmpty()) page.total else s.offset + page.issues.size) }
            } catch (e: CancellationException) { throw e } catch (e: Exception) { if (g == generation) mutable.update { it.copy(error = requestError(e)) } }
            finally { if (g == generation) mutable.update { it.copy(loadingMore = false) } }
        }
    }
    fun detail(issue: Issue) {
        val g = ++detailGeneration; mutable.update { it.copy(detail = issue, detailLoading = true, detailError = null, actionNotice = null) }
        scope.launch {
            try {
                val fresh = api.issue(issue.id)
                val catalog = if (state.value.statuses.isEmpty()) api.statuses().statuses.filter { it.archived_at == null } else state.value.statuses
                if (g == detailGeneration) mutable.update { it.copy(detail = fresh, statuses = catalog) }
            }
            catch (e: CancellationException) { throw e } catch (e: Exception) { if (g == detailGeneration) mutable.update { it.copy(detailError = requestError(e)) } }
            finally { if (g == detailGeneration) mutable.update { it.copy(detailLoading = false) } }
        }
    }
    fun closeDetail() { if (state.value.saving) return; detailGeneration++; mutable.update { it.copy(detail = null, detailLoading = false, detailError = null) } }
    fun changeStatus(key: String) {
        val s = state.value; val issue = s.detail ?: return
        if (s.saving || s.detailLoading || s.detailError != null || key == issue.status || s.statuses.none { it.key == key }) return
        mutable.update { it.copy(saving = true, detailError = null, actionNotice = null) }
        scope.launch {
            try {
                val updated = api.updateIssue(issue.id, IssueUpdate(key, suppress_run = true, expected_revision = issue.revision))
                val previousCategory = issue.status_category ?: s.statuses.find { it.key == issue.status }?.category ?: issue.status
                val updatedCategory = updated.status_category ?: s.statuses.find { it.key == updated.status }?.category ?: updated.status
                if (updated.id != issue.id || updated.status != key || updated.revision == null || issue.revision == null || (updated.revision ?: 0) <= (issue.revision ?: 0) || (s.statuses.find { it.key == key }?.category == "done" && updatedCategory != "done")) {
                    mutable.update { it.copy(actionNotice = null, detailError = "服务器回执未确认本次修改，请重新读取状态核对。") }
                    return@launch
                }
                val notice = when {
                    previousCategory == "in_review" && updatedCategory == "done" -> "已验收"
                    previousCategory == "blocked" && updatedCategory == "in_progress" -> "阻塞已解除，任务继续进行"
                    else -> "状态已更新：${statusName(updated.status, s.statuses)}"
                }
                mutable.update { it.copy(detail = updated, actionNotice = notice, issues = it.issues.map { row -> if (row.id == updated.id) updated else row }.filter { row -> it.filter == null || row.status == it.filter }) }
                // Aggregate counts are server-owned. A failed count refresh doesn't retry the write.
                runCatching { api.projects() }.getOrNull()?.let { page -> mutable.update { it.copy(projects = page.projects) } }
                state.value.selected?.let { loadIssues(it, state.value.query, state.value.filter, retain = true) }
            } catch (e: CancellationException) { throw e } catch (e: Exception) {
                if ((e as? HttpException)?.code() == 409) {
                    val fresh = runCatching { api.issue(issue.id) }.getOrNull()
                    mutable.update { it.copy(detail = fresh ?: it.detail, actionNotice = null, detailError = "内容已被更新，未提交本次修改。请核对最新状态后重试。") }
                } else mutable.update { it.copy(actionNotice = null, detailError = requestError(e) + " 请重新读取状态核对，避免重复提交。") }
            }
            finally { mutable.update { it.copy(saving = false) } }
        }
    }
}
