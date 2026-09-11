package ai.chatty.core.auth

import ai.chatty.core.model.*
import ai.chatty.core.network.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class AuthRepository(private val api: MulticaApi, private val store: CredentialStore) {
    val token = store.token
    val lastWorkspace get() = store.workspaceSlug
    suspend fun sendCode(email: String) = api.sendCode(CodeRequest(email.trim()))
    suspend fun verify(email: String, code: String) {
        val result = api.verifyCode(VerifyRequest(email.trim(), code.trim()))
        check(result.token.isNotBlank()) { "Empty token in server response" }
        withContext(Dispatchers.IO) { store.saveToken(result.token) }
    }
    suspend fun workspaces() = api.workspaces()
    suspend fun me() = api.me()
    suspend fun select(workspace: Workspace) = withContext(Dispatchers.IO) { store.workspaceSlug = workspace.slug }
    suspend fun signOut() = withContext(Dispatchers.IO) {
        store.saveToken(null)
        store.workspaceSlug = null
    }
}
