import SwiftUI
import ChattyCore

/// Conversation history. DeepSeek calls this the 「历史对话侧边栏」 and opens it
/// from the top-left icon; on iPhone it is an overlay, so this is a full-height
/// sheet. Rows are plain selection rows: the server exposes no write path for
/// renaming, pinning or deleting a conversation, so there is no long-press menu
/// (spec §4.2, decisions D7). Pinned conversations still sort to the top because
/// the server reports the flag.
struct ChatHistoryView: View {
    let model: ChatModel
    let close: () -> Void
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    private var rows: [ChatSession] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return model.sessions }
        return model.sessions.filter { session in
            let title = (session.title ?? "").lowercased()
            let preview = (session.lastMessage?.content ?? "").lowercased()
            return title.contains(needle) || preview.contains(needle)
        }
    }

    var body: some View {
        Group {
            if model.sessions.isEmpty {
                ContentUnavailableView("还没有历史对话", systemImage: "bubble.left.and.bubble.right",
                                       description: Text("和 Mika 说点什么，对话会出现在这里。"))
            } else if rows.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List(rows) { session in
                    Button { open(session) } label: { row(session) }
                        .buttonStyle(.plain)
                        .listRowBackground(ChattyTheme.background)
                        .accessibilityIdentifier("history.row.\(session.id)")
                }
                .listStyle(.plain)
                .accessibilityIdentifier("history.list")
            }
        }
        .background(ChattyTheme.background)
        .searchable(text: $query, prompt: "搜索聊天内容")
        .refreshable { await model.refresh() }
        .navigationTitle("历史对话")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("关闭") { close() }.accessibilityIdentifier("history.close")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.startNewSession(); close() } label: { Label("新建对话", systemImage: "plus.bubble") }
                    .accessibilityIdentifier("history.newSession")
            }
        }
    }

    private func open(_ session: ChatSession) {
        Task { await model.open(session) }
        close()
    }

    private func row(_ session: ChatSession) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(ChatSessions.displayTitle(session.title, firstUserMessage: session.lastMessage?.content))
                        .font(.body.weight(session.id == model.session?.id ? .semibold : .regular))
                        .lineLimit(1)
                    if (session.unreadCount ?? 0) > 0 {
                        Circle().fill(ChattyTheme.accent).frame(width: 7, height: 7)
                            .accessibilityLabel("有未读消息")
                    }
                }
                if let preview = session.lastMessage?.content, !preview.isEmpty {
                    Text(session.lastMessage?.role == "user" ? "你：\(preview)" : preview)
                        .font(.caption).foregroundStyle(ChattyTheme.textSecondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                Text(ChatHistoryView.timestamp(session.updatedAt)).font(.caption).foregroundStyle(ChattyTheme.textSecondary)
                if session.id == model.session?.id {
                    Image(systemName: "checkmark").font(.caption.weight(.semibold)).foregroundStyle(ChattyTheme.accent)
                }
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    /// Today shows a clock time, this week a weekday, older a date — the same
    /// escalation a compact history list needs to stay scannable.
    static func timestamp(_ value: String?) -> String {
        guard let value, let date = parse(value) else { return "" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return date.formatted(date: .omitted, time: .shortened) }
        if calendar.isDateInYesterday(date) { return "昨天" }
        if let days = calendar.dateComponents([.day], from: date, to: Date()).day, days < 7 {
            return date.formatted(.dateTime.weekday(.abbreviated))
        }
        return date.formatted(.dateTime.month(.defaultDigits).day())
    }
    private static func parse(_ value: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withFraction.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}
