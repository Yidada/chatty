import SwiftUI
import ChattyCore

enum LinkedScreen: Identifiable {
    case issue(String), project(String), attachment(String)
    var id: String { switch self { case .issue(let id): "issue-" + id; case .project(let id): "project-" + id; case .attachment(let id): "attachment-" + id } }
}

struct WorkspaceTabs: View {
    let model: WorkspaceModel
    let session: SessionModel
    @State private var tab: AppTab = .activity
    @State private var showingSettings = false
    @State private var linked: LinkedScreen?
    @State private var linkNotice = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right.fill").font(.title2).foregroundStyle(ChattyTheme.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Chatty").font(.headline)
                        Text(model.context.workspace.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }.padding(20)
                List(selection: $tab) {
                    HStack {
                        Label("动态", systemImage: "waveform.path")
                        Spacer()
                        if model.activity.hasAttention { Circle().fill(.red).frame(width: 7, height: 7).accessibilityLabel("有未读动态").accessibilityIdentifier("sidebar.attention") }
                    }.tag(AppTab.activity).accessibilityIdentifier("nav.activity")
                    Label("Mika", systemImage: "sparkles").tag(AppTab.chat).accessibilityIdentifier("nav.chat")
                    Label("项目", systemImage: "folder").tag(AppTab.projects).accessibilityIdentifier("nav.projects")
                }.listStyle(.sidebar)
                Text("让工作，继续发生。").font(.caption).foregroundStyle(.tertiary).padding(20)
            }.navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            NavigationStack {
                Group {
                    switch tab {
                    case .activity: ActivityScreen(model: model.activity, projects: model.projects, context: model.context, discuss: discuss)
                    case .chat: ChatScreen(model: model.chat, context: model.context)
                    case .projects: ProjectsScreen(model: model.projects, context: model.context, onViewed: model.activity.markRead, onChanged: model.activity.apply, discuss: discuss)
                    }
                }.toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("刷新", systemImage: "arrow.clockwise") {
                            Task {
                                switch tab {
                                case .activity: await model.activity.refresh()
                                case .chat: await model.chat.refresh(); await model.chat.loadProjects()
                                case .projects: await model.projects.overview()
                                }
                            }
                        }.help("刷新当前页面").accessibilityIdentifier("workspace.refresh")
                    }
                    profileButton
                }
            }.id(tab)
        }
        .onReceive(NotificationCenter.default.publisher(for: .chattySettings)) { _ in showingSettings = true }
        .onReceive(NotificationCenter.default.publisher(for: .chattyNavigate)) { event in
            if let raw = event.object as? String, let destination = AppTab(rawValue: raw) { tab = destination }
        }
        .environment(\.openURL, OpenURLAction { url in
            switch NativeLink.resolve(url.absoluteString, api: model.context.api.baseURL, workspace: model.context.workspace.slug) {
            case .issue(let id): linked = .issue(id); return .handled
            case .project(let id): linked = .project(id); return .handled
            case .attachment(let id): linked = .attachment(id); return .handled
            case .external(let url): return .systemAction(url)
            default: linkNotice = true; return .handled
            }
        })
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsScreen(session: session, resources: model.resources, context: model.context)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { showingSettings = false }.accessibilityIdentifier("settings.close") } }
            }.frame(width: 680, height: 640)
        }
        .sheet(item: $linked) { destination in
            NavigationStack {
                Group {
                    switch destination {
                    case .attachment(let id): LinkedAttachmentScreen(id: id, context: model.context)
                    case .issue(let id): IssueScreen(model: model.projects, context: model.context, issueId: id, onViewed: model.activity.markRead, onChanged: model.activity.apply, discuss: discuss)
                    case .project(let id): IssuesScreen(model: model.projects, context: model.context, projectId: id, title: "项目事项", onViewed: model.activity.markRead, onChanged: model.activity.apply, discuss: discuss)
                    }
                }.toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { linked = nil } } }
            }.frame(width: 720, height: 660)
        }
        .alert("此链接暂不支持在当前页面打开", isPresented: $linkNotice) { Button("知道了", role: .cancel) {} } message: { Text("请从项目或设置中查看对应资源。") }
        .task {
            if scenePhase == .active { model.activity.start() }
            await model.chat.initialize()
            session.rememberDraftScope(model)
            if scenePhase == .active { model.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.start() } else { model.pause() }
        }
        .onDisappear { model.pause() }
    }
    private var profileButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button { showingSettings = true } label: {
                Text(String((model.context.user.name ?? model.context.user.email ?? "我").prefix(1)).uppercased())
                    .font(.callout.weight(.medium)).frame(width: 32, height: 32)
                    .foregroundStyle(ChattyTheme.accent).background(ChattyTheme.accent.opacity(0.12), in: Circle())
                    .frame(minWidth: 44, minHeight: 44)
            }.accessibilityLabel("个人与设置").accessibilityIdentifier("profile.open")
        }
    }
    private func discuss(_ issue: Issue) {
        linked = nil
        model.chat.prepareIssueDiscussion(issue)
        tab = .chat
    }

}
