package ai.chatty.feature.inbox

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first

/** Per-account, per-workspace storage for which activity fingerprints a user has seen. */
interface ActivityReads {
    suspend fun read(workspaceId: String): Map<String, String>
    suspend fun write(workspaceId: String, reads: Map<String, String>)
}

private val Context.activityReadsStore by preferencesDataStore("activity_reads")

class AndroidActivityReads(private val context: Context, private val account: String) : ActivityReads {
    private fun key(workspaceId: String) = stringPreferencesKey("$account:$workspaceId")

    override suspend fun read(workspaceId: String): Map<String, String> =
        context.activityReadsStore.data.first()[key(workspaceId)].orEmpty()
            .lineSequence().filter { it.isNotBlank() }
            .mapNotNull { line -> val tab = line.indexOf('\t'); if (tab <= 0) null else line.substring(0, tab) to line.substring(tab + 1) }
            .toMap()

    override suspend fun write(workspaceId: String, reads: Map<String, String>) {
        val encoded = reads.entries.filter { it.key.isNotBlank() }.joinToString("\n") { "${it.key}\t${it.value}" }
        context.activityReadsStore.edit { if (encoded.isEmpty()) it.remove(key(workspaceId)) else it[key(workspaceId)] = encoded }
    }
}
