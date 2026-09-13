import Foundation

/// LaTeX → Unicode for the subset that shows up in chat answers.
///
/// The DeepSeek app renders formulas with KaTeX; this package has no web view, so
/// the alternative is to render the common shapes with system fonts. The rule that
/// matters most is **never drop content**: anything this converter does not
/// understand is returned verbatim rather than silently emptied, so a wrong guess
/// is visible instead of invisible (spec §8 requires a degradation path).
public enum MathText {
    /// Rewrites the backslash delimiters into the dollar forms **before** Markdown
    /// parsing. `swift-markdown` treats `\[` and `\(` as escaped punctuation and
    /// hands back a bare bracket, so a LaTeX delimiter never survives to the block
    /// builder; canonicalising it first is what makes `\[…\]` and `\(…\)` work at
    /// all.
    public static func normalizeDelimiters(_ source: String) -> String {
        source
            .replacingOccurrences(of: "\\[", with: "$$")
            .replacingOccurrences(of: "\\]", with: "$$")
            .replacingOccurrences(of: "\\(", with: "$")
            .replacingOccurrences(of: "\\)", with: "$")
    }

    /// Splits on `$…$` and `\(…\)` while leaving currency and lone dollars alone.
    /// Returns alternating plain/math segments.
    public static func segments(_ source: String) -> [(text: String, isMath: Bool)] {
        var result: [(String, Bool)] = []
        var plain = ""
        var index = source.startIndex
        func flush() { if !plain.isEmpty { result.append((plain, false)); plain = "" } }
        while index < source.endIndex {
            let rest = source[index...]
            if rest.hasPrefix("\\("), let close = rest.range(of: "\\)") {
                flush()
                result.append((String(rest[rest.index(rest.startIndex, offsetBy: 2)..<close.lowerBound]), true))
                index = close.upperBound
                continue
            }
            if rest.hasPrefix("$"), !rest.hasPrefix("$$") {
                let afterOpen = rest.index(after: rest.startIndex)
                if let close = rest[afterOpen...].firstIndex(of: "$") {
                    let body = rest[afterOpen..<close]
                    // `$5 and $6` is prose, not math: require no space just inside
                    // the delimiters and at least one non-space character.
                    if !body.isEmpty, body.first != " ", body.last != " ", !body.contains("\n") {
                        flush()
                        result.append((String(body), true))
                        index = rest.index(after: close)
                        continue
                    }
                }
            }
            plain.append(source[index])
            index = source.index(after: index)
        }
        flush()
        return result
    }

    /// True when the paragraph is one whole display-math expression.
    public static func displaySource(_ paragraph: String) -> String? {
        let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
        for (open, close) in [("$$", "$$"), ("\\[", "\\]")] {
            guard trimmed.hasPrefix(open), trimmed.hasSuffix(close), trimmed.count > open.count + close.count else { continue }
            let body = String(trimmed.dropFirst(open.count).dropLast(close.count))
            if !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return body }
        }
        return nil
    }

    public static func render(_ source: String) -> String {
        var text = source
        // Spacing and sizing hints carry no meaning once we are not typesetting.
        for noise in ["\\left", "\\right", "\\displaystyle", "\\,", "\\;", "\\!", "\\quad", "\\qquad", "\\limits"] {
            text = text.replacingOccurrences(of: noise, with: "")
        }
        text = replaceCommands(text)
        text = replaceFrac(text)
        text = replaceSqrt(text)
        text = replaceScripts(text)
        text = text.replacingOccurrences(of: "\\text{", with: "{")
        text = text.replacingOccurrences(of: "\\mathrm{", with: "{")
        text = text.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let commands: [String: String] = [
        "\\alpha": "α", "\\beta": "β", "\\gamma": "γ", "\\delta": "δ", "\\epsilon": "ε", "\\varepsilon": "ε",
        "\\zeta": "ζ", "\\eta": "η", "\\theta": "θ", "\\iota": "ι", "\\kappa": "κ", "\\lambda": "λ",
        "\\mu": "μ", "\\nu": "ν", "\\xi": "ξ", "\\pi": "π", "\\rho": "ρ", "\\sigma": "σ", "\\tau": "τ",
        "\\upsilon": "υ", "\\phi": "φ", "\\varphi": "φ", "\\chi": "χ", "\\psi": "ψ", "\\omega": "ω",
        "\\Gamma": "Γ", "\\Delta": "Δ", "\\Theta": "Θ", "\\Lambda": "Λ", "\\Xi": "Ξ", "\\Pi": "Π",
        "\\Sigma": "Σ", "\\Phi": "Φ", "\\Psi": "Ψ", "\\Omega": "Ω",
        "\\times": "×", "\\cdot": "·", "\\div": "÷", "\\pm": "±", "\\mp": "∓",
        "\\le": "≤", "\\leq": "≤", "\\ge": "≥", "\\geq": "≥", "\\ne": "≠", "\\neq": "≠",
        "\\approx": "≈", "\\equiv": "≡", "\\sim": "∼", "\\propto": "∝",
        "\\infty": "∞", "\\sum": "∑", "\\prod": "∏", "\\int": "∫", "\\partial": "∂", "\\nabla": "∇",
        "\\to": "→", "\\rightarrow": "→", "\\leftarrow": "←", "\\Rightarrow": "⇒", "\\mapsto": "↦",
        "\\in": "∈", "\\notin": "∉", "\\subset": "⊂", "\\cup": "∪", "\\cap": "∩", "\\emptyset": "∅",
        "\\forall": "∀", "\\exists": "∃", "\\neg": "¬", "\\land": "∧", "\\lor": "∨",
        "\\angle": "∠", "\\circ": "∘", "\\prime": "′", "\\ldots": "…", "\\dots": "…", "\\cdots": "⋯",
    ]

    private static func replaceCommands(_ source: String) -> String {
        var result = source
        // Longest name first so `\leq` is not consumed by `\le`.
        for name in commands.keys.sorted(by: { $0.count > $1.count }) {
            guard let value = commands[name] else { continue }
            var cursor = result.startIndex
            while let found = result.range(of: name, range: cursor..<result.endIndex) {
                let next = found.upperBound
                // A command must not be the prefix of a longer one (`\pii`).
                if next < result.endIndex, result[next].isLetter { cursor = next; continue }
                // `replaceSubrange` invalidates every index, so remember where the
                // match was by offset and rebuild the cursor afterwards.
                let offset = result.distance(from: result.startIndex, to: found.lowerBound)
                result.replaceSubrange(found, with: value)
                cursor = result.index(result.startIndex, offsetBy: offset + value.count)
            }
        }
        return result
    }

    private static func replaceFrac(_ source: String) -> String {
        var text = source
        while let start = text.range(of: "\\frac") {
            guard let numerator = balanced(in: text, from: start.upperBound) else { break }
            let afterNumerator = numerator.end
            guard afterNumerator < text.endIndex, text[afterNumerator] == "{",
                  let denominator = balanced(in: text, from: afterNumerator) else { break }
            // A flat slash changes precedence, so a multi-term operand keeps its
            // grouping: `\frac{a+b}{2}` must not read as `a + b/2`.
            let replacement = "\(grouped(numerator.body))/\(grouped(denominator.body))"
            text.replaceSubrange(start.lowerBound..<denominator.end, with: replacement)
        }
        return text
    }

    private static func grouped(_ operand: String) -> String {
        let trimmed = operand.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains(where: { "+-±∓×·/ ".contains($0) }) else { return trimmed }
        return "(\(trimmed))"
    }

    private static func replaceSqrt(_ source: String) -> String {
        var text = source
        while let start = text.range(of: "\\sqrt") {
            guard let body = balanced(in: text, from: start.upperBound) else { break }
            text.replaceSubrange(start.lowerBound..<body.end, with: "√(\(body.body))")
        }
        return text
    }

    /// Reads a `{…}` group whose opening brace sits at `index`, honouring nesting.
    private static func balanced(in text: String, from index: String.Index) -> (body: String, end: String.Index)? {
        guard index < text.endIndex, text[index] == "{" else { return nil }
        var depth = 0
        var cursor = index
        var body = ""
        while cursor < text.endIndex {
            let character = text[cursor]
            if character == "{" {
                depth += 1
                if depth > 1 { body.append(character) }
            } else if character == "}" {
                depth -= 1
                if depth == 0 { return (body, text.index(after: cursor)) }
                body.append(character)
            } else {
                body.append(character)
            }
            cursor = text.index(after: cursor)
        }
        return nil
    }

    private static let superscripts: [Character: Character] = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
        "+": "⁺", "-": "⁻", "=": "⁼", "(": "⁽", ")": "⁾", "n": "ⁿ", "i": "ⁱ",
    ]
    private static let subscripts: [Character: Character] = [
        "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄", "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
        "+": "₊", "-": "₋", "=": "₌", "(": "₍", ")": "₎",
        "a": "ₐ", "e": "ₑ", "i": "ᵢ", "j": "ⱼ", "k": "ₖ", "l": "ₗ", "m": "ₘ", "n": "ₙ", "o": "ₒ",
        "p": "ₚ", "r": "ᵣ", "s": "ₛ", "t": "ₜ", "u": "ᵤ", "v": "ᵥ", "x": "ₓ",
    ]

    /// `x^{2}` → `x²`, `a_{i}` → `aᵢ`. A script with no Unicode form keeps its
    /// braces so the reader sees the intent instead of a mystery.
    private static func replaceScripts(_ source: String) -> String {
        var text = source
        for (marker, table) in [("^", superscripts), ("_", subscripts)] {
            var cursor = text.startIndex
            while let start = text.range(of: marker, range: cursor..<text.endIndex) {
                let contentStart = start.upperBound
                let body: String
                let end: String.Index
                if contentStart < text.endIndex, text[contentStart] == "{" {
                    guard let group = balanced(in: text, from: contentStart) else { break }
                    body = group.body
                    end = group.end
                } else if contentStart < text.endIndex {
                    body = String(text[contentStart])
                    end = text.index(after: contentStart)
                } else { break }
                // A script with no Unicode form falls back to `^(…)` rather than
                // `^{…}`, because the grouping braces are stripped later and
                // `x^{ab}` would otherwise read as `x^ab`.
                let converted = body.allSatisfy { table[$0] != nil }
                    ? String(body.map { table[$0] ?? $0 })
                    : "\(marker)(\(replaceScripts(body)))"
                // Advance past the replacement: an unmappable script keeps its
                // marker, and re-scanning it would spin forever. Rebuild the cursor
                // from an offset because the replacement invalidated the indices.
                let offset = text.distance(from: text.startIndex, to: start.lowerBound)
                text.replaceSubrange(start.lowerBound..<end, with: converted)
                cursor = text.index(text.startIndex, offsetBy: offset + converted.count)
            }
        }
        return text
    }
}
