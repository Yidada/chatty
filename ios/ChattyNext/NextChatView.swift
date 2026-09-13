import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import ChattyCore
import ChattyNextCore
import AVFoundation

struct NextChatView: View {
    @ObservedObject var model: NextModel
    @StateObject private var speech = SpeechInputController()
    @Environment(\.scenePhase) private var scenePhase
    @State private var voiceMode = false
    @State private var focused = false
    @State private var history = false
    @State private var sheet: String?
    @State private var workspaceToChange: Wire?
    @State private var filePicker = false
    @State private var camera = false
    @State private var photo: PhotosPickerItem?
    @State private var followBottom = true
    @State private var scrollID: String?
    private let blue = Color(red: 77/255, green: 107/255, blue: 254/255)
    private var voiceScope: String { (model.client?.credential.origin.key ?? "") + model.current }
    /// DeepSeek 的空输入框长按说话：不切换文字 / 语音模式，按住即录音，
    /// 松手发送、上滑取消。框里有文字时返回 nil，长按仍归系统文本选择。
    private var composerHold: ComposerHoldGesture? {
        guard ComposerHoldGesture.eligible(text: model.draft.text, enabled: !speech.active) else { return nil }
        return ComposerHoldGesture(
            begin: {
                focused = false
                if speech.available { if model.canRecord { speech.begin(scope: voiceScope, revision: model.draft.revision) } }
                else { Task { await speech.prepare() } }
            },
            move: { speech.move(upward: $0, threshold: $1) },
            release: { speech.release() },
            cancel: { speech.cancel() }
        )
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                VStack(spacing: 0) {
                    toolbar
                    if !model.ready { HStack { Text(model.status); Button("重新连接") { Task { await model.resume() } } }.font(.caption).padding(8).frame(maxWidth: .infinity).background(.quaternary) }
                    if let error = model.error { HStack(alignment: .top) { Text(error).font(.caption); Spacer(); Button { model.error = nil } label: { Image(systemName: "xmark") } }.padding(10).foregroundStyle(.red).background(.red.opacity(0.05)) }
                    conversation
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { composer.padding(.horizontal, 12).padding(.bottom, 6).background(Color(uiColor: .systemBackground)) }
                if speech.active {
                    voiceOverlay(height: geometry.size.height * 0.34).frame(maxHeight: .infinity, alignment: .bottom).ignoresSafeArea(edges: .bottom).allowsHitTesting(false)
                }
                if history {
                    Color.black.opacity(0.22).ignoresSafeArea().onTapGesture { withAnimation(.easeOut(duration: 0.22)) { history = false } }
                    NextHistoryView(model: model, close: { withAnimation(.easeOut(duration: 0.22)) { history = false } }, settings: { sheet = "settings" }).frame(width: min(geometry.size.width - 42, 360)).transition(.move(edge: .leading))
                }
            }.background(Color(uiColor: .systemBackground))
        }
        .sheet(item: Binding(get: { sheet.map(SheetID.init) }, set: { sheet = $0?.id })) { item in selectionSheet(item.id).presentationDetents([.medium, .large]).presentationDragIndicator(.visible) }
        .confirmationDialog("在新的工作目录开始对话？", isPresented: Binding(get: { workspaceToChange != nil }, set: { if !$0 { workspaceToChange = nil } }), titleVisibility: .visible) {
            Button("保留草稿并新建对话") { if let w = workspaceToChange { speech.cancel(); model.chooseWorkspace(w); workspaceToChange = nil; sheet = nil } }
        } message: { Text("原对话和正在进行的任务会保留。未发送文字和附件来源带入新对话。") }
        .fileImporter(isPresented: $filePicker, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            do { for url in try result.get() { let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }; let data = try Data(contentsOf: url); model.importAttachment(data: data, name: url.lastPathComponent) } } catch { model.report(error) }
        }
        .onChange(of: photo) { _, item in
            let target = voiceScope
            Task { if let data = try? await item?.loadTransferable(type: Data.self), target == voiceScope { importImage(data) }; if photo == item { photo = nil } }
        }
        .sheet(isPresented: $camera) { NextCamera { image in camera = false; if let data = image?.jpegData(compressionQuality: 0.85) { importImage(data) } }.ignoresSafeArea() }
        .onAppear { restoreReadPosition(); speech.onCommit = { text, scope, revision in guard scope == voiceScope, revision == model.draft.revision else { return }; Task { await model.send(voiceText: text) } } }
        .onChange(of: model.current) { _, _ in speech.cancel(); focused = false; restoreReadPosition() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { speech.interrupt() } }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in speech.interrupt() }
        .onDisappear { speech.cancel() }
    }
    private var toolbar: some View {
        HStack {
            circle("line.3.horizontal.decrease", label: "历史对话") { speech.cancel(); focused = false; withAnimation(.easeOut(duration: 0.22)) { history = true }; Task { try? await model.refreshSessions() } }.accessibilityIdentifier("next.history")
            Spacer(); Text(model.isDraft ? "" : model.title).font(.subheadline).lineLimit(1); Spacer()
            circle("plus.message", label: "新对话") { speech.cancel(); model.newConversation() }.accessibilityIdentifier("next.new")
        }.padding(.horizontal, 16).frame(height: 60).disabled(speech.active || model.busy)
    }
    private var conversation: some View {
        ScrollViewReader { proxy in
            let items = NextTranscriptItem.grouping(model.reducer.messages)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    if model.reducer.hasMore { Button("加载更早的消息") { Task { await model.loadOlder() } }.frame(maxWidth: .infinity) }
                    if model.reducer.messages.isEmpty && model.local.pending.filter({ $0.sessionID == model.current }).isEmpty {
                        VStack(spacing: 24) { Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 38, weight: .semibold)).foregroundStyle(blue); Text("嗨！今天想聊些什么？").font(.system(size: 23, weight: .semibold)) }.frame(maxWidth: .infinity).containerRelativeFrame(.vertical) { height, _ in max(240, height - 50) }
                    }
                    ForEach(items) { item in
                        Group {
                            if item.isProcess {
                                NextToolActivityView(item: item, client: model.client, sessionID: model.current, running: model.isRunning && item.id == items.last?.id)
                                    .id(model.current + item.id)
                            } else if let message = item.messages.first {
                                NextMessageView(message: message, client: model.client, sessionID: model.current)
                            }
                        }.id(item.id)
                    }
                    ForEach(model.local.pending.filter { $0.sessionID == model.current }) { pending in
                        VStack(alignment: .trailing, spacing: 7) {
                            ForEach(pending.draft.attachments) { file in Label(file.name, systemImage: "doc").font(.caption) }
                            Text(pending.draft.text).padding(14).background(blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                            Text(pending.state == "accepted" ? "已接受，等待回复" : pending.state == "uncertain" ? "正在确认是否已发送" : "正在发送…").font(.caption).foregroundStyle(.secondary)
                            if pending.state == "uncertain" { HStack { Button("核对状态") { Task { await model.resume() } }; Button("复制到新草稿") { model.recoverPendingText(pending) } }.font(.caption) }
                        }.frame(maxWidth: .infinity, alignment: .trailing).id(pending.id)
                    }
                    ForEach(model.queues[model.current] ?? [], id: \.self) { item in
                        HStack { Text(item["message"]["content"].array.map { $0["text"].text }.joined()).lineLimit(3); Spacer(); Text("等待回复").font(.caption).foregroundStyle(.secondary); Button("移除") { Task { await model.removeQueue(item["id"].text) } } }.font(.callout)
                    }
                    ForEach(model.prompts.filter { $0["agentId"].text == model.current }, id: \.self) { prompt in NextPromptView(model: model, prompt: prompt) }
                    Color.clear.frame(height: 1).id("bottom")
                }.scrollTargetLayout().padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 12)
            }
            .scrollPosition(id: $scrollID, anchor: .top)
            .onScrollGeometryChange(for: Bool.self) { geometry in geometry.contentSize.height - geometry.visibleRect.maxY < 32 } action: { _, atBottom in if atBottom { followBottom = true } }
            .onScrollPhaseChange { _, phase in if phase == .interacting { followBottom = false }; if phase == .idle { model.saveReadPosition(scrollID) } }
            .onChange(of: model.reducer.messages) { _, _ in if followBottom { proxy.scrollTo("bottom", anchor: .bottom) } }
            .onChange(of: model.local.pending.count) { _, _ in if followBottom { proxy.scrollTo("bottom", anchor: .bottom) } }
            .overlay(alignment: .bottomTrailing) { if !followBottom { Button { followBottom = true; withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } } label: { Image(systemName: "arrow.down").padding(12).background(.regularMaterial, in: Circle()) }.padding(14).accessibilityLabel("回到底部") } }
        }
    }
    private var composer: some View {
        VStack(spacing: 8) {
            if let notice = speech.notice { HStack { Text(notice).font(.caption); if !speech.available { Button("准备语音") { Task { await speech.prepare() } }.disabled(speech.phase == "preparing") } }.foregroundStyle(.secondary).padding(.horizontal, 6) }
            if !model.draft.attachments.isEmpty { ScrollView(.horizontal) { HStack { ForEach(model.draft.attachments) { a in HStack { Image(systemName: "doc"); Text(a.name).lineLimit(1); Button { model.removeAttachment(a.id) } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("移除 \(a.name)") }.font(.caption).padding(8).background(.quaternary, in: Capsule()) } } } }
            VStack(spacing: 8) {
                if voiceMode && model.draft.text.isEmpty && model.draft.attachments.isEmpty {
                    HoldToTalk(enabled: speech.available && (model.canRecord || speech.active), begin: { speech.begin(scope: voiceScope, revision: model.draft.revision) }, move: { speech.move(upward: $0, threshold: $1) }, release: { speech.release() }, cancel: { speech.cancel() }).frame(height: 52)
                    Divider().opacity(0.5)
                } else {
                    ZStack(alignment: .topLeading) {
                        if model.draft.text.isEmpty { Text("发消息").foregroundStyle(.secondary).padding(.top, 10).allowsHitTesting(false) }
                        ComposerText(text: Binding(get: { model.draft.text }, set: { model.editText($0) }), focused: $focused, enabled: !speech.active, onSubmit: { Task { await model.send() } }, accessibilityLabel: "消息草稿", hold: composerHold).frame(minHeight: 52).accessibilityIdentifier("next.draft")
                    }
                }
                HStack(spacing: 8) {
                    chip(model.modelName, id: "next.model", disabled: model.modelLocked) { sheet = "model" }
                    chip(model.workspaceName, id: "next.workspace", disabled: !model.ready || model.busy) { sheet = "workspace" }
                    Spacer(minLength: 0)
                    Menu {
                        PhotosPicker(selection: $photo, matching: .images) { Label("照片", systemImage: "photo") }
                        Button("文件", systemImage: "doc") { filePicker = true }
                        if UIImagePickerController.isSourceTypeAvailable(.camera) { Button("拍照", systemImage: "camera") { camera = true } }
                    } label: { Image(systemName: "plus.circle").font(.system(size: 24)).frame(width: 32, height: 38) }.accessibilityLabel("添加附件")
                    if model.isRunning || model.stopping {
                        Button { Task { await model.cancel() } } label: { Image(systemName: "stop.fill").font(.system(size: 13)).foregroundStyle(.white).frame(width: 32, height: 32).background(blue, in: Circle()) }.disabled(model.stopping).accessibilityLabel(model.stopping ? "正在停止" : "停止回复").accessibilityIdentifier("next.stop")
                    }
                    if !model.draft.text.isEmpty || !model.draft.attachments.isEmpty {
                        Button { Task { await model.send() } } label: { Image(systemName: "arrow.up").font(.system(size: 19, weight: .semibold)).foregroundStyle(.white).frame(width: 32, height: 32).background(model.canSend ? blue : .gray, in: Circle()) }.disabled(!model.canSend).accessibilityLabel("发送消息").accessibilityIdentifier("next.send")
                    } else {
                        Button { voiceMode.toggle(); focused = !voiceMode; if voiceMode { Task { await speech.prepare() } } } label: { Image(systemName: voiceMode ? "keyboard" : "waveform.circle").font(.system(size: 25)).frame(width: 34, height: 38) }.accessibilityLabel(voiceMode ? "切换文字输入" : "切换按住说话").accessibilityIdentifier("next.input-mode")
                    }
                }.foregroundStyle(.primary).disabled(speech.active)
            }.padding(.horizontal, 12).padding(.vertical, 10).background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 27)).overlay(RoundedRectangle(cornerRadius: 27).stroke(Color.primary.opacity(0.09), lineWidth: 0.7)).shadow(color: .black.opacity(0.05), radius: 12, y: 4).opacity(speech.active ? 0 : 1)
        }
    }
    private func voiceOverlay(height: CGFloat) -> some View {
        let tint = speech.cancelArmed ? Color.red : blue
        return VStack(spacing: 42) {
            Text(speech.phase == "finalizing" ? "正在整理文字…" : speech.phase == "starting" ? "正在启动麦克风…" : speech.cancelArmed ? "松手取消" : "松手发送，上滑取消").font(.system(size: 14)).foregroundStyle(.secondary)
            TimelineView(.animation(minimumInterval: 1/30)) { context in
                HStack(spacing: 2.5) { ForEach(0..<56) { i in
                    let wave = abs(sin(context.date.timeIntervalSinceReferenceDate * 8 + Double(i) * 0.7))
                    Rectangle().fill(tint).frame(width: 2, height: 3 + CGFloat(speech.level) * CGFloat(wave) * 30)
                } }.frame(height: 34)
            }.accessibilityHidden(true)
        }.frame(maxWidth: .infinity).frame(height: height).background(LinearGradient(colors: [Color(uiColor: .systemBackground).opacity(0), tint.opacity(0.07), tint.opacity(0.18)], startPoint: .top, endPoint: .bottom)).accessibilityElement(children: .ignore).accessibilityLabel(speech.cancelArmed ? "松手取消" : "正在录音")
        .accessibilityAction(named: "结束并发送") { speech.release() }.accessibilityAction(named: "取消录音") { speech.cancel() }
        .accessibilityIdentifier("next.voice.recording")
    }
    @ViewBuilder private func selectionSheet(_ type: String) -> some View {
        NavigationStack {
            List {
                if type == "model" {
                    ForEach(model.models, id: \.self) { choice in Button { Task { await model.chooseModel(choice); sheet = nil } } label: { HStack { VStack(alignment: .leading) { Text(choice["name"].text); Text(choice["providerName"].text).font(.caption).foregroundStyle(.secondary) }; Spacer(); if choice["model"] == model.draft.model["model"] && choice["provider"] == model.draft.model["provider"] { Image(systemName: "checkmark") } } }.disabled(model.modelLocked) }
                    if model.models.isEmpty { Text("暂无可用模型，请在 Mac 检查配置。") }
                } else if type == "workspace" {
                    ForEach(model.workspaces, id: \.self) { w in Button { if model.isDraft { model.chooseWorkspace(w); sheet = nil } else { workspaceToChange = w } } label: { VStack(alignment: .leading, spacing: 5) { Text(w["title"].text); Text(w["path"].text).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) } } }
                    if model.workspaces.isEmpty { Text("暂无工作目录，请先在 Mac 的 dsh 登记。") }
                } else {
                    Section("当前 Mac") { Text(model.client?.credential.origin.key ?? "").textSelection(.enabled); Text(model.status); Button("重新连接") { Task { await model.resume() } } }
                    Section { LabeledContent("默认方式", value: "自动审核") } header: { Text("权限") } footer: { Text("Mac 会审核工具权限，符合任务授权的操作自动继续。需要你判断时再确认。") }
                    Section { Button("断开此连接", role: .destructive) { speech.cancel(); model.disconnect(); sheet = nil } } footer: { Text("本机草稿保留，重新连接同一地址后恢复。") }
                }
            }.navigationTitle(type == "model" ? "选择模型" : type == "workspace" ? "选择工作目录" : "连接设置").toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { sheet = nil } } }
        }
    }
    private func restoreReadPosition() { scrollID = model.local.readPositions[model.current]; followBottom = scrollID == nil || scrollID == "bottom" }
    private func circle(_ icon: String, label: String, action: @escaping () -> Void) -> some View { Button(action: action) { Image(systemName: icon).font(.system(size: 21)).foregroundStyle(.primary).frame(width: 44, height: 44).background(Color.primary.opacity(0.035), in: Circle()).overlay(Circle().stroke(.primary.opacity(0.07), lineWidth: 0.6)) }.buttonStyle(.plain).accessibilityLabel(label) }
    private func chip(_ text: String, id: String, disabled: Bool, action: @escaping () -> Void) -> some View { Button(action: action) { HStack(spacing: 4) { Text(text).lineLimit(1); Image(systemName: "chevron.down").font(.system(size: 9)) }.font(.system(size: 12)).padding(.horizontal, 9).frame(height: 32).background(blue.opacity(0.07), in: Capsule()) }.disabled(disabled).accessibilityIdentifier(id) }
    private func importImage(_ data: Data) { guard let image = UIImage(data: data), let bytes = image.jpegData(compressionQuality: 0.85) else { return }; model.importAttachment(data: bytes, name: "照片.jpg", mediaType: "image/jpeg") }
    private struct SheetID: Identifiable { let id: String; init(_ id: String) { self.id = id } }
}

struct NextMessageView: View {
    let message: TranscriptMessage
    let client: DSHClient?
    let sessionID: String
    var insideProcess = false
    @State private var reasoningExpanded = false
    @State private var toolsExpanded = false
    private var isTool: Bool { message.role.hasPrefix("tool") }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isTool && !insideProcess {
                DisclosureGroup(isExpanded: $toolsExpanded) {
                    messageContent.padding(.top, 8)
                } label: {
                    Label(message.role == "tool" ? "工具调用" : "工具结果", systemImage: "wrench.and.screwdriver")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .tint(.secondary)
                .accessibilityIdentifier("next.tool-details")
            } else {
                if isTool { Label(message.role == "tool" ? "工具调用" : "工具结果", systemImage: "wrench.and.screwdriver").font(.caption).foregroundStyle(.secondary) }
                messageContent
            }
            if message.pending { ProgressView().controlSize(.mini).accessibilityLabel("正在回复") }
            if message.interrupted { Text("本次回复已中断").font(.caption).foregroundStyle(.secondary) }
            if !message.pending, message.role == "assistant", !message.text.isEmpty { HStack { Button { UIPasteboard.general.string = message.text } label: { Image(systemName: "doc.on.doc") }.accessibilityLabel("复制回复"); ShareLink(item: message.text) { Image(systemName: "square.and.arrow.up") }.accessibilityLabel("分享回复") }.font(.callout).foregroundStyle(.secondary) }
        }
        .padding(message.role == "user" ? 14 : 0).background(message.role == "user" ? ChattyTheme.bubbleUser : .clear, in: RoundedRectangle(cornerRadius: 18))
        .frame(maxWidth: message.role == "user" ? 310 : .infinity, alignment: .leading).frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
        .textSelection(.enabled).accessibilityIdentifier("next.message." + message.role)
        .onChange(of: sessionID) { _, _ in toolsExpanded = false; reasoningExpanded = false }
    }
    private var messageContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(NextTranscriptItem.displayBlocks(message.content).enumerated()), id: \.offset) { _, block in
                if block["type"].text == "reasoning" { DisclosureGroup("思考过程", isExpanded: $reasoningExpanded) { Text(block["text"].text).font(.callout).foregroundStyle(.secondary).textSelection(.enabled) } }
                else if block["type"].text == "text" { NativeRichContent(source: block["text"].text, link: { safeLink($0) }, image: { alt, source in AnyView(Group { if let url = safeLink(source) { Link(alt.isEmpty ? "查看图片" : alt, destination: url) } else { Text(alt.isEmpty ? "图片暂不可预览" : alt).foregroundStyle(.secondary) } }) }) }
                else if block["type"].text == "image" { NextImageView(client: client, sessionID: sessionID, attachment: block["attachment"]) }
                else if block["type"].text == "file" { Label(block["attachment"]["name"].string ?? "文件", systemImage: "doc").font(.callout) }
                else if block["type"].text == "tool-call" { NextToolCallView(block: block).id(sessionID) }
                else { Text(block["name"].string ?? block["text"].string ?? "附件：" + block["type"].text).font(.callout).foregroundStyle(.secondary) }
            }
        }
    }
    private func safeLink(_ source: String) -> URL? { guard let url = URL(string: source), url.scheme == "https", url.user == nil, url.password == nil else { return nil }; return url }
}

/// Streamed arguments and restored calls use the same collapsed presentation.
private struct NextToolCallView: View {
    let block: Wire
    @State private var expanded = false
    private var arguments: String {
        if let text = block["arguments"].string { return text }
        guard block["arguments"] != .null, let data = try? block["arguments"].data(), let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }
    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            if !arguments.isEmpty { Text(arguments).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8) }
        } label: {
            Label(block["name"].string ?? "工具调用", systemImage: "wrench").font(.subheadline).foregroundStyle(.secondary)
        }.tint(.secondary).accessibilityIdentifier("next.tool-call-details")
    }
}

/// Presentation-only grouping keeps tool output out of the answer while leaving
/// the reducer's event identities and persistence untouched.
struct NextTranscriptItem: Identifiable {
    var messages: [TranscriptMessage]
    let isProcess: Bool
    var id: String { messages[0].id }
    var callCount: Int {
        let calls = messages.filter { $0.role == "tool" }.count
        if calls > 0 { return calls }
        return messages.flatMap(\.content).filter { $0["type"].text == "tool-call" }.count
    }
    var hasTools: Bool { messages.contains { $0.role.hasPrefix("tool") || $0.content.contains { $0["type"].text == "tool-call" } } }
    var title: String {
        if hasTools { return callCount > 0 ? "工具调用 · \(callCount) 次" : "工具调用" }
        return messages.flatMap(\.content).contains { $0["type"].text == "reasoning" } ? "思考过程" : "正在回复"
    }
    static func grouping(_ messages: [TranscriptMessage]) -> [Self] {
        var items: [Self] = []
        for message in messages {
            let process = message.role.hasPrefix("tool") || (message.role == "assistant" && message.content.allSatisfy { ["reasoning", "tool-call"].contains($0["type"].text) || ($0["type"].text == "text" && $0["text"].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) })
            if process, items.last?.isProcess == true { items[items.count - 1].messages.append(message) }
            else { items.append(Self(messages: [message], isProcess: process)) }
        }
        return items
    }
    static func displayBlocks(_ blocks: [Wire]) -> [Wire] {
        blocks.flatMap { block in
            if block["type"].text == "tool-result" {
                var content = block["content"].array
                if block["isError"].bool { content.insert(.object(["type": .str("text"), "text": .str("工具执行未成功")]), at: 0) }
                return content
            }
            return [block]
        }
    }
}

private struct NextToolActivityView: View {
    let item: NextTranscriptItem
    let client: DSHClient?
    let sessionID: String
    let running: Bool
    @State private var expanded = false
    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            if expanded {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(item.messages) { message in
                        NextMessageView(message: message, client: client, sessionID: sessionID, insideProcess: true)
                    }
                }.padding(.top, 10).padding(.leading, 8)
            }
        } label: {
            HStack(spacing: 8) {
                if running { ProgressView().controlSize(.mini) }
                else { Image(systemName: item.hasTools ? "wrench.and.screwdriver" : "sparkle") }
                Text(item.title)
            }.font(.subheadline).foregroundStyle(.secondary)
        }.tint(.secondary).accessibilityIdentifier("next.tool-activity")
    }
}
