package ai.chatty.core.network

import android.content.Context
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import okhttp3.Call
import okhttp3.EventListener
import okhttp3.Handshake
import okhttp3.Protocol
import okhttp3.Request
import okhttp3.Response
import java.io.IOException
import java.net.InetSocketAddress
import java.net.Proxy
import java.util.concurrent.atomic.AtomicLong

/**
 * Opt-in per-call HTTP phase timing (DNS / TCP / TLS / TTFB / body / end-to-end)
 * against a designated test service.
 *
 * The probe is inert unless the device flag `chatty_network_probe` is set to 1,
 * which the perf collector does with `adb shell settings put global ...` before
 * launching the target and clears afterwards. With the flag absent every
 * callback returns on the first flag check: production behaviour, request
 * headers and bodies are untouched.
 *
 * Only `method`, `host`, `port`, a redacted path, timings, status, protocol and
 * the failure class are emitted. Query strings, headers (including
 * authorization), bodies and response payloads are never logged.
 */
object NetworkProbe {
    const val TAG = "ChattyNetProbe"
    const val SETTING_KEY = "chatty_network_probe"
    private const val FLAG_TTL_MS = 2_000L
    private val sequence = AtomicLong(0)

    @Volatile private var appContext: Context? = null
    @Volatile private var cachedEnabled = false
    // Sentinel far enough in the past that the first call refreshes, without
    // overflowing the subtraction against the monotonic clock.
    @Volatile private var checkedAtMs = -2 * FLAG_TTL_MS

    /**
     * Stores the application context only. The device flag is read lazily on the
     * first call, off the main thread, so app startup and the cold-start
     * measurement are not perturbed by a settings read.
     */
    fun install(context: Context) {
        appContext = context.applicationContext
    }

    fun isEnabled(): Boolean {
        val context = appContext ?: return false
        val now = SystemClock.elapsedRealtime()
        if (now - checkedAtMs >= FLAG_TTL_MS) {
            cachedEnabled = runCatching { Settings.Global.getInt(context.contentResolver, SETTING_KEY, 0) == 1 }.getOrDefault(false)
            checkedAtMs = now
        }
        return cachedEnabled
    }

    internal fun nextCallId(): String = "c" + sequence.incrementAndGet()

    /** One listener per call, so phase timestamps never leak between requests. */
    val factory: EventListener.Factory = EventListener.Factory { NetworkPhaseListener() }
}

/**
 * Redacts identifier-shaped path segments, matching the fixture metric
 * convention, so measurement output never becomes a record of user/session ids.
 */
fun redactNetworkPath(path: String): String {
    if (path.isEmpty()) return path
    return path.split('/').joinToString("/") { segment ->
        when {
            segment.isEmpty() -> segment
            UUID_PATTERN.matches(segment) -> "{id}"
            HEX_ID_PATTERN.matches(segment) -> "{id}"
            segment.all(Char::isDigit) -> "{id}"
            else -> segment
        }
    }
}

private val UUID_PATTERN = Regex("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
private val HEX_ID_PATTERN = Regex("[0-9a-fA-F]{8,}")

/** Result of one observed call. Field order in [toLogLine] is a host-side contract. */
data class NetworkPhaseRecord(
    val id: String,
    val method: String,
    val host: String,
    val port: Int,
    val path: String,
    val dnsMs: Double?,
    val tcpMs: Double?,
    val tlsMs: Double?,
    val ttfbMs: Double?,
    val bodyMs: Double?,
    val e2eMs: Double?,
    val status: Int?,
    val protocol: String,
    val outcome: String,
    val error: String,
) {
    fun toLogLine(): String = buildString {
        append("netcall {\"id\":").append(quote(id))
        append(",\"method\":").append(quote(method))
        append(",\"host\":").append(quote(host))
        append(",\"port\":").append(port)
        append(",\"path\":").append(quote(path))
        append(",\"dns_ms\":").append(number(dnsMs))
        append(",\"tcp_ms\":").append(number(tcpMs))
        append(",\"tls_ms\":").append(number(tlsMs))
        append(",\"ttfb_ms\":").append(number(ttfbMs))
        append(",\"body_ms\":").append(number(bodyMs))
        append(",\"e2e_ms\":").append(number(e2eMs))
        append(",\"status\":").append(status?.toString() ?: "null")
        append(",\"protocol\":").append(quote(protocol))
        append(",\"outcome\":").append(quote(outcome))
        append(",\"error\":").append(quote(error))
        append('}')
    }

    private fun number(value: Double?): String =
        if (value == null) "null" else String.format(java.util.Locale.US, "%.3f", value)

    private fun quote(value: String): String = buildString {
        append('"')
        for (character in value) {
            when (character) {
                '"' -> append("\\\"")
                '\\' -> append("\\\\")
                '\n' -> append("\\n")
                '\r' -> append("\\r")
                '\t' -> append("\\t")
                else -> if (character < ' ') append(String.format(java.util.Locale.US, "\\u%04x", character.code)) else append(character)
            }
        }
        append('"')
    }
}

private class NetworkPhaseListener : EventListener() {
    private var capturing = false
    private var callStartNanos = 0L
    private var dnsStartNanos = 0L
    private var connectStartNanos = 0L
    private var tlsStartNanos = 0L
    private var requestHeadersNanos = 0L
    private var responseHeadersNanos = 0L
    private var dnsMs: Double? = null
    private var tcpMs: Double? = null
    private var tlsMs: Double? = null
    private var ttfbMs: Double? = null
    private var bodyMs: Double? = null
    private var status: Int? = null
    private var protocol: String = ""
    private var callId: String = ""

    override fun callStart(call: Call) {
        capturing = NetworkProbe.isEnabled()
        if (!capturing) return
        callId = NetworkProbe.nextCallId()
        callStartNanos = SystemClock.elapsedRealtimeNanos()
    }

    override fun dnsStart(call: Call, domainName: String) {
        if (!capturing) return
        dnsStartNanos = SystemClock.elapsedRealtimeNanos()
    }

    override fun dnsEnd(call: Call, domainName: String, inetAddressList: List<java.net.InetAddress>) {
        if (!capturing) return
        dnsMs = elapsed(dnsStartNanos)
    }

    override fun connectStart(call: Call, inetSocketAddress: InetSocketAddress, proxy: Proxy) {
        if (!capturing) return
        connectStartNanos = SystemClock.elapsedRealtimeNanos()
    }

    override fun secureConnectStart(call: Call) {
        if (!capturing) return
        tlsStartNanos = SystemClock.elapsedRealtimeNanos()
    }

    override fun secureConnectEnd(call: Call, handshake: Handshake?) {
        if (!capturing) return
        tlsMs = elapsed(tlsStartNanos)
        tcpMs = since(connectStartNanos, tlsStartNanos)
    }

    override fun connectEnd(call: Call, inetSocketAddress: InetSocketAddress, proxy: Proxy, protocol: Protocol?) {
        if (!capturing) return
        // Cleartext keeps TCP as the full connect span; TLS splits it above.
        if (tlsStartNanos == 0L) tcpMs = elapsed(connectStartNanos)
    }

    override fun requestHeadersStart(call: Call) {
        if (!capturing) return
        requestHeadersNanos = SystemClock.elapsedRealtimeNanos()
    }

    override fun responseHeadersStart(call: Call) {
        if (!capturing) return
        responseHeadersNanos = SystemClock.elapsedRealtimeNanos()
        ttfbMs = since(requestHeadersNanos, responseHeadersNanos)
    }

    override fun responseHeadersEnd(call: Call, response: Response) {
        if (!capturing) return
        status = response.code
        protocol = response.protocol.toString()
    }

    override fun responseBodyEnd(call: Call, bytesRead: Long) {
        if (!capturing) return
        bodyMs = since(responseHeadersNanos, SystemClock.elapsedRealtimeNanos())
    }

    override fun callEnd(call: Call) {
        if (!capturing) return
        emit(call, outcome = "success", error = "")
    }

    override fun callFailed(call: Call, ioe: IOException) {
        if (!capturing) return
        emit(call, outcome = "failure", error = ioe.javaClass.simpleName)
    }

    private fun emit(call: Call, outcome: String, error: String) {
        val url = call.request().url
        val record = NetworkPhaseRecord(
            id = callId,
            method = call.request().method,
            host = url.host,
            port = url.port,
            path = redactNetworkPath(url.encodedPath),
            dnsMs = dnsMs,
            tcpMs = tcpMs,
            tlsMs = tlsMs,
            ttfbMs = ttfbMs,
            bodyMs = bodyMs,
            e2eMs = elapsed(callStartNanos),
            status = status,
            protocol = protocol,
            outcome = outcome,
            error = error,
        )
        Log.i(NetworkProbe.TAG, record.toLogLine())
    }

    private fun elapsed(startNanos: Long): Double? =
        if (startNanos == 0L) null else (SystemClock.elapsedRealtimeNanos() - startNanos) / 1_000_000.0

    private fun since(startNanos: Long, endNanos: Long): Double? =
        if (startNanos == 0L || endNanos == 0L) null else (endNanos - startNanos) / 1_000_000.0
}
