package ai.chatty.feature.chat

import ai.chatty.core.model.*
import java.net.URI
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

// Mirrors packages/core/permissions/rules.ts: owner, explicit workspace/member grant; no admin bypass.
fun canChat(agent: ChatAgent, userId: String?, role: String?): Boolean = userId != null &&
    (agent.owner_id == userId || (agent.permission_mode == "public_to" && agent.invocation_targets.orEmpty().any {
        (it.target_type == "workspace" && role != null) || (it.target_type == "member" && it.target_id == userId)
    }))
fun orderedSessions(sessions: List<ChatSession>) = sessions.sortedWith(compareByDescending<ChatSession> { it.pinned }.thenByDescending { it.updated_at })
fun preview(content: String) = content.replace(Regex("```[\\s\\S]*?```"), " ").replace(Regex("[#*`>~]"), "").replace(Regex("\\s+"), " ").trim()
fun chatTime(value: String): String = runCatching {
    val date = Instant.parse(value).atZone(ZoneId.systemDefault())
    val now = java.time.ZonedDateTime.now()
    date.format(DateTimeFormatter.ofPattern(if (date.toLocalDate() == now.toLocalDate()) "HH:mm" else if (date.year == now.year) "M/d" else "yyyy/M/d"))
}.getOrDefault("")
fun stripQuickProtocol(content: String): String {
    val match = Regex("(?:^|\\r?\\n)```quick-actions(?:\\r?\\n|$)").findAll(content).lastOrNull() ?: return content
    val remainder = content.substring(match.range.last + 1)
    val closing = Regex("\\r?\\n```").find(remainder)
    if (closing != null && remainder.substring(closing.range.last + 1).isNotBlank()) return content
    return content.substring(0, match.range.first).trimEnd()
}
fun redactTrace(content: String): String {
    var text = content
    val patterns = listOf(
        "\\bAKIA[0-9A-Z]{16}\\b", "(?i)(?:aws_secret_access_key|secret_?access_?key)\\s*[=:]\\s*[A-Za-z0-9/+=]{40}",
        "-----BEGIN[A-Z\\s]*PRIVATE KEY-----[\\s\\S]*?-----END[A-Z\\s]*PRIVATE KEY-----",
        "\\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9_]{36,255}\\b", "\\bgithub_pat_[A-Za-z0-9_]{20,255}\\b",
        "\\bAIza[0-9A-Za-z_-]{35}", "\\bglpat-[A-Za-z0-9_-]{20,}\\b", "\\bsk-[A-Za-z0-9_-]{20,}\\b",
        "\\bxox[bporas]-[A-Za-z0-9-]{10,}\\b", "\\bey[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{10,}\\b",
        "(?i)\\bBearer\\s+[A-Za-z0-9\\-._~+/]+=*", "(?i)(?:postgres|mysql|mongodb|redis|amqp)(?:ql)?://[^:\\s]+:[^@\\s]+@",
        "(?i)(?:API_KEY|API_SECRET|SECRET_KEY|SECRET|ACCESS_TOKEN|AUTH_TOKEN|PRIVATE_KEY|DATABASE_URL|DB_PASSWORD|DB_URL|REDIS_URL|PASSWORD|TOKEN)\\s*[=:]\\s*\\S+"
    )
    patterns.forEach { text = text.replace(Regex(it), "[已隐藏凭据]") }
    return text
}
fun timeline(rows: List<TaskTrace>): List<TaskTrace> {
    val out = mutableListOf<TaskTrace>()
    rows.associateBy { it.seq }.values.sortedBy { it.seq }.forEach { next ->
        val prev = out.lastOrNull()
        if (prev != null && prev.type == next.type && next.type in listOf("text", "thinking"))
            out[out.lastIndex] = prev.copy(content = prev.content.orEmpty() + next.content.orEmpty())
        else out += next
    }
    return out.map { it.copy(content = it.content?.let(::redactTrace), output = it.output?.let(::redactTrace)) }
}
data class TimelineParts(val preface: List<TaskTrace>, val middle: List<TaskTrace>, val final: List<TaskTrace>)
fun splitTimeline(rows: List<TaskTrace>): TimelineParts {
    val first = rows.indexOfFirst { it.type != "text" }
    if (first < 0) return TimelineParts(emptyList(), emptyList(), rows)
    val last = rows.indexOfLast { it.type != "text" }
    return TimelineParts(rows.take(first), rows.subList(first, last + 1), rows.drop(last + 1))
}
fun pendingLabel(p: PendingTask, agent: ChatAgent?, trace: List<TaskTrace>): String = when {
    p.status == "deferred" -> "等待重试"
    p.status in listOf("queued", "dispatched") && agent?.status == "offline" -> "等待原 Runtime 上线"
    p.status == "waiting_local_directory" -> p.wait_reason?.takeIf { it.isNotBlank() } ?: "等待工作目录可用"
    p.status == "queued" -> "排队中"
    p.status == "dispatched" -> "正在启动"
    p.status == "running" -> when (val last = trace.lastOrNull { it.type !in listOf("error", "tool_result") }) {
        null -> "正在思考"
        else -> when (last.type) { "text" -> "正在回复"; "tool_use" -> "正在使用 ${last.tool ?: "工具"}"; else -> "正在思考" }
    }
    else -> p.status ?: "等待状态更新"
}
fun elapsed(value: Long?): String = value?.let { if (it < 60000) "${it / 1000} 秒" else "${it / 60000} 分 ${it / 1000 % 60} 秒" }.orEmpty()
fun safeWebLink(value: String, base: String): String? = runCatching {
    val uri = URI(base).resolve(value)
    uri.takeIf { it.scheme in listOf("https", "http") && it.host != null && it.userInfo == null }?.toString()
}.getOrNull()
fun attachmentLink(a: Attachment, base: String): String? =
    safeWebLink(a.markdown_url.ifBlank { "api/attachments/${a.id}/download" }, base)

fun failureLabel(reason: String): String = when (reason) {
    "timeout", "runtime_cli_timeout", "codex_semantic_inactivity" -> "任务等待超时，可以稍后重试。"
    "runtime_offline", "runtime_recovery" -> "执行设备暂时离线，请等待设备恢复。"
    "manual", "cancelled" -> "任务已停止。"
    "agent_error.provider_auth_or_access" -> "模型服务需要重新验证登录或权限。"
    "agent_error.provider_quota_limit" -> "模型服务额度不足，请检查账号额度。"
    "agent_error.provider_capacity_or_rate_limit" -> "模型服务繁忙，请稍后重试。"
    "agent_error.provider_network" -> "连接模型服务失败，请检查网络后重试。"
    "agent_error.context_overflow" -> "对话内容超过模型容量，请新建对话后重试。"
    else -> "这次任务未能完成，可以查看详情后重试。"
}
fun fileSize(bytes: Long): String = when { bytes < 1024 -> "$bytes B"; bytes < 1024 * 1024 -> "${bytes / 1024} KB"; else -> "${bytes / (1024 * 1024)} MB" }

// Navigation policy is separate from URLs used to fetch images and attachments.
fun externalContentLink(value: String, base: String): String? {
    val safe = safeWebLink(value, base) ?: return null
    val host = URI(safe).host.lowercase(java.util.Locale.ROOT).trimEnd('.')
    val apiHost = runCatching { URI(base).host?.lowercase(java.util.Locale.ROOT)?.trimEnd('.') }.getOrNull()
    return safe.takeUnless { host == "multica.ai" || host.endsWith(".multica.ai") || host == apiHost }
}

// Keep labels and their children (including emphasis); remove only navigation semantics.
fun removeAppLinks(node: org.commonmark.node.Node, base: String) {
    node.accept(object : org.commonmark.node.AbstractVisitor() {
        override fun visit(link: org.commonmark.node.Link) {
            visitChildren(link)
            if (externalContentLink(link.destination, base) == null) {
                while (link.firstChild != null) link.insertBefore(link.firstChild)
                link.unlink()
            }
        }
    })
}
