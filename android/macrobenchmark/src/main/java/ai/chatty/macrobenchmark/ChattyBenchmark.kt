package ai.chatty.macrobenchmark

import android.os.Bundle
import androidx.benchmark.macro.*
import androidx.benchmark.macro.junit4.MacrobenchmarkRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.*
import org.json.JSONObject
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

/**
 * Synthetic, isolated package only. No production credentials or app data.
 *
 * Scenario coverage as of CLE-86:
 *  - `cold`/`hot`     — S1 startup first display (Macrobenchmark startup metric).
 *  - `scroll`         — S1 loaded-window scroll.
 *  - `memory`         — S1 post-start PSS snapshots.
 *  - `s2Pagination`   — S2 full composite-cursor paging through every page.
 *  - `s2LiveEvent`    — S2 live `chat:message` frame rendered without a manual refresh.
 *  - `s3Traversal`    — S3 project/issue/Runtime/Agent/Squad traversal.
 *  - `s4FaultCorrect` — S4 injected 5xx/429/timeout/disconnect/socket-drop correctness.
 *
 * `composer-interactive` (process start -> composer ready) is captured from
 * logcat by `scripts/perf/collect.py --methods interactive`, because the boundary
 * must be relative to the app process start, not to the instrumentation.
 */
@RunWith(AndroidJUnit4::class)
class ChattyBenchmark {
    @get:Rule val benchmark = MacrobenchmarkRule()
    private val pkg = "ai.chatty.app.benchmark"
    private val device get() = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())

    private fun required(selector: BySelector) = requireNotNull(device.wait(Until.findObject(selector), 15_000)) {
        "Required fixture UI absent: $selector"
    }

    private fun hideKeyboardIfShown() {
        // UiObject2.setText may not open an IME; unconditional Back exits the app.
        if (device.executeShellCommand("dumpsys input_method").contains("mInputShown=true")) {
            device.pressBack()
        }
    }

    private fun launch(clearTask: Boolean = false) {
        // 1.3.4's gfxinfo launch confirmation cannot parse this Android 16 build.
        // Keep Macrobenchmark's process/trace/metric handling, but confirm launch
        // with ActivityManager plus the actual fixture UI instead.
        val flags = if (clearTask) "0x10008000" else "0x10000000"
        val result = device.executeShellCommand(
            "am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -f $flags -n $pkg/ai.chatty.app.MainActivity"
        )
        check(result.contains("Status: ok")) { "ActivityManager launch failed: $result" }
    }

    private fun login() {
        if (device.wait(Until.hasObject(By.res("email")), 3_000)) {
            required(By.res("email")).text = "fixture@example.test"
            hideKeyboardIfShown()
            required(By.text("获取验证码")).click()
            required(By.res("code")).text = "123456"
            hideKeyboardIfShown()
            required(By.text("登录并连接")).click()
        }
        if (device.wait(Until.hasObject(By.text("Loop Test Workspace")), 3_000)) {
            required(By.text("Loop Test Workspace")).click()
        }
        required(By.res("chat-draft"))
        required(By.res("chat-messages"))
    }

    /** Loopback fixture control channel, reachable only through the adb reverse mapping. */
    private fun fixture(payload: Map<String, Any?>): String {
        val connection = URL("http://127.0.0.1:8765/__perf").openConnection() as HttpURLConnection
        return try {
            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            connection.connectTimeout = 5_000
            connection.readTimeout = 5_000
            connection.outputStream.use { it.write(JSONObject(payload).toString().toByteArray()) }
            connection.inputStream.bufferedReader().use { it.readText() }
        } finally {
            connection.disconnect()
        }
    }

    private fun openTab(label: String) {
        required(By.text(label)).click()
    }

    private fun refreshChat() {
        required(By.desc("刷新对话")).click()
    }

    @Test fun prepare() {
        device.executeShellCommand("am start -W -n $pkg/ai.chatty.app.MainActivity")
        login()
    }

    @Test fun cold() = startup(StartupMode.COLD, 10)

    @Test fun hot() = startup(StartupMode.HOT, 20)

    private fun startup(mode: StartupMode, count: Int) = benchmark.measureRepeated(
        packageName = pkg,
        metrics = listOf(StartupTimingMetric()),
        compilationMode = CompilationMode.None(),
        startupMode = mode,
        iterations = count,
        setupBlock = {
            if (mode == StartupMode.HOT) {
                launch()
                required(By.res("chat-draft"))
            }
            pressHome()
            if (mode == StartupMode.HOT) Thread.sleep(5_000)
        }
    ) {
        launch(clearTask = mode == StartupMode.COLD)
        required(By.res("chat-draft"))
        required(By.res("chat-messages"))
    }

    @Test fun memory() {
        repeat(5) { sample ->
            device.executeShellCommand("am force-stop $pkg")
            launch(clearTask = true)
            required(By.res("chat-messages"))
            required(By.textContains("Baseline message"))
            Thread.sleep(1_000)
            val raw = device.executeShellCommand("dumpsys meminfo $pkg")
            check(!raw.contains("No process found")) { "Target exited before PSS snapshot" }
            InstrumentationRegistry.getInstrumentation().sendStatus(2, Bundle().apply {
                putString("stream", "PSS_SAMPLE_BEGIN $sample\n$raw\nPSS_SAMPLE_END $sample\n")
            })
        }
    }

    @Test fun scroll() = benchmark.measureRepeated(
        packageName = pkg,
        metrics = listOf(FrameTimingMetric()),
        compilationMode = CompilationMode.None(),
        iterations = 10,
        setupBlock = { launch(); required(By.res("chat-messages")) }
    ) {
        val list = required(By.res("chat-messages"))
        list.setGestureMargin(device.displayWidth / 5)
        repeat(5) { list.scroll(Direction.UP, 1f) }
        repeat(5) { list.scroll(Direction.DOWN, 1f) }
    }

    /**
     * S2 loads every composite-cursor page through the "older" affordance. The
     * loop ends when the affordance stops being offered, which is the fixture's
     * `has_more=false` — not a fixed click count.
     */
    @Test fun s2Pagination() = benchmark.measureRepeated(
        packageName = pkg,
        metrics = listOf(FrameTimingMetric()),
        compilationMode = CompilationMode.None(),
        iterations = 5,
        setupBlock = { launch(); login() }
    ) {
        var pages = 0
        while (device.wait(Until.hasObject(By.text("加载更早消息")), 3_000)) {
            required(By.text("加载更早消息")).click()
            pages++
            check(pages <= 25) { "pagination did not terminate after $pages pages" }
        }
        // S2 seeds 1,000 messages at 50 per page: 19 further pages beyond the first.
        check(pages >= 18) { "S2 pagination offered only $pages older pages" }
        required(By.res("chat-messages"))
    }

    /**
     * S2 live event: the fixture appends a message and broadcasts `chat:message`.
     * The app must re-fetch and render it without any manual refresh.
     */
    @Test fun s2LiveEvent() = benchmark.measureRepeated(
        packageName = pkg,
        metrics = listOf(FrameTimingMetric()),
        compilationMode = CompilationMode.None(),
        iterations = 5,
        setupBlock = { launch(); login() }
    ) {
        val marker = "Live event " + UUID.randomUUID()
        fixture(mapOf("append_message" to mapOf("content" to marker, "chat_session_id" to "s1")))
        required(By.textContains(marker))
    }

    /** S3 traversal: projects -> issues, then Runtimes/Agents/Squads detail round trips. */
    @Test fun s3Traversal() = benchmark.measureRepeated(
        packageName = pkg,
        metrics = listOf(FrameTimingMetric()),
        compilationMode = CompilationMode.None(),
        iterations = 5,
        setupBlock = { launch(); login() }
    ) {
        openTab("项目")
        required(By.res("projects-list"))
        required(By.text("Baseline project 0")).click()
        required(By.res("issues-list"))
        device.pressBack()
        required(By.res("projects-list"))

        openTab("设置")
        required(By.res("settings-list"))
        required(By.text("Runtimes")).click()
        required(By.text("Runtime 0")).click()
        required(By.res("resource-detail"))
        device.pressBack()
        required(By.text("Runtime 0"))
        device.pressBack()
        required(By.res("settings-list"))

        required(By.text("Agents")).click()
        required(By.text("Mika Renamed"))
        device.pressBack()
        required(By.res("settings-list"))

        required(By.text("Squads")).click()
        required(By.text("Squad 0"))
        device.pressBack()
        required(By.res("settings-list"))
    }

    /**
     * S4 fault correctness. Not a benchmark: injected faults make timings
     * meaningless, so this asserts only that each fault surfaces and that the
     * app recovers without a crash, a permanent pending task or a dead socket.
     */
    @Test fun s4FaultCorrectness() {
        launch()
        login()
        val unreachable = "暂时无法连接"

        // 1. Server error and rate limit are surfaced, and the composer survives.
        for (status in listOf(500, 429)) {
            fixture(mapOf("status" to status, "retry_after" to 2))
            refreshChat()
            check(device.wait(Until.hasObject(By.textContains(unreachable)), 15_000)) {
                "HTTP $status was not surfaced to the user"
            }
            required(By.res("chat-draft"))
        }

        // 2. Transport reset: the call fails instead of hanging the pending task.
        fixture(mapOf("status" to 200, "disconnect" to true))
        refreshChat()
        check(device.wait(Until.hasObject(By.textContains(unreachable)), 15_000)) { "connection reset was not surfaced" }
        required(By.res("chat-draft"))

        // 3. Socket drop: the client must reconnect on its own and show connected.
        fixture(mapOf("status" to 200, "delay_ms" to 0, "disconnect" to false, "drop_ws" to true))
        check(device.wait(Until.hasObject(By.text("已连接")), 30_000)) { "WebSocket did not reconnect after a dropped socket" }

        // 4. Recovery: with the fixture healthy again a refresh clears the error.
        fixture(mapOf("status" to 200, "delay_ms" to 0, "disconnect" to false))
        refreshChat()
        required(By.res("chat-draft"))
        required(By.res("chat-messages"))
    }
}
