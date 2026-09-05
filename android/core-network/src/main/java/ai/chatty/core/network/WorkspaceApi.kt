package ai.chatty.core.network
import ai.chatty.core.model.*
import retrofit2.http.*

interface WorkspaceApi {
    @GET("api/projects") suspend fun projects(): ProjectPage
    @GET("api/issues") suspend fun issues(@Query("project_id") project: String? = null, @Query("include_no_project") noProject: Boolean? = null,
        @Query("limit") limit: Int = 50, @Query("offset") offset: Int = 0, @Query("q") query: String? = null, @Query("status") status: String? = null): IssuePage
    @GET("api/issues/{id}") suspend fun issue(@Path("id") id: String): Issue
    @PUT("api/issues/{id}") suspend fun updateIssue(@Path("id") id: String, @Body body: IssueUpdate): Issue
    @GET("api/issue-statuses") suspend fun statuses(): StatusCatalog
    @GET("api/runtimes") suspend fun runtimes(): List<RuntimeDevice>
    @GET("api/agents") suspend fun agents(): List<ChatAgent>
    @GET("api/squads") suspend fun squads(): List<Squad>
}
fun scopedWorkspaceApi(base: String, store: CredentialStore, slug: String): WorkspaceApi {
    val scoped = object : CredentialStore {
        override val token = store.token
        override fun saveToken(value: String?) = store.saveToken(value)
        override var workspaceSlug: String? = slug
    }
    return createRetrofit(base, scoped).create(WorkspaceApi::class.java)
}
