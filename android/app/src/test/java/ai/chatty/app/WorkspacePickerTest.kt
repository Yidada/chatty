package ai.chatty.app

import ai.chatty.core.auth.AuthRepository
import ai.chatty.core.model.*
import ai.chatty.core.network.*
import androidx.lifecycle.ViewModelStore
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.test.*
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.Assert.*

@OptIn(ExperimentalCoroutinesApi::class)
class WorkspacePickerTest {
    private val dispatcher = StandardTestDispatcher()
    private val owner = ViewModelStore()
    private val first = Workspace("w1", "one", "First")
    private val second = Workspace("w2", "two", "Second")
    private class Store : CredentialStore {
        override val token = MutableStateFlow<String?>("fixture")
        override fun saveToken(value: String?) { token.value = value }
        var writes = 0
        override var workspaceSlug: String? = "one"
            set(value) { writes++; field = value }
    }
    private inner class Api : MulticaApi {
        var gate: CompletableDeferred<Unit>? = null
        override suspend fun workspaces(): List<Workspace> { gate?.await(); return listOf(first, second) }
        override suspend fun sendCode(body: CodeRequest) = Unit
        override suspend fun verifyCode(body: VerifyRequest) = LoginResponse("fixture")
    }
    private fun model(api: Api, store: Store) = AuthViewModel(AuthRepository(api, store)).also { owner.put("auth", it) }
    @Before fun setup() { Dispatchers.setMain(dispatcher) }
    @After fun cleanup() { owner.clear(); Dispatchers.resetMain() }

    @Test fun cancellingDuringReloadKeepsCurrentWorkspace() = runTest(dispatcher) {
        val api = Api(); val store = Store(); val vm = model(api, store); runCurrent()
        api.gate = CompletableDeferred()
        vm.switchWorkspace(); runCurrent()
        assertTrue(vm.state.value.workspacePicker)
        assertEquals(first, vm.state.value.selected)
        vm.dismissWorkspacePicker()
        api.gate!!.complete(Unit); advanceUntilIdle()
        assertFalse(vm.state.value.workspacePicker)
        assertEquals(first, vm.state.value.selected)
        assertEquals(0, store.writes)
    }
    @Test fun selectingSameWorkspaceOnlyDismissesPicker() = runTest(dispatcher) {
        val store = Store(); val vm = model(Api(), store); runCurrent()
        vm.switchWorkspace(); advanceUntilIdle(); vm.select(first); advanceUntilIdle()
        assertFalse(vm.state.value.workspacePicker)
        assertEquals(first, vm.state.value.selected)
        assertEquals(0, store.writes)
    }
    @Test fun switchingCommitsSelectedWorkspaceAndDismissesPicker() = runTest(dispatcher) {
        val store = Store(); val vm = model(Api(), store); runCurrent()
        vm.switchWorkspace(); advanceUntilIdle(); vm.select(second)
        vm.state.first { it.selected == second }
        assertFalse(vm.state.value.workspacePicker)
        assertEquals("two", store.workspaceSlug)
        assertEquals(1, store.writes)
    }
}
