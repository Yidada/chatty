import Foundation
import Markdown

public struct InlineRun: Equatable, Sendable {
    public var text: String
    public var bold = false
    public var italic = false
    public var strike = false
    public var code = false
    public var link: String?
}
public indirect enum RichBlock: Equatable, Sendable {
    case heading(Int, [InlineRun]), paragraph([InlineRun]), code(String?, String)
    case table([[InlineRun]], [[[InlineRun]]])
    case listItem(Int, Int?, Bool?, [RichBlock]), quote([RichBlock])
    case image(String, String), literal(String), rule
}
public enum RichDocument {
    public static func parse(_ source: String) -> [RichBlock] {
        Document(parsing: DisplayText.message(source)).children.flatMap { blocks($0, depth: 0) }
    }
    private static func inline(_ node: any Markup, style: InlineRun = .init(text: "")) -> [InlineRun] {
        var style = style
        if let value = node as? Markdown.Text { style.text = value.string; return [style] }
        if let value = node as? InlineCode { style.text = value.code; style.code = true; return [style] }
        if let value = node as? InlineHTML { style.text = value.rawHTML; style.code = true; return [style] }
        if node is SoftBreak { style.text = " "; return [style] }
        if node is LineBreak { style.text = "\n"; return [style] }
        if node is Strong { style.bold = true }
        if node is Emphasis { style.italic = true }
        if node is Strikethrough { style.strike = true }
        if let link = node as? Markdown.Link { style.link = link.destination }
        return node.children.flatMap { inline($0, style: style) }
    }
    private static func blocks(_ node: any Markup, depth: Int) -> [RichBlock] {
        switch node {
        case let heading as Heading: return [.heading(heading.level, inline(heading))]
        case let paragraph as Paragraph:
            var result: [RichBlock] = []; var runs: [InlineRun] = []
            for child in paragraph.children {
                if let image = child as? Markdown.Image, let source = image.source {
                    if !runs.isEmpty { result.append(.paragraph(runs)); runs = [] }
                    result.append(.image(inline(image).map(\.text).joined(), source))
                } else { runs += inline(child) }
            }
            if !runs.isEmpty { result.append(.paragraph(runs)) }; return result
        case let code as CodeBlock: return [.code(code.language, code.code)]
        case let table as Table:
            return [.table(Array(table.head.cells.map { inline($0) }), Array(table.body.rows.map { row in Array(row.cells.map { inline($0) }) }))]
        case let list as OrderedList:
            return list.children.enumerated().flatMap { index, child -> [RichBlock] in
                guard let item = child as? ListItem else { return blocks(child, depth: depth) }
                return [.listItem(depth, Int(list.startIndex) + index, item.checkbox.map { $0 == .checked }, item.children.flatMap { blocks($0, depth: depth + 1) })]
            }
        case let list as UnorderedList:
            return list.children.flatMap { child -> [RichBlock] in
                guard let item = child as? ListItem else { return blocks(child, depth: depth) }
                return [.listItem(depth, nil, item.checkbox.map { $0 == .checked }, item.children.flatMap { blocks($0, depth: depth + 1) })]
            }
        case let quote as BlockQuote: return [.quote(quote.children.flatMap { blocks($0, depth: depth) })]
        case let html as HTMLBlock: return [.literal(html.rawHTML)]
        case is ThematicBreak: return [.rule]
        default: return node.children.flatMap { blocks($0, depth: depth) }
        }
    }
}

public enum NativeLink: Equatable, Sendable {
    case issue(String), project(String), attachment(String), external(URL), unavailable
    public static func resolve(_ source: String, api: URL, workspace: String) -> NativeLink {
        guard !source.contains("\\"), !source.hasPrefix("//"), let url = URL(string: source, relativeTo: api)?.absoluteURL,
              url.user == nil, url.password == nil else { return .unavailable }
        let parts = url.path.split(separator: "/").map(String.init)
        if url.scheme == "mention", let id = parts.first {
            if url.host == "issue" { return .issue(id) }
            if url.host == "project" { return .project(id) }
        }
        let firstParty = [api.host, "multica.ai", "app.multica.ai", "cloud.multica.ai"].compactMap { $0 }.contains(url.host ?? "")
        if firstParty {
            if (parts.count == 3 || parts.count == 4 && ["download", "content"].contains(parts[3])), parts[0] == "api", parts[1] == "attachments" { return .attachment(parts[2]) }
            let entity = parts.first == workspace ? Array(parts.dropFirst()) : parts
            if entity.count == 2, entity[0] == "issues" { return .issue(entity[1]) }
            if entity.count == 2, entity[0] == "projects" { return .project(entity[1]) }
            // Unsupported Multica business routes remain inside the native app.
            return .unavailable
        }
        guard url.scheme == "https" else { return .unavailable }
        return .external(url)
    }
}
