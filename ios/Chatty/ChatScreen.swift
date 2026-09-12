import SwiftUI
import ChattyCore
import PhotosUI
import UniformTypeIdentifiers
import CoreTransferable
import UIKit

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
    @FocusState private var draftFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var commands: AppCommandCenter

    var body: some View {
        VStack(spacing: 0) {
            if let error = model.error { ErrorNotice(text: error, identifier: "chat.error").padding(.horizontal, 16).padding(.top, 8) }
            if let notice = model.notice { Text(notice).font(.callout).foregroundStyle(.secondary).padding(.horizontal, 20).padding(.top, 8).accessibilityIdentifier("chat.notice") }
            if model.uncertain {
                HStack {
                    Text("发送结果待确认").font(.callout).accessibilityIdentifier("chat.uncertain")
                    Spacer()
                    Button("刷新核对") { Task { await model.refresh() } }.frame(minHeight: 44)
                    Button("核对结果") { confirmUncertain = true }.frame(minHeight: 44).accessibilityIdentifier("chat.acknowledge")
                }.padding(.horizontal, 16).background(.orange.opacity(0.08))
            }
            if model.outbox.contains(where: { $0.status == .held }) {
                HStack {
                    Text("未发送的消息已保留").font(.callout)
                    Spacer()
                    Button("继续发送") { Task { await model.resumeOutbox() } }.frame(minHeight: 44).disabled(model.sending || model.uncertain).accessibilityIdentifier("chat.resumeQueue")
                }.padding(.horizontal, 20)
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
                        if model.initialized && model.messages.isEmpty {
                            if model.agent == nil {
                                ContentUnavailableView("当前工作区还没有可对话的 Mika", systemImage: "sparkles", description: Text("可在「设置 › Agents」查看工作区里的 Agent，或切换工作区。"))
                            } else {
                                ContentUnavailableView("和 Mika 开始工作", systemImage: "sparkles", description: Text("输入你的需求，Mika 会接着处理。"))
                            }
                        }
                        ForEach(model.messages) { message in
                            MessageRow(message: message, model: model, context: context).id(message.id)
                        }
                        ForEach(model.outbox) { item in
                            OutgoingRow(item: item, model: model).id(item.id)
                        }
                        if let pending = model.pending, let task = pending.taskId {
                            DisclosureGroup {
                                if let reason = pending.waitReason { Text(reason).font(.caption).foregroundStyle(.secondary) }
                                TaskDetails(taskId: task, model: model)
                            } label: {
                                Text((pending.queuedTasks?.isEmpty == false) ? "Mika 正在处理 · \(pending.queuedTasks?.count ?? 0) 条排队" : "Mika 正在处理").font(.callout).foregroundStyle(.secondary)
                            }.accessibilityIdentifier("chat.pending")
                        }
                        Color.clear.frame(height: 1).id("chat.bottom")
                    }.padding(20)
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
        .navigationTitle("Mika").navigationBarTitleDisplayMode(.inline)
        .background(ChattyTheme.background)
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
        .alert("这条消息已经收到？", isPresented: $confirmUncertain) {
            Button("确认已收到") { model.acknowledgeUncertain() }
            if model.outbox.contains(where: { $0.status == .uncertain }) {
                Button("确认未收到，重试") { Task { await model.retryUncertainAfterReview() } }
            }
            Button("继续核对", role: .cancel) {}
        } message: { Text("请先刷新核对聊天记录。已收到会移除本机待核对记录；重试会再次提交，如果原消息稍后到达，可能重复执行。") }
    }
    private var composer: some View {
        VStack(spacing: 10) {
            HStack {
                if horizontalSizeClass == .regular { projectPickerPopover } else { projectPickerMenu }
                Spacer()
            }.padding(.horizontal, 24)
            if let error = model.projectError { Text(error).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 24) }
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
                .disabled(model.uploading || model.agent == nil).accessibilityLabel("添加附件").accessibilityIdentifier("chat.attach")
                TextField("和 Mika 说点什么…", text: Binding(get: { model.draft }, set: { model.setDraft($0) }), axis: .vertical)
                    .lineLimit(1...6).focused($draftFocused).padding(.vertical, 12).accessibilityIdentifier("chat.draft")
                    .disabled(model.agent == nil)
                Button { Task { await model.send() } } label: {
                    Image(systemName: "arrow.up").fontWeight(.medium)
                        .frame(width: 44, height: 44).background(model.canSend ? ChattyTheme.accent : .secondary.opacity(0.1), in: Circle())
                        .foregroundStyle(model.canSend ? ChattyTheme.onAccent : Color.secondary)
                }.disabled(!model.canSend).accessibilityLabel("发送").accessibilityIdentifier("chat.send")
            }.padding(8).background(ChattyTheme.surface, in: RoundedRectangle(cornerRadius: 28)).padding(.horizontal, 12)
        }.padding(.vertical, 8).background(ChattyTheme.background)
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
    private var projectPickerLabel: some View {
        Label(model.selectedProjectName, systemImage: "folder").font(.callout).lineLimit(1).frame(minHeight: 44)
    }
    private var projectPickerMenu: some View {
        Menu {
            projectPickerRows
        } label: { projectPickerLabel }.accessibilityIdentifier("chat.projectPicker")
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

private struct MessageRow: View {
    let message: ChatMessage
    let model: ChatModel
    let context: WorkspaceContext
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if message.role == "user" {
                HStack { Spacer(minLength: 36); Text(message.content ?? "").padding(14).background(ChattyTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 18)).textSelection(.enabled) }
                if model.pending?.queuedTasks?.contains(where: { $0.messageId == message.id }) == true {
                    Text("排队中").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .trailing)
                }
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
            .contextMenu {
                if let content = message.content?.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty {
                    Button("复制文本", systemImage: "doc.on.doc") { UIPasteboard.general.string = content }
                }
            }
            .accessibilityElement(children: .contain).accessibilityIdentifier("message.\(message.id)")
    }
    private func suggestionsView(_ actions: [QuickAction]) -> some View {
        ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
            Button(action.label) { model.setDraft(action.prompt) }.buttonStyle(.bordered).frame(minHeight: 44).hoverEffect(.highlight).disabled(model.sending).accessibilityIdentifier("chat.suggestion")
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
                }.padding(14).background(ChattyTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
            }
            HStack(spacing: 8) {
                if item.status == .submitting { ProgressView().controlSize(.mini) }
                Text(item.status.label)
                if let project = model.projects.first(where: { $0.id == item.projectId }) { Text("· \(project.title)").lineLimit(1) }
            }.font(.caption).foregroundStyle(.secondary)
            if let failure = item.failure { Text(failure).font(.caption).foregroundStyle(.secondary) }
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
