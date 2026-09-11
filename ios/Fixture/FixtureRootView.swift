import SwiftUI
import ChattyCore
import ChattyFixtureSupport

struct FixtureRootView: View {
    @State private var tab: AppTab = .chat
    @State private var model = FixtureModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "flask")
                Text("测试工作区 · 合成数据")
            }
            .font(.caption)
            .foregroundStyle(ChattyTheme.accent)
            .padding(.vertical, 6)
            .accessibilityIdentifier("fixture.banner")
            if let error = model.error {
                HStack(alignment: .top) {
                    Text(error).font(.callout).accessibilityIdentifier("fixture.error")
                    Spacer()
                    Button("重试") { Task { await model.reload() } }
                        .accessibilityIdentifier("fixture.retry")
                        .disabled(model.isLoading)
                }
                .padding(14)
                .background(.orange.opacity(0.12))
            }
            TabView(selection: $tab) {
                Tab("对话", systemImage: "bubble.left.and.bubble.right", value: .chat) {
                    NavigationStack {
                        if let snapshot = model.snapshot {
                            FixtureChatView(snapshot: snapshot)
                                .navigationTitle("Mika")
                                .toolbar { refresh }
                        } else { loading(title: "Mika") }
                    }
                    .accessibilityIdentifier("tab.chat")
                }
                Tab("项目", systemImage: "folder", value: .projects) {
                    NavigationStack {
                        if let snapshot = model.snapshot {
                            FixtureProjectsView(projects: snapshot.projects.projects)
                                .navigationTitle("项目")
                                .toolbar { refresh }
                        } else { loading(title: "项目") }
                    }
                    .accessibilityIdentifier("tab.projects")
                }
                Tab("设置", systemImage: "gearshape", value: .settings) {
                    NavigationStack {
                        if let snapshot = model.snapshot {
                            FixtureSettingsView(snapshot: snapshot)
                                .navigationTitle("设置")
                                .toolbar { refresh }
                        } else { loading(title: "设置") }
                    }
                    .accessibilityIdentifier("tab.settings")
                }
            }
            .tabViewStyle(.sidebarAdaptable)
        }
        .background(ChattyTheme.background)
        .tint(ChattyTheme.accent)
        .task { await model.loadIfNeeded() }
    }

    @ToolbarContentBuilder private var refresh: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("刷新", systemImage: "arrow.clockwise") { Task { await model.reload() } }
                .accessibilityIdentifier("fixture.refresh")
                .disabled(model.isLoading)
        }
    }

    private func loading(title: String) -> some View {
        Group {
            if model.isLoading { ProgressView("正在读取测试数据…") }
            else { ContentUnavailableView("尚无测试数据", systemImage: "network") }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(title)
        .background(ChattyTheme.background)
    }
}
