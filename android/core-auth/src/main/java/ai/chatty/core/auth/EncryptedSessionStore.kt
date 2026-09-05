package ai.chatty.core.auth

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import ai.chatty.core.network.CredentialStore
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

/** Only credentials and last workspace are persisted. Android backup is disabled. */
class EncryptedSessionStore(context: Context) : CredentialStore {
    private val prefs = EncryptedSharedPreferences.create(context, "chatty_session",
        MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM)
    private val current = MutableStateFlow(prefs.getString("jwt", null))
    override val token = current.asStateFlow()
    @Synchronized override fun saveToken(value: String?) {
        check(prefs.edit().apply { if (value == null) remove("jwt") else putString("jwt", value) }.commit()) { "Secure storage unavailable" }
        current.value = value
    }
    override var workspaceSlug: String?
        get() = prefs.getString("workspace", null)
        set(value) { check(prefs.edit().putString("workspace", value).commit()) }
}
