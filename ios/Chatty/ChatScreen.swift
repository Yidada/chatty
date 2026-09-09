import SwiftUI
import ChattyCore
import PhotosUI
import UniformTypeIdentifiers
import CoreTransferable

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
    @FocusState private var draftFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            if let error = model.error { ErrorNotice(text: error, identifier: "chat.error").padding(.horizontal, 16).padding(.top, 8) }
            if let notice = model.notice { Text(notice).font(.callout).foregroundStyle(.secondary).padding(.horizontal, 20).padding(.top, 8).accessibilityIdentifier("chat.notice") }
            if model.uncertain {
                HStack {
                    Text("发送结果待确认").font(.callout).accessibilityIdentifier("chat.uncertain")
                    Spacer()
                    Button("刷新核对") { Task { await model.refresh() } }.frame(minHeight: 44)
                    Button("已核对") { confirmUncertain = true }.frame(minHeight: 44).accessibilityIdentifier("chat.acknowledge")
                }.padding(.horizontal, 16).background(.orange.opacity(0.08))
            }
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
                        if model.initialized && model.messages.isEmpty && model.agent != nil {
                            ContentUnavailableView("和 Mika 开始工作", systemImage: "sparkles", description: Text("输入你的需求，Mika 会接着处理。"))
                        }
                        ForEach(model.messages) { message in
                            MessageRow(message: message, model: model, context: context).id(message.id)
                        }
                        if let pending = model.pending, let task = pending.taskId {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack { ProgressView(); Text(DisplayText.status(pending.status ?? "running")).font(.callout) }
                                if let reason = pending.waitReason { Text(reason).font(.caption).foregroundStyle(.secondary) }
                                TaskDetails(taskId: task, model: model)
                            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                .background(ChattyTheme.surface, in: RoundedRectangle(cornerRadius: 18)).accessibilityIdentifier("chat.pending")
                        }
                        Color.clear.frame(height: 1).id("chat.bottom")
                    }.padding(20)
                }
                .defaultScrollAnchor(.bottom, for: .initialOffset)
                .scrollDismissesKeyboard(.interactively)
                .accessibilityIdentifier("chat.messages")
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
        .task { await model.setVisible(true) }
        .onDisappear { Task { await model.setVisible(false) } }
        .navigationTitle("Mika").navigationBarTitleDisplayMode(.inline)
        .background(ChattyTheme.background)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Label(model.connected ? "实时连接" : "定时同步", systemImage: model.connected ? "bolt.horizontal.circle.fill" : "arrow.triangle.2.circlepath")
                    .font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("chat.connection")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("刷新", systemImage: "arrow.clockwise") { Task { await model.refresh() } }.accessibilityIdentifier("chat.refresh")
            }
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("收起键盘") { draftFocused = false } }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { composer }
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
        .alert("已核对服务端消息？", isPresented: $confirmUncertain) {
            Button("已核对，继续编辑") { model.acknowledgeUncertain() }
            Button("继续核对", role: .cancel) {}
        } message: { Text("解除待确认后可以再次发送。请先确认上一条消息是否已经到达，避免重复执行。") }
    }
    private var composer: some View {
        VStack(spacing: 10) {
            if !model.attachments.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(model.attachments) { file in
                            HStack { Text(file.filename).font(.caption).lineLimit(1); Button("移除附件", systemImage: "xmark.circle.fill") { model.removeAttachment(file.id) }.labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44).accessibilityIdentifier("compose.remove.\(file.id)") }
                                .padding(.leading, 12).background(ChattyTheme.surface, in: Capsule())
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
                .disabled(model.sending || model.uploading || model.agent == nil).accessibilityLabel("添加附件").accessibilityIdentifier("chat.attach")
                TextField("和 Mika 说点什么…", text: Binding(get: { model.draft }, set: { model.setDraft($0) }), axis: .vertical)
                    .lineLimit(1...6).focused($draftFocused).padding(.vertical, 12).accessibilityIdentifier("chat.draft")
                    .disabled(model.agent == nil || model.sending)
                Button { Task { await model.send() } } label: {
                    Group { if model.sending { ProgressView() } else { Image(systemName: "arrow.up").fontWeight(.semibold) } }
                        .frame(width: 44, height: 44).background(model.canSend ? ChattyTheme.accent : .secondary.opacity(0.1), in: Circle())
                        .foregroundStyle(model.canSend ? ChattyTheme.onAccent : Color.secondary)
                }.disabled(!model.canSend).accessibilityLabel("发送").accessibilityIdentifier("chat.send")
            }.padding(8).background(ChattyTheme.surface, in: RoundedRectangle(cornerRadius: 28)).padding(.horizontal, 12)
        }.padding(.vertical, 8).background(ChattyTheme.background)
    }
}

private struct MessageRow: View {
    let message: ChatMessage
    let model: ChatModel
    let context: WorkspaceContext
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if message.role == "user" {
                HStack { Spacer(minLength: 36); Text(message.content ?? "").padding(14).background(ChattyTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 18)).textSelection(.enabled) }
            } else {
                if message.messageKind == "no_response" || (message.content ?? "").isEmpty && (message.attachments ?? []).isEmpty {
                    Label("本次执行没有返回文字回复。", systemImage: "text.bubble").foregroundStyle(.secondary)
                }
                if let failure = message.failureReason {
                    ErrorNotice(text: DisplayText.failure(failure), identifier: "chat.failure.\(message.id)")
                }
                if let content = message.content, !content.isEmpty { RichContentView(source: content, context: context) }
                if let elapsed = message.elapsedMs { Text(String(format: "耗时 %.1f 秒", Double(elapsed) / 1000)).font(.caption).foregroundStyle(.secondary) }
            }
            ForEach(message.attachments ?? []) { attachment in AttachmentButton(attachment: attachment, context: context) }
            if let task = message.taskId, message.role != "user" { TaskDetails(taskId: task, model: model) }
            if let suggestions = message.quickActions, !suggestions.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack { suggestionsView(suggestions) }
                    VStack(alignment: .leading) { suggestionsView(suggestions) }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain).accessibilityIdentifier("message.\(message.id)")
    }
    private func suggestionsView(_ actions: [QuickAction]) -> some View {
        ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
            Button(action.label) { model.setDraft(action.prompt) }.buttonStyle(.bordered).frame(minHeight: 44).disabled(model.sending).accessibilityIdentifier("chat.suggestion")
        }
    }
}

private struct TaskDetails: View {
    let taskId: String
    let model: ChatModel
    @State private var expanded = false
    var body: some View {
        DisclosureGroup("执行过程", isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 14) {
                if model.traces[taskId] == nil { ProgressView("读取过程…") }
                else if model.traces[taskId]?.isEmpty == true { Text("暂时没有过程记录。").foregroundStyle(.secondary) }
                ForEach(model.traces[taskId] ?? []) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        Label("\(row.seq) · \(row.tool ?? row.type)", systemImage: "circle.dotted").font(.caption).foregroundStyle(.secondary)
                        if let text = row.content ?? row.output { Text(verbatim: DisplayText.redactTrace(text)).font(.callout).textSelection(.enabled) }
                        if let input = row.input, let data = try? JSONEncoder().encode(DisplayText.redactInput(input)) { Text(verbatim: DisplayText.redactTrace(String(decoding: data, as: UTF8.self))).font(.system(.caption, design: .monospaced)).textSelection(.enabled) }
                    }
                }
            }.padding(.top, 10)
        }.font(.callout).accessibilityIdentifier("trace.\(taskId)")
            .onChange(of: expanded) { _, value in if value { Task { await model.loadTrace(taskId) } } }
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
