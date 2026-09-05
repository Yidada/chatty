package ai.chatty.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.SystemBarStyle
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    @javax.inject.Inject lateinit var credentials: ai.chatty.core.network.CredentialStore
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge(statusBarStyle = SystemBarStyle.light(android.graphics.Color.TRANSPARENT, android.graphics.Color.TRANSPARENT))
        setContent { ChattyTheme { AuthRoot(credentials = credentials) } }
    }
}

@Composable
fun ChattyTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = lightColorScheme(
        primary = Color(0xFF153D36), background = Color(0xFFFAF9F6), surface = Color(0xFFFAF9F6),
        surfaceVariant = Color(0xFFF0EEE8), onSurface = Color(0xFF202420)
    ), content = content)
}

@Composable
fun ChattyShell(workspace: ai.chatty.core.model.Workspace, credentials: ai.chatty.core.network.CredentialStore, switchWorkspace: () -> Unit, signOut: () -> Unit) {
    var tab by rememberSaveable { mutableStateOf("对话") }
    Scaffold(bottomBar = {
        NavigationBar(containerColor = MaterialTheme.colorScheme.background) {
            listOf("对话", "项目", "设置").forEach { title ->
                NavigationBarItem(selected = tab == title, onClick = { tab = title }, icon = { Text(when (title) { "对话" -> "◌"; "项目" -> "▦"; else -> "⚙" }) }, label = { Text(title) })
            }
        }
    }) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            key(workspace.id, tab) {
                when (tab) {
                    "对话" -> ai.chatty.feature.chat.ChatRoute(workspace, credentials, BuildConfig.API_BASE_URL)
                    "项目" -> ai.chatty.feature.workspace.ProjectsRoute(workspace, credentials, BuildConfig.API_BASE_URL)
                    "设置" -> ai.chatty.feature.workspace.SettingsRoute(workspace, credentials, BuildConfig.API_BASE_URL, switchWorkspace, signOut)
                }
            }
        }
    }
}

@OptIn(androidx.compose.ui.ExperimentalComposeUiApi::class)
@Composable
fun AuthRoot(credentials: ai.chatty.core.network.CredentialStore, vm: AuthViewModel = viewModel()) {
    val state by vm.state.collectAsStateWithLifecycle()
    Surface(Modifier.fillMaxSize().semantics { testTagsAsResourceId = true }) {
        when {
            state.restoring -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            !state.loggedIn -> LoginScreen(state, vm)
            state.selected != null -> ChattyShell(state.selected!!, credentials, vm::switchWorkspace, vm::signOut)
            else -> Column(Modifier.fillMaxSize().safeDrawingPadding().padding(24.dp).verticalScroll(rememberScrollState())) {
                Spacer(Modifier.height(32.dp))
                Text("选择工作区", style = MaterialTheme.typography.headlineLarge)
                Text("与 Multica 使用同一份 Agent 和任务。", Modifier.padding(vertical = 16.dp))
                if (state.busy) LinearProgressIndicator(Modifier.fillMaxWidth())
                state.error?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(vertical = 16.dp)) }
                state.workspaces.forEach { workspace ->
                    OutlinedButton(onClick = { vm.select(workspace) }, enabled = !state.busy, modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) { Text(workspace.name) }
                }
                if (!state.busy && state.error == null && state.workspaces.isEmpty()) Text("此账号暂无工作区。请在 Multica 网页端创建。")
                TextButton(onClick = vm::refresh, enabled = !state.busy) { Text("重新加载") }
                TextButton(onClick = vm::signOut, enabled = !state.busy) { Text("退出登录") }
            }
        }
    }
}

@Composable
private fun LoginScreen(state: AuthState, vm: AuthViewModel) {
    var email by rememberSaveable { mutableStateOf("") }
    var code by remember { mutableStateOf("") }
    Column(Modifier.fillMaxSize().safeDrawingPadding().imePadding().padding(horizontal = 28.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.Center) {
        Text("Chatty", style = MaterialTheme.typography.titleLarge, color = MaterialTheme.colorScheme.primary)
        Spacer(Modifier.height(48.dp))
        Text("把 Multica\n装进口袋。", style = MaterialTheme.typography.displaySmall)
        Spacer(Modifier.height(16.dp))
        Text("使用 Multica 邮箱登录，连接你的工作区。", style = MaterialTheme.typography.bodyLarge)
        Spacer(Modifier.height(32.dp))
        if (BuildConfig.APPLICATION_ID.endsWith(".fixture")) Text("本地测试环境 · 合成数据", color = MaterialTheme.colorScheme.error)
        OutlinedTextField(value = email, onValueChange = { email = it }, label = { Text("邮箱") }, enabled = !state.busy && !state.codeSent, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email), modifier = Modifier.fillMaxWidth().testTag("email"), shape = RoundedCornerShape(16.dp))
        Spacer(Modifier.height(12.dp))
        if (state.codeSent) {
            Text("验证码已发送，请查看邮箱。")
            OutlinedTextField(value = code, onValueChange = { code = it.filter(Char::isDigit).take(6) }, label = { Text("验证码") }, visualTransformation = PasswordVisualTransformation(), enabled = !state.busy, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword), modifier = Modifier.fillMaxWidth().testTag("code"), shape = RoundedCornerShape(16.dp))
            Spacer(Modifier.height(12.dp))
            Button(onClick = { vm.verify(email, code); code = "" }, enabled = !state.busy && code.length == 6, modifier = Modifier.fillMaxWidth().height(54.dp)) { Text("登录并连接") }
            TextButton(onClick = { code = ""; vm.changeEmail() }, enabled = !state.busy) { Text("更换邮箱") }
        } else {
            Button(onClick = { vm.sendCode(email) }, enabled = !state.busy && android.util.Patterns.EMAIL_ADDRESS.matcher(email.trim()).matches(), modifier = Modifier.fillMaxWidth().height(54.dp)) { Text("获取验证码") }
        }
        if (state.busy) LinearProgressIndicator(Modifier.fillMaxWidth().padding(vertical = 12.dp))
        state.error?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(vertical = 12.dp)) }
        Spacer(Modifier.height(24.dp))
        Text((if (BuildConfig.APPLICATION_ID.endsWith(".fixture")) "连接本机合成测试服务" else "连接 api.multica.ai") + "\n登录凭据由 Android 安全存储保护。退出仅清除此设备登录状态。", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(32.dp))
    }
}
