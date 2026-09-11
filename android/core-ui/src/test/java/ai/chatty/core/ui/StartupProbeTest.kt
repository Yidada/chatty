package ai.chatty.core.ui

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the logcat contract that `scripts/perf/measure.py` parses. Only the pure
 * functions are covered here; `markComposerInteractive` needs a device because it
 * calls `android.os.Process`.
 */
class StartupProbeTest {
    @Test
    fun `elapsed is the boundary between process start and composer readiness`() {
        assertEquals(305L, StartupProbe.elapsedMillis(1_305L, 1_000L))
        assertEquals(0L, StartupProbe.elapsedMillis(1_000L, 1_000L))
    }

    @Test
    fun `record line keeps field order and units expected by the host parser`() {
        val line = StartupProbe.recordLine(elapsedMs = 412L, startUptimeMs = 1_000L, nowUptimeMs = 1_412L, pid = 4321, fullyDrawn = true)
        assertEquals("composer-interactive elapsed_ms=412 start_uptime_ms=1000 now_uptime_ms=1412 pid=4321 fully_drawn=true", line)
    }

    @Test
    fun `record line marks a missing activity without changing the boundary`() {
        val line = StartupProbe.recordLine(elapsedMs = 99L, startUptimeMs = 1L, nowUptimeMs = 100L, pid = 7, fullyDrawn = false)
        assertEquals("composer-interactive elapsed_ms=99 start_uptime_ms=1 now_uptime_ms=100 pid=7 fully_drawn=false", line)
    }
}
