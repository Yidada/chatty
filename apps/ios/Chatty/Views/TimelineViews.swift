import SwiftUI

/// 时间线中的一行。用户消息用气泡，Agent 回复全宽纯文本（参考 ChatGPT / Claude）。
struct TimelineRow: View {
    let item: TimelineItem
    let openDiff: ([FileChange]) -> Void

    var body: some View {
        switch item.kind {
        case .user:
            HStack {
                Spacer(minLength: 48)
                Text(item.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
            }
        case .agent:
            Text(item.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        case .tools:
            ToolGroupRow(item: item)
        case .changes:
            ChangesCard(files: item.changes) { openDiff(item.changes) }
        case .notice:
            Text(item.text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground), in: Capsule())
                .frame(maxWidth: .infinity)
        }
    }
}

/// 多次工具调用合并成一行，点开查看每一步（参考 Claude）
struct ToolGroupRow: View {
    let item: TimelineItem
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    if item.isRunning {
                        ProgressView()
                            .controlSize(.mini)
                        Text(item.steps.last.map { "正在执行 · \($0.title)" } ?? "正在执行…")
                    } else {
                        Image(systemName: "checkmark.circle")
                        Text("执行了 \(item.steps.count) 个操作")
                    }
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2.weight(.semibold))
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(item.steps) { step in
                        Label(step.title, systemImage: step.icon)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 4)
                .transition(.opacity)
            }
        }
    }
}

/// 每轮结束的改动卡片（参考 Codex）
struct ChangesCard: View {
    let files: [FileChange]
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(files.count) 个文件已修改")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        Text("+\(files.reduce(0) { $0 + $1.added })")
                            .foregroundStyle(.green)
                        Text("−\(files.reduce(0) { $0 + $1.removed })")
                            .foregroundStyle(.red)
                    }
                    .font(.footnote.monospacedDigit())
                }
                Spacer()
                Text("查看")
                    .font(.footnote)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color(.separator))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
