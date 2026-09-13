import XCTest
@testable import ChattyCore

/// Spec §8: formulas must stop being plain text, and the conversion must never
/// silently drop what it does not understand.
final class MathTextTests: XCTestCase {

    func testScriptsOperatorsAndGreekBecomeUnicode() {
        XCTAssertEqual(MathText.render("a^2 + b^2 = n"), "a² + b² = n")
        XCTAssertEqual(MathText.render("N = a^2 + b^2 = c^2 + d^2"), "N = a² + b² = c² + d²")
        XCTAssertEqual(MathText.render("a_{i} + x_1"), "aᵢ + x₁")
        XCTAssertEqual(MathText.render("\\alpha \\times \\beta \\leq \\gamma"), "α × β ≤ γ")
        XCTAssertEqual(MathText.render("x \\neq y \\approx z"), "x ≠ y ≈ z")
        XCTAssertEqual(MathText.render("\\sum_{i=1}^{n} i"), "∑ᵢ₌₁ⁿ i")
    }

    func testFractionsAndRootsBecomeReadableText() {
        XCTAssertEqual(MathText.render("\\frac{1}{2}"), "1/2")
        // Multi-term operands keep their grouping: a flat slash would silently
        // change the meaning to a + b/2.
        XCTAssertEqual(MathText.render("\\frac{a+b}{c}"), "(a+b)/c")
        XCTAssertEqual(MathText.render("\\frac{a}{b+c}"), "a/(b+c)")
        XCTAssertEqual(MathText.render("\\sqrt{x+1}"), "√(x+1)")
        XCTAssertEqual(MathText.render("\\frac{\\sqrt{2}}{2}"), "√(2)/2")
    }

    func testNestedScriptsKeepBothLevelsAndAdvanceTheScanner() {
        // Guards the loop that would otherwise re-scan an unconvertible script
        // forever, and the fallback that keeps an unconvertible script readable
        // instead of collapsing `x^{ab}` into `x^ab`.
        XCTAssertEqual(MathText.render("x^{2}"), "x²")
        XCTAssertEqual(MathText.render("x^{ab}"), "x^(ab)")
        XCTAssertEqual(MathText.render("a^{b^2}"), "a^(b²)")
    }

    func testUnknownCommandsArePreservedRatherThanDropped() {
        let rendered = MathText.render("\\unknowncmd{x}")
        XCTAssertTrue(rendered.contains("unknowncmd"), rendered)
        XCTAssertTrue(rendered.contains("x"), rendered)
    }

    func testInlineSegmentsSplitMathFromProse() {
        let segments = MathText.segments("计算 $a^2+b^2=n$ 的值")
        XCTAssertEqual(segments.map(\.isMath), [false, true, false])
        XCTAssertEqual(segments.map(\.text), ["计算 ", "a^2+b^2=n", " 的值"])

        let parenthesised = MathText.segments("斜边 \\(c\\) 的长度")
        XCTAssertEqual(parenthesised.map(\.isMath), [false, true, false])
        XCTAssertEqual(parenthesised[1].text, "c")
    }

    func testCurrencyIsNotTreatedAsMath() {
        let segments = MathText.segments("价格是 $5 和 $6")
        XCTAssertEqual(segments.map(\.isMath), [false])
        XCTAssertEqual(segments.map(\.text), ["价格是 $5 和 $6"])
    }

    func testDisplaySourceOnlyMatchesAWholeFormulaParagraph() {
        XCTAssertEqual(MathText.displaySource("$$a^2 + b^2 = n$$"), "a^2 + b^2 = n")
        XCTAssertEqual(MathText.displaySource("  \\[ x = 1 \\]  "), " x = 1 ")
        XCTAssertNil(MathText.displaySource("普通段落"))
        XCTAssertNil(MathText.displaySource("$$$$"))
        XCTAssertNil(MathText.displaySource("前面 $$x$$"))
    }

    func testRichDocumentProducesDisplayMathAndInlineMathRuns() {
        XCTAssertEqual(RichDocument.parse("$$a^2 + b^2 = n$$"), [.math("a^2 + b^2 = n")])

        guard case .paragraph(let runs)? = RichDocument.parse("行内 $x_1$ 公式").first else {
            return XCTFail("expected a paragraph")
        }
        XCTAssertEqual(runs.map(\.math), [false, true, false])
        XCTAssertEqual(runs.first(where: \.math)?.text, "x_1")
        XCTAssertEqual(runs.map(\.text).joined(), "行内 x_1 公式")
    }

    func testFormulaKeepsMarkdownStructureAroundIt() {
        let blocks = RichDocument.parse("""
        答案如下：

        $$c^2 = a^2 + b^2$$

        - 第一项
        """)
        XCTAssertTrue(blocks.contains(.math("c^2 = a^2 + b^2")))
        XCTAssertTrue(blocks.contains { if case .paragraph = $0 { true } else { false } })
        XCTAssertTrue(blocks.contains { if case .listItem = $0 { true } else { false } })
    }

    /// `swift-markdown` unescapes `\[` to `[`, so the backslash forms only survive
    /// because they are canonicalised before parsing.
    func testBackslashDelimitersSurviveMarkdownParsing() {
        XCTAssertEqual(RichDocument.parse("\\[c^2 = a^2 + b^2\\]"), [.math("c^2 = a^2 + b^2")])

        guard case .paragraph(let runs)? = RichDocument.parse("斜边 \\(c\\) 的长度").first else {
            return XCTFail("expected a paragraph")
        }
        XCTAssertEqual(runs.map(\.math), [false, true, false])
        XCTAssertEqual(runs.first(where: \.math)?.text, "c")

        XCTAssertEqual(MathText.normalizeDelimiters("\\[x\\] 与 \\(y\\)"), "$$x$$ 与 $y$")
    }
}
