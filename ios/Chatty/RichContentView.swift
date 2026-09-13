import SwiftUI
import ChattyCore
import UIKit

#if !CHATTY_NEXT
struct RichContentView: View {
    let source: String
    let context: WorkspaceContext
    var body: some View {
        NativeRichContent(source: source, link: { source in
            guard NativeLink.resolve(source, api: context.api.baseURL, workspace: context.workspace.slug) != .unavailable else { return nil }
            return URL(string: source, relativeTo: context.api.baseURL)?.absoluteURL
        }, image: { alt, source in AnyView(InlineImageView(source: source, alt: alt, context: context)) })
    }
}

#endif

struct NativeRichContent: View {
    let source: String
    var link: (String) -> URL?
    var image: (String, String) -> AnyView
    @State private var blocks: [RichBlock] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in RichBlockView(block: block, link: link, image: image) }
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
    let link: (String) -> URL?
    var body: some View { Text(attributed).fixedSize(horizontal: false, vertical: true) }
    private var attributed: AttributedString {
        var result = AttributedString()
        for run in runs {
            // Inline math is LaTeX in the source; show the converted formula with a
            // serif face so it reads as maths rather than prose (spec §8).
            var text = AttributedString(run.math ? MathText.render(run.text) : run.text)
            var font: Font = run.code ? .system(.body, design: .monospaced)
                : run.math ? .system(.body, design: .serif).italic()
                : .body
            if run.bold { font = font.bold() }; if run.italic { font = font.italic() }
            text.font = font
            if run.strike { text.strikethroughStyle = .single }
            if run.code { text.backgroundColor = Color.secondary.opacity(0.12) }
            if let source = run.link, let url = link(source) { text.link = url }
            result.append(text)
        }
        return result
    }
}

private struct RichBlockView: View {
    let block: RichBlock
    let link: (String) -> URL?
    let image: (String, String) -> AnyView
    var body: some View {
        switch block {
        case .heading(let level, let runs):
            Text(runs.map(\.text).joined()).font(level == 1 ? .title2.bold() : level == 2 ? .title3.bold() : .headline)
                .accessibilityAddTraits(.isHeader).fixedSize(horizontal: false, vertical: true)
        case .paragraph(let runs): InlineText(runs: runs, link: link)
        case .code(let language, let content):
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(language ?? "代码").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("复制", systemImage: "doc.on.doc") { UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: content]], options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)]) }
                        .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44).accessibilityLabel("复制代码")
                }
                ScrollView(.horizontal) { Text(verbatim: content.trimmingCharacters(in: .newlines)).font(.system(.callout, design: .monospaced)).fixedSize() }
            }
            .padding(14).background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        case .table(let headers, let rows):
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 12) {
                    GridRow { ForEach(Array(headers.enumerated()), id: \.offset) { _, cell in InlineText(runs: cell, link: link).fontWeight(.semibold) } }
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        GridRow { ForEach(Array(row.enumerated()), id: \.offset) { _, cell in InlineText(runs: cell, link: link) } }
                    }
                }.padding(16).background(ChattyTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            }.accessibilityElement(children: .contain).accessibilityIdentifier("markdown.table")
        case .listItem(_, let number, let checked, let children):
            HStack(alignment: .top, spacing: 10) {
                if let checked { Image(systemName: checked ? "checkmark.square" : "square").accessibilityLabel(checked ? "已完成" : "未完成") }
                else { Text(number.map { "\($0)." } ?? "•").foregroundStyle(.secondary) }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(children.enumerated()), id: \.offset) { _, child in AnyView(RichBlockView(block: child, link: link, image: image)) }
                }
            }
        case .quote(let children):
            HStack(alignment: .top, spacing: 12) {
                Rectangle().fill(ChattyTheme.accent.opacity(0.5)).frame(width: 3)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(children.enumerated()), id: \.offset) { _, child in AnyView(RichBlockView(block: child, link: link, image: image)) }
                }.foregroundStyle(.secondary)
            }.fixedSize(horizontal: false, vertical: true)
        case .image(let alt, let source): image(alt, source)
        case .math(let source):
            // Display formula: centred and set apart, matching how the DeepSeek app
            // presents `$$…$$` (research.md §2.5).
            Text(verbatim: MathText.render(source))
                .font(.system(.title3, design: .serif))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 6)
                .accessibilityIdentifier("markdown.math")
        case .literal(let source): Text(verbatim: source).font(.system(.callout, design: .monospaced)).fixedSize(horizontal: false, vertical: true)
        case .rule: Divider()
        }
    }
}
