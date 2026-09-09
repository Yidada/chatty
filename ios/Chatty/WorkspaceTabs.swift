import SwiftUI
import ChattyCore

enum LinkedScreen: Identifiable {
    case issue(String), project(String), attachment(String)
    var id: String { switch self { case .issue(let id): "issue-" + id; case .project(let id): "project-" + id; case .attachment(let id): "attachment-" + id } }
}

struct WorkspaceTabs: View {
    let model: WorkspaceModel
    let session: SessionModel
    @State private var tab: AppTab = .chat
    @State private var linked: LinkedScreen?
    @State private var linkNotice = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $tab) {
            Tab("对话", systemImage: "bubble.left.and.bubble.right", value: .chat) {
                NavigationStack { ChatScreen(model: model.chat, context: model.context) }
            }
            Tab("项目", systemImage: "folder", value: .projects) {
                NavigationStack { ProjectsScreen(model: model.projects, context: model.context) }
            }
            Tab("设置", systemImage: "gearshape", value: .settings) {
                NavigationStack { SettingsScreen(session: session, resources: model.resources, context: model.context) }
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
        .sheet(item: $linked) { destination in
            NavigationStack {
                Group {
                    switch destination {
                    case .attachment(let id): LinkedAttachmentScreen(id: id, context: model.context)
                    case .issue(let id): IssueScreen(model: model.projects, context: model.context, issueId: id)
                    case .project(let id): IssuesScreen(model: model.projects, context: model.context, projectId: id, title: "项目 Issues")
                    }
                }.toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { linked = nil } } }
            }
        }
        .alert("此链接暂不支持在当前页面打开", isPresented: $linkNotice) { Button("知道了", role: .cancel) {} } message: { Text("请从项目或设置中查看对应资源。") }
        .task {
            await model.chat.initialize()
            session.rememberDraftScope(model)
            if scenePhase == .active { model.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.start() } else { model.pause() }
        }
        .onDisappear { model.pause() }
    }
}
