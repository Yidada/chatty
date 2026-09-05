package ai.chatty.feature.chat

import ai.chatty.core.ui.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.ArrowUpward
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.foundation.BorderStroke
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.widget.TextView
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.*
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.repeatOnLifecycle
import ai.chatty.core.model.*
import ai.chatty.core.network.*
import coil.compose.AsyncImage
import coil.request.ImageRequest
import coil.ImageLoader
import io.noties.markwon.Markwon
import io.noties.markwon.ext.tables.TablePlugin
import io.noties.markwon.ext.tables.TableAwareMovementMethod
import io.noties.markwon.ext.strikethrough.StrikethroughPlugin
import io.noties.markwon.ext.tasklist.TaskListPlugin
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.first
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.RequestBody
import okio.BufferedSink

private data class ChatResources(val api: ChatApi, val base: String, val token: String?, val workspace: String)
private val LocalChatResources = staticCompositionLocalOf<ChatResources?> { null }
private val Context.chatDraftStore by preferencesDataStore("chat_drafts")
class AndroidChatDrafts(private val context: Context, private val account: String) : ChatDrafts {
    override suspend fun read(key: String) = context.chatDraftStore.data.first()[stringPreferencesKey("$account:$key")].orEmpty()
    override suspend fun write(key: String, value: String) { context.chatDraftStore.edit { if (value.isEmpty()) it.remove(stringPreferencesKey("$account:$key")) else it[stringPreferencesKey("$account:$key")] = value } }
}

@Composable
fun ChatRoute(workspace: Workspace, credentials: CredentialStore, baseUrl: String, active: Boolean = true) {
    val context = LocalContext.current.applicationContext
    val scope = rememberCoroutineScope()
    // Credentials are never written to draft keys; a one-way digest separates accounts on this device.
    val token by credentials.token.collectAsStateWithLifecycle()
    val account = remember(token) { java.security.MessageDigest.getInstance("SHA-256").digest(token.orEmpty().toByteArray()).joinToString("") { "%02x".format(it) } }
    val controller = remember(workspace.id, account) {
        val socket = ChatSocket(baseUrl, credentials, workspace.slug)
        ChatController(createChatApi(baseUrl, credentials, workspace.slug), AndroidChatDrafts(context, account), workspace, scope, socket::events)
    }
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    var initialized by remember(controller) { mutableStateOf(false) }
    LaunchedEffect(controller, lifecycle, active) {
        if (!active) return@LaunchedEffect
        if (!initialized) { controller.initialize(); initialized = true }
        lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
            controller.start()
            try { awaitCancellation() } finally { controller.stop() }
        }
    }
    val state by controller.state.collectAsStateWithLifecycle()
    val resources = remember(workspace.id, token) { ChatResources(createChatApi(baseUrl, credentials, workspace.slug), baseUrl, token, workspace.slug) }
    val savedUi = androidx.compose.runtime.saveable.rememberSaveableStateHolder()
    if (active) savedUi.SaveableStateProvider("chat") {
        CompositionLocalProvider(LocalChatResources provides resources) {
            ChatScreen(state, controller, baseUrl)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ChatScreen(state: ChatState, controller: ChatController, baseUrl: String) {
    var localError by remember { mutableStateOf<String?>(null) }
    val context = LocalContext.current
    val keyboard = LocalSoftwareKeyboardController.current
    val list = rememberLazyListState()
    var followLatest by androidx.compose.runtime.saveable.rememberSaveable(state.session?.id) { mutableStateOf(true) }
    LaunchedEffect(list) {
        snapshotFlow { list.isScrollInProgress to ((list.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0) >= list.layoutInfo.totalItemsCount - 2) }
            .collect { (scrolling, nearEnd) -> if (scrolling) followLatest = nearEnd }
    }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) runCatching { controller.upload(uploadPart(context, uri)) }.onFailure { localError = it.message ?: "无法读取附件" }
    }
    LaunchedEffect(state.messages.lastOrNull()?.id, state.pending.task_id) {
        if (followLatest && !state.loadingOlder && state.messages.isNotEmpty()) list.animateScrollToItem((list.layoutInfo.totalItemsCount - 1).coerceAtLeast(0))
    }
    Column(Modifier.fillMaxSize().imePadding()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            GlyphBadge(Icons.Outlined.AutoAwesome, prominent = true)
            Column(Modifier.weight(1f)) {
                Text("Mika", style = MaterialTheme.typography.titleLarge)
                Text(if (state.connected) "已连接" else "正在连接 · 自动同步", style = MaterialTheme.typography.labelSmall, color = if (state.connected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant)
            }
            ActionIcon(Icons.Outlined.Refresh, "刷新对话", controller::refresh, !state.sending)
        }
        if (state.loading) LinearProgressIndicator(Modifier.fillMaxWidth())
        LazyColumn(state = list, modifier = Modifier.weight(1f).fillMaxWidth().testTag("chat-messages"), contentPadding = PaddingValues(horizontal = 24.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
            if (state.hasMore) item("older") { TextButton(onClick = controller::older, enabled = !state.loadingOlder) { Text(if (state.loadingOlder) "正在加载…" else "加载更早消息") } }
            if (state.messages.isEmpty() && !state.loading) item("empty") {
                Column(Modifier.fillMaxWidth().padding(vertical = 64.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Outlined.AutoAwesome, null, Modifier.size(44.dp), tint = MaterialTheme.colorScheme.primary)
                    Text("和 Mika 聊聊", Modifier.padding(top = 24.dp), style = MaterialTheme.typography.headlineMedium)
                    Text("一个想法，就从这里开始。", Modifier.padding(top = 12.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            items(state.messages.filterNot { it.message_kind == "onboarding_kickoff" }, key = { if (it.role == "assistant" && it.task_id != null) "task:${it.task_id}" else "message:${it.id}" }) { message ->
                MessageRow(message, state.traces[message.task_id], baseUrl, { message.task_id?.let(controller::loadTrace) }, { controller.draft(it) })
            }
            val pendingId = state.pending.task_id
            if (pendingId != null && state.messages.none { it.role == "assistant" && it.task_id == pendingId }) item("task:$pendingId") {
                Column {
                    Text(pendingLabel(state.pending, state.agent, state.traces[pendingId].orEmpty()), color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.labelLarge)
                    Transcript(state.traces[pendingId].orEmpty(), baseUrl)
                }
            }
            if (state.generic.isNotEmpty()) item("generic") { Expandable("其他活动（${state.generic.size}）") { Text(redactTrace(state.generic.joinToString("\n")), style = MaterialTheme.typography.bodySmall) } }
        }
        val error = localError ?: state.error
        if (error != null) Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(error, Modifier.weight(1f), color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
            TextButton(onClick = { localError = null; controller.refresh() }) { Text("刷新") }
        }
        state.notice?.let { Text(it, Modifier.padding(horizontal = 16.dp), color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }
        if (state.uncertain) TextButton(onClick = controller::acknowledgeUncertain) { Text("已核对历史，允许再次发送") }
        if (state.session?.status == "archived") Text("此会话已归档", Modifier.padding(horizontal = 16.dp))
        if (state.agent != null && (state.agent.runtime_bound == false || state.agent.runtime_id.isBlank())) Text("此 Agent 尚未绑定 Runtime", Modifier.padding(horizontal = 16.dp))
        if (state.agent != null && !canChat(state.agent, state.userId, state.role)) Text("没有调用此 Agent 的权限", Modifier.padding(horizontal = 16.dp))
        state.attachments.forEach { a -> Row(Modifier.padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(a.filename, Modifier.weight(1f), maxLines = 1); TextButton(onClick = { controller.removeAttachment(a.id) }, enabled = !state.sending) { Text("移除") }
        } }
        Surface(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp), shape = RoundedCornerShape(28.dp), color = MaterialTheme.colorScheme.surface, border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant), shadowElevation = 1.dp) {
            Row(Modifier.fillMaxWidth().padding(6.dp), verticalAlignment = Alignment.Bottom) {
                ActionIcon(Icons.Outlined.Add, "附件", { launcher.launch(arrayOf("*/*")) }, !state.sending && !state.loading && state.session?.status != "archived")
                TextField(state.draft, controller::draft, Modifier.weight(1f).testTag("chat-draft"), placeholder = { Text("和 Mika 聊聊…") }, maxLines = 5, enabled = !state.sending,
                    colors = TextFieldDefaults.colors(focusedContainerColor = Color.Transparent, unfocusedContainerColor = Color.Transparent, disabledContainerColor = Color.Transparent, focusedIndicatorColor = Color.Transparent, unfocusedIndicatorColor = Color.Transparent, disabledIndicatorColor = Color.Transparent))
                FilledIconButton(onClick = { followLatest = true; keyboard?.hide(); controller.send() }, enabled = state.canSend, modifier = Modifier.size(48.dp).testTag("chat-send")) {
                    Icon(Icons.Outlined.ArrowUpward, if (state.sending) "发送中" else "发送", Modifier.size(24.dp))
                }
            }
        }
    }
}

@Composable
private fun MessageRow(message: ChatMessage, traces: List<TaskTrace>?, base: String, load: () -> Unit, quick: (String) -> Unit) {
    val clipboard = LocalClipboardManager.current
    val user = message.role == "user"
    LaunchedEffect(message.task_id) { if (!user && message.task_id != null) load() }
    Row(Modifier.fillMaxWidth(), horizontalArrangement = if (user) Arrangement.End else Arrangement.Start) {
        Column((if (user) Modifier.fillMaxWidth(.85f).background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(topStart = 22.dp, topEnd = 22.dp, bottomStart = 22.dp, bottomEnd = 6.dp)).padding(16.dp) else Modifier.fillMaxWidth())) {
            if (message.failure_reason != null) {
                Text(failureLabel(message.failure_reason.orEmpty()), color = MaterialTheme.colorScheme.error)
                Expandable("错误详情") { Text(redactTrace(message.content), style = MaterialTheme.typography.bodySmall) }
            }
            if (message.message_kind == "no_response") Text("任务已结束，没有生成回复。", color = MaterialTheme.colorScheme.onSurfaceVariant)
            if (!user && !traces.isNullOrEmpty()) Transcript(traces, base) else if (message.failure_reason == null) Markdown(stripQuickProtocol(message.content), base)
            message.attachments.orEmpty().forEach { AttachmentCard(it, base) }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(listOf(chatTime(message.created_at), elapsed(message.elapsed_ms)).filter { it.isNotBlank() }.joinToString(" · "), Modifier.weight(1f), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                TextButton(onClick = {
                    val parts = splitTimeline(timeline(traces.orEmpty()))
                    val text = (parts.preface + parts.final).joinToString("\n\n") { it.content.orEmpty() }.ifBlank { message.content }
                    clipboard.setText(AnnotatedString(stripQuickProtocol(text)))
                }) { Text("复制", style = MaterialTheme.typography.labelSmall) }
            }
            message.quick_actions.orEmpty().forEach { action -> OutlinedButton(onClick = { quick(action.prompt) }) { Text(action.label) } }
        }
    }
}

@Composable
private fun Transcript(raw: List<TaskTrace>, base: String) {
    val parts = splitTimeline(timeline(raw))
    parts.preface.forEach { Markdown(stripQuickProtocol(it.content.orEmpty()), base) }
    if (parts.middle.isNotEmpty()) Expandable("任务过程 · ${parts.middle.size} 项") {
        parts.middle.forEach { row ->
            Column(Modifier.fillMaxWidth().padding(vertical = 8.dp)) {
                Text(when (row.type) { "thinking" -> "思考"; "tool_use" -> "工具 · ${row.tool.orEmpty()}"; "tool_result" -> "工具结果"; "error" -> "错误"; "text" -> "说明"; else -> "活动 · ${row.type}" }, style = MaterialTheme.typography.labelLarge)
                if (row.type == "text" || row.type == "thinking") Markdown(row.content.orEmpty(), base)
                else Text(listOfNotNull(row.content, row.input?.toString()?.let(::redactTrace), row.output).joinToString("\n").ifBlank { row.type }, style = MaterialTheme.typography.bodySmall)
            }
        }
    }
    parts.final.forEach { Markdown(stripQuickProtocol(it.content.orEmpty()), base) }
}

@Composable
private fun Expandable(label: String, content: @Composable () -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    TextButton(onClick = { expanded = !expanded }) { Text((if (expanded) "▾ " else "▸ ") + label) }
    if (expanded) content()
}

@Composable
private fun Markdown(text: String, base: String) {
    val context = LocalContext.current
    val colors = MaterialTheme.colorScheme
    val color = colors.onSurface
    var previewImage by remember(text) { mutableStateOf<String?>(null) }
    val markwon = remember(context, base, colors) { Markwon.builder(context)
        .usePlugin(TablePlugin.create(context)).usePlugin(StrikethroughPlugin.create()).usePlugin(TaskListPlugin.create(context))
        .usePlugin(object : io.noties.markwon.AbstractMarkwonPlugin() {
            override fun configureTheme(builder: io.noties.markwon.core.MarkwonTheme.Builder) {
                builder.linkColor(colors.primary.toArgb())
                    .codeTextColor(colors.onSurface.toArgb()).codeBlockTextColor(colors.onSurface.toArgb())
                    .codeBackgroundColor(colors.surfaceVariant.toArgb()).codeBlockBackgroundColor(colors.surfaceVariant.toArgb())
                    .blockQuoteColor(colors.outline.toArgb()).headingBreakColor(colors.outlineVariant.toArgb())
                    .thematicBreakColor(colors.outlineVariant.toArgb())
            }
            override fun beforeRender(node: org.commonmark.node.Node) {
                removeAppLinks(node, base)
            }
            override fun configureConfiguration(builder: io.noties.markwon.MarkwonConfiguration.Builder) {
                builder.linkResolver { _, link -> openLink(context, link, base) }
            }
        }).build() }
    if (text.isNotBlank()) AndroidView(factory = { TextView(it).apply { textSize = 16f; setTextIsSelectable(true); movementMethod = TableAwareMovementMethod.create(); setLineSpacing(4f, 1f) } }, modifier = Modifier.fillMaxWidth(), update = { view -> view.setTextColor(android.graphics.Color.rgb((color.red*255).toInt(), (color.green*255).toInt(), (color.blue*255).toInt())); markwon.setMarkdown(view, text) })
    Regex("!\\[[^]]*]\\(([^)\\s]+)(?:\\s+[^)]*)?\\)").findAll(text).forEach { image ->
        val url = safeWebLink(image.groupValues[1], base)
        if (url != null) SafeImage(url, "消息图片", modifier = Modifier.fillMaxWidth().heightIn(min = 80.dp, max = 280.dp).clickable { previewImage = url })
    }
    previewImage?.let { url ->
        AlertDialog(onDismissRequest = { previewImage = null }, title = { Text("图片") }, text = {
            SafeImage(url, "图片预览", Modifier.fillMaxWidth().heightIn(min = 180.dp, max = 480.dp))
        }, confirmButton = { TextButton(onClick = { previewImage = null }) { Text("关闭") } })
    }
}

@Composable
private fun SafeImage(url: String?, description: String, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val resources = LocalChatResources.current
    val request = remember(url, resources) {
        ImageRequest.Builder(context).data(url).apply {
            if (url != null && resources != null) {
                val target = java.net.URI(url); val base = java.net.URI(resources.base)
                if (target.scheme == base.scheme && target.authority == base.authority && target.path.startsWith("/api/")) {
                    resources.token?.let { addHeader("Authorization", "Bearer $it") }; addHeader("X-Workspace-Slug", resources.workspace)
                }
            }
        }.diskCachePolicy(coil.request.CachePolicy.DISABLED).build()
    }
    val loader = remember(context) { ImageLoader.Builder(context).okHttpClient(okhttp3.OkHttpClient.Builder().followRedirects(false).followSslRedirects(false).build()).build() }
    AsyncImage(model = request, imageLoader = loader, contentDescription = description, modifier = modifier)
}

@Composable
private fun AttachmentCard(a: Attachment, base: String) {
    val context = LocalContext.current
    val resources = LocalChatResources.current
    val scope = rememberCoroutineScope()
    var fresh by remember(a.id) { mutableStateOf(a) }
    var detail by remember(a.id) { mutableStateOf<String?>(null) }
    var imagePreview by remember(a.id) { mutableStateOf(false) }
    var busy by remember(a.id) { mutableStateOf(false) }
    var error by remember(a.id) { mutableStateOf<String?>(null) }
    LaunchedEffect(a.id) {
        if (a.content_type.startsWith("image/")) runCatching { resources?.api?.attachment(a.id) }.getOrNull()?.let { fresh = it }
    }
    Card(onClick = {
        if (!busy) scope.launch {
            busy = true; error = null
            try {
                fresh = resources?.api?.attachment(a.id) ?: a
                if (fresh.content_type.startsWith("image/")) {
                    imagePreview = true
                } else if (fresh.content_type.startsWith("text/") || fresh.content_type in listOf("application/json", "application/xml")) {
                    detail = withContext(Dispatchers.IO) { resources?.api?.attachmentText(a.id)?.use { it.string() } } ?: "无法读取附件"
                } else {
                    val link = safeWebLink(fresh.download_url.ifBlank { fresh.url }, base)
                    if (link == null) error = "暂无可用下载地址，请稍后重试"
                    else if (resources != null && java.net.URI(link).authority == java.net.URI(base).authority && java.net.URI(link).path.startsWith("/api/")) {
                        openProxyAttachment(context, resources, fresh)
                    } else openLink(context, link, base)
                }
            } catch (e: CancellationException) { throw e } catch (_: Exception) { error = "附件暂时无法打开，请点击重试" } finally { busy = false }
        }
    }, modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
        Column(Modifier.padding(12.dp)) {
            if (fresh.content_type.startsWith("image/")) SafeImage(safeWebLink(fresh.download_url.ifBlank { fresh.url }, base), fresh.filename, Modifier.fillMaxWidth().heightIn(min = 80.dp, max = 240.dp))
            Text(fresh.filename, style = MaterialTheme.typography.bodyMedium)
            Text(if (busy) "正在打开…" else "${fresh.content_type} · ${fileSize(fresh.size_bytes)}", style = MaterialTheme.typography.labelSmall)
            error?.let { Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }
        }
    }
    if (imagePreview) AlertDialog(onDismissRequest = { imagePreview = false }, title = { Text(fresh.filename) }, text = {
        SafeImage(safeWebLink(fresh.download_url.ifBlank { fresh.url }, base), "附件图片预览", Modifier.fillMaxWidth().heightIn(min = 180.dp, max = 480.dp))
    }, confirmButton = { TextButton(onClick = { imagePreview = false }) { Text("关闭") } })
    if (detail != null) AlertDialog(onDismissRequest = { detail = null }, title = { Text(fresh.filename) }, text = {
        Column(Modifier.heightIn(max = 480.dp).verticalScroll(rememberScrollState())) { Text(detail.orEmpty()) }
    }, confirmButton = { TextButton(onClick = { detail = null }) { Text("关闭") } })
}
private suspend fun openProxyAttachment(context: Context, resources: ChatResources, a: Attachment) {
    val response = resources.api.attachmentDownload(a.id)
    if (response.code() in 300..399) {
        response.body()?.close()
        val link = response.headers()["Location"] ?: error("缺少下载地址")
        openLink(context, link, resources.base); return
    }
    check(response.isSuccessful) { "下载失败" }
    val file = withContext(Dispatchers.IO) {
        val folder = java.io.File(context.cacheDir, "chat_attachments").apply { mkdirs() }
        folder.listFiles()?.filter { System.currentTimeMillis() - it.lastModified() > 3600000 }?.forEach { it.delete() }
        val name = a.filename.replace(Regex("[^\\p{L}\\p{N}._-]"), "_").take(100).ifBlank { "attachment" }
        val target = java.io.File(folder, "${java.util.UUID.randomUUID()}-$name")
        try {
            response.body()?.use { body -> body.byteStream().use { input -> target.outputStream().use { output ->
                val buffer = ByteArray(8192); var total = 0L
                while (true) { val n = input.read(buffer); if (n < 0) break; total += n; check(total <= 100L * 1024 * 1024); output.write(buffer, 0, n) }
            } } } ?: error("附件为空")
            target
        } catch (e: Exception) { target.delete(); throw e }
    }
    val uri = androidx.core.content.FileProvider.getUriForFile(context, "${context.packageName}.chatfiles", file)
    context.startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, a.content_type.ifBlank { "application/octet-stream" }).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK))
}
private fun openLink(context: Context, link: String, base: String) {
    val safe = externalContentLink(link, base) ?: run {
        android.widget.Toast.makeText(context, "此链接暂无原生查看方式", android.widget.Toast.LENGTH_SHORT).show()
        return
    }
    runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(safe)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
}
private fun uploadPart(context: Context, uri: Uri): MultipartBody.Part {
    var name = "attachment"; var size = -1L
    context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use {
        if (it.moveToFirst()) { name = it.getString(0) ?: name; if (!it.isNull(1)) size = it.getLong(1) }
    }
    require(size <= 100L * 1024 * 1024) { "附件不能超过 100 MB" }
    val body = object : RequestBody() {
        override fun contentType() = context.contentResolver.getType(uri)?.toMediaTypeOrNull()
        override fun contentLength() = size
        override fun writeTo(sink: BufferedSink) {
            val input = context.contentResolver.openInputStream(uri) ?: error("无法读取附件")
            input.use { stream -> val buffer = ByteArray(8192); var total = 0L; while (true) { val read = stream.read(buffer); if (read < 0) break; total += read; require(total <= 100L * 1024 * 1024) { "附件不能超过 100 MB" }; sink.write(buffer, 0, read) } }
        }
    }
    return MultipartBody.Part.createFormData("file", name, body)
}
