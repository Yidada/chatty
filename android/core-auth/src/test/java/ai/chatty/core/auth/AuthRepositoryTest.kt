package ai.chatty.core.auth

import ai.chatty.core.model.*
import ai.chatty.core.network.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

class AuthRepositoryTest {
    private val store = object : CredentialStore {
        override val token = MutableStateFlow<String?>(null)
        override fun saveToken(value: String?) { token.value = value }
        override var workspaceSlug: String? = null
    }
    private var issuedToken = "fixture-token"
    private val api = object : MulticaApi {
        override suspend fun sendCode(body: CodeRequest) {}
        override suspend fun verifyCode(body: VerifyRequest) = LoginResponse(issuedToken)
        override suspend fun workspaces() = listOf(Workspace("w1", "test", "Test"))
        override suspend fun me() = ChatUser("u1")
    }
    private val auth = AuthRepository(api,store)
    @Test fun verifyPersistsTokenAndWorkspaceSelection() = runBlocking {
        auth.verify("fixture@example.test", "123456")
        auth.select(auth.workspaces().single())
        assertEquals("fixture-token",store.token.value)
        assertEquals("test",auth.lastWorkspace)
    }
    @Test fun signOutRemovesCredentialAndWorkspace() = runBlocking {
        auth.verify("fixture@example.test", "123456")
        auth.select(auth.workspaces().single())
        auth.signOut()
        assertNull(store.token.value)
        assertNull(store.workspaceSlug)
    }
    @Test fun emptyTokenIsRejected() = runBlocking {
        issuedToken = ""
        assertTrue(runCatching { auth.verify("fixture@example.test", "123456") }.isFailure)
        assertNull(store.token.value)
    }
}
