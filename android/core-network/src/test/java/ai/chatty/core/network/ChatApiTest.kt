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
