import SwiftUI
import ChattyCore
import PhotosUI
import UniformTypeIdentifiers
import CoreTransferable
import UIKit

/// The Mika conversation surface, aligned with DeepSeek iOS (spec §3–§9):
/// top bar with history / session title / new conversation, a welcome state that
/// is immediately typable, right-aligned user bubbles against full-width
/// assistant text, and a process block that expands while Mika works and folds
/// to a single line when the answer arrives.
struct ChatScreen: View {
    @Bindable var model: ChatModel
    let context: WorkspaceContext
    @State private var pickingFile = false
    @State private var pickingPhoto = false
    @State private var photo: PhotosPickerItem?
    @State private var importError: String?
    @State private var confirmUncertain = false
    @State private var followingBottom = true
    @State private var initialBottom = true
    @State private var dropTargeted = false
    @State private var showProjectPicker = false
    @State private var showHistory = false
    /// User overrides for the process block, keyed by task. Absent means "follow
    /// the default", which is expanded while the task runs and folded once it ends
    /// (spec §6.3).
    @State private var processExpanded: [String: Bool] = [:]
    @State private var draftFocused = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var commands: AppCommandCenter

    /// Readable column on iPad while staying single-column, matching the official
    /// DeepSeek iPad screenshots (spec §10).
    private var readableWidth: CGFloat? { horizontalSizeClass == .regular ? 700 : nil }

    var body: some View {
        VStack(spacing: 0) {
            banners
            timeline
        }
        .background(ChattyTheme.background)
        .safeAreaInset(edge: .bottom, spacing: 0) { composer }
        .toolbar { toolbarItems }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                ChatHistoryView(model: model) { showHistory = false }
            }
        }
        .task {
            await model.setVisible(true)
            commands.send = { [model] in Task { await model.send() } }
            commands.focusComposer = { draftFocused = true }
            commands.canSend = model.canSend
        }
        .onChange(of: model.canSend) { _, value in commands.canSend = value }
        .onDisappear {
            Task { await model.setVisible(false) }
            commands.send = nil; commands.canSend = false; commands.focusComposer = nil
        }
        .fileImporter(isPresented: $pickingFile, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
            Task {
                do {
                    guard let url = try result.get().first else { return }
                    let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .contentTypeKey])
                    guard values.isRegularFile == true else { throw APIError.unsafeFile }
                    guard (values.fileSize ?? Int.max) <= APIClient.maximumFileBytes else { throw APIError.oversizedFile }
                    let data = try Data(contentsOf: url, options: .mappedIfSafe)
                    await model.upload(data: data, filename: url.lastPathComponent, contentType: values.contentType?.preferredMIMEType ?? "application/octet-stream")
                } catch { importError = DisplayText.error(error) }
            }
        }
        .photosPicker(isPresented: $pickingPhoto, selection: $photo, matching: .images)
        .onChange(of: photo) { _, item in
            Task {
                do {
                    if let file = try await item?.loadTransferable(type: PickedPhoto.self) {
                        await model.upload(data: file.data, filename: file.name, contentType: file.contentType)
                    }
                } catch { importError = DisplayText.error(error) }
                photo = nil
            }
        }
        .alert("附件未能读取", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) { Button("知道了", role: .cancel) {} } message: { Text(importError ?? "") }
        .alert("这条消息已经收到？", isPresented: $confirmUncertain) {
            Button("确认已收到") { model.acknowledgeUncertain() }
            if model.outbox.contains(where: { $0.status == .uncertain }) {
                Button("确认未收到，重试") { Task { await model.retryUncertainAfterReview() } }
            }
            Button("继续核对", role: .cancel) {}
        } message: { Text("请先刷新核对聊天记录。已收到会移除本机待核对记录；重试会再次提交，如果原消息稍后到达，可能重复执行。") }
    }

    // MARK: - Top bar

    @ToolbarContentBuilder private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { showHistory = true } label: {
                Image(systemName: "line.3.horizontal").font(.body.weight(.medium))
                    .frame(width: 34, height: 34)
                    .background(ChattyTheme.surfaceMuted, in: Circle())
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("历史对话").accessibilityIdentifier("chat.history")
        }
        ToolbarItem(placement: .principal) {
            Text(model.sessionTitle)
                .font(.headline).lineLimit(1)
                .accessibilityIdentifier("chat.title")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { model.startNewSession() } label: {
                Image(systemName: "plus.bubble").font(.body.weight(.medium))
                    .frame(width: 34, height: 34)
                    .background(ChattyTheme.surfaceMuted, in: Circle())
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("新建对话").accessibilityIdentifier("chat.newSession")
        }
    }

    // MARK: - Banners

    @ViewBuilder private var banners: some View {
        if let error = model.error {
            ErrorNotice(text: error, identifier: "chat.error").padding(.horizontal, 16).padding(.top, 8)
        }
        // The welcome state already tells the user this is a fresh conversation, so
        // the "已开始新的对话" notice is redundant there — and at the largest
        // accessibility text size its three lines squeezed the timeline until
        // 「想从哪里开始？」 was pushed out of reach (evidence.md §17.4). Every other
        // notice, including "原对话已归档或删除", still shows.
        if let notice = model.notice, !model.isStartingNewSession {
            Text(notice).font(.callout).foregroundStyle(ChattyTheme.textSecondary)
                .padding(.horizontal, 20).padding(.top, 8).accessibilityIdentifier("chat.notice")
        }

        if model.uncertain {
            HStack {
                Text("发送结果待确认").font(.callout).accessibilityIdentifier("chat.uncertain")
                Spacer()
                Button("刷新核对") { Task { await model.refresh() } }.frame(minHeight: 44)
                Button("核对结果") { confirmUncertain = true }.frame(minHeight: 44).accessibilityIdentifier("chat.acknowledge")
            }.padding(.horizontal, 16).background(ChattyTheme.danger.opacity(0.08))
        }
        if model.outbox.contains(where: { $0.status == .held }) {
            HStack {
                Text("未发送的消息已保留").font(.callout)
                Spacer()
                Button("继续发送") { Task { await model.resumeOutbox() } }.frame(minHeight: 44).disabled(model.sending || model.uncertain).accessibilityIdentifier("chat.resumeQueue")
            }.padding(.horizontal, 20)
        }
    }

    // MARK: - Timeline

    private var timeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if model.loading && model.messages.isEmpty { ProgressView("读取对话…").frame(maxWidth: .infinity) }
                    if model.hasMore {
                        Button {
                            initialBottom = false
                            let anchor = model.messages.first?.id
                            Task { await model.older(); if let anchor { proxy.scrollTo(anchor, anchor: .top) } }
                        } label: { if model.loadingOlder { ProgressView() } else { Text("加载更早消息") } }
                        .frame(maxWidth: .infinity, minHeight: 44).disabled(model.loadingOlder).accessibilityIdentifier("chat.older")
                    }
                    if model.initialized && model.messages.isEmpty && model.outbox.isEmpty {
                        if model.agent == nil {
                            ContentUnavailableView("当前工作区还没有可对话的 Mika", systemImage: "sparkles", description: Text("可在「设置 › Agents」查看工作区里的 Agent，或切换工作区。"))
                        } else {
                            ChatWelcomeView(starters: Self.starters) { model.setDraft($0) }
                        }
                    }
                    ForEach(model.messages) { message in
                        ChatMessageRow(
                            message: message,
                            model: model,
                            context: context,
                            processExpanded: $processExpanded
                        ).id(message.id)
                    }
                    ForEach(model.outbox) { item in
                        OutgoingRow(item: item, model: model).id(item.id)
                    }
                    if !model.queuedTasks.isEmpty {
                        // No identifier on the container: setting one here collapses the
                        // subtree into a single accessibility element, which hides the
                        // per-row 优先 / 编辑 / 移除 buttons from both VoiceOver and the
                        // device tests. The children carry their own identifiers.
                        ChatQueueList(model: model)
                    }
                    if let pending = model.pending, let task = pending.taskId,
                       !model.messages.contains(where: { $0.taskId == task && $0.role != "user" }) {
                        // The send receipt arrives before Mika answers, so the
                        // running task has no assistant row to hang a process block
                        // on yet. Show it standalone until the answer lands and
                        // takes it over; otherwise a long task looks like nothing
                        // is happening.
                        ChatProcessBlock(
                            taskId: task,
                            isRunning: true,
                            waitReason: pending.waitReason,
                            fallbackSeconds: nil,
                            model: model,
                            expanded: Binding(
                                get: { processExpanded[task] ?? true },
                                set: { processExpanded[task] = $0 }
                            )
                        ).accessibilityIdentifier("chat.pending")
                    }
                    Color.clear.frame(height: 1).id("chat.bottom")
                }
                .padding(20)
                .frame(maxWidth: readableWidth)
                .frame(maxWidth: .infinity)
            }
            .defaultScrollAnchor(.bottom, for: .initialOffset)
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("chat.messages")
            .refreshable { await model.refresh(); await model.loadProjects() }
            .onChange(of: model.scrollRequest) { _, _ in initialBottom = true; proxy.scrollTo("chat.bottom", anchor: .bottom) }
            .onScrollPhaseChange { _, phase in if phase == .interacting { initialBottom = false } }
            .onScrollGeometryChange(for: ChatScrollMetrics.self) { geometry in
                ChatScrollMetrics(height: geometry.contentSize.height, bottom: geometry.contentOffset.y + geometry.containerSize.height - geometry.contentInsets.bottom)
            } action: { old, new in
                followingBottom = initialBottom || new.nearBottom
                if old.height != new.height && (initialBottom || old.nearBottom) { proxy.scrollTo("chat.bottom", anchor: .bottom) }
            }
            .onChange(of: model.messages.last?.id) { _, _ in
                if followingBottom {
                    if reduceMotion { proxy.scrollTo("chat.bottom", anchor: .bottom) }
                    else { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("chat.bottom", anchor: .bottom) } }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !followingBottom && !model.messages.isEmpty {
                    Button("最新消息", systemImage: "arrow.down") { proxy.scrollTo("chat.bottom", anchor: .bottom) }
                        .font(.caption).padding(12).background(.regularMaterial, in: Capsule()).padding(12)
                        .accessibilityIdentifier("chat.latest")
                }
            }
        }
    }

    static let starters = ["看看今天有哪些待处理", "汇总我负责项目的进度"]

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 10) {
            HStack {
                if horizontalSizeClass == .regular { projectPickerPopover } else { projectPickerMenu }
                Spacer()
            }.padding(.horizontal, 24)
            if let error = model.projectError { Text(error).font(.caption).foregroundStyle(ChattyTheme.textSecondary).padding(.horizontal, 24) }
            if !model.attachments.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(model.attachments) { file in
                            HStack { Text(file.filename).font(.caption).lineLimit(1); Button("移除附件", systemImage: "xmark.circle.fill") { model.removeAttachment(file.id) }.labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44).accessibilityIdentifier("compose.remove.\(file.id)") }
                                .padding(.leading, 12).background(ChattyTheme.surfaceMuted, in: Capsule())
                        }
                    }.padding(.horizontal, 16)
                }
            }
            if model.uploading { ProgressView("上传附件…").font(.caption) }
            HStack(alignment: .bottom, spacing: 10) {
                Menu {
                    Button("选择照片", systemImage: "photo") { pickingPhoto = true }
                    Button("选择文件", systemImage: "doc") { pickingFile = true }
                } label: { Image(systemName: "plus").font(.title3).frame(width: 44, height: 44) }
                .disabled(model.uploading || model.agent == nil).accessibilityLabel("添加附件").accessibilityIdentifier("chat.attach")
                ZStack(alignment: .topLeading) {
                    if model.draft.isEmpty {
                        Text("和 Mika 说点什么…").foregroundStyle(.secondary).padding(.vertical, 10)
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }
                    ComposerText(text: Binding(get: { model.draft }, set: { model.setDraft($0) }), focused: $draftFocused,
                                 enabled: model.agent != nil,
                                 onSubmit: { if model.canSend { Task { await model.send() } } })
                }
                .frame(maxWidth: .infinity).disabled(model.agent == nil)
                sendOrStop
            }.padding(8).background(ChattyTheme.surface, in: RoundedRectangle(cornerRadius: 24)).padding(.horizontal, 12)
        }.padding(.vertical, 8).background(ChattyTheme.background)
            .frame(maxWidth: readableWidth)
            .frame(maxWidth: .infinity)
            .dropDestination(for: DroppedAttachment.self) { items, _ in
                guard let item = items.first else { return false }
                Task { await model.upload(imported: item.imported) }
                return true
            } isTargeted: { dropTargeted = $0 }
            .overlay {
                if dropTargeted {
                    RoundedRectangle(cornerRadius: 20).strokeBorder(ChattyTheme.accent, style: StrokeStyle(lineWidth: 2, dash: [7]))
                        .background(ChattyTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
                        .overlay { Label("松手即可添加附件", systemImage: "plus.circle").font(.callout).foregroundStyle(ChattyTheme.accent) }
                        .allowsHitTesting(false).accessibilityIdentifier("chat.dropTarget")
                }
            }
    }

    /// DeepSeek swaps the trailing control for a stop action while it works; we do
    /// the same, but only when the composer is empty — otherwise the user is
    /// composing the next message and sending it must stay available (spec §7.2).
    @ViewBuilder private var sendOrStop: some View {
        if model.canStop && model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && model.attachments.isEmpty {
            Button { Task { await model.stopCurrent() } } label: {
                Image(systemName: "stop.fill").fontWeight(.medium)
                    .frame(width: 44, height: 44).background(ChattyTheme.textPrimary, in: Circle())
                    .foregroundStyle(ChattyTheme.background)
            }.accessibilityLabel("停止生成").accessibilityIdentifier("chat.stop")
        } else {
            Button { Task { await model.send() } } label: {
                Image(systemName: "arrow.up").fontWeight(.medium)
                    .frame(width: 44, height: 44).background(model.canSend ? ChattyTheme.accent : ChattyTheme.surfaceMuted, in: Circle())
                    .foregroundStyle(model.canSend ? ChattyTheme.onAccent : ChattyTheme.textSecondary)
            }.disabled(!model.canSend).accessibilityLabel("发送").accessibilityIdentifier("chat.send")
        }
    }

    private var projectPickerLabel: some View {
        Label(model.selectedProjectName, systemImage: "folder").font(.callout).lineLimit(1).frame(minHeight: 44)
    }
    private var projectPickerMenu: some View {
        Menu { projectPickerRows } label: { projectPickerLabel }.accessibilityIdentifier("chat.projectPicker")
    }
    /// Regular width keeps the context: a popover anchored to the composer button
    /// instead of a full sheet. Selection and persistence stay on ChatModel.
    private var projectPickerPopover: some View {
        Button { showProjectPicker = true } label: { projectPickerLabel }
            .accessibilityIdentifier("chat.projectPicker")
            .popover(isPresented: $showProjectPicker, arrowEdge: .bottom) {
                List {
                    Button { model.selectProject(nil); showProjectPicker = false } label: { projectRow("不指定项目", selected: model.selectedProjectId == nil) }
                    ForEach(model.projects) { project in
                        Button { model.selectProject(project.id); showProjectPicker = false } label: { projectRow(project.title, selected: model.selectedProjectId == project.id) }
                    }
                    Button("刷新项目") { Task { await model.loadProjects() } }
                }
                .frame(minWidth: 280, minHeight: 220)
                .accessibilityIdentifier("chat.projectPopover")
            }
    }
    private func projectRow(_ title: String, selected: Bool) -> some View {
        HStack { Text(title); Spacer(); if selected { Image(systemName: "checkmark").foregroundStyle(ChattyTheme.accent) } }
    }
    @ViewBuilder private var projectPickerRows: some View {
        Button("不指定项目") { model.selectProject(nil) }
        ForEach(model.projects) { project in Button(project.title) { model.selectProject(project.id) } }
        Divider()
        Button("刷新项目") { Task { await model.loadProjects() } }
    }
}

// MARK: - Welcome

/// First screen of a conversation. Mirrors DeepSeek's centred mark over a single
/// short line ("想从哪里开始？", verified against the 2026-09-10 on-device capture)
/// plus two starters. No feature toggles: the server exposes no parameter for
/// them, so showing them would be a control that does nothing (spec §13).
private struct ChatWelcomeView: View {
    let starters: [String]
    let choose: (String) -> Void
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles").font(.system(size: 44, weight: .regular)).foregroundStyle(ChattyTheme.accent)
            Text("想从哪里开始？").font(.title3.weight(.semibold)).foregroundStyle(ChattyTheme.textPrimary)
                .accessibilityIdentifier("chat.welcome")
            VStack(spacing: 8) {
                ForEach(starters, id: \.self) { text in
                    Button(text) { choose(text) }
                        .buttonStyle(.bordered).frame(minHeight: 44)
                        .accessibilityIdentifier("chat.suggestion")
                }
            }.padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Message rows

private struct ChatMessageRow: View {
    let message: ChatMessage
    let model: ChatModel
    let context: WorkspaceContext
    @Binding var processExpanded: [String: Bool]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if message.role == "user" {
                userRow
            } else {
                assistantRow
            }
            ForEach(message.attachments ?? []) { attachment in AttachmentButton(attachment: attachment, context: context) }
            if let task = message.taskId, message.role != "user" {
                ChatProcessBlock(
                    taskId: task,
                    isRunning: model.pending?.taskId == task,
                    waitReason: model.pending?.taskId == task ? model.pending?.waitReason : nil,
                    fallbackSeconds: message.elapsedMs.map { $0 / 1000 },
                    model: model,
                    expanded: Binding(
                        get: { processExpanded[task] ?? (model.pending?.taskId == task) },
                        set: { processExpanded[task] = $0 }
                    )
                )
            }
            if let suggestions = message.quickActions, !suggestions.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack { suggestionsView(suggestions) }
                    VStack(alignment: .leading) { suggestionsView(suggestions) }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
            .contextMenu {
                if let content = message.content?.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty {
                    Button("复制文本", systemImage: "doc.on.doc") { UIPasteboard.general.string = content }
                    ShareLink(item: content) { Label("分享", systemImage: "square.and.arrow.up") }
                    Button("引用到输入框", systemImage: "text.quote") { model.setDraft(quoted(content)) }
                }
            }
            .accessibilityElement(children: .contain).accessibilityIdentifier("message.\(message.id)")
    }

    /// Quote the selected text into the composer without discarding what is there.
    private func quoted(_ content: String) -> String {
        let quoted = content.split(separator: "\n").prefix(3).map { "> \($0)" }.joined(separator: "\n")
        let existing = model.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return existing.isEmpty ? quoted + "\n" : existing + "\n\n" + quoted + "\n"
    }

    private var userRow: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if let files = message.attachments, !files.isEmpty {
                HStack { Spacer(minLength: 36); ChatAttachmentCards(attachments: files, context: context) }
            }
            HStack {
                Spacer(minLength: 36)
                Text(message.content ?? "")
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(ChattyTheme.bubbleUser, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(ChattyTheme.bubbleUserText)
                    .textSelection(.enabled)
            }
            if model.pending?.queuedTasks?.contains(where: { $0.messageId == message.id }) == true {
                Text("排队中").font(.caption).foregroundStyle(ChattyTheme.textSecondary)
            }
        }
    }

    private var assistantRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            if message.messageKind == "no_response" || (message.content ?? "").isEmpty && (message.attachments ?? []).isEmpty {
                Label("本次执行没有返回文字回复。", systemImage: "text.bubble").foregroundStyle(ChattyTheme.textSecondary)
            }
            if let failure = message.failureReason {
                ErrorNotice(text: DisplayText.failure(failure), identifier: "chat.failure.\(message.id)")
            }
            if let content = message.content, !content.isEmpty { RichContentView(source: content, context: context) }
            if let elapsed = message.elapsedMs {
                Text(String(format: "用时 %.1f 秒", Double(elapsed) / 1000)).font(.caption).foregroundStyle(ChattyTheme.textSecondary)
            }
        }
    }

    private func suggestionsView(_ actions: [QuickAction]) -> some View {
        ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
            Button(action.label) { model.setDraft(action.prompt) }.buttonStyle(.bordered).frame(minHeight: 44).hoverEffect(.highlight).disabled(model.sending).accessibilityIdentifier("chat.suggestion")
        }
    }
}

/// File attachments render above the bubble as cards (name + size), matching the
/// official screenshots.
private struct ChatAttachmentCards: View {
    let attachments: [Attachment]
    let context: WorkspaceContext
    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            ForEach(attachments.prefix(3)) { file in
                HStack(spacing: 10) {
                    Image(systemName: "doc.fill").foregroundStyle(ChattyTheme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.filename).font(.callout).lineLimit(1)
                        if let size = file.sizeBytes { Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)).font(.caption).foregroundStyle(ChattyTheme.textSecondary) }
                    }
                }
                .padding(10)
                .background(ChattyTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ChattyTheme.chipInactiveBorder))
                .frame(maxWidth: 280, alignment: .trailing)
            }
            if attachments.count > 3 {
                Text("+\(attachments.count - 3) 个附件").font(.caption).foregroundStyle(ChattyTheme.textSecondary)
            }
        }
    }
}

// MARK: - Process block

/// The collapsible reasoning block. It is the closest observable equivalent of
/// DeepSeek's "正在思考" → "已思考（用时 N 秒）": Multica streams task steps over the
/// socket and has no web-page counts, so the steps are rendered from `TaskTrace`
/// instead of the search/browse rows in the screenshots (spec §6.3, decisions J2).
private struct ChatProcessBlock: View {
    let taskId: String
    let isRunning: Bool
    let waitReason: String?
    /// Server-reported duration for a finished message; `TaskTrace` carries no
    /// timestamp of its own, so a task we did not watch live falls back to this.
    let fallbackSeconds: Int?
    let model: ChatModel
    @Binding var expanded: Bool
    @State private var loadedOnce = false
    @State private var startedAt: Date?
    @State private var elapsed: TimeInterval = 0
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var rows: [TaskTrace] { model.traces[taskId] ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { expanded.toggle(); if expanded { Task { await model.loadTrace(taskId) } } } label: {
                HStack(spacing: 6) {
                    Text(title).font(.subheadline)
                    Image(systemName: expanded ? "chevron.down" : "chevron.right").font(.caption.weight(.semibold))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(ChattyTheme.textSecondary)
                .contentShape(Rectangle())
                .frame(minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(expanded ? "\(title)，已展开" : "\(title)，已折叠")

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    if let waitReason, isRunning { Text(waitReason).font(.caption).foregroundStyle(ChattyTheme.textSecondary) }
                    // `loadTrace` stores an empty array for a task whose steps have
                    // not arrived yet, so the running state must key off `isRunning`
                    // and not off "the trace dictionary has no entry".
                    if rows.isEmpty && isRunning { ProgressView().controlSize(.mini) }
                    else if rows.isEmpty { Text("这次执行没有过程记录。").font(.callout).foregroundStyle(ChattyTheme.textSecondary) }
                    ForEach(displayedRows) { row in ChatProcessRow(row: row) }
                    if rows.count > 6 {
                        Text("共 \(rows.count) 步").font(.caption).foregroundStyle(ChattyTheme.textSecondary)
                    }
                }
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle().fill(ChattyTheme.separator).frame(width: 1)
                }
            }
        }
        .font(.callout)
        .accessibilityIdentifier("trace.\(taskId)")
        .task(id: expanded) {
            guard expanded, !loadedOnce else { return }
            loadedOnce = true
            await model.loadTrace(taskId)
        }
        .onAppear { if isRunning, startedAt == nil { startedAt = Date() } }
        .onChange(of: isRunning) { _, running in
            if running { if startedAt == nil { startedAt = Date() }; elapsed = 0 }
            else if let startedAt, elapsed == 0 { elapsed = Date().timeIntervalSince(startedAt) }
        }
        .onReceive(ticker) { _ in
            guard isRunning, let startedAt else { return }
            elapsed = Date().timeIntervalSince(startedAt)
        }
    }

    /// Keep the tail visible while it streams; a long task must not push the answer
    /// out of the way.
    private var displayedRows: ArraySlice<TaskTrace> {
        rows.count > 6 ? rows.suffix(6) : rows[0...]
    }
    private var seconds: Int {
        if isRunning { return max(0, Int(elapsed.rounded())) }
        if elapsed > 0 { return Int(elapsed.rounded()) }
        return fallbackSeconds ?? 0
    }
    private var title: String {
        isRunning ? "正在思考" : (seconds > 0 ? "已思考（用时 \(seconds) 秒）" : "已思考")
    }
}

private struct ChatProcessRow: View {
    let row: TaskTrace
    var body: some View {
        switch row.type {
        case "tool_use":
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "wrench.and.screwdriver").font(.caption).foregroundStyle(ChattyTheme.textSecondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.tool ?? row.type).font(.caption.weight(.semibold)).foregroundStyle(ChattyTheme.textPrimary)
                    if let text = row.content ?? row.output, !text.isEmpty {
                        Text(verbatim: DisplayText.redactTrace(text)).font(.caption).foregroundStyle(ChattyTheme.textSecondary).textSelection(.enabled)
                    }
                    if let input = row.input, let data = try? JSONEncoder().encode(DisplayText.redactInput(input)) {
                        Text(verbatim: DisplayText.redactTrace(String(decoding: data, as: UTF8.self)))
                            .font(.system(.caption2, design: .monospaced)).foregroundStyle(ChattyTheme.textSecondary)
                            .textSelection(.enabled)
                    }
                }
            }
        case "thinking":
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•").font(.caption).foregroundStyle(ChattyTheme.textSecondary)
                Text(verbatim: DisplayText.redactTrace(row.content ?? "")).font(.caption).foregroundStyle(ChattyTheme.textSecondary).textSelection(.enabled)
            }
        default:
            EmptyView()
        }
    }
}

// MARK: - Queue

/// Queued follow-up messages, each individually actionable, matching the queue
/// semantics Android already shipped (spec §7.3).
private struct ChatQueueList: View {
    let model: ChatModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("排队中 \(model.queuedTasks.count) 条").font(.caption).foregroundStyle(ChattyTheme.textSecondary)
                Spacer()
                Button("清空", role: .destructive) { Task { await model.clearQueued() } }
                    .font(.caption).frame(minHeight: 44).disabled(model.stopping)
                    .accessibilityIdentifier("chat.queue.clear")
            }
            ForEach(model.queuedTasks) { task in
                HStack(spacing: 12) {
                    Text(task.content ?? "").font(.callout).lineLimit(2)
                    Spacer(minLength: 8)
                    Button("优先") { Task { await model.sendQueuedNow(task.taskId) } }.font(.caption).frame(minHeight: 44)
                        .accessibilityIdentifier("chat.queue.prioritize.\(task.taskId)")
                    Button("编辑") { Task { await model.editQueued(task.taskId) } }.font(.caption).frame(minHeight: 44)
                        .accessibilityIdentifier("chat.queue.edit.\(task.taskId)")
                    Button("移除") { Task { await model.removeQueued(task.taskId) } }.font(.caption).frame(minHeight: 44)
                        .accessibilityIdentifier("chat.queue.remove.\(task.taskId)")
                }
                .padding(12).background(ChattyTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                .disabled(model.stopping)
            }
        }
    }
}

// MARK: - Outbox rows

private struct OutgoingRow: View {
    let item: OutgoingMessage
    let model: ChatModel
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack {
                Spacer(minLength: 36)
                VStack(alignment: .leading, spacing: 8) {
                    if !item.content.isEmpty { Text(item.content).textSelection(.enabled) }
                    ForEach(item.attachments) { file in Label(file.filename, systemImage: "paperclip").font(.caption).lineLimit(2) }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(ChattyTheme.bubbleUser, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(ChattyTheme.bubbleUserText)
            }
            HStack(spacing: 8) {
                if item.status == .submitting { ProgressView().controlSize(.mini) }
                Text(item.status.label)
                if let project = model.projects.first(where: { $0.id == item.projectId }) { Text("· \(project.title)").lineLimit(1) }
            }.font(.caption).foregroundStyle(ChattyTheme.textSecondary)
            if let failure = item.failure { Text(failure).font(.caption).foregroundStyle(ChattyTheme.textSecondary) }
            if item.status == .failed {
                HStack {
                    Button("重新编辑") { model.editOutgoing(item.id) }.frame(minHeight: 44)
                    Button("重试") { Task { await model.retryOutgoing(item.id) } }.frame(minHeight: 44)
                }.font(.callout)
            } else if item.status == .held || item.status == .queued {
                Button("编辑") { model.editOutgoing(item.id) }.font(.caption).frame(minHeight: 44)
            }
        }.frame(maxWidth: .infinity, alignment: .trailing).accessibilityIdentifier("chat.outgoing.\(item.id)")
    }
}

private struct ChatScrollMetrics: Equatable {
    let height: CGFloat
    let bottom: CGFloat
    var nearBottom: Bool { height - bottom < 100 }
}

private struct PickedPhoto: Transferable {
    let data: Data
    let name: String
    let contentType: String
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let values = try received.file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .contentTypeKey])
            guard values.isRegularFile == true else { throw APIError.unsafeFile }
            guard (values.fileSize ?? Int.max) <= APIClient.maximumFileBytes else { throw APIError.oversizedFile }
            return PickedPhoto(data: try Data(contentsOf: received.file, options: .mappedIfSafe), name: received.file.lastPathComponent, contentType: values.contentType?.preferredMIMEType ?? "application/octet-stream")
        }
    }
}

/// Drop payload for the composer. Files/other apps arrive as file URLs; apps
/// that only publish image data (Photos) fall back to the data representation.
/// Both routes run through `AttachmentImport`, the same validator the picker uses.
struct DroppedAttachment: Transferable {
    let imported: ImportedAttachment
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .item) { received in
            DroppedAttachment(imported: try AttachmentImport.read(fileURL: received.file))
        }
        DataRepresentation(importedContentType: .image) { data in
            DroppedAttachment(imported: try AttachmentImport.prepared(data: data, filename: "image.png", contentType: "image/png"))
        }
    }
}
