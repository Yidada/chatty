package ai.chatty.core.network
import ai.chatty.core.model.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import okhttp3.*
import okhttp3.mockwebserver.*
import org.junit.*
import org.junit.Assert.*
import java.util.concurrent.LinkedBlockingQueue

class ChatApiTest {
    private val server = MockWebServer()
    private val store = object : CredentialStore {
        override val token = MutableStateFlow<String?>("synthetic-token")
        override var workspaceSlug: String? = "other"
        override fun saveToken(value: String?) { token.value = value }
    }
    @Before fun setup() { server.start() }
    @After fun close() { server.shutdown() }
    @Test fun cursorScopeAndNullableAttachments() = runBlocking {
        val api = createChatApi(server.url("/").toString(), store, "chat-scope")
        server.enqueue(MockResponse().setBody("""{"messages":[{"id":"m","chat_session_id":"s","role":"assistant","attachments":null,"quick_actions":null}],"has_more":false}"""))
        assertNull(api.messages("s", beforeTime="2026-01-01T00:00:00Z", beforeId="m0").messages.single().attachments)
        val req = server.takeRequest(); assertEquals("chat-scope", req.getHeader("X-Workspace-Slug"))
        assertEquals("m0", req.requestUrl?.queryParameter("before_id")); assertEquals("50", req.requestUrl?.queryParameter("limit"))
        assertEquals("/api/chat/sessions/s/messages/page", req.requestUrl?.encodedPath)
    }
    @Test fun sendReceiptAndBodyUseWireNames() = runBlocking {
        server.enqueue(MockResponse().setBody("""{"message_id":"m1","task_id":"t1","created_at":"now"}"""))
        val result = createChatApi(server.url("/").toString(), store, "w").send("s", SendMessage("hello", listOf("f1")))
        assertEquals("t1", result.task_id); val r = server.takeRequest()
        assertTrue(r.body.readUtf8().contains("\"attachment_ids\":[\"f1\"]")); assertEquals("POST", r.method)
    }
    @Test fun apiRequestsAdvertiseDraftRestoreCapability() = runBlocking {
        server.enqueue(MockResponse().setBody("[]"))
        createChatApi(server.url("/").toString(), store, "w").sessions()
        assertEquals("chat-draft-restore-v1", server.takeRequest().getHeader("X-Client-Capabilities"))
    }
    @Test fun cancelTaskUsesQueuedScopeAndQueueAction() = runBlocking {
        server.enqueue(MockResponse().setBody("""{"cancelled_chat_message":{"chat_session_id":"s","message_id":"m","content":"hi","restore_to_input":true}}"""))
        val result = createChatApi(server.url("/").toString(), store, "w")
            .cancelTask("t1", expectedStatus = "queued", chatSessionId = "s", queueAction = "edit")
        assertEquals("hi", result.cancelled_chat_message?.content); assertTrue(result.cancelled_chat_message?.restore_to_input == true)
        val req = server.takeRequest(); assertEquals("/api/tasks/t1/cancel", req.requestUrl?.encodedPath)
        assertEquals("queued", req.requestUrl?.queryParameter("expected_status")); assertEquals("edit", req.requestUrl?.queryParameter("queue_action"))
        assertEquals("s", req.requestUrl?.queryParameter("chat_session_id"))
    }
    @Test fun prioritizeAndClearQueuedUseWireRoutes() = runBlocking {
        val api = createChatApi(server.url("/").toString(), store, "w")
        server.enqueue(MockResponse().setBody("""{"task_id":"t2","active_task_id":"t1"}"""))
        assertEquals("t1", api.prioritize("s", "t2").active_task_id)
        var req = server.takeRequest(); assertEquals("/api/chat/sessions/s/queued-tasks/t2/prioritize", req.requestUrl?.encodedPath); assertEquals("POST", req.method)
        server.enqueue(MockResponse().setResponseCode(204))
        api.clearQueued("s")
        req = server.takeRequest(); assertEquals("DELETE", req.method); assertEquals("/api/chat/sessions/s/queued-tasks", req.requestUrl?.encodedPath)
    }
    @Test fun socketAuthenticatesInFirstFrameWithoutUrlCredential() = runBlocking {
        val frames = LinkedBlockingQueue<String>()
        server.enqueue(MockResponse().withWebSocketUpgrade(object : WebSocketListener() {
            override fun onMessage(webSocket: WebSocket, text: String) { frames.add(text); webSocket.send("""{"type":"auth_ack","payload":{}}""") }
        }))
        val ack = withTimeout(5000) { ChatSocket(server.url("/").toString(), store, "w").events().first() }
        assertEquals("\"auth_ack\"", ack["type"].toString())
        assertTrue(frames.take().contains("\"token\":\"synthetic-token\""))
        val req = server.takeRequest(); assertFalse(req.path.orEmpty().contains("synthetic-token")); assertNull(req.getHeader("Authorization"))
        assertEquals("mobile", req.requestUrl?.queryParameter("client_platform"))
    }
}
