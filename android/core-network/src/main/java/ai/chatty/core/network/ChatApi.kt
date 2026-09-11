package ai.chatty.core.network

import ai.chatty.core.model.*
import okhttp3.MultipartBody
import retrofit2.http.*

interface ChatApi {
    @GET("api/chat/sessions") suspend fun sessions(): List<ChatSession>
    @GET("api/agents") suspend fun agents(): List<ChatAgent>
    @GET("api/me") suspend fun me(): ChatUser
    @GET("api/projects") suspend fun projects(): ProjectPage
    @GET("api/workspaces/{id}/members") suspend fun members(@Path("id") id: String): List<ChatMember>
    @POST("api/chat/sessions") suspend fun create(@Body body: NewChat): ChatSession
    @PATCH("api/chat/sessions/{id}") suspend fun updateSession(@Path("id") id: String, @Body body: ChatSessionUpdate): ChatSession
    @GET("api/chat/sessions/{id}/messages/page") suspend fun messages(@Path("id") id: String,
        @Query("limit") limit: Int = 50, @Query("before_created_at") beforeTime: String? = null,
        @Query("before_id") beforeId: String? = null): MessagePage
    @POST("api/chat/sessions/{id}/messages") suspend fun send(@Path("id") id: String, @Body body: SendMessage): SendReceipt
    @GET("api/chat/sessions/{id}/pending-task") suspend fun pending(@Path("id") id: String): PendingTask
    @POST("api/chat/sessions/{id}/queued-tasks/{taskId}/prioritize")
    suspend fun prioritize(@Path("id") id: String, @Path("taskId") taskId: String): PrioritizeQueuedResponse
    @DELETE("api/chat/sessions/{id}/queued-tasks") suspend fun clearQueued(@Path("id") id: String)
    @POST("api/tasks/{taskId}/cancel") suspend fun cancelTask(@Path("taskId") taskId: String,
        @Query("expected_status") expectedStatus: String? = null, @Query("chat_session_id") chatSessionId: String? = null,
        @Query("queue_action") queueAction: String? = null): CancelTaskResponse
    @POST("api/chat/sessions/{id}/read") suspend fun markRead(@Path("id") id: String)
    @GET("api/tasks/{id}/messages") suspend fun trace(@Path("id") id: String): List<TaskTrace>
    @GET("api/attachments/{id}") suspend fun attachment(@Path("id") id: String): Attachment
    @Streaming @GET("api/attachments/{id}/download") suspend fun attachmentDownload(@Path("id") id: String): retrofit2.Response<okhttp3.ResponseBody>
    @GET("api/attachments/{id}/content") suspend fun attachmentText(@Path("id") id: String): okhttp3.ResponseBody
    @Multipart @POST("api/upload-file") suspend fun upload(@Part file: MultipartBody.Part): Attachment
}

fun createChatApi(baseUrl: String, store: CredentialStore, workspace: String): ChatApi {
    val scoped = object : CredentialStore {
        override val token = store.token
        override fun saveToken(value: String?) = store.saveToken(value)
        override var workspaceSlug: String? = workspace
    }
    return createRetrofit(baseUrl, scoped).create(ChatApi::class.java)
}
