package ai.chatty.app
import android.content.Context
import ai.chatty.core.auth.*
import ai.chatty.core.network.*
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module @InstallIn(SingletonComponent::class)
object AppModule {
    @Provides @Singleton fun credentials(@ApplicationContext context: Context): CredentialStore = EncryptedSessionStore(context)
    @Provides @Singleton fun api(store: CredentialStore): MulticaApi = createApi(BuildConfig.API_BASE_URL, store)
    @Provides @Singleton fun auth(api: MulticaApi, store: CredentialStore) = AuthRepository(api, store)
}
