import SwiftUI

/// The normal app has no fixture dependency or network path in the P0 slice.
struct ShellView: View {
    @State private var tab: AppTab = .chat

    var body: some View {
        TabView(selection: $tab) {
            Tab("对话", systemImage: "bubble.left.and.bubble.right", value: .chat) {
                NavigationStack { disconnected(title: "Mika", symbol: "sparkles") }
            }
            Tab("项目", systemImage: "folder", value: .projects) {
                NavigationStack { disconnected(title: "项目", symbol: "folder") }
            }
            Tab("设置", systemImage: "gearshape", value: .settings) {
                NavigationStack { disconnected(title: "设置", symbol: "gearshape") }
            }
        }
        .tint(ChattyTheme.accent)
    }

    private func disconnected(title: String, symbol: String) -> some View {
        ContentUnavailableView("尚未连接工作区", systemImage: symbol,
                               description: Text("连接后，与你的 Mika 继续工作。"))
            .accessibilityIdentifier("app.disconnected")
            .navigationTitle(title)
            .background(ChattyTheme.background)
    }
}
