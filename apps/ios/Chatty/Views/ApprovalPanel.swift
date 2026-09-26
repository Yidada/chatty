import SwiftUI

/// 底部审批面板。Agent 等待审批时暂时替代输入框（参考 Omnara / Happy）。
struct ApprovalPanel: View {
    @Environment(AppStore.self) private var store
    let session: ChatSession
    let approval: ApprovalRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                "\(store.harness(session.harnessID)?.name ?? "Agent") \(approval.title)",
                systemImage: "exclamationmark.shield"
            )
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.orange)

            Text(approval.command)
                .font(.system(.callout, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 10) {
                Button {
                    store.respond(.reject)
                } label: {
                    Text("拒绝").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    store.respond(.approve)
                } label: {
                    Text("同意").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)

            HStack(spacing: 6) {
                Button("本次会话都允许") { store.respond(.approveForSession) }
                Text("·")
                Button("拒绝并说明") { store.respond(.rejectWithNote) }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.orange.opacity(0.08))
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 22))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.orange.opacity(0.5))
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}
