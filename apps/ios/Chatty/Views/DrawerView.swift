import SwiftUI

/// 侧边抽屉：搜索、按仓库分组的会话列表、Runner 状态、设置入口（参考 ChatGPT / DeepSeek / Happy）。
struct DrawerView: View {
    @Environment(AppStore.self) private var store
    let close: () -> Void

    @State private var query = ""
    @State private var isSettingsPresented = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索", text: $query)
            }
            .padding(10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Button {
                store.startNewSession()
                close()
            } label: {
                Label("新会话", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            List {
                ForEach(store.groupedSessions(matching: query)) { group in
                    Section {
                        ForEach(group.sessions) { session in
                            SessionRow(session: session)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    store.select(session.id)
                                    close()
                                }
                                .listRowBackground(
                                    session.id == store.currentSessionID
                                        ? Color(.secondarySystemBackground)
                                        : Color.clear
                                )
                                .swipeActions {
                                    Button(role: .destructive) {
                                        store.delete(session.id)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Text(group.repo)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            Divider()

            RunnerCard(runner: store.runner, runningCount: store.runningCount)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            Button {
                isSettingsPresented = true
            } label: {
                HStack {
                    Label("设置", systemImage: "gearshape")
                    Spacer()
                    Text("Agent 管理 · Runner 配对")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground))
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
        }
    }
}

private struct SessionRow: View {
    @Environment(AppStore.self) private var store
    let session: ChatSession

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .lineLimit(1)
                Text(store.engineLabel(harnessID: session.harnessID, modelID: session.modelID))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            statusText
        }
        .padding(.vertical, 2)
    }

    private var dotColor: Color {
        switch session.state {
        case .idle: .clear
        case .running: .blue
        case .awaitingApproval: .orange
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch session.state {
        case .running:
            Text("运行中").font(.caption).foregroundStyle(.blue)
        case .awaitingApproval:
            Text("待审批").font(.caption).foregroundStyle(.orange)
        case .idle:
            Text(session.updatedAt, format: .relative(presentation: .named))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

private struct RunnerCard: View {
    let runner: RunnerInfo
    let runningCount: Int

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(runner.isConnected ? Color.green : Color.gray)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(runner.name)
                    .font(.subheadline.weight(.medium))
                Text(runner.isConnected ? "已连接 · \(runningCount) 个会话进行中" : "未连接")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
