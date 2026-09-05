package ai.chatty.core.network

import ai.chatty.core.model.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.runBlocking
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.*
import org.junit.Assert.*

class MulticaApiTest {
    private val server = MockWebServer()
    private val store = object : CredentialStore {
        override val token = MutableStateFlow<String?>("synthetic-token")
        override fun saveToken(value: String?) { token.value = value }
        override var workspaceSlug: String? = "fixture-workspace"
    }
    private lateinit var api: MulticaApi
    @Before fun setup() { server.start(); api = createApi(server.url("/").toString(), store) }
    @After fun teardown() { server.shutdown() }
    @Test fun typedWorkspaceAndScopedHeaders() = runBlocking {
        server.enqueue(MockResponse().setBody("""[{"id":"w1","slug":"fixture-workspace","name":"Test","future":true}]"""))
        assertEquals("Test", api.workspaces().single().name)
        val r = server.takeRequest()
        assertEquals("Bearer synthetic-token", r.getHeader("Authorization"))
        assertEquals("fixture-workspace", r.getHeader("X-Workspace-Slug"))
        assertNotNull(r.getHeader("X-Request-ID"))
    }
    @Test fun unauthorizedClearsCredential() = runBlocking {
        server.enqueue(MockResponse().setResponseCode(401))
        runCatching { api.workspaces() }
        assertNull(store.token.value)
    }
    @Test fun serverFailurePreservesCredentialAndDoesNotRetry() = runBlocking {
        server.enqueue(MockResponse().setResponseCode(503))
        assertTrue(runCatching { api.workspaces() }.isFailure)
        assertEquals("synthetic-token", store.token.value)
        assertEquals(1, server.requestCount)
    }
    @Test fun forbiddenPreservesCredential() = runBlocking {
        server.enqueue(MockResponse().setResponseCode(403))
        runCatching { api.workspaces() }
        assertEquals("synthetic-token", store.token.value)
    }
    @Test fun connectionFailurePreservesCredential() = runBlocking {
        server.shutdown()
        assertTrue(runCatching { api.workspaces() }.isFailure)
        assertEquals("synthetic-token", store.token.value)
    }
    @Test fun authRequestsDoNotSendExistingCredential() = runBlocking {
        server.enqueue(MockResponse().setResponseCode(204))
        api.sendCode(CodeRequest("fixture@example.test"))
        val r = server.takeRequest()
        assertNull(r.getHeader("Authorization"))
        assertNull(r.getHeader("X-Workspace-Slug"))
        assertEquals("/auth/send-code",r.path)
    }
    @Test fun malformedResponseDoesNotBecomeSuccessfulEmptyWorkspace() = runBlocking {
        server.enqueue(MockResponse().setBody("""[{"id":"w1"}]"""))
        assertTrue(runCatching { api.workspaces() }.isFailure)
        assertEquals("synthetic-token",store.token.value)
    }
    @Test fun redirectIsNotFollowedWithCredentials() = runBlocking {
        server.enqueue(MockResponse().setResponseCode(302).setHeader("Location",server.url("/other")))
        assertTrue(runCatching { api.workspaces() }.isFailure)
        assertEquals(1,server.requestCount)
    }
    @Test fun staleUnauthorizedDoesNotEraseReplacementToken() = runBlocking {
        server.dispatcher = object : okhttp3.mockwebserver.Dispatcher() {
            override fun dispatch(request: okhttp3.mockwebserver.RecordedRequest): MockResponse {
                store.saveToken("replacement-token")
                return MockResponse().setResponseCode(401)
            }
        }
        runCatching { api.workspaces() }
        assertEquals("replacement-token",store.token.value)
    }
}
