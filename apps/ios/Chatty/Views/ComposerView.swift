import SwiftUI

/// 底部输入框。下方一排状态 chip（参考 Happy），运行中发送键变为停止键（参考 ChatGPT）。
struct ComposerView: View {
    @Environment(AppStore.self) private var store
    @FocusState private var isFocused: Bool

    var body: some View {
        @Bindable var store = store
        let isRunning = store.currentSession.map { $0.state != .idle } ?? false
        let repo = store.currentSession?.repo ?? store.draftAgent?.repo ?? "—"

        VStack(alignment: .leading, spacing: 10) {
            TextField("给 Agent 发消息", text: $store.draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($isFocused)

            HStack(spacing: 8) {
                ChipLabel(icon: "arrow.triangle.branch", text: repo)

                Menu {
                    Picker("权限模式", selection: $store.permissionMode) {
                        ForEach(PermissionMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                } label: {
                    ChipLabel(icon: "hand.raised", text: store.permissionMode.title)
                }

                Spacer()

                if isRunning {
                    Button {
                        store.stop()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.footnote)
                            .frame(width: 34, height: 34)
                            .background(Color(.label), in: Circle())
                            .foregroundStyle(Color(.systemBackground))
                    }
                    .accessibilityLabel("停止")
                } else {
                    let isEmpty = store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    Button {
                        store.send()
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.body.weight(.semibold))
                            .frame(width: 34, height: 34)
                            .background(isEmpty ? Color(.systemGray4) : Color(.label), in: Circle())
                            .foregroundStyle(Color(.systemBackground))
                    }
                    .disabled(isEmpty)
                    .accessibilityLabel("发送")
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color(.separator).opacity(0.6))
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

struct ChipLabel: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground), in: Capsule())
    }
}
