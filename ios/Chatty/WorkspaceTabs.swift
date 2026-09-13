import SwiftUI
import ChattyCore

enum LinkedScreen: Identifiable {
    case issue(String), project(String), attachment(String)
    var id: String { switch self { case .issue(let id): "issue-" + id; case .project(let id): "project-" + id; case .attachment(let id): "attachment-" + id } }
}

struct WorkspaceTabs: View {
    let model: WorkspaceModel
    let session: SessionModel
    var route: AppRoute?

    // Per-window scene state. Two windows keep independent selections, and the
    // system restores them when the window comes back after the app is killed
    // (`@SceneStorage` is not enough: a force quit loses it, and the restored
    // window would otherwise re-apply the tab it was originally opened with).
    @State private var storedTab = AppTab.activity.rawValue
    @State private var restoredTab = false
    @State private var showingSettings = false
    @State private var linked: LinkedScreen?
    @State private var linkNotice = false
    @State private var activity = SceneActivityMonitor.shared
    @Environment(\.openWindow) private var openWindow
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    // Stage B: the menu bar is process-wide, so the window that is on screen
    // registers the concrete actions for it.
    @EnvironmentObject private var commands: AppCommandCenter

    /// Identity of this window for restoration purposes. A window opened through
    /// `openWindow` carries its own route token; the first window uses "default".
    private var sceneKey: String { route?.token.uuidString ?? "default" }

    private var tab: Binding<AppTab> {
        Binding(get: { AppTab(rawValue: storedTab) ?? .activity }, set: { storedTab = $0.rawValue })
    }

    var body: some View {
        tabShell
            // spec §5「深链资源 Sheet = 改」：常规宽度改为 popover，紧凑宽度保持
            // 原有 Sheet；`NativeLink` 的解析逻辑不变。
            .modifier(LinkedScreenPresentation(linked: $linked, usesPopover: horizontalSizeClass == .regular) { destination in
                linkedScreen(destination)
            })
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    SettingsScreen(session: session, resources: model.resources, context: model.context)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { showingSettings = false }.accessibilityIdentifier("settings.close") } }
                }
            }
            .alert("此链接暂不支持在当前页面打开", isPresented: $linkNotice) { Button("知道了", role: .cancel) {} } message: { Text("请从项目或设置中查看对应资源。") }
            .task {
                activity.start()
                restoreTab()
                commands.registerWorkspaceWindow()
                registerCommands()
                if activity.shouldKeepRunning { model.start() }
                await model.chat.initialize()
                session.rememberDraftScope(model)
            }
            .onChange(of: storedTab) { _, value in persistTab(value) }
            // Scene driven, not view driven: with several windows the shared poller
            // and socket must stop only when the last window goes away (and not for
            // the instant between two windows swapping).
            .onChange(of: activity.shouldKeepRunning) { _, run in
                if run { model.start() } else { model.pause() }
            }
            // Sign-out and workspace switches still clear the menu; closing one of
            // several windows does not, because the others are still using it.
            .onDisappear { commands.unregisterWorkspaceWindow() }
    }

    private var tabShell: some View {
        TabView(selection: tab) {
            Tab("动态", systemImage: "waveform.path", value: AppTab.activity) {
                NavigationStack {
                    ActivityScreen(model: model.activity, projects: model.projects, context: model.context, discuss: discuss)
                        .toolbar { profileButton }
                }
            }.badge(model.activity.hasAttention ? Text(" ") : nil)
            Tab("Mika", systemImage: "sparkles", value: AppTab.chat) {
                NavigationStack {
                    ChatScreen(model: model.chat, context: model.context)
                        .toolbar { profileButton; if horizontalSizeClass == .regular { newWindowButton } }
                }
            }
            Tab("项目", systemImage: "folder", value: AppTab.projects) {
                NavigationStack {
                    ProjectsScreen(model: model.projects, context: model.context, onViewed: model.activity.markRead, onChanged: model.activity.apply, discuss: discuss)
                        .toolbar { profileButton; newWindowButton }
                }
            }
        }
        .tabViewStyle(.tabBarOnly)
        .environment(\.openURL, OpenURLAction { url in
            switch NativeLink.resolve(url.absoluteString, api: model.context.api.baseURL, workspace: model.context.workspace.slug) {
            case .issue(let id): linked = .issue(id); return .handled
            case .project(let id): linked = .project(id); return .handled
            case .attachment(let id): linked = .attachment(id); return .handled
            case .external(let url): return .systemAction(url)
            default: linkNotice = true; return .handled
            }
        })
    }

    /// Content of a deep-linked resource. Shared by the regular-width popover and
    /// the compact-width sheet so both presentations stay identical.
    @ViewBuilder private func linkedScreen(_ destination: LinkedScreen) -> some View {
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

    /// The menu bar and shortcut table are scene-level. Registering here (and
    /// clearing when the last workspace window leaves) keeps every item honest
    /// about what is on screen.
    private func registerCommands() {
        commands.hasWorkspace = true
        commands.selectTab = { value in tab.wrappedValue = value }
        commands.openSettings = { showingSettings = true }
        commands.newSession = { model.chat.startNewSession(); tab.wrappedValue = .chat }
        commands.refresh = {
            Task {
                switch tab.wrappedValue {
                case .activity: await model.activity.refresh()
                case .chat: await model.chat.refresh()
                case .projects: await model.projects.overview()
                case .settings: break
                }
            }
        }
        commands.focusIssueSearch = {
            tab.wrappedValue = .projects
            commands.issueSearchRequest += 1
        }
        commands.cancel = {
            if linked != nil { linked = nil }
            else if showingSettings { showingSettings = false }
        }
    }

    /// A restored window returns to the tab the user left it on; a window just
    /// opened through `openWindow` starts on the tab it was asked for.
    private func restoreTab() {
        guard !restoredTab else { return }
        restoredTab = true
        if let saved = try? model.context.files.sceneTab(window: sceneKey), let tab = AppTab(rawValue: saved) {
            storedTab = tab.rawValue
        } else if let route {
            storedTab = route.tab.rawValue
            persistTab(storedTab)
        }
    }

    private func persistTab(_ value: String) {
        guard restoredTab else { return }
        try? model.context.files.saveSceneTab(value, window: sceneKey)
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
    private var newWindowButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("在新窗口打开", systemImage: "rectangle.badge.plus") {
                openWindow(id: AppWindow.main, value: AppRoute(tab: tab.wrappedValue))
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier("window.open")
        }
    }
    private func discuss(_ issue: Issue) {
        linked = nil
        model.chat.prepareIssueDiscussion(issue)
        storedTab = AppTab.chat.rawValue
    }

}

/// Regular width presents a deep-linked resource as a popover so the workspace
/// shell (sidebar + list) stays visible behind it; compact width — iPhone,
/// Slide Over, narrow Split View — keeps the previous full sheet, so behaviour
/// there is unchanged. A deep link has no source view to hang off, so the
/// anchor is pinned to the centre of the shell instead of the default
/// `.rect(.bounds)`, which would clamp the popover into a screen corner. The
/// explicit minimum size is required because a screen built on `ScrollView` has
/// no intrinsic popover size.
private struct LinkedScreenPresentation<Destination: View>: ViewModifier {
    @Binding var linked: LinkedScreen?
    let usesPopover: Bool
    let destination: (LinkedScreen) -> Destination

    func body(content: Content) -> some View {
        if usesPopover {
            content.popover(item: $linked, attachmentAnchor: .point(.center)) {
                destination($0).frame(minWidth: 420, minHeight: 520)
            }
        } else {
            content.sheet(item: $linked) { destination($0) }
        }
    }
}
