import SwiftUI
import ChattyCore
import AppKit

struct RichContentView: View {
    let source: String
    let context: WorkspaceContext
    @State private var blocks: [RichBlock] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in RichBlockView(block: block, context: context) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
        .task(id: source) {
            let value = await Task.detached(priority: .userInitiated) { RichDocument.parse(source) }.value
            guard !Task.isCancelled else { return }; blocks = value
        }
    }
}

private struct InlineText: View {
    let runs: [InlineRun]
    let context: WorkspaceContext
    var body: some View { Text(attributed).fixedSize(horizontal: false, vertical: true) }
    private var attributed: AttributedString {
        var result = AttributedString()
        for run in runs {
            var text = AttributedString(run.text)
            var font: Font = run.code ? .system(.body, design: .monospaced) : .body
            if run.bold { font = font.bold() }; if run.italic { font = font.italic() }
            text.font = font
            if run.strike { text.strikethroughStyle = .single }
            if run.code { text.backgroundColor = Color.secondary.opacity(0.12) }
            if let link = run.link, let url = URL(string: link, relativeTo: context.api.baseURL)?.absoluteURL,
               NativeLink.resolve(link, api: context.api.baseURL, workspace: context.workspace.slug) != .unavailable { text.link = url }
            result.append(text)
        }
        return result
    }
}

private struct RichBlockView: View {
    let block: RichBlock
    let context: WorkspaceContext
    var body: some View {
        switch block {
        case .heading(let level, let runs):
            Text(runs.map(\.text).joined()).font(level == 1 ? .title2.bold() : level == 2 ? .title3.bold() : .headline)
                .accessibilityAddTraits(.isHeader).fixedSize(horizontal: false, vertical: true)
        case .paragraph(let runs): InlineText(runs: runs, context: context)
        case .code(let language, let content):
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(language ?? "代码").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("复制", systemImage: "doc.on.doc") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(content, forType: .string) }
                        .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44).accessibilityLabel("复制代码")
                }
                ScrollView(.horizontal) { Text(verbatim: content.trimmingCharacters(in: .newlines)).font(.system(.callout, design: .monospaced)).fixedSize() }
            }
            .padding(14).background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        case .table(let headers, let rows):
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 12) {
                    GridRow { ForEach(Array(headers.enumerated()), id: \.offset) { _, cell in InlineText(runs: cell, context: context).fontWeight(.semibold) } }
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        GridRow { ForEach(Array(row.enumerated()), id: \.offset) { _, cell in InlineText(runs: cell, context: context) } }
                    }
                }.padding(16).background(ChattyTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            }.accessibilityElement(children: .contain).accessibilityIdentifier("markdown.table")
        case .listItem(_, let number, let checked, let children):
            HStack(alignment: .top, spacing: 10) {
                if let checked { Image(systemName: checked ? "checkmark.square" : "square").accessibilityLabel(checked ? "已完成" : "未完成") }
                else { Text(number.map { "\($0)." } ?? "•").foregroundStyle(.secondary) }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(children.enumerated()), id: \.offset) { _, child in AnyView(RichBlockView(block: child, context: context)) }
                }
            }
        case .quote(let children):
            HStack(alignment: .top, spacing: 12) {
                Rectangle().fill(ChattyTheme.accent.opacity(0.5)).frame(width: 3)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(children.enumerated()), id: \.offset) { _, child in AnyView(RichBlockView(block: child, context: context)) }
                }.foregroundStyle(.secondary)
            }.fixedSize(horizontal: false, vertical: true)
        case .image(let alt, let source): InlineImageView(source: source, alt: alt, context: context)
        case .literal(let source): Text(verbatim: source).font(.system(.callout, design: .monospaced)).fixedSize(horizontal: false, vertical: true)
        case .rule: Divider()
        }
    }
}
