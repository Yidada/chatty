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
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
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
fun ProjectsRoute(workspace: Workspace, credentials: CredentialStore, base: String, active: Boolean = true, openIssue: Issue? = null, onIssueOpened: () -> Unit = {}, onDiscussIssue: (Issue) -> Unit = {}, onIssueViewed: (Issue) -> Unit = {}) {
    val scope = rememberCoroutineScope()
    val api = remember(workspace.id, base) { scopedWorkspaceApi(base, credentials, workspace.slug) }
    // Retrofit proxies do not provide reflexive equals; never use them as Compose keys.
    val controller = remember(workspace.id, base) { ProjectsController(api, scope) }
    val state by controller.state.collectAsStateWithLifecycle()
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    val overviewScroll = rememberLazyListState()
    val issuesScroll = key(state.selected, state.query, state.filter) { rememberLazyListState() }
    val detailScroll = remember(state.detail?.id) { ScrollState(0) }
    val savedUi = rememberSaveableStateHolder()
    LaunchedEffect(controller, lifecycle, active) {
        if (!active) return@LaunchedEffect
        lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
            controller.refresh()
            while (isActive) {
                delay(30000)
                if (controller.state.value.selected == null && controller.state.value.detail == null) controller.refresh()
            }
        }
    }
    if (!active) return
    LaunchedEffect(openIssue?.id) {
        openIssue?.let { controller.detail(it); onIssueOpened() }
    }
    BackHandler(state.detail != null || state.selected != null) {
        if (state.detail != null) controller.closeDetail() else controller.overview()
    }
    LaunchedEffect(state.detail, state.detailLoading, state.detailError) {
        if (!state.detailLoading && state.detailError == null) state.detail?.let(onIssueViewed)
    }
    val issue = state.detail
    if (issue != null) {
        IssueDetail(state, controller, issue, detailScroll, onDiscussIssue)
        return
    }
    savedUi.SaveableStateProvider("project-list") {
        Column(Modifier.fillMaxSize()) {
            PageHeader(
                title = if (state.selected == null) "项目" else if (state.selected == NO_PROJECT) "未归属项目" else state.projects.find { it.id == state.selected }?.title ?: "项目 Issues",
                subtitle = if (state.selected == null) workspace.name else null,
                backLabel = "返回项目", back = if (state.selected != null) controller::overview else null
            ) { ActionIcon(Icons.Outlined.Refresh, "刷新", controller::refresh, !state.loading) }
            if (state.loading) LinearProgressIndicator(Modifier.fillMaxWidth())
            state.error?.let { Text(it, Modifier.padding(16.dp), color = MaterialTheme.colorScheme.error) }
            if (state.selected == null) {
                LazyColumn(Modifier.fillMaxSize().testTag("projects-list"), state = overviewScroll, contentPadding = PaddingValues(horizontal = 24.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
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
                var query by rememberSaveable(state.selected, state.query) { mutableStateOf(state.query) }
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
                    Text("全部事项 · 包含所有发起人 · 共 ${state.total} 个 · 已加载 ${state.issues.size} 个", Modifier.padding(bottom = 12.dp), color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.labelSmall)
                }
                LazyColumn(Modifier.weight(1f).testTag("issues-list"), state = issuesScroll, contentPadding = PaddingValues(horizontal = 24.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
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
    }
}

@Composable
private fun IssueDetail(state: ProjectsState, controller: ProjectsController, issue: Issue, scroll: ScrollState, onDiscussIssue: (Issue) -> Unit) {
    var menu by remember(issue.id) { mutableStateOf(false) }
    Column(Modifier.fillMaxSize().testTag("issue-detail")) {
        PageHeader(issue.identifier, "Issue 详情", "返回 Issues", controller::closeDetail) {
            ActionIcon(Icons.Outlined.Refresh, "刷新详情", { controller.detail(issue) }, !state.saving && !state.detailLoading)
        }
        if (state.detailLoading || state.saving) LinearProgressIndicator(Modifier.fillMaxWidth())
        Column(Modifier.fillMaxWidth().weight(1f).verticalScroll(scroll).padding(horizontal = 24.dp).padding(bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            SelectionContainer { Text(issue.title, style = MaterialTheme.typography.headlineSmall) }
            Text(issueSummary(issue, state.statuses), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            val doneKey = doneStatusKey(state.statuses)
            if (issueCategory(issue, state.statuses) == "in_review" && doneKey != null) {
                Button(onClick = { controller.changeStatus(doneKey) }, enabled = !state.saving && !state.detailLoading && state.detailError == null, modifier = Modifier.fillMaxWidth().testTag("issue.approve")) { Text("验收通过") }
            }
            state.actionNotice?.let { Text(it, color = MaterialTheme.colorScheme.primary, modifier = Modifier.testTag("issue.action-notice")) }
            if (issueCategory(issue, state.statuses) == "blocked") Text("讨论不会自动解除阻塞。补充信息后，需任务状态更新才会移出待关注。", style = MaterialTheme.typography.bodySmall)
            OutlinedButton(onClick = { onDiscussIssue(issue) }, modifier = Modifier.fillMaxWidth().testTag("issue.discuss")) { Text("有修改意见，和 Mika 说") }
            Surface(color = MaterialTheme.colorScheme.surface, shape = RoundedCornerShape(20.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Box {
                        OutlinedButton(onClick = { menu = true }, enabled = !state.saving && !state.detailLoading && state.detailError == null && state.statuses.isNotEmpty()) { Text("状态：${statusName(issue.status, state.statuses)}") }
                        DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                            state.statuses.forEach { status -> DropdownMenuItem(text = { Text(status.name) }, onClick = { menu = false; controller.changeStatus(status.key) }) }
                        }
                    }
                    Text("优先级：${priorityName(issue.priority)}", style = MaterialTheme.typography.bodyMedium)
                    issue.due_date?.let { Text("截止：$it", style = MaterialTheme.typography.bodyMedium) }
                    Text("状态修改仅更新进度，不自动启动 Agent。", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            state.detailError?.let {
                Text(it, color = MaterialTheme.colorScheme.error)
                TextButton(onClick = { controller.detail(issue) }) { Text("重新读取状态") }
            }
            SectionLabel("描述")
            SelectionContainer { Text(issue.description?.ifBlank { "暂无描述" } ?: "暂无描述", style = MaterialTheme.typography.bodyLarge) }
        }
    }
}

private fun priorityName(value: String) = when(value) { "urgent" -> "紧急"; "high" -> "高"; "medium" -> "中"; "low" -> "低"; else -> "无" }
private fun issueCategory(issue: Issue, statuses: List<IssueStatusEntry>) = issue.status_category ?: statuses.find { it.key == issue.status }?.category ?: issue.status
private fun doneStatusKey(statuses: List<IssueStatusEntry>) = statuses.find { it.category == "done" }?.key ?: statuses.find { it.key == "done" || it.key == "completed" }?.key
private fun issueSummary(issue: Issue, statuses: List<IssueStatusEntry>) = when (issueCategory(issue, statuses)) {
    "in_review" -> "已进入审核，等待确认。"; "blocked" -> "当前受阻，需要进一步处理。"; "done" -> "事项已完成。"
    "cancelled" -> "事项已取消。"; "in_progress" -> "事项正在推进。"; "todo" -> "事项已记录，等待开始。"
    else -> "当前状态：${statusName(issue.status, statuses)}"
}
private data class ResourceRow(val id: String, val title: String, val subtitle: String, val facts: List<Pair<String, String>>)
@Composable
fun SettingsRoute(workspace: Workspace, credentials: CredentialStore, base: String, switchWorkspace: () -> Unit, signOut: () -> Unit, active: Boolean = true) {
    val api = remember(workspace.id, base) { scopedWorkspaceApi(base, credentials, workspace.slug) }
    var section by remember { mutableStateOf<String?>(null) }
    var rows by remember { mutableStateOf<List<ResourceRow>>(emptyList()) }
    var selectedId by remember { mutableStateOf<String?>(null) }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var version by remember { mutableIntStateOf(0) }
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    val settingsScroll = rememberLazyListState()
    val resourceScroll = key(section) { rememberLazyListState() }
    val detailScroll = remember(selectedId) { ScrollState(0) }
    LaunchedEffect(section, version, workspace.id, base, active, lifecycle) {
        val current = section ?: return@LaunchedEffect
        if (!active) return@LaunchedEffect
        lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
            loading = true; error = null
            try {
                rows = when (current) {
                    "Runtimes" -> api.runtimes().map { r -> ResourceRow(r.id, r.custom_name?.takeIf { it.isNotBlank() } ?: r.name, if (r.status == "online") "在线" else "离线", listOf("执行模式" to r.runtime_mode, "Provider" to r.provider, "设备" to r.device_info, "最后在线" to r.last_seen_at.orEmpty())) }
                    "Agents" -> {
                        val runtimes = runCatching { api.runtimes() }.getOrDefault(emptyList())
                        api.agents().filter { it.archived_at == null }.map { a -> ResourceRow(a.id, a.name, if (a.status == "offline") "离线" else a.status, listOf("Runtime" to (runtimes.find { it.id == a.runtime_id }?.let { it.custom_name?.takeIf { n -> n.isNotBlank() } ?: it.name } ?: a.runtime_id.ifBlank { "未绑定" }), "访问范围" to a.permission_mode)) }
                    }
                    else -> {
                        val agents = runCatching { api.agents() }.getOrDefault(emptyList())
                        api.squads().filter { it.archived_at == null }.map { s -> ResourceRow(s.id, s.name, s.member_count?.let { "$it 位成员" } ?: "成员数量待加载", listOf("说明" to s.description, "负责人" to (agents.find { it.id == s.leader_id }?.name ?: s.leader_id))) }
                    }
                }
            } catch (e: CancellationException) { throw e } catch (e: Exception) { error = requestError(e) } finally { loading = false }
            awaitCancellation()
        }
    }
    if (!active) return
    BackHandler(section != null) { if (selectedId != null) selectedId = null else { section = null; rows = emptyList() } }
    if (selectedId != null) {
        val row = rows.find { it.id == selectedId }
        Column(Modifier.fillMaxSize().testTag("resource-detail")) {
            PageHeader(row?.title ?: "资源详情", section, "返回 $section", { selectedId = null }) {
                ActionIcon(Icons.Outlined.Refresh, "刷新详情", { version++ }, !loading)
            }
            if (loading) LinearProgressIndicator(Modifier.fillMaxWidth())
            Column(Modifier.fillMaxWidth().weight(1f).verticalScroll(detailScroll).padding(horizontal = 24.dp).padding(bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
                error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
                if (row != null) {
                    StatusPill(row.subtitle)
                    row.facts.forEach { (label, value) ->
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            SectionLabel(label)
                            SelectionContainer { Text(value.ifBlank { "暂无信息" }, style = MaterialTheme.typography.bodyLarge) }
                        }
                    }
                } else if (!loading && error == null) Text("资源已不存在或当前不可见。")
            }
        }
        return
    }
    Column(Modifier.fillMaxSize()) {
        PageHeader(section ?: "设置", subtitle = if (section == null) "你的工作空间与协作伙伴" else null,
            backLabel = "返回设置", back = if (section != null) ({ section = null; rows = emptyList() }) else null) {
            if (section != null) ActionIcon(Icons.Outlined.Refresh, "刷新", { version++ }, !loading)
        }
        if (section == null) LazyColumn(Modifier.fillMaxSize().testTag("settings-list"), state = settingsScroll, contentPadding = PaddingValues(horizontal = 24.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
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
                            ResourceItem(name, description, resourceIcon(name), { rows = emptyList(); error = null; section = name })
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
            LazyColumn(Modifier.fillMaxSize(), state = resourceScroll, contentPadding = PaddingValues(horizontal = 24.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items(rows, key = { it.id }) { row -> ResourceItem(row.title, row.subtitle, resourceIcon(section!!), { selectedId = row.id }) }
                if (!loading && error == null && rows.isEmpty()) item {
                    Column(Modifier.fillMaxWidth().padding(vertical = 48.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        GlyphBadge(resourceIcon(section!!))
                        Text("暂无可见的 $section", Modifier.padding(top = 16.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }

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
