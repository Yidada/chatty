import SwiftUI
import ChattyCore
import ChattyFixtureSupport

struct FixtureChatView: View {
    let snapshot: FixtureSnapshot

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                Text("已读取 \(snapshot.messages.messages.count) 条合成消息")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(snapshot.messages.messages) { message in
                    if message.role == "user" {
                        HStack {
                            Spacer(minLength: 36)
                            Text(message.content ?? "")
                                .padding(14)
                                .background(ChattyTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            MarkdownView(source: message.content ?? "")
                            ForEach(message.attachments ?? []) { file in
                                Label(file.filename, systemImage: "doc.text")
                                    .font(.callout).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .defaultScrollAnchor(.bottom)
        .accessibilityIdentifier("chat.messages")
        .background(ChattyTheme.background)
        .safeAreaInset(edge: .bottom) {
            Label("只读预览", systemImage: "eye")
                .font(.callout).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity).padding(14)
                .background(ChattyTheme.surface, in: Capsule())
                .padding(.horizontal, 20).padding(.vertical, 8)
                .accessibilityIdentifier("chat.readonly")
        }
    }
}

struct MarkdownView: View {
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(MarkdownContent.blocks(source).enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .textSelection(.enabled)
    }

    @ViewBuilder private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(text).font(level == 1 ? .title2.bold() : .headline)
        case .paragraph(let text):
            Text(verbatim: text).font(.body)
        case .code(let language, let content):
            VStack(alignment: .leading, spacing: 8) {
                if let language { Text(language).font(.caption).foregroundStyle(.secondary) }
                ScrollView(.horizontal) {
                    Text(verbatim: content.trimmingCharacters(in: .newlines))
                        .font(.system(.callout, design: .monospaced)).fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(14).background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        case .table(let headers, let rows):
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 10) {
                    GridRow { ForEach(Array(headers.enumerated()), id: \.offset) { _, value in Text(value).bold() } }
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        GridRow { ForEach(Array(row.enumerated()), id: \.offset) { _, value in Text(value) } }
                    }
                }
                .padding(14).frame(minWidth: 220, alignment: .leading)
                .background(ChattyTheme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityIdentifier("markdown.table")
        case .listItem(let text, let checked):
            Label(text, systemImage: checked.map { $0 ? "checkmark.square" : "square" } ?? "circle.fill")
        case .quote(let text):
            HStack { Rectangle().fill(ChattyTheme.accent).frame(width: 3); Text(text).foregroundStyle(.secondary) }
        case .literal(let text):
            Text(verbatim: text).font(.system(.callout, design: .monospaced))
        }
    }
}
