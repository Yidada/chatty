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
class ChatControllerTest {
    private class Fake : ChatApi {
        val session = ChatSession("s1", "mika", "Fixture")
        var rows = listOf(ChatMessage("a0", "s1", "assistant", "Hello", created_at = "2026-01-02"))
        var older = listOf(ChatMessage("a-1", "s1", "assistant", "Earlier", created_at = "2026-01-01"))
        var receiptAttachments: List<String>? = null
        var sends = 0; var fail = false; var gate: CompletableDeferred<Unit>? = null
        var pendingTask = PendingTask(); var cursor: String? = null
        override suspend fun sessions() = listOf(session)
        override suspend fun agents() = listOf(ChatAgent("mika", "Renamed", system_key = "mika", owner_id = "u1", runtime_id = "r1"))
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
    @Test fun sendIsSingleFlightAndUsesServerTask() = runTest {
        val api = Fake(); val drafts = Drafts(); val c = ChatController(api, drafts, Workspace("w", "slug", "Test"), this)
        c.initialize(); runCurrent(); assertEquals("mika", c.state.value.agent?.id)
        c.draft("hello"); api.gate = CompletableDeferred(); c.send(); c.send(); runCurrent()
        assertEquals(1, api.sends); assertTrue(c.state.value.sending)
        api.gate!!.complete(Unit); advanceUntilIdle()
        assertEquals("t1", c.state.value.pending.task_id); assertEquals(1, c.state.value.messages.count { it.id == "u2" })
        assertEquals("", c.state.value.draft); assertFalse(c.state.value.canSend)
    }
    @Test fun lostReceiptPreservesDraftAndRequiresReview() = runTest {
        val api = Fake(); api.fail = true; val drafts = Drafts(); val c = ChatController(api, drafts, Workspace("w", "slug", "Test"), this)
        c.initialize(); runCurrent(); c.draft("keep me"); c.send(); advanceUntilIdle()
        assertTrue(c.state.value.uncertain); assertEquals("keep me", c.state.value.draft)
        c.send(); advanceUntilIdle(); assertEquals(1, api.sends)
        assertTrue(drafts.data.values.contains("keep me"))
    }
    @Test fun paginationDeduplicatesAndRefreshKeepsOlderRows() = runTest {
        val api = Fake(); val c = ChatController(api, Drafts(), Workspace("w", "slug", "Test"), this)
        c.initialize(); advanceUntilIdle(); c.older(); advanceUntilIdle()
        assertEquals("a0", api.cursor); assertEquals(listOf("a-1", "a0"), c.state.value.messages.map { it.id })
        c.refresh(); advanceUntilIdle(); assertEquals(listOf("a-1", "a0"), c.state.value.messages.map { it.id })
        assertFalse(c.state.value.hasMore)
    }
    @Test fun rejectedAttachmentRemainsVisibleForRetry() = runTest {
        val api = Fake(); api.receiptAttachments = emptyList()
        val c = ChatController(api, Drafts(), Workspace("w", "slug", "Test"), this)
        c.initialize(); advanceUntilIdle()
        c.upload(MultipartBody.Part.createFormData("file", "synthetic")); advanceUntilIdle()
        c.send(); advanceUntilIdle()
        assertEquals("f1", c.state.value.attachments.single().id)
        assertTrue(c.state.value.notice.orEmpty().contains("test.txt"))
        assertEquals(1, api.sends)
    }
    @Test fun sameTimestampCursorSurvivesRefresh() = runTest {
        val api = Fake(); api.older = listOf(ChatMessage("a-1", "s1", "assistant", "same time", created_at="2026-01-02"))
        val c = ChatController(api, Drafts(), Workspace("w", "slug", "Test"), this)
        c.initialize(); advanceUntilIdle(); c.older(); advanceUntilIdle(); c.refresh(); advanceUntilIdle()
        assertEquals(listOf("a-1", "a0"), c.state.value.messages.map { it.id })
    }
    @Test fun acceptedSendRemainsPendingIfLocalStorageFails() = runTest {
        val api = Fake()
        val badDisk = object : ChatDrafts {
            override suspend fun read(key: String) = ""
            override suspend fun write(key: String, value: String) { if (value.isEmpty()) throw java.io.IOException("disk full") }
        }
        val c = ChatController(api, badDisk, Workspace("w", "slug", "Test"), this)
        c.initialize(); advanceUntilIdle(); c.draft("hello"); c.send(); advanceUntilIdle()
        assertEquals("t1", c.state.value.pending.task_id); assertFalse(c.state.value.uncertain)
        c.send(); advanceUntilIdle(); assertEquals(1, api.sends)
    }
    @Test fun scopedEventsAndFinalMessageConverge() = runTest {
        val api = Fake(); api.pendingTask = PendingTask("t1", "running")
        val c = ChatController(api, Drafts(), Workspace("w", "slug", "Test"), this); c.initialize(); advanceUntilIdle()
        fun event(type: String, payload: String) = c.onEvent(Json.parseToJsonElement("""{"type":"$type","payload":$payload}""").jsonObject)
        event("task:message", """{"task_id":"other","seq":1,"type":"text","content":"wrong"}""")
        assertTrue(c.state.value.traces.values.flatten().isEmpty())
        repeat(2) { event("task:message", """{"task_id":"t1","seq":1,"type":"text","content":"reply"}""") }
        assertEquals(1, c.state.value.traces["t1"]?.size)
        event("future:event", """{"task_id":"t1","new":"data"}"""); assertEquals(1, c.state.value.generic.size)
        api.rows = api.rows + ChatMessage("a2", "s1", "assistant", "Done", "t1", "2026-01-04"); api.pendingTask = PendingTask()
        repeat(2) { event("chat:done", """{"chat_session_id":"s1","task_id":"t1","message_id":"a2"}""") }; advanceUntilIdle()
        assertNull(c.state.value.pending.task_id); assertEquals(1, c.state.value.messages.count { it.id == "a2" })
    }
    @Test fun sourcePermissionAndTimelineRules() {
        val privateAgent = ChatAgent("a", "A", owner_id = "owner")
        assertFalse(canChat(privateAgent, "admin", "admin")); assertTrue(canChat(privateAgent, "owner", null))
        val shared = privateAgent.copy(permission_mode = "public_to", invocation_targets = listOf(InvocationTarget("workspace", "w")))
        assertTrue(canChat(shared, "member", "member")); assertFalse(canChat(shared, "external", null))
        val rows = timeline(listOf(TaskTrace(seq=3, type="text", content="done"), TaskTrace(seq=1, type="thinking", content="a"), TaskTrace(seq=2, type="thinking", content="b")))
        assertEquals("ab", rows[0].content); assertEquals("done", splitTimeline(rows).final.single().content)
        assertEquals("answer", stripQuickProtocol("answer\n```quick-actions\n{}\n```"))
        assertTrue(stripQuickProtocol("example\n```quick-actions\n{}\n```\nmore").endsWith("more"))
        assertNull(safeWebLink("javascript:alert(1)", "https://api.multica.ai/"))
        assertFalse(redactTrace("Bearer abcdefghijk").contains("abcdefghijk"))
    }
}
