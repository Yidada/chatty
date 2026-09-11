package ai.chatty.core.network

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

/**
 * The logcat line is a contract with `scripts/perf/measure.py`; these assertions
 * fail if a field is renamed, reordered or reformatted. Only the pure functions
 * are covered here — the listener itself needs a device.
 */
class NetworkProbeTest {
    private fun record(
        dnsMs: Double? = 0.4,
        tcpMs: Double? = 1.2,
        tlsMs: Double? = null,
        ttfbMs: Double? = 12.0,
        bodyMs: Double? = 3.0,
        e2eMs: Double? = 16.4,
        status: Int? = 200,
        outcome: String = "success",
        error: String = "",
        path: String = "/api/chat/sessions/s1/messages/page",
    ) = NetworkPhaseRecord(
        id = "c1", method = "GET", host = "127.0.0.1", port = 8765, path = path,
        dnsMs = dnsMs, tcpMs = tcpMs, tlsMs = tlsMs, ttfbMs = ttfbMs, bodyMs = bodyMs,
        e2eMs = e2eMs, status = status, protocol = "http/1.1", outcome = outcome, error = error,
    )

    @Test
    fun `log line keeps the host parser field names and order`() {
        assertEquals(
            "netcall {\"id\":\"c1\",\"method\":\"GET\",\"host\":\"127.0.0.1\",\"port\":8765," +
                "\"path\":\"/api/chat/sessions/s1/messages/page\",\"dns_ms\":0.400,\"tcp_ms\":1.200," +
                "\"tls_ms\":null,\"ttfb_ms\":12.000,\"body_ms\":3.000,\"e2e_ms\":16.400,\"status\":200," +
                "\"protocol\":\"http/1.1\",\"outcome\":\"success\",\"error\":\"\"}",
            record().toLogLine(),
        )
    }

    @Test
    fun `failure keeps the exception class and omits unavailable phases`() {
        val line = record(dnsMs = null, tcpMs = null, ttfbMs = null, bodyMs = null, e2eMs = 25000.0,
            status = null, outcome = "failure", error = "SocketTimeoutException").toLogLine()
        assertEquals(true, line.contains("\"outcome\":\"failure\""))
        assertEquals(true, line.contains("\"error\":\"SocketTimeoutException\""))
        assertEquals(true, line.contains("\"status\":null"))
        assertEquals(true, line.contains("\"ttfb_ms\":null"))
    }

    @Test
    fun `quoting escapes characters that would break a json line`() {
        val line = record(error = "bad\"quote\\slash", path = "/api/a\nb").toLogLine()
        assertEquals(true, line.contains("\"error\":\"bad\\\"quote\\\\slash\""))
        assertFalse(line.contains("\n"))
    }

    @Test
    fun `redacts identifier shaped segments only`() {
        assertEquals("/api/chat/sessions/{id}/messages/page", redactNetworkPath("/api/chat/sessions/2f0c9f4e-1111-2222-3333-444455556666/messages/page"))
        assertEquals("/api/chat/sessions/{id}/messages/page", redactNetworkPath("/api/chat/sessions/ab12cd34ef/messages/page"))
        assertEquals("/api/chat/sessions/{id}/messages/page", redactNetworkPath("/api/chat/sessions/12345/messages/page"))
        assertEquals("/api/workspaces", redactNetworkPath("/api/workspaces"))
        assertEquals("/api/agents/status", redactNetworkPath("/api/agents/status"))
    }
}
