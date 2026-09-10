package ai.chatty.core.network

import ai.chatty.core.model.*
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.json.Json
import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory
import retrofit2.http.*
import java.util.UUID
import java.util.concurrent.TimeUnit

interface CredentialStore {
    val token: StateFlow<String?>
    fun saveToken(value: String?)
    var workspaceSlug: String?
}

interface MulticaApi {
    @POST("auth/send-code") suspend fun sendCode(@Body body: CodeRequest)
    @POST("auth/verify-code") suspend fun verifyCode(@Body body: VerifyRequest): LoginResponse
    @GET("api/workspaces") suspend fun workspaces(): List<Workspace>
}

/** Credentials are attached only to the configured API origin; redirects are disabled. */
class SessionInterceptor(private val store: CredentialStore) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): okhttp3.Response {
        val token = store.token.value
        val authenticated = chain.request().url.encodedPath.startsWith("/api/")
        val request = chain.request().newBuilder().header("X-Request-ID", UUID.randomUUID().toString())
        if (authenticated) {
            token?.let { request.header("Authorization", "Bearer $it") }
            store.workspaceSlug?.let { request.header("X-Workspace-Slug", it) }
        }
        val response = chain.proceed(request.build())
        // A late response for a replaced credential must not log out the new session.
        if (authenticated && token != null && response.code == 401 && store.token.value == token) {
            store.saveToken(null)
        }
        return response
    }
}

fun createRetrofit(baseUrl: String, store: CredentialStore): Retrofit {
    val client = OkHttpClient.Builder()
        .addInterceptor(SessionInterceptor(store))
        // Inert unless the device flag `chatty_network_probe` is set; captures
        // DNS/TCP/TLS/TTFB/end-to-end phases for the perf harness only.
        .eventListenerFactory(NetworkProbe.factory)
        .followRedirects(false).followSslRedirects(false)
        .retryOnConnectionFailure(false) // Sends and verification are never silently repeated.
        .callTimeout(25, TimeUnit.SECONDS).build()
    return Retrofit.Builder().baseUrl(baseUrl).client(client)
        .addConverterFactory(Json { ignoreUnknownKeys = true }.asConverterFactory("application/json".toMediaType()))
        .build()
}

fun createApi(baseUrl: String, store: CredentialStore): MulticaApi = createRetrofit(baseUrl, store).create(MulticaApi::class.java)
