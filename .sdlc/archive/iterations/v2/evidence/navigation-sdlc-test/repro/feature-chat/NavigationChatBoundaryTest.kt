package ai.chatty.feature.chat
import ai.chatty.core.model.*
import ai.chatty.core.network.ChatApi
import kotlinx.coroutines.*
import kotlinx.coroutines.test.*
import kotlinx.serialization.json.*
import okhttp3.MultipartBody
import org.junit.Test
import org.junit.Assert.*

@OptIn(ExperimentalCoroutinesApi::class)
class NavigationChatBoundaryTest {
    private class Fake : ChatApi {
        val session = ChatSession("s1", "mika", "Fixture")
        var rows = listOf(ChatMessage("a0", "s1", "assistant", "Hello", created_at = "2026-01-02"))
        var older = listOf(ChatMessage("a-1", "s1", "assistant", "Earlier", created_at = "2026-01-01"))
        var receiptAttachments: List<String>? = null
        var sends = 0; var fail = false; var gate: CompletableDeferred<Unit>? = null
        var pendingTask = PendingTask(); var cursor: String? = null
        override suspend fun sessions() = listOf(session)
        var agentRows = listOf(ChatAgent("mika", "Renamed", system_key = "mika", owner_id = "u1", runtime_id = "r1"))
        override suspend fun agents() = agentRows
        override suspend fun me() = ChatUser("u1")
        override suspend fun members(id: String) = listOf(ChatMember("u1", "member"))
        override suspend fun create(body: NewChat) = session
        override suspend fun messages(id: String, limit: Int, beforeTime: String?, beforeId: String?): MessagePage {
            cursor = beforeId
            return if (beforeId == null) MessagePage(rows, true, MessageCursor("a0", "2026-01-02")) else MessagePage(older + rows.take(1))
        }
        override suspend fun send(id: String, body: SendMessage): SendReceipt {
            sends++; gate?.await(); if (fail) throw java.io.IOException("response lost")
            rows = rows + ChatMessage("u2", "s1", "user", body.content, "t1", "2026-01-03")
            pendingTask = PendingTask("t1", "running")
            return SendReceipt("u2", "t1", "2026-01-03", attachment_ids = receiptAttachments)
        }
        override suspend fun pending(id: String) = pendingTask
        override suspend fun markRead(id: String) {}
        override suspend fun trace(id: String) = emptyList<TaskTrace>()
        override suspend fun attachment(id: String) = Attachment(id, "test.txt")
        override suspend fun attachmentDownload(id: String): retrofit2.Response<okhttp3.ResponseBody> = error("unused")
        override suspend fun attachmentText(id: String): okhttp3.ResponseBody = error("unused")
        override suspend fun upload(file: MultipartBody.Part) = Attachment("f1", "test.txt")
    }
    private class Drafts : ChatDrafts {
        val data = mutableMapOf<String, String>()
        override suspend fun read(key: String) = data[key].orEmpty()
        override suspend fun write(key: String, value: String) { data[key] = value }
    }

    @Test fun retainedChatRefreshRecognizesNewRuntimeBinding() = runTest {
        val api = Fake()
        val ready = api.agentRows.single()
        api.agentRows = listOf(ready.copy(runtime_id = "", runtime_bound = false))
        val c = ChatController(api, Drafts(), Workspace("w", "slug", "Test"), this)
        c.initialize(); advanceUntilIdle(); c.draft("keep this draft"); advanceUntilIdle()
        assertFalse(c.state.value.canSend)
        // Settings now sees the bound runtime; returning to Chat calls start/refresh.
        api.agentRows = listOf(ready.copy(runtime_bound = true))
        c.start(); runCurrent(); c.stop(); advanceUntilIdle()
        c.refresh(); advanceUntilIdle()
        assertEquals("keep this draft", c.state.value.draft)
        assertTrue("Returning to Chat and manual refresh must recognize the runtime binding", c.state.value.canSend)
    }
    @Test fun stoppingVisibleChatDoesNotCancelAnInFlightSend() = runTest {
        val api = Fake(); val c = ChatController(api, Drafts(), Workspace("w", "slug", "Test"), this)
        c.initialize(); advanceUntilIdle(); c.start(); runCurrent()
        c.draft("submitted before leaving tab"); api.gate = CompletableDeferred(); c.send(); runCurrent()
        assertEquals(1, api.sends); assertTrue(c.state.value.sending)
        c.stop(); runCurrent()
        assertTrue(c.state.value.sending)
        api.gate!!.complete(Unit); advanceUntilIdle()
        assertEquals(1, api.sends); assertFalse(c.state.value.sending)
        assertEquals("t1", c.state.value.pending.task_id); assertEquals("", c.state.value.draft)
    }
}
