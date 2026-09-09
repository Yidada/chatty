import SwiftUI
import ChattyCore

struct AppConfiguration {
    let baseURL: URL
    let isFixture: Bool
    var hint: String?
    static let production = AppConfiguration(baseURL: URL(string: "https://api.multica.ai/")!, isFixture: false)
}

struct AppBootstrap: View {
    let configuration: AppConfiguration
    @State private var model: SessionModel?
    @State private var failure: String?

    var body: some View {
        Group {
            if let model {
                VStack(spacing: 0) {
                    if configuration.isFixture {
                        Label("测试工作区 · 合成数据", systemImage: "flask")
                            .font(.caption).foregroundStyle(ChattyTheme.accent).padding(.vertical, 6)
                            .accessibilityIdentifier("fixture.banner")
                    }
                    SessionRootView(model: model, hint: configuration.hint)
                }
            } else if let failure {
                ContentUnavailableView { Label("暂时无法启动", systemImage: "lock.trianglebadge.exclamationmark") }
                    description: { Text(failure) } actions: { Button("重试", action: prepare) }
            } else { ProgressView("准备工作区…") }
        }
        .background(ChattyTheme.background)
        .tint(ChattyTheme.accent)
        .task { prepare() }
    }
    private func prepare() {
        guard model == nil else { return }
        do {
            let identity = Bundle.main.bundleIdentifier ?? "ai.chatty.ios"
            let files = try ProtectedStorage(identifier: identity)
            model = SessionModel(baseURL: configuration.baseURL, vault: KeychainVault(service: identity), files: files)
            failure = nil
        } catch { failure = error.localizedDescription }
    }
}

struct SessionRootView: View {
    @Bindable var model: SessionModel
    let hint: String?
    var body: some View {
        Group {
            if model.restoring { ProgressView("恢复登录…") }
            else if let workspace = model.current { WorkspaceTabs(model: workspace, session: model).id(workspace.id) }
            else if model.authenticated && model.recoveryScope != nil { OfflineDraftView(model: model) }
            else if model.authenticated { WorkspacePicker(model: model) }
            else { LoginView(model: model, hint: hint) }
        }
        .task { await model.restore() }
    }
}

struct LoginView: View {
    @Bindable var model: SessionModel
    let hint: String?
    @FocusState private var focused: Bool
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 44)).foregroundStyle(ChattyTheme.accent).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("工作，随你继续。").font(.largeTitle.bold())
                        Text("登录 Multica，与你的 Mika 接着聊。").foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        if model.codeSent {
                            Text("验证码已发送至 \(model.email)").font(.callout).foregroundStyle(.secondary)
                            TextField("六位验证码", text: $model.code)
                                .textContentType(.oneTimeCode).keyboardType(.numberPad).focused($focused)
                                .accessibilityIdentifier("auth.code")
                                .padding(18).background(ChattyTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                            Button { focused = false; Task { await model.verify() } } label: {
                                Group { if model.busy { ProgressView() } else { Text("登录").fontWeight(.semibold) } }.frame(maxWidth: .infinity).frame(minHeight: 44)
                            }.buttonStyle(.borderedProminent).disabled(model.busy).accessibilityIdentifier("auth.verify")
                            Button("更换邮箱") { model.changeEmail() }.frame(minHeight: 44).accessibilityIdentifier("auth.changeEmail")
                        } else {
                            TextField("邮箱地址", text: $model.email)
                                .keyboardType(.emailAddress).textContentType(.emailAddress).focused($focused).textInputAutocapitalization(.never).autocorrectionDisabled()
                                .accessibilityIdentifier("auth.email")
                                .padding(18).background(ChattyTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                            Button { Task { await model.sendCode() } } label: {
                                Group { if model.busy { ProgressView() } else { Text("获取验证码").fontWeight(.semibold) } }.frame(maxWidth: .infinity).frame(minHeight: 44)
                            }.buttonStyle(.borderedProminent).disabled(model.busy).accessibilityIdentifier("auth.sendCode")
                        }
                        if let error = model.error { ErrorNotice(text: error, identifier: "auth.error") }
                        if let hint { Text(hint).font(.caption).foregroundStyle(.secondary) }
                    }
                    Text("验证码仅用于这次登录。登录凭据保存在此设备的安全存储中。").font(.footnote).foregroundStyle(.secondary)
                    if model.error?.contains("未完全清理") == true { Button("重试清理本机数据") { model.signOut() } }
                }.padding(28).padding(.top, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(ChattyTheme.background)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成") { focused = false } } }
        }
    }
}

struct WorkspacePicker: View {
    @Bindable var model: SessionModel
    var body: some View {
        NavigationStack {
            List {
                Section { Text("选择一个工作区，继续你的工作。").foregroundStyle(.secondary) }
                if model.busy { ProgressView("读取工作区…") }
                if let error = model.error { ErrorNotice(text: error, identifier: "workspace.error") }
                if !model.busy && model.workspaces.isEmpty && model.error == nil {
                    ContentUnavailableView("还没有可用工作区", systemImage: "building.2", description: Text("当前账号尚未加入工作区。"))
                }
                ForEach(model.workspaces) { workspace in
                    Button { model.select(workspace) } label: {
                        Label(workspace.name, systemImage: "building.2").padding(.vertical, 10)
                    }.accessibilityIdentifier("workspace.\(workspace.id)")
                }
                Section { Button("退出登录", role: .destructive) { model.signOut() }.accessibilityIdentifier("auth.signOut") }
            }
            .navigationTitle("选择工作区").scrollContentBackground(.hidden).background(ChattyTheme.background)
            .refreshable { await model.loadAccount() }
            .toolbar { Button("刷新", systemImage: "arrow.clockwise") { Task { await model.loadAccount() } }.disabled(model.busy).accessibilityIdentifier("workspace.refresh") }
        }
    }
}

struct ErrorNotice: View {
    let text: String
    var identifier = "error.notice"
    var body: some View {
        Label(text, systemImage: "exclamationmark.circle")
            .font(.callout).foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading)
            .padding(14).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityIdentifier(identifier)
    }
}

struct OfflineDraftView: View {
    @Bindable var model: SessionModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Label("暂时离线", systemImage: "wifi.slash").font(.title2.bold())
                    Text(model.recoveryScope?.workspace.name ?? "工作区").font(.headline)
                    Text("可以继续编辑本机草稿。联网确认账户和工作区后，才能读取历史或发送消息。").foregroundStyle(.secondary)
                    if model.recoveryDraft.uncertain { ErrorNotice(text: "上一条发送结果仍待确认，联网后请先核对消息。", identifier: "offline.uncertain") }
                    TextField("继续编辑草稿…", text: Binding(get: { model.recoveryDraft.text }, set: { model.setRecoveryDraft($0) }), axis: .vertical)
                        .lineLimit(6...20).padding(16).background(ChattyTheme.surface, in: RoundedRectangle(cornerRadius: 16)).accessibilityIdentifier("offline.draft")
                    if let error = model.error { ErrorNotice(text: error, identifier: "offline.error") }
                    Button { Task { await model.loadAccount() } } label: { Text(model.busy ? "正在重连…" : "重试连接").frame(minHeight: 44) }
                        .buttonStyle(.borderedProminent).disabled(model.busy).accessibilityIdentifier("offline.retry")
                }.padding(24)
            }.scrollDismissesKeyboard(.interactively).background(ChattyTheme.background).navigationTitle("本机草稿")
                .toolbar { Button("退出登录", role: .destructive) { model.signOut() } }
        }
    }
}

private struct ForegroundRefresh: ViewModifier {
    let action: @MainActor () async -> Void
    @Environment(\.scenePhase) private var phase
    @State private var visible = false
    @State private var refresh: Task<Void, Never>?
    func body(content: Content) -> some View {
        content.onAppear { visible = true }
            .onDisappear { visible = false; refresh?.cancel(); refresh = nil }
            .onChange(of: phase) { _, value in
                refresh?.cancel(); refresh = nil
                if visible && value == .active { refresh = Task { await action() } }
            }
    }
}
extension View {
    func onForegroundRefresh(_ action: @escaping @MainActor () async -> Void) -> some View { modifier(ForegroundRefresh(action: action)) }
}
