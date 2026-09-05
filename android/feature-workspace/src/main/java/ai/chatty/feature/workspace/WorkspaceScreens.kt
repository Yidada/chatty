package ai.chatty.feature.workspace

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.repeatOnLifecycle
import ai.chatty.core.model.*
import ai.chatty.core.network.*
import kotlinx.coroutines.*

@Composable
fun ProjectsRoute(workspace: Workspace, credentials: CredentialStore, base: String) {
    val scope = rememberCoroutineScope()
    val api = remember(workspace.id, base) { scopedWorkspaceApi(base, credentials, workspace.slug) }
    // Retrofit proxies do not provide reflexive equals; never use them as Compose keys.
    val controller = remember(workspace.id, base) { ProjectsController(api, scope) }
    val state by controller.state.collectAsStateWithLifecycle()
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    LaunchedEffect(controller, lifecycle) { lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) { controller.refresh(); while (isActive) { delay(30000); if (controller.state.value.selected == null && controller.state.value.detail == null) controller.refresh() } } }
    BackHandler(state.selected != null && state.detail == null) { controller.overview() }
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            if (state.selected != null) TextButton(onClick = controller::overview) { Text("返回项目") }
            Text(if (state.selected == null) "项目" else if (state.selected == NO_PROJECT) "未归属项目" else state.projects.find { it.id == state.selected }?.title ?: "项目 Issues", Modifier.weight(1f), style = MaterialTheme.typography.titleLarge, maxLines = 1)
            TextButton(onClick = controller::refresh, enabled = !state.loading) { Text("刷新") }
        }
        if (state.loading) LinearProgressIndicator(Modifier.fillMaxWidth())
        state.error?.let { Text(it, Modifier.padding(16.dp), color = MaterialTheme.colorScheme.error) }
        if (state.selected == null) {
            LazyColumn(Modifier.fillMaxSize().testTag("projects-list"), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                item { Text("按项目查看所有 Issues 的进度", style = MaterialTheme.typography.bodyMedium) }
                items(state.projects, key = { it.id }) { project ->
                    OutlinedCard(onClick = { controller.select(project.id) }, modifier = Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            Text(project.title, style = MaterialTheme.typography.titleMedium)
                            Text(statusName(project.status, emptyList()) + (project.due_date?.let { " · 截止 $it" } ?: ""), style = MaterialTheme.typography.labelMedium)
                            LinearProgressIndicator(progress = { progress(project) }, modifier = Modifier.fillMaxWidth())
                            Text("${project.done_count} / ${project.issue_count} 已完成", style = MaterialTheme.typography.bodyMedium)
                        }
                    }
                }
                item { OutlinedButton(onClick = { controller.select(NO_PROJECT) }, modifier = Modifier.fillMaxWidth()) { Text("未归属项目的 Issues") } }
                if (!state.loading && state.projects.isEmpty() && state.error == null) item { Text("暂无项目，仍可查看未归属项目的 Issues。") }
            }
        } else {
            var query by remember(state.selected) { mutableStateOf(state.query) }
            var filters by remember { mutableStateOf(false) }
            Row(Modifier.padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(query, { query = it }, Modifier.weight(1f).testTag("issue-search"), label = { Text("搜索 Issues") }, singleLine = true)
                TextButton(onClick = { controller.select(state.selected, query, state.filter) }) { Text("搜索") }
                Box { TextButton(onClick = { filters = true }) { Text(state.filter?.let { statusName(it, state.statuses) } ?: "全部状态") }
                    DropdownMenu(expanded = filters, onDismissRequest = { filters = false }) {
                        DropdownMenuItem(text = { Text("全部状态") }, onClick = { filters = false; controller.select(state.selected, query, null) })
                        state.statuses.forEach { entry -> DropdownMenuItem(text = { Text(entry.name) }, onClick = { filters = false; controller.select(state.selected, query, entry.key) }) }
                    }
                }
            }
            Text("共 ${state.total} 个 · 已加载 ${state.issues.size} 个", Modifier.padding(16.dp), style = MaterialTheme.typography.labelMedium)
            LazyColumn(Modifier.weight(1f).testTag("issues-list"), contentPadding = PaddingValues(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items(state.issues, key = { it.id }) { issue ->
                    OutlinedCard(onClick = { controller.detail(issue) }, Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(14.dp)) {
                            Text(issue.identifier + " · " + statusName(issue.status, state.statuses), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
                            Text(issue.title, Modifier.padding(vertical = 6.dp), style = MaterialTheme.typography.titleMedium)
                            Text("优先级：${priorityName(issue.priority)}" + (issue.due_date?.let { " · 截止 $it" } ?: ""), style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
                if (!state.loading && state.issues.isEmpty() && state.error == null) item { Text("没有符合条件的 Issue。") }
                if (state.offset < state.total) item { TextButton(onClick = controller::more, enabled = !state.loadingMore) { Text(if (state.loadingMore) "加载中…" else "加载更多 Issues") } }
                item { Spacer(Modifier.height(16.dp)) }
            }
        }
    }
    state.detail?.let { issue ->
        var menu by remember(issue.id) { mutableStateOf(false) }
        AlertDialog(onDismissRequest = controller::closeDetail, title = { Text(issue.identifier + " · " + issue.title) }, text = {
            Column(Modifier.heightIn(max = 480.dp).verticalScroll(rememberScrollState())) {
                if (state.detailLoading || state.saving) LinearProgressIndicator(Modifier.fillMaxWidth())
                Text(issue.description?.ifBlank { "暂无描述" } ?: "暂无描述")
                Spacer(Modifier.height(16.dp))
                Box { OutlinedButton(onClick = { menu = true }, enabled = !state.saving && !state.detailLoading && state.detailError == null && state.statuses.isNotEmpty()) { Text("状态：${statusName(issue.status, state.statuses)}") }
                    DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) { state.statuses.forEach { status -> DropdownMenuItem(text = { Text(status.name) }, onClick = { menu = false; controller.changeStatus(status.key) }) } }
                }
                Text("状态修改仅更新进度，不自动启动 Agent。", style = MaterialTheme.typography.bodySmall)
                state.detailError?.let { Text(it, color = MaterialTheme.colorScheme.error); TextButton(onClick = { controller.detail(issue) }) { Text("重新读取状态") } }
                WebButton("在 Multica 管理完整 Issue", web(workspace.slug, "issue/${issue.identifier}"))
            }
        }, confirmButton = { TextButton(onClick = controller::closeDetail, enabled = !state.saving) { Text("关闭") } })
    }
}

private fun priorityName(value: String) = when(value) { "urgent" -> "紧急"; "high" -> "高"; "medium" -> "中"; "low" -> "低"; else -> "无" }
private fun web(slug: String, path: String) = "https://multica.ai/${Uri.encode(slug)}/$path"
@Composable private fun WebButton(label: String, url: String) {
    val context = LocalContext.current
    TextButton(onClick = { runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) } }) { Text(label) }
}

private data class ResourceRow(val id: String, val title: String, val subtitle: String, val detail: String, val path: String)
@Composable
fun SettingsRoute(workspace: Workspace, credentials: CredentialStore, base: String, switchWorkspace: () -> Unit, signOut: () -> Unit) {
    val api = remember(workspace.id, base) { scopedWorkspaceApi(base, credentials, workspace.slug) }
    var section by remember { mutableStateOf<String?>(null) }
    var rows by remember { mutableStateOf<List<ResourceRow>>(emptyList()) }
    var selected by remember { mutableStateOf<ResourceRow?>(null) }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var version by remember { mutableIntStateOf(0) }
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    DisposableEffect(lifecycle) {
        val observer = androidx.lifecycle.LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) { version++; selected = null }
        }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer) }
    }
    BackHandler(section != null && selected == null) { section = null }
    LaunchedEffect(section, version, workspace.id, base) {
        val current = section ?: return@LaunchedEffect
        loading = true; error = null; rows = emptyList()
        try {
            rows = when (current) {
                "Runtimes" -> api.runtimes().map { r -> ResourceRow(r.id, r.custom_name?.takeIf { it.isNotBlank() } ?: r.name, if (r.status == "online") "在线" else "离线", listOf(r.runtime_mode, r.provider, r.device_info, r.last_seen_at?.let { "最后在线：$it" }.orEmpty()).filter { it.isNotBlank() }.joinToString("\n"), "runtimes/${r.id}") }
                "Agents" -> {
                    val runtimes = runCatching { api.runtimes() }.getOrDefault(emptyList())
                    api.agents().filter { it.archived_at == null }.map { a -> ResourceRow(a.id, a.name, if (a.status == "offline") "离线" else a.status, "Runtime：" + (runtimes.find { it.id == a.runtime_id }?.let { it.custom_name?.takeIf { n -> n.isNotBlank() } ?: it.name } ?: a.runtime_id.ifBlank { "未绑定" }) + "\n访问范围：${a.permission_mode}", "agents/${a.id}") }
                }
                else -> {
                    val agents = runCatching { api.agents() }.getOrDefault(emptyList())
                    api.squads().filter { it.archived_at == null }.map { s -> ResourceRow(s.id, s.name, s.member_count?.let { "$it 位成员" } ?: "成员数量待加载", s.description + "\n负责人：" + (agents.find { it.id == s.leader_id }?.name ?: s.leader_id), "squads/${s.id}") }
                }
            }
        } catch (e: CancellationException) { throw e } catch (e: Exception) { error = requestError(e) } finally { loading = false }
    }
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            if (section != null) TextButton(onClick = { section = null }) { Text("返回设置") }
            Text(section ?: "设置", Modifier.weight(1f), style = MaterialTheme.typography.titleLarge)
            if (section != null) TextButton(onClick = { version++ }, enabled = !loading) { Text("刷新") }
        }
        if (section == null) LazyColumn(Modifier.fillMaxSize().testTag("settings-list"), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            item { Text(workspace.name, style = MaterialTheme.typography.titleMedium); Text("工作区", style = MaterialTheme.typography.labelMedium) }
            item { Row { TextButton(onClick = switchWorkspace) { Text("切换工作区") }; TextButton(onClick = signOut) { Text("退出登录") } } }
            item { Text("运行与协作", style = MaterialTheme.typography.titleMedium) }
            listOf("Runtimes" to "执行设备与连接状态", "Agents" to "Agent 与 Runtime 绑定", "Squads" to "团队、成员和负责人").forEach { (name, description) -> item { OutlinedCard(onClick = { section = name }, modifier = Modifier.fillMaxWidth()) { Column(Modifier.padding(16.dp)) { Text(name, style = MaterialTheme.typography.titleMedium); Text(description, style = MaterialTheme.typography.bodySmall) } } } }
            item { Text("账号设置", Modifier.padding(top = 16.dp), style = MaterialTheme.typography.titleMedium) }
            accountSettings.forEach { (name, tab) -> item { WebButton(name, web(workspace.slug, "settings?tab=$tab")) } }
            item { Text("工作区设置", Modifier.padding(top = 16.dp), style = MaterialTheme.typography.titleMedium) }
            workspaceSettings.forEach { (name, tab) -> item { WebButton(name, web(workspace.slug, "settings?tab=$tab")) } }
            item { Text("详细配置在 Multica 打开，并遵循当前账号权限。", style = MaterialTheme.typography.bodySmall) }
        } else {
            if (loading) LinearProgressIndicator(Modifier.fillMaxWidth())
            error?.let { Text(it, Modifier.padding(16.dp), color = MaterialTheme.colorScheme.error) }
            LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                item { WebButton("在 Multica 管理 $section", web(workspace.slug, section!!.lowercase())) }
                items(rows, key = { it.id }) { row -> OutlinedCard(onClick = { selected = row }, modifier = Modifier.fillMaxWidth()) { Column(Modifier.padding(16.dp)) { Text(row.title, style = MaterialTheme.typography.titleMedium); Text(row.subtitle, Modifier.padding(top = 8.dp), style = MaterialTheme.typography.bodyMedium) } } }
                if (!loading && error == null && rows.isEmpty()) item { Text("暂无可见的 $section") }
            }
        }
    }
    selected?.let { row -> AlertDialog(onDismissRequest = { selected = null }, title = { Text(row.title) }, text = { Column(Modifier.verticalScroll(rememberScrollState())) { Text(row.subtitle); Text(row.detail, Modifier.padding(vertical = 12.dp)); WebButton("在 Multica 编辑配置", web(workspace.slug, row.path)) } }, confirmButton = { TextButton(onClick = { selected = null }) { Text("关闭") } }) }
}
// Exact tab values from Multica settings-page.tsx; server enforces roles and feature flags.
val accountSettings = listOf("个人资料" to "profile", "偏好设置" to "preferences", "快捷键" to "shortcuts", "Issue 偏好" to "issue", "Chat 偏好" to "chat", "通知" to "notifications", "访问令牌" to "tokens")
val workspaceSettings = listOf("基本信息" to "workspace", "代码仓库" to "repositories", "GitHub" to "github", "集成" to "integrations", "实验功能" to "labs", "成员" to "members", "账单" to "billing", "标签" to "labels", "Issue 状态" to "issue-statuses", "属性" to "properties", "快捷操作" to "quick-actions", "MCP" to "mcp", "插件" to "plugins")
