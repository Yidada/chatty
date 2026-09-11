package ai.chatty.feature.chat

import ai.chatty.core.model.ChatMessage
import ai.chatty.core.model.PendingTask
import ai.chatty.core.model.QueuedTask
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ChatPendingTest {
    private fun queued(id: String, at: String = "", messageId: String? = null, content: String? = null) =
        QueuedTask(id, "queued", at, messageId, content)

    @Test fun idleSendBecomesHeadAndRunningSendQueuesBehindIt() {
        val head = enqueuePending(null, queued("t1", "2026-01-01T00:00:00Z", "m1", "one"))
        assertEquals("t1", head.task_id); assertTrue(head.queued_tasks.orEmpty().isEmpty())
        val two = enqueuePending(head, queued("t2", "2026-01-01T00:00:01Z", "m2", "two"))
        assertEquals("t1", two.task_id); assertEquals(listOf("t2"), two.queued_tasks.orEmpty().map { it.task_id })
    }

    @Test fun richObservationWinsOverSparseRegardlessOfOrder() {
        val head = enqueuePending(null, queued("t0", "2026-01-01T00:00:00Z"))
        val sparse = enqueuePending(head, queued("t1", "2026-01-01T00:00:00Z"))
        val rich = enqueuePending(sparse, queued("t1", "2026-01-01T00:00:00Z", "m1", "hello"), queued = true)
        assertEquals("hello", rich.queued_tasks.orEmpty().single().content)
        val backToSparse = enqueuePending(rich, queued("t1", "2026-01-01T00:00:00Z"), queued = true)
        assertEquals("m1", backToSparse.queued_tasks.orEmpty().single().message_id)
    }

    @Test fun queueSortsByCreatedAtThenTaskId() {
        val head = enqueuePending(null, queued("head", "2026-01-01T00:00:00Z"))
        val a = enqueuePending(head, queued("b", "2026-01-01T00:00:02Z"))
        val b = enqueuePending(a, queued("a", "2026-01-01T00:00:01Z"))
        assertEquals(listOf("a", "b"), b.queued_tasks.orEmpty().map { it.task_id })
    }

    @Test fun promoteMovesQueuedTaskToHeadAndKeepsUnstartedHead() {
        var pending = PendingTask("t1", "queued", "2026-01-01T00:00:00Z", supports_queue = true,
            queued_tasks = listOf(queued("t2", "2026-01-01T00:00:01Z", "m2", "two")))
        pending = promotePending(pending, "t2", "running", "2026-01-01T00:00:01Z")
        assertEquals("t2", pending.task_id); assertEquals("running", pending.status)
        assertEquals(listOf("t1"), pending.queued_tasks.orEmpty().map { it.task_id })
    }

    @Test fun removeHeadPromotesNextAndRemoveQueuedOnlyDropsRow() {
        val pending = PendingTask("t1", "running", supports_queue = true,
            queued_tasks = listOf(queued("t2"), queued("t3")))
        val promoted = removePending(pending, "t1")
        assertEquals("t2", promoted.task_id); assertEquals(listOf("t3"), promoted.queued_tasks.orEmpty().map { it.task_id })
        val dropped = removePending(pending, "t3")
        assertEquals("t1", dropped.task_id); assertEquals(listOf("t2"), dropped.queued_tasks.orEmpty().map { it.task_id })
    }

    @Test fun prioritizeMovesSelectedToFront() {
        val pending = PendingTask("t1", "running", supports_queue = true,
            queued_tasks = listOf(queued("t2"), queued("t3")))
        val prioritized = prioritizePending(pending, "t3")
        assertEquals(listOf("t3", "t2"), prioritized.queued_tasks.orEmpty().map { it.task_id })
    }

    @Test fun hideQueuedMessagesHidesOnlyMatchingMessageAndTask() {
        val messages = listOf(
            ChatMessage("m1", "s1", "user", "one", task_id = "t1"),
            ChatMessage("m2", "s1", "user", "two", task_id = "t2"),
            ChatMessage("m3", "s1", "assistant", "reply", task_id = "t1"))
        val pending = PendingTask("t1", "running", queued_tasks = listOf(queued("t2", messageId = "m2")))
        assertEquals(listOf("m1", "m3"), hideQueuedMessages(messages, pending).map { it.id })
        assertEquals(3, hideQueuedMessages(messages, PendingTask()).size)
    }

    @Test fun waitReasonOnlySurvivesWhileStatusIsCurrent() {
        val waiting = PendingTask("t1", "queued", supports_queue = true,
            queued_tasks = listOf(queued("t2")))
        val held = promotePending(waiting, "t2", "waiting_local_directory", waitReason = "waiting for /tmp")
        assertEquals("waiting for /tmp", held.wait_reason)
        val running = promotePending(held, "t2", "running")
        assertNull(running.wait_reason)
    }
}
