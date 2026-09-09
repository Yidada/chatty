import Markdown

public enum MarkdownBlock: Equatable, Sendable {
    case heading(Int, String)
    case paragraph(String)
    case code(String?, String)
    case table([String], [[String]])
    case listItem(String, Bool?)
    case quote(String)
    case literal(String)
}

/// P0 rendering spike: preserves block structure without executing rich content.
/// Full inline/link/media rendering remains an IOS-P3 delivery criterion.
public enum MarkdownContent {
    public static func blocks(_ source: String) -> [MarkdownBlock] {
        Document(parsing: source).children.flatMap(convert)
    }

    private static func text(_ node: any Markup) -> String {
        if let text = node as? Markdown.Text { return text.string }
        if let code = node as? InlineCode { return code.code }
        if node is SoftBreak || node is LineBreak { return "\n" }
        return node.children.map(text).joined()
    }

    private static func convert(_ node: any Markup) -> [MarkdownBlock] {
        switch node {
        case let h as Heading: return [.heading(h.level, text(h))]
        case let p as Paragraph: return [.paragraph(text(p))]
        case let code as CodeBlock: return [.code(code.language, code.code)]
        case let table as Table:
            let headers = Array(table.head.cells.map(text))
            let rows = Array(table.body.rows.map { row in Array(row.cells.map(text)) })
            return [.table(headers, rows)]
        case let item as ListItem:
            return [.listItem(text(item), item.checkbox.map { $0 == .checked })]
        case let quote as BlockQuote: return [.quote(text(quote))]
        case let html as HTMLBlock: return [.literal(html.rawHTML)]
        default: return node.children.flatMap(convert)
        }
    }
}
