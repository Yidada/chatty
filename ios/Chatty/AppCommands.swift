import SwiftUI

/// Scene-level command bus for the menu bar and hardware-keyboard shortcuts.
///
/// `Commands` only owns the menu; the visible screens register the concrete
/// actions, so no menu item can act on a model the user is not looking at. That
/// keeps ⌘↩ / ⌘F meaningful on iPad without giving the app a second state tree.
@MainActor
final class AppCommandCenter: ObservableObject {
    @Published var hasWorkspace = false
    @Published var canSend = false
    /// Bumped by ⌘F; the visible issues list focuses its search field.
    @Published var issueSearchRequest = 0

    var newSession: (() -> Void)?
    var send: (() -> Void)?
    var focusComposer: (() -> Void)?
    var focusIssueSearch: (() -> Void)?
    var selectTab: ((AppTab) -> Void)?
    var refresh: (() -> Void)?
    var openSettings: (() -> Void)?
    var cancel: (() -> Void)?

    /// Called when the workspace shell leaves the hierarchy (sign-out, switch
    /// workspace) so stale closures cannot fire against an invalidated model.
    func clearWorkspaceCommands() {
        hasWorkspace = false
        canSend = false
        newSession = nil; send = nil; focusComposer = nil; focusIssueSearch = nil
        selectTab = nil; refresh = nil; openSettings = nil; cancel = nil
    }
}

struct ChattyCommands: Commands {
    @ObservedObject var center: AppCommandCenter

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("新建 Mika 会话") { center.newSession?() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(center.newSession == nil)
        }
        CommandGroup(replacing: .appSettings) {
            Button("设置…") { center.openSettings?() }
                .keyboardShortcut(",", modifiers: .command)
                .disabled(center.openSettings == nil)
        }
        CommandMenu("对话") {
            Button("发送") { center.send?() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!center.canSend)
            Button("聚焦输入框") { center.focusComposer?() }
                .disabled(center.focusComposer == nil)
            Button("搜索事项") { center.focusIssueSearch?() }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(center.focusIssueSearch == nil)
            Divider()
            Button("取消") { center.cancel?() }
                .keyboardShortcut(.cancelAction)
                .disabled(center.cancel == nil)
        }
        CommandMenu("视图") {
            Button("动态") { center.selectTab?(.activity) }
                .keyboardShortcut("1", modifiers: .command)
                .disabled(center.selectTab == nil)
            Button("Mika") { center.selectTab?(.chat) }
                .keyboardShortcut("2", modifiers: .command)
                .disabled(center.selectTab == nil)
            Button("项目") { center.selectTab?(.projects) }
                .keyboardShortcut("3", modifiers: .command)
                .disabled(center.selectTab == nil)
            Divider()
            Button("刷新") { center.refresh?() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(center.refresh == nil)
        }
    }
}
