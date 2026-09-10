package ai.chatty.app
import ai.chatty.core.network.NetworkProbe
import android.app.Application
import dagger.hilt.android.HiltAndroidApp
@HiltAndroidApp class ChattyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Registers the opt-in network phase probe. It stores only the context
        // here; the device flag is read on the first call, so startup is not
        // perturbed and the probe stays inert unless the perf collector sets it.
        NetworkProbe.install(this)
    }
}
