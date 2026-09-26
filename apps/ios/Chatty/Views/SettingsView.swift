import SwiftUI

/// 设置页：Runner 配对、Agent 管理。
struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var isPairingAlertPresented = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Runner") {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(store.runner.isConnected ? Color.green : Color.gray)
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.runner.name)
                            Text("\(store.runner.address) · Tailscale")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(store.runner.isConnected ? "已配对" : "未连接")
                            .font(.caption)
                            .foregroundStyle(store.runner.isConnected ? .green : .secondary)
                    }
                    Button {
                        isPairingAlertPresented = true
                    } label: {
                        Label("扫码配对新 Runner", systemImage: "qrcode.viewfinder")
                    }
                }

                Section {
                    ForEach(store.agents) { agent in
                        NavigationLink {
                            AgentEditorView(agentID: agent.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(agent.name)
                                Text("\(store.engineLabel(harnessID: agent.harnessID, modelID: agent.modelID)) · \(agent.repo)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { store.deleteAgents(at: $0) }

                    Button {
                        _ = store.addAgent()
                    } label: {
                        Label("新建 Agent", systemImage: "plus")
                    }
                } header: {
                    Text("Agents")
                } footer: {
                    Text("Agent = Harness + Model + Context，三项独立选择。")
                }

                Section("关于") {
                    LabeledContent("版本", value: Self.versionText)
                    Text("当前为 UI 原型，所有数据都是演示数据，尚未连接真实 Runner。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("扫码配对", isPresented: $isPairingAlertPresented) {
                Button("好", role: .cancel) {}
            } message: {
                Text("原型阶段暂不支持扫码。Runner 完成后，在 Runner 终端运行 chatty-runner pair 显示二维码。")
            }
        }
    }

    private static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}

/// 编辑 Agent：Harness、Model、Context 三项独立选择。
struct AgentEditorView: View {
    @Environment(AppStore.self) private var store
    let agentID: UUID

    var body: some View {
        @Bindable var store = store
        if let index = store.agents.firstIndex(where: { $0.id == agentID }) {
            let harnessID = store.agents[index].harnessID
            Form {
                Section("名称") {
                    TextField("名称", text: $store.agents[index].name)
                }
                Section {
                    Picker("Harness", selection: $store.agents[index].harnessID) {
                        ForEach(store.harnesses.filter(\.isAvailable)) { harness in
                            Text(harness.name).tag(harness.id)
                        }
                    }
                    Picker("Model", selection: $store.agents[index].modelID) {
                        ForEach(store.harness(harnessID)?.models ?? []) { model in
                            Text(model.name).tag(model.id)
                        }
                    }
                    Picker("Context", selection: $store.agents[index].repo) {
                        ForEach(store.repos, id: \.self) { repo in
                            Text(repo).tag(repo)
                        }
                    }
                } footer: {
                    Text("切换 Harness 后，Model 只列出该 Harness 支持的模型。")
                }
            }
            .navigationTitle(store.agents[index].name)
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: harnessID) {
                resetModelIfNeeded(agentID: agentID, harnessID: harnessID)
            }
        } else {
            ContentUnavailableView("Agent 已删除", systemImage: "trash")
        }
    }

    /// 切换 Harness 后，如果原模型不属于新 Harness，改为新 Harness 的默认模型
    private func resetModelIfNeeded(agentID: UUID, harnessID: String) {
        guard let index = store.agents.firstIndex(where: { $0.id == agentID }) else { return }
        let harness = store.harness(harnessID)
        if harness?.model(store.agents[index].modelID) == nil {
            store.agents[index].modelID = harness?.defaultModelID ?? ""
        }
    }
}
