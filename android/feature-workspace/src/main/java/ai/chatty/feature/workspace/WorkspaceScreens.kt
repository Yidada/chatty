package ai.chatty.feature.workspace

import ai.chatty.core.ui.*
import androidx.compose.foundation.clickable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.automirrored.outlined.Logout
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextOverflow
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
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
        PageHeader(
            title = if (state.selected == null) "项目" else if (state.selected == NO_PROJECT) "未归属项目" else state.projects.find { it.id == state.selected }?.title ?: "项目 Issues",
            subtitle = if (state.selected == null) workspace.name else null,
            backLabel = "返回项目", back = if (state.selected != null) controller::overview else null
        ) { ActionIcon(Icons.Outlined.Refresh, "刷新", controller::refresh, !state.loading) }
        if (state.loading) LinearProgressIndicator(Modifier.fillMaxWidth())
        state.error?.let { Text(it, Modifier.padding(16.dp), color = MaterialTheme.colorScheme.error) }
        if (state.selected == null) {
            LazyColumn(Modifier.fillMaxSize().testTag("projects-list"), contentPadding = PaddingValues(horizontal = 24.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                item { Text("按项目查看所有 Issues 的进度", color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall) }
                items(state.projects, key = { it.id }) { project ->
                    Card(onClick = { controller.select(project.id) }, modifier = Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                GlyphBadge(Icons.Outlined.FolderOpen, prominent = true)
                                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                    Text(project.title, style = MaterialTheme.typography.titleMedium, maxLines = 2, overflow = TextOverflow.Ellipsis)
                                    Text(statusName(project.status, emptyList()) + (project.due_date?.let { " · 截止 $it" } ?: ""), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                                Icon(Icons.Outlined.ChevronRight, null, Modifier.size(18.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                LinearProgressIndicator(progress = { progress(project) }, modifier = Modifier.fillMaxWidth().height(5.dp), trackColor = MaterialTheme.colorScheme.surfaceVariant)
                                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                    Text("${project.done_count} / ${project.issue_count} 已完成", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Text("${(progress(project) * 100).toInt()}%", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
                                }
                            }
                        }
                    }
                }
                item { ResourceItem("未归属项目的 Issues", "查看未分组的工作", Icons.Outlined.Inbox, { controller.select(NO_PROJECT) }) }

                if (!state.loading && state.projects.isEmpty() && state.error == null) item { Text("暂无项目，仍可查看未归属项目的 Issues。") }
            }
        } else {
            var query by remember(state.selected) { mutableStateOf(state.query) }
            var filters by remember { mutableStateOf(false) }
            Column(Modifier.padding(horizontal = 24.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(query, { query = it }, Modifier.fillMaxWidth().testTag("issue-search"), placeholder = { Text("搜索 Issues") }, singleLine = true, shape = RoundedCornerShape(16.dp),
                    trailingIcon = { ActionIcon(Icons.Outlined.Search, "搜索", { controller.select(state.selected, query, state.filter) }) },
                    colors = OutlinedTextFieldDefaults.colors(unfocusedBorderColor = MaterialTheme.colorScheme.outlineVariant, focusedBorderColor = MaterialTheme.colorScheme.primary, unfocusedContainerColor = MaterialTheme.colorScheme.surface, focusedContainerColor = MaterialTheme.colorScheme.surface))
                Box {
                    AssistChip(onClick = { filters = true }, label = { Text(state.filter?.let { statusName(it, state.statuses) } ?: "全部状态") }, leadingIcon = { Icon(Icons.Outlined.Tune, null, Modifier.size(16.dp)) })
                    DropdownMenu(expanded = filters, onDismissRequest = { filters = false }) {
                        DropdownMenuItem(text = { Text("全部状态") }, onClick = { filters = false; controller.select(state.selected, query, null) })
                        state.statuses.forEach { entry -> DropdownMenuItem(text = { Text(entry.name) }, onClick = { filters = false; controller.select(state.selected, query, entry.key) }) }
                    }
                }
                Text("共 ${state.total} 个 · 已加载 ${state.issues.size} 个", Modifier.padding(bottom = 12.dp), color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.labelSmall)
            }
            LazyColumn(Modifier.weight(1f).testTag("issues-list"), contentPadding = PaddingValues(horizontal = 24.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(state.issues, key = { it.id }) { issue ->
                    Card(onClick = { controller.detail(issue) }, Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(issue.identifier, Modifier.weight(1f), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                StatusPill(statusName(issue.status, state.statuses))
                            }
                            Text(issue.title, style = MaterialTheme.typography.titleMedium)
                            Text("优先级：${priorityName(issue.priority)}" + (issue.due_date?.let { " · 截止 $it" } ?: ""), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
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
            }
        }, confirmButton = { TextButton(onClick = controller::closeDetail, enabled = !state.saving) { Text("关闭") } })
    }
}

private fun priorityName(value: String) = when(value) { "urgent" -> "紧急"; "high" -> "高"; "medium" -> "中"; "low" -> "低"; else -> "无" }
private data class ResourceRow(val id: String, val title: String, val subtitle: String, val detail: String)
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
                "Runtimes" -> api.runtimes().map { r -> ResourceRow(r.id, r.custom_name?.takeIf { it.isNotBlank() } ?: r.name, if (r.status == "online") "在线" else "离线", listOf(r.runtime_mode, r.provider, r.device_info, r.last_seen_at?.let { "最后在线：$it" }.orEmpty()).filter { it.isNotBlank() }.joinToString("\n")) }
                "Agents" -> {
                    val runtimes = runCatching { api.runtimes() }.getOrDefault(emptyList())
                    api.agents().filter { it.archived_at == null }.map { a -> ResourceRow(a.id, a.name, if (a.status == "offline") "离线" else a.status, "Runtime：" + (runtimes.find { it.id == a.runtime_id }?.let { it.custom_name?.takeIf { n -> n.isNotBlank() } ?: it.name } ?: a.runtime_id.ifBlank { "未绑定" }) + "\n访问范围：${a.permission_mode}") }
                }
                else -> {
                    val agents = runCatching { api.agents() }.getOrDefault(emptyList())
                    api.squads().filter { it.archived_at == null }.map { s -> ResourceRow(s.id, s.name, s.member_count?.let { "$it 位成员" } ?: "成员数量待加载", s.description + "\n负责人：" + (agents.find { it.id == s.leader_id }?.name ?: s.leader_id)) }
                }
            }
        } catch (e: CancellationException) { throw e } catch (e: Exception) { error = requestError(e) } finally { loading = false }
    }
    Column(Modifier.fillMaxSize()) {
        PageHeader(section ?: "设置", subtitle = if (section == null) "你的工作空间与协作伙伴" else null,
            backLabel = "返回设置", back = if (section != null) ({ section = null }) else null) {
            if (section != null) ActionIcon(Icons.Outlined.Refresh, "刷新", { version++ }, !loading)
        }
        if (section == null) LazyColumn(Modifier.fillMaxSize().testTag("settings-list"), contentPadding = PaddingValues(horizontal = 24.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            item {
                Surface(color = MaterialTheme.colorScheme.primaryContainer, shape = RoundedCornerShape(24.dp)) {
                    Column(Modifier.fillMaxWidth().padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            GlyphBadge(Icons.Outlined.Apartment, prominent = true)
                            Column(Modifier.weight(1f)) {
                                Text("工作区", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onPrimaryContainer)
                                Text(workspace.name, Modifier.padding(top = 4.dp), style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onPrimaryContainer)
                            }
                        }
                        TextButton(onClick = switchWorkspace, contentPadding = PaddingValues(horizontal = 0.dp)) {
                            Icon(Icons.Outlined.SwapHoriz, null, Modifier.size(18.dp)); Spacer(Modifier.width(8.dp)); Text("切换工作区")
                        }
                    }
                }
            }
            item { SectionLabel("运行与协作") }
            item {
                Surface(color = MaterialTheme.colorScheme.surface, shape = RoundedCornerShape(20.dp)) {
                    Column {
                        listOf("Runtimes" to "执行设备与连接状态", "Agents" to "Agent 状态与执行设备", "Squads" to "团队概况与负责人").forEachIndexed { index, (name, description) ->
                            ResourceItem(name, description, resourceIcon(name), { section = name })
                            if (index < 2) HorizontalDivider(Modifier.padding(start = 72.dp, end = 16.dp), color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = .6f))
                        }
                    }
                }
            }
            item {
                TextButton(onClick = signOut, modifier = Modifier.padding(top = 12.dp), colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.onSurfaceVariant)) {
                    Icon(Icons.AutoMirrored.Outlined.Logout, null, Modifier.size(18.dp)); Spacer(Modifier.width(8.dp)); Text("退出登录")
                }
            }
        } else {
            if (loading) LinearProgressIndicator(Modifier.fillMaxWidth())
            error?.let { Text(it, Modifier.padding(24.dp), color = MaterialTheme.colorScheme.error) }
            LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(horizontal = 24.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items(rows, key = { it.id }) { row -> ResourceItem(row.title, row.subtitle, resourceIcon(section!!), { selected = row }) }
                if (!loading && error == null && rows.isEmpty()) item {
                    Column(Modifier.fillMaxWidth().padding(vertical = 48.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        GlyphBadge(resourceIcon(section!!))
                        Text("暂无可见的 $section", Modifier.padding(top = 16.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }
    selected?.let { row -> AlertDialog(onDismissRequest = { selected = null }, title = { Text(row.title) }, text = { Column(Modifier.verticalScroll(rememberScrollState())) { Text(row.subtitle); Text(row.detail, Modifier.padding(vertical = 12.dp)) } }, confirmButton = { TextButton(onClick = { selected = null }) { Text("关闭") } }) }
}

private fun resourceIcon(section: String): ImageVector = when (section) {
    "Runtimes" -> Icons.Outlined.Dns
    "Agents" -> Icons.Outlined.SmartToy
    else -> Icons.Outlined.Groups
}

@Composable
private fun ResourceItem(title: String, subtitle: String, icon: ImageVector, onClick: () -> Unit) {
    Surface(color = MaterialTheme.colorScheme.surface, shape = RoundedCornerShape(18.dp)) {
        Row(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            GlyphBadge(icon)
            Column(Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.titleMedium)
                Text(subtitle, Modifier.padding(top = 4.dp), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Icon(Icons.Outlined.ChevronRight, null, Modifier.size(18.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
