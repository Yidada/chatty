package ai.chatty.core.network
import ai.chatty.core.model.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.runBlocking
import okhttp3.mockwebserver.*
import org.junit.*
import org.junit.Assert.*
class WorkspaceApiTest {
    private val server=MockWebServer()
    private val store=object:CredentialStore {
        override val token=MutableStateFlow<String?>("synthetic")
        override var workspaceSlug:String?="other"
        override fun saveToken(value:String?) { token.value=value }
    }
    @Before fun setup() { server.start() }
    @After fun close() { server.shutdown() }
    @Test fun projectPaginationAndScopeUseActualContract()=runBlocking {
        server.enqueue(MockResponse().setBody("""{"issues":[],"total":100}"""))
        val page=scopedWorkspaceApi(server.url("/").toString(),store,"chosen").issues(project="p1",offset=50,query="中文",status="qa")
        val r=server.takeRequest();assertEquals(100,page.total);assertEquals("p1",r.requestUrl!!.queryParameter("project_id"));assertEquals("50",r.requestUrl!!.queryParameter("offset"));assertEquals("chosen",r.getHeader("X-Workspace-Slug"));assertEquals("中文",r.requestUrl!!.queryParameter("q"))
    }
    @Test fun progressWriteExplicitlySuppressesRunAndUsesRevision()=runBlocking {
        server.enqueue(MockResponse().setBody("""{"id":"i","identifier":"T-1","title":"T","status":"qa"}"""))
        scopedWorkspaceApi(server.url("/").toString(),store,"w").updateIssue("i",IssueUpdate("qa",true,3))
        val r=server.takeRequest();val body=r.body.readUtf8();assertEquals("PUT",r.method);assertTrue(body.contains("\"suppress_run\":true"));assertTrue(body.contains("\"expected_revision\":3"));assertEquals("/api/issues/i",r.path)
    }
    @Test fun settingsShapesHandleNullableOptionalFields()=runBlocking {
        val api=scopedWorkspaceApi(server.url("/").toString(),store,"w")
        server.enqueue(MockResponse().setBody("""[{"id":"r","name":"Device","custom_name":null,"last_seen_at":null}]"""));assertEquals("Device",api.runtimes().single().name)
        server.enqueue(MockResponse().setBody("""[{"id":"s","name":"Team","archived_at":null,"member_count":3}]"""));assertEquals(3,api.squads().single().member_count)
    }
}
