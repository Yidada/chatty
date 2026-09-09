package ai.chatty.macrobenchmark

import android.os.Bundle
import androidx.benchmark.macro.*
import androidx.benchmark.macro.junit4.MacrobenchmarkRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** Synthetic, isolated package only. No production credentials or app data. */
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
}
