import SwiftUI
import ChattyCore

private enum ResourcePage: String, CaseIterable, Hashable {
    case runtimes = "Runtimes", agents = "Agents", squads = "Squads"
    var symbol: String { switch self { case .runtimes: "desktopcomputer"; case .agents: "sparkles"; case .squads: "person.3" } }
}

struct SettingsScreen: View {
    let session: SessionModel
    let resources: ResourcesModel
    let context: WorkspaceContext
    @State private var signOut = false
    @State private var switching = false
    var body: some View {
        List {
            Section("当前工作区") {
                Label(context.workspace.name, systemImage: "building.2").padding(.vertical, 8).accessibilityIdentifier("settings.workspace")
                Button("切换工作区", systemImage: "arrow.left.arrow.right") { switching = true }.frame(minHeight: 44).accessibilityIdentifier("settings.workspaces")
            }
            Section("运行与协作") {
                ForEach(ResourcePage.allCases, id: \.self) { page in
                    NavigationLink(value: page) { Label(page.rawValue, systemImage: page.symbol).padding(.vertical, 8) }
                        .accessibilityIdentifier("settings.\(page.rawValue.lowercased())")
                }
            }
            Section("账户") {
                if let email = context.user.email { Text(email).foregroundStyle(.secondary) }
                Button("退出登录", role: .destructive) { signOut = true }.frame(minHeight: 44).accessibilityIdentifier("settings.signOut")
            }
            Section { Text("重新打开应用后，会同步最新消息和执行进度。").font(.footnote).foregroundStyle(.secondary) }
        }
        .navigationTitle("设置").scrollContentBackground(.hidden).background(ChattyTheme.background)
        .navigationDestination(for: ResourcePage.self) { page in ResourceListScreen(page: page, model: resources) }
        .sheet(isPresented: $switching) {
            NavigationStack {
                List {
                    ForEach(session.workspaces) { workspace in
                        Button { session.select(workspace); switching = false } label: {
                            HStack { Text(workspace.name); Spacer(); if workspace.id == context.workspace.id { Image(systemName: "checkmark") } }.frame(minHeight: 44)
                        }.accessibilityIdentifier("workspace.\(workspace.id)")
                    }
                    if let error = session.error { ErrorNotice(text: error) }
                }.navigationTitle("切换工作区").refreshable { await session.loadAccount() }
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { switching = false } } }
            }
        }
        .confirmationDialog("退出后会清除此设备的登录、草稿和临时附件。", isPresented: $signOut, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) { session.signOut() }
            Button("取消", role: .cancel) {}
        }
    }
}

private struct ResourceListScreen: View {
    let page: ResourcePage
    let model: ResourcesModel
    var body: some View {
        List {
            if model.loading { ProgressView("读取资源…") }
            if let error = model.error { ErrorNotice(text: error, identifier: "resources.error") }
            switch page {
            case .runtimes:
                ForEach(model.runtimes) { runtime in
                    NavigationLink { ResourceDetails(title: runtime.displayName, symbol: "desktopcomputer", fields: [("状态", DisplayText.status(runtime.status ?? "offline")), ("设备", runtime.deviceInfo), ("运行方式", runtime.runtimeMode), ("提供方", runtime.provider), ("最近在线", runtime.lastSeenAt)]) } label: {
                        ResourceRow(name: runtime.displayName, subtitle: runtime.deviceInfo ?? "", status: DisplayText.status(runtime.status ?? "offline"), symbol: "desktopcomputer")
                    }.accessibilityIdentifier("runtime.\(runtime.id)")
                }
                if model.runtimes.isEmpty && !model.loading { empty }
            case .agents:
                ForEach(model.agents) { agent in
                    NavigationLink { ResourceDetails(title: agent.name, symbol: "sparkles", fields: [("身份", agent.systemKey == "mika" ? "Mika" : "Agent"), ("状态", DisplayText.status(agent.status ?? "offline")), ("可见范围", agent.permissionMode ?? "private"), ("Runtime", model.runtimes.first(where: { $0.id == agent.runtimeId })?.displayName ?? agent.runtimeId)]) } label: {
                        ResourceRow(name: agent.name, subtitle: agent.systemKey == "mika" ? "Mika" : "Agent", status: DisplayText.status(agent.status ?? "offline"), symbol: "sparkles")
                    }.accessibilityIdentifier("agent.\(agent.id)")
                }
                if model.agents.isEmpty && !model.loading { empty }
            case .squads:
                ForEach(model.squads) { squad in
                    NavigationLink { ResourceDetails(title: squad.name, symbol: "person.3", fields: [("成员", squad.memberCount.map { "\($0) 位" }), ("负责人", model.agents.first(where: { $0.id == squad.leaderId })?.name ?? squad.leaderId), ("描述", squad.description)]) } label: {
                        ResourceRow(name: squad.name, subtitle: squad.description ?? "", status: squad.memberCount.map { "\($0) 位成员" } ?? "", symbol: "person.3")
                    }.accessibilityIdentifier("squad.\(squad.id)")
                }
                if model.squads.isEmpty && !model.loading { empty }
            }
        }
        .navigationTitle(page.rawValue).scrollContentBackground(.hidden).background(ChattyTheme.background)
        .task { await model.refresh() }.refreshable { await model.refresh() }
        .onForegroundRefresh { await model.refresh() }
        .toolbar { Button("刷新", systemImage: "arrow.clockwise") { Task { await model.refresh() } }.accessibilityIdentifier("resources.refresh") }
    }
    private var empty: some View { ContentUnavailableView("暂无可见资源", systemImage: page.symbol, description: Text("当前工作区没有返回可查看的资源。")) }
}

private struct ResourceRow: View {
    let name: String
    let subtitle: String
    let status: String
    let symbol: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.title3).foregroundStyle(ChattyTheme.accent)
            VStack(alignment: .leading, spacing: 8) {
                Text(name).font(.headline)
                if !subtitle.isEmpty { Text(subtitle).font(.callout).foregroundStyle(.secondary).lineLimit(3) }
                if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary) }
            }
        }.padding(.vertical, 10)
    }
}

private struct ResourceDetails: View {
    let title: String
    let symbol: String
    let fields: [(String, String?)]
    var body: some View {
        List {
            Section { Label(title, systemImage: symbol).font(.title3.bold()).padding(.vertical, 12).accessibilityElement(children: .combine).accessibilityLabel(title).accessibilityIdentifier("resource.details.title") }
            Section {
                ForEach(Array(fields.enumerated()), id: \.offset) { _, field in
                    if let value = field.1, !value.isEmpty { VStack(alignment: .leading, spacing: 8) { Text(field.0).font(.caption).foregroundStyle(.secondary); Text(verbatim: value).textSelection(.enabled) }.padding(.vertical, 6) }
                }
            }
        }.navigationTitle(title).scrollContentBackground(.hidden).background(ChattyTheme.background)
    }
}
