package ai.chatty.feature.inbox

import ai.chatty.core.model.Issue
import ai.chatty.core.model.Workspace
import ai.chatty.core.ui.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.HelpOutline
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.outlined.Waves
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

@Composable
fun ActivityRoute(
    controller: ActivityController, workspace: Workspace, active: Boolean = true,
    onOpenIssue: (Issue) -> Unit = {}
) {
    val state by controller.state.collectAsStateWithLifecycle()
    val list = rememberLazyListState()
    var pending by rememberSaveable { mutableStateOf(false) }
    LaunchedEffect(active) { if (active) controller.refresh() }
    if (!active) return
    Column(Modifier.fillMaxSize()) {
        PageHeader("动态", workspace.name) { ActionIcon(Icons.Outlined.Refresh, "刷新动态", controller::refresh, !state.loading) }
        Row(Modifier.fillMaxWidth().padding(horizontal = 24.dp), verticalAlignment = Alignment.CenterVertically) {
            ActivityTab("最近动态", !pending) { pending = false }
            ActivityTab(if (state.actionTotal > 0) "待关注 ${state.actionTotal}" else "待关注", pending) { pending = true }
        }
        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
        if (state.loading && state.recent.isEmpty() && state.actions.isEmpty()) LinearProgressIndicator(Modifier.fillMaxWidth())
        val rows = if (pending) state.actions else state.recent
        val error = if (pending) state.actionError else state.error
        error?.let { Text(it, Modifier.padding(horizontal = 24.dp, vertical = 8.dp), color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }
        state.readError?.let { Text(it, Modifier.padding(horizontal = 24.dp), color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }
        LazyColumn(Modifier.weight(1f).testTag("activity-list"), state = list, contentPadding = PaddingValues(horizontal = 24.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            if (rows.isEmpty() && !state.loading) item("empty") {
                Column(Modifier.fillMaxWidth().padding(vertical = 64.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    GlyphBadge(Icons.Outlined.Waves)
                    Text(if (pending) "当前没有待关注事项" else "暂时没有项目动态", Modifier.padding(top = 16.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            if (pending) {
                item("explanation") { Text("工作区内待验收或受阻的任务；查看不会解除关注。", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
                listOf("in_review" to "待验收", "blocked" to "受阻").forEach { (category, label) ->
                    val group = rows.filter { activityCategory(it, state.statuses) == category }
                    if (group.isNotEmpty()) {
                        item("group-$category") { Text(label, style = MaterialTheme.typography.titleSmall, modifier = Modifier.padding(top = 8.dp)) }
                        items(group, key = { it.id }) { issue -> ActivityRow(issue, state) { onOpenIssue(issue) } }
                    }
                }
            } else {
                items(rows, key = { it.id }) { issue -> ActivityRow(issue, state) { onOpenIssue(issue) } }
            }
            if (controller.hasMore(pending)) item("more") {
                Text("已加载 ${rows.size} / 共 ${if (pending) state.actionTotal else state.recentTotal} 项", style = MaterialTheme.typography.bodySmall)
                TextButton(onClick = { controller.more(pending) }, enabled = !state.loadingMore) {
                    Text(if (state.loadingMore) "加载中…" else "加载更多")
                }
            }
            item { Spacer(Modifier.height(16.dp)) }
        }
    }
}

@Composable
private fun ActivityTab(label: String, selected: Boolean, onClick: () -> Unit) {
    Column(Modifier.clickable(onClick = onClick).padding(vertical = 8.dp, horizontal = 4.dp).padding(end = 16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label, style = MaterialTheme.typography.titleSmall, color = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(6.dp))
        Box(Modifier.height(2.dp).width(28.dp).clip(CircleShape).background(if (selected) MaterialTheme.colorScheme.primary else androidx.compose.ui.graphics.Color.Transparent))
    }
}

private fun categoryIcon(issue: Issue, statuses: List<ai.chatty.core.model.IssueStatusEntry>): ImageVector = when (activityCategory(issue, statuses)) {
    "in_review", "done", "completed" -> Icons.Outlined.CheckCircle
    "blocked" -> Icons.Outlined.HelpOutline
    else -> Icons.Outlined.Waves
}

@Composable
private fun ActivityRow(issue: Issue, state: ActivityState, onClick: () -> Unit) {
    val unread = activityUnread(issue, state.reads)
    Card(onClick = onClick, modifier = Modifier.fillMaxWidth().testTag("activity.issue.${issue.id}"), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box {
                GlyphBadge(categoryIcon(issue, state.statuses))
                if (unread) Box(Modifier.align(Alignment.TopEnd).offset(x = 2.dp, y = (-2).dp).size(10.dp).clip(CircleShape).background(MaterialTheme.colorScheme.error))
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(issue.identifier, Modifier.weight(1f), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(activityStatusName(issue.status, state.statuses), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                }
                Text(issue.title, style = MaterialTheme.typography.titleMedium, maxLines = 2, overflow = TextOverflow.Ellipsis)
                Text("${state.projects.find { it.id == issue.project_id }?.title ?: "未归属项目"} · ${activitySummary(issue, state.statuses)}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 2, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}
