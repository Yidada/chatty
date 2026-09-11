package ai.chatty.feature.chat

import ai.chatty.core.model.ChatMessage
import ai.chatty.core.model.PendingTask
import ai.chatty.core.model.QueuedTask

// Ported from Multica packages/core/chat/pending.ts. The head task and its FIFO
// follow-ups share one PendingTask; these helpers keep the queue convergent as
// sparse lifecycle events and authoritative refetches arrive in any order.

private fun compareQueuedTasks(left: QueuedTask, right: QueuedTask): Int {
    val leftTime = runCatching { java.time.Instant.parse(left.created_at).toEpochMilli() }.getOrNull()
    val rightTime = runCatching { java.time.Instant.parse(right.created_at).toEpochMilli() }.getOrNull()
    if (leftTime != null && rightTime != null && leftTime != rightTime) return leftTime.compareTo(rightTime)
    return left.task_id.compareTo(right.task_id)
}

private fun uniqueQueue(tasks: List<QueuedTask>): List<QueuedTask> {
    // The send response carries the message preview while task:queued is sparse.
    // Keep whichever observation is rich regardless of arrival order.
    val byId = LinkedHashMap<String, QueuedTask>()
    for (task in tasks) if (!byId.containsKey(task.task_id) || task.message_id != null) byId[task.task_id] = task
    return byId.values.toList()
}

private fun normalizeQueue(tasks: List<QueuedTask>) = uniqueQueue(tasks).sortedWith(::compareQueuedTasks)

private fun asSummary(task: PendingTask): QueuedTask? {
    val id = task.task_id ?: return null
    return QueuedTask(id, task.status ?: "queued", task.created_at.orEmpty())
}

// A hold explanation outlives the hold: keep it only while the waiting status is current.
private fun resolveWaitReason(status: String, incoming: String?, existing: String?): String? =
    if (status != "waiting_local_directory") null else incoming ?: existing

fun enqueuePending(current: PendingTask?, task: QueuedTask, queued: Boolean = current?.task_id != null && current.task_id != task.task_id): PendingTask {
    val support = current?.supports_queue == true
    if (current?.task_id == null) {
        return if (queued) PendingTask(supports_queue = support, queued_tasks = listOf(task))
        else PendingTask(task_id = task.task_id, status = task.status, created_at = task.created_at, supports_queue = support,
            queued_tasks = normalizeQueue(current?.queued_tasks.orEmpty().filter { it.task_id != task.task_id }))
    }
    if (current.task_id == task.task_id) {
        val status = if (current.status != null && current.status != "queued") current.status else task.status
        return current.copy(status = status, created_at = current.created_at ?: task.created_at,
            queued_tasks = current.queued_tasks.orEmpty().filter { it.task_id != task.task_id })
    }
    if (!queued) return PendingTask(task_id = task.task_id, status = task.status, created_at = task.created_at,
        supports_queue = support, queued_tasks = emptyList())
    return current.copy(queued_tasks = normalizeQueue(current.queued_tasks.orEmpty() + task))
}

fun promotePending(current: PendingTask?, taskID: String, status: String, createdAt: String? = null, waitReason: String? = null): PendingTask {
    val queue = current?.queued_tasks.orEmpty()
    if (current?.task_id == taskID) return current.copy(status = status,
        wait_reason = resolveWaitReason(status, waitReason, current.wait_reason),
        queued_tasks = queue.filter { it.task_id != taskID })
    val promoted = queue.find { it.task_id == taskID }
    // Lifecycle events are only hints: a late event for an unknown task must not
    // synthesize a new head after the authoritative pending query cleared.
    if (current?.task_id == null || promoted == null) return current ?: PendingTask()
    val previousHead = asSummary(current)
    return PendingTask(task_id = promoted.task_id, status = status,
        wait_reason = resolveWaitReason(status, waitReason, null),
        created_at = promoted.created_at.ifEmpty { createdAt.orEmpty() },
        supports_queue = current.supports_queue,
        queued_tasks = uniqueQueue(listOfNotNull(previousHead?.takeIf { it.status == "queued" }) + queue.filter { it.task_id != taskID }))
}

fun removePending(current: PendingTask?, taskID: String): PendingTask {
    if (current?.task_id == null) return PendingTask()
    if (current.task_id != taskID) return current.copy(queued_tasks = current.queued_tasks.orEmpty().filter { it.task_id != taskID })
    val remaining = uniqueQueue(current.queued_tasks.orEmpty().filter { it.task_id != taskID })
    val next = remaining.firstOrNull() ?: return PendingTask(supports_queue = current.supports_queue)
    return PendingTask(task_id = next.task_id, status = next.status, created_at = next.created_at,
        supports_queue = current.supports_queue, queued_tasks = remaining.drop(1))
}

fun prioritizePending(current: PendingTask?, taskID: String): PendingTask {
    if (current?.task_id == null) return PendingTask()
    val queue = current.queued_tasks.orEmpty()
    val selected = queue.find { it.task_id == taskID } ?: return current
    return current.copy(queued_tasks = listOf(selected) + queue.filter { it.task_id != taskID })
}

// Queued sends stay out of the transcript; the queue tray under the composer owns them.
fun hideQueuedMessages(messages: List<ChatMessage>, pending: PendingTask?): List<ChatMessage> {
    val queuedByMessage = pending?.queued_tasks.orEmpty().mapNotNull { task -> task.message_id?.let { it to task.task_id } }.toMap()
    if (queuedByMessage.isEmpty()) return messages
    return messages.filter { queuedByMessage[it.id] != it.task_id }
}
