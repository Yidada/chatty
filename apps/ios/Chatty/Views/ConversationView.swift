import SwiftUI

/// 会话页：新会话空状态、时间线、底部输入框或审批面板。
struct ConversationView: View {
    @Environment(AppStore.self) private var store
    let openDrawer: () -> Void

    @State private var isSwitchPanelPresented = false
    @State private var diffFiles: DiffPayload?

    var body: some View {
        Group {
            if let session = store.currentSession {
                timeline(session)
            } else {
                EmptyStateView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            if let session = store.currentSession, let approval = session.approval {
                ApprovalPanel(session: session, approval: approval)
            } else {
                ComposerView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: openDrawer) {
                    Image(systemName: "line.3.horizontal")
                }
                .accessibilityLabel("会话列表")
            }
            ToolbarItem(placement: .principal) {
                titleView
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.startNewSession()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("新会话")
            }
        }
        .sheet(isPresented: $isSwitchPanelPresented) {
            SwitchPanel()
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $diffFiles) { payload in
            DiffSheet(files: payload.files)
        }
    }

    @ViewBuilder
    private var titleView: some View {
        if let session = store.currentSession {
            Button {
                isSwitchPanelPresented = true
            } label: {
                VStack(spacing: 1) {
                    HStack(spacing: 4) {
                        Text(store.engineLabel(harnessID: session.harnessID, modelID: session.modelID))
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                    }
                    Text("\(session.repo) · \(session.branch)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .accessibilityHint("切换引擎与模型")
        } else {
            Menu {
                ForEach(store.agents) { agent in
                    Button {
                        store.draftAgentID = agent.id
                    } label: {
                        if agent.id == store.draftAgent?.id {
                            Label(agent.name, systemImage: "checkmark")
                        } else {
                            Text(agent.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(store.draftAgent?.name ?? "选择 Agent")
                        .font(.headline)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(.primary)
            }
        }
    }

    private func timeline(_ session: ChatSession) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(session.items) { item in
                        TimelineRow(item: item) { files in
                            diffFiles = DiffPayload(files: files)
                        }
                        .id(item.id)
                    }
                    Color.clear
                        .frame(height: 1)
                        .id(Self.bottomID)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                proxy.scrollTo(Self.bottomID, anchor: .bottom)
            }
            .onChange(of: store.timelineRevision) {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(Self.bottomID, anchor: .bottom)
                }
            }
        }
    }

    private static let bottomID = "timeline-bottom"
}

struct DiffPayload: Identifiable {
    let id = UUID()
    let files: [FileChange]
}

/// 新会话空状态（参考 ChatGPT / Claude）
private struct EmptyStateView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 8) {
                Text("今天要做什么？")
                    .font(.title2.weight(.semibold))
                if let agent = store.draftAgent {
                    Text("\(store.engineLabel(harnessID: agent.harnessID, modelID: agent.modelID)) · \(agent.repo)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(spacing: 8) {
                ForEach(DemoData.suggestions(), id: \.self) { suggestion in
                    Button {
                        store.send(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
}
