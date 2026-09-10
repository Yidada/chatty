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
        TabView(selection: $tab) {
            Tab("动态", systemImage: "waveform.path", value: .activity) {
                NavigationStack {
                    ActivityScreen(model: model.activity, projects: model.projects, context: model.context, discuss: discuss)
                        .toolbar { profileButton }
                }
            }.badge(model.activity.hasAttention ? Text(" ") : nil)
            Tab("Mika", systemImage: "sparkles", value: .chat) {
                NavigationStack { ChatScreen(model: model.chat, context: model.context).toolbar { profileButton } }
            }
            Tab("项目", systemImage: "folder", value: .projects) {
                NavigationStack {
                    ProjectsScreen(model: model.projects, context: model.context, onViewed: model.activity.markRead, onChanged: model.activity.apply, discuss: discuss)
                        .toolbar { profileButton }
                }
            }
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
            }
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
            }
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
        ToolbarItem(placement: .topBarTrailing) {
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
