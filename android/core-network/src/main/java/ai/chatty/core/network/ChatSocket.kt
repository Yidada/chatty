package ai.chatty.core.network

import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.serialization.json.*
import okhttp3.*
import okhttp3.HttpUrl.Companion.toHttpUrl
import java.util.concurrent.TimeUnit

// Lifecycle/retry is owned by the chat feature. No token in URL or logging.
class ChatSocket(private val baseUrl: String, private val credentials: CredentialStore, private val workspace: String) {
    private val client = OkHttpClient.Builder().pingInterval(25, TimeUnit.SECONDS).build()
    fun events() = callbackFlow<JsonObject> {
        val token = credentials.token.value ?: run { close(); return@callbackFlow }
        val url = baseUrl.toHttpUrl().newBuilder().encodedPath("/ws")
            .addQueryParameter("workspace_slug", workspace).addQueryParameter("client_platform", "mobile")
            .addQueryParameter("client_os", "android").build()
        val authenticated = java.util.concurrent.atomic.AtomicBoolean(false)
        val socket = client.newWebSocket(Request.Builder().url(url).build(), object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                webSocket.send(buildJsonObject { put("type", "auth"); putJsonObject("payload") { put("token", token) } }.toString())
            }
            override fun onMessage(webSocket: WebSocket, text: String) {
                val message = runCatching { Json.parseToJsonElement(text).jsonObject }.getOrNull() ?: return
                when (message["type"]?.jsonPrimitive?.contentOrNull) {
                    "auth_ack" -> { authenticated.set(true); trySend(message) }
                    "auth_error" -> { close(java.io.IOException("WebSocket authentication failed")); webSocket.cancel() }
                    else -> if (authenticated.get()) trySend(message)
                }
            }
            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) { close(t) }
            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) { webSocket.close(code, null); close() }
            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) { close() }
        })
        val timeout = launch { delay(15000); if (!authenticated.get()) { close(java.io.IOException("WebSocket authentication timeout")); socket.cancel() } }
        awaitClose { timeout.cancel(); socket.cancel() }
    }
}
