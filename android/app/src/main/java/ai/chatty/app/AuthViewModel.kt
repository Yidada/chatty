package ai.chatty.app

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ai.chatty.core.auth.AuthRepository
import ai.chatty.core.model.Workspace
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.*
import retrofit2.HttpException

// Auth UI state is memory-only. Passwords, JWTs and server entities never enter saved state.
data class AuthState(
    val restoring: Boolean = true, val loggedIn: Boolean = false,
    val busy: Boolean = false, val codeSent: Boolean = false,
    val workspaces: List<Workspace> = emptyList(), val selected: Workspace? = null,
    val workspacePicker: Boolean = false,
    val error: String? = null
)

@HiltViewModel
class AuthViewModel @Inject constructor(private val auth: AuthRepository) : ViewModel() {
    private val mutable = MutableStateFlow(AuthState())
    val state = mutable.asStateFlow()
    private var loadJob: Job? = null
    init {
        viewModelScope.launch {
            auth.token.collect { token ->
                if (token == null) {
                    loadJob?.cancel()
                    mutable.value = AuthState(restoring = false)
                } else {
                    mutable.update { it.copy(loggedIn = true, restoring = false) }
                    refresh()
                }
            }
        }
    }
    private fun action(block: suspend () -> Unit) {
        if (mutable.value.busy) return
        mutable.update { it.copy(busy = true, error = null) }
        viewModelScope.launch {
            try { block() }
            catch (e: CancellationException) { throw e }
            catch (e: Exception) { mutable.update { it.copy(error = errorText(e)) } }
            finally { mutable.update { it.copy(busy = false) } }
        }
    }
    fun sendCode(email: String) = action {
        auth.sendCode(email)
        mutable.update { it.copy(codeSent = true) }
    }
    fun verify(email: String, code: String) = action { auth.verify(email, code) }
    fun changeEmail() { mutable.update { it.copy(codeSent = false, error = null) } }
    fun refresh() {
        if (auth.token.value == null) return
        loadJob?.cancel()
        mutable.update { it.copy(busy = true, error = null) }
        loadJob = viewModelScope.launch {
            try {
                val workspaces = auth.workspaces()
                mutable.update { it.copy(workspaces = workspaces, selected = workspaces.find { w -> w.slug == auth.lastWorkspace }) }
            } catch (e: CancellationException) { throw e }
            catch (e: Exception) {
                if (auth.token.value != null) mutable.update { it.copy(error = errorText(e)) }
            } finally { mutable.update { it.copy(busy = false) } }
        }
    }
    fun select(workspace: Workspace) = action {
        if (workspace.id != state.value.selected?.id) auth.select(workspace)
        mutable.update { it.copy(selected = workspace, workspacePicker = false) }
    }
    fun switchWorkspace() {
        mutable.update { it.copy(workspacePicker = true) }
        refresh()
    }
    fun dismissWorkspacePicker() { mutable.update { it.copy(workspacePicker = false) } }
    fun signOut() = action { auth.signOut() }
    private fun errorText(e: Exception): String {
        android.util.Log.w("ChattyAuth", "Request failed: " + e.javaClass.simpleName + if (e is HttpException) " HTTP " + e.code() else "")
        return when {
        e is HttpException && e.code() == 401 -> "登录已失效，请重新登录。"
        e is HttpException && e.code() == 403 -> "你暂时没有访问权限。"
        e is HttpException && e.code() == 429 -> "请求过于频繁，请稍后重试。"
        e is HttpException && e.code() in 400..499 -> "请求未通过，请检查邮箱和验证码。"
        else -> "暂时无法连接，请重试。已有登录信息会保留。"
        }
    }
}
