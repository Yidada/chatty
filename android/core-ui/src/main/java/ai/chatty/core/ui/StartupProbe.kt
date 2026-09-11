package ai.chatty.core.ui

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.os.Process
import android.os.SystemClock
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Host-visible boundary from app-process start to the chat composer becoming
 * interactive.
 *
 * Definition of the boundary: the composer input is placed in the window, it is
 * enabled for typing, and the chat session it belongs to has resolved. Message
 * history arrival is deliberately *not* part of it — that is "first usable
 * content", a separate metric. The value therefore sits between first display
 * (what `StartupTimingMetric` reports) and "messages visible" (what the
 * Macrobenchmark UI assertions prove).
 *
 * The measurement is emitted once per process, so recomposition and tab switches
 * cannot inflate a startup sample. `Process.getStartUptimeMillis()` is used as
 * the origin, so the number is relative to process start and excludes fork/exec
 * before the process exists.
 */
object StartupProbe {
    const val TAG = "ChattyStartupProbe"
    const val EVENT = "composer-interactive"
    private val reported = AtomicBoolean(false)

    /** Pure boundary arithmetic; unit-tested without a device. */
    fun elapsedMillis(nowUptimeMillis: Long, startUptimeMillis: Long): Long = nowUptimeMillis - startUptimeMillis

    /** The logcat contract consumed by `scripts/perf/measure.py`. Do not reorder fields. */
    fun recordLine(elapsedMs: Long, startUptimeMs: Long, nowUptimeMs: Long, pid: Int, fullyDrawn: Boolean): String =
        "$EVENT elapsed_ms=$elapsedMs start_uptime_ms=$startUptimeMs now_uptime_ms=$nowUptimeMs pid=$pid fully_drawn=$fullyDrawn"

    /**
     * Records the boundary for this process. The first caller wins; later calls
     * are no-ops. A process whose start time is unavailable is discarded rather
     * than reported with a meaningless origin.
     */
    fun markComposerInteractive(activity: Activity? = null) {
        if (!reported.compareAndSet(false, true)) return
        val start = Process.getStartUptimeMillis()
        if (start <= 0L) {
            Log.w(TAG, "process start uptime unavailable; composer-interactive sample discarded")
            return
        }
        val now = SystemClock.uptimeMillis()
        val hasActivity = activity != null
        activity?.reportFullyDrawn()
        Log.i(TAG, recordLine(elapsedMillis(now, start), start, now, Process.myPid(), hasActivity))
    }

    /** `LocalContext` is usually the Activity, but unwrap in case it is a wrapper. */
    fun findActivity(context: Context?): Activity? {
        var current = context
        while (current is ContextWrapper) {
            if (current is Activity) return current
            current = current.baseContext
        }
        return current as? Activity
    }
}
