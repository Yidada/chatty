package ai.chatty.core.model

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject

// Reference: Multica 1cc46b269, packages/core/types/chat.ts and attachment.ts.
@Serializable data class ChatSession(
    val id: String, val agent_id: String, val title: String = "",
    val status: String = "active", val pinned: Boolean = false,
    val has_unread: Boolean = false, val unread_count: Int = 0,
    val last_message: ChatPreview? = null, val created_at: String = "", val updated_at: String = ""
)
@Serializable data class ChatPreview(val content: String = "", val role: String = "assistant", val created_at: String = "", val failure_reason: String? = null)
@Serializable data class ChatMessage(
    val id: String, val chat_session_id: String, val role: String, val content: String = "",
    val task_id: String? = null, val created_at: String = "", val attachments: List<Attachment>? = emptyList(),
    val failure_reason: String? = null, val elapsed_ms: Long? = null,
    val message_kind: String = "message", val quick_actions: List<QuickAction>? = emptyList()
)
@Serializable data class Attachment(val id: String, val filename: String, val content_type: String = "", val size_bytes: Long = 0,
    val url: String = "", val download_url: String = "", val markdown_url: String = "")
@Serializable data class QuickAction(val label: String, val prompt: String, val primary: Boolean = false)
@Serializable data class MessageCursor(val id: String, val created_at: String)
@Serializable data class MessagePage(val messages: List<ChatMessage>, val has_more: Boolean = false, val next_cursor: MessageCursor? = null)
@Serializable data class NewChat(val agent_id: String)
@Serializable data class SendMessage(val content: String, val attachment_ids: List<String> = emptyList())
@Serializable data class SendReceipt(val message_id: String, val task_id: String, val created_at: String, val queued: Boolean = false, val supports_queue: Boolean = false, val attachment_ids: List<String>? = null)
@Serializable data class QueuedTask(val task_id: String, val status: String = "queued", val created_at: String = "", val message_id: String? = null, val content: String? = null)
@Serializable data class PendingTask(val task_id: String? = null, val status: String? = null, val created_at: String? = null,
    val wait_reason: String? = null, val supports_queue: Boolean = false, val queued_tasks: List<QueuedTask>? = emptyList())
// server/pkg/protocol/messages.go TaskMessagePayload. Unknown type/input stay inspectable.
@Serializable data class TaskTrace(val task_id: String = "", val seq: Int = 0, val type: String = "activity.generic",
    val tool: String? = null, val content: String? = null, val input: JsonObject? = null, val output: String? = null,
    val created_at: String? = null)
// packages/core/types/agent.ts; permission rules.ts. Do not infer identity from display name.
@Serializable data class ChatAgent(val id: String, val name: String, val system_key: String? = null,
    val avatar_url: String? = null, val status: String = "offline", val runtime_id: String = "",
    val runtime_bound: Boolean? = null, val archived_at: String? = null,
    val owner_id: String? = null, val permission_mode: String = "private", val invocation_targets: List<InvocationTarget>? = emptyList())
@Serializable data class InvocationTarget(val target_type: String, val target_id: String)
@Serializable data class ChatUser(val id: String)
@Serializable data class ChatMember(val user_id: String, val role: String)
