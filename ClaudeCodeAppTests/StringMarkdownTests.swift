import XCTest
@testable import ClaudeCodeApp

final class StringMarkdownTests: XCTestCase {

    // MARK: - normalizedCodeFences Tests

    func testNormalizeInlineTripleBackticks() {
        let input = "Use ```myFunction()``` here"
        let expected = "Use `myFunction()` here"

        XCTAssertEqual(input.normalizedCodeFences, expected)
    }

    func testPreserveMultilineCodeBlocks() {
        let input = """
        ```swift
        let x = 1
        let y = 2
        ```
        """

        // Multiline blocks should not be changed
        XCTAssertEqual(input.normalizedCodeFences, input)
    }

    func testNormalizeMultipleInlineCodeFences() {
        let input = "Use ```foo``` and ```bar``` together"
        let expected = "Use `foo` and `bar` together"

        XCTAssertEqual(input.normalizedCodeFences, expected)
    }

    // MARK: - htmlDecoded Tests

    func testDecodeBasicHTMLEntities() {
        let input = "&lt;div&gt;Hello &amp; World&lt;/div&gt;"
        let expected = "<div>Hello & World</div>"

        XCTAssertEqual(input.htmlDecoded, expected)
    }

    func testDecodeQuotes() {
        let input = "&quot;Hello&quot; and &#39;World&#39;"
        let expected = "\"Hello\" and 'World'"

        XCTAssertEqual(input.htmlDecoded, expected)
    }

    func testDecodeNbsp() {
        let input = "Hello&nbsp;World"
        let expected = "Hello World"

        XCTAssertEqual(input.htmlDecoded, expected)
    }

    func testDecodeNumericEntities() {
        let input = "&#60;tag&#62; and &#x27;quote&#x27;"
        let expected = "<tag> and 'quote'"

        XCTAssertEqual(input.htmlDecoded, expected)
    }

    func testNoHTMLEntities() {
        let input = "Plain text without entities"

        XCTAssertEqual(input.htmlDecoded, input)
    }

    // MARK: - formattedUsageLimit Tests

    func testFormatUsageLimitMessage() {
        // Create epoch for a known time
        let date = Date()
        let epoch = date.timeIntervalSince1970
        let input = "Claude AI usage limit reached|\(Int(epoch))"

        let result = input.formattedUsageLimit

        XCTAssertTrue(result.contains("usage limit reached"))
        XCTAssertTrue(result.contains("resets at"))
        XCTAssertFalse(result.contains("|"))  // Pipe should be removed
    }

    func testNonUsageLimitMessage() {
        let input = "Regular error message"

        XCTAssertEqual(input.formattedUsageLimit, input)
    }

    // MARK: - Math Escape Protection Tests

    func testProtectMathEscapes() {
        let input = "\\{ x \\}"

        let (protected, replacements) = input.protectMathEscapes()

        XCTAssertFalse(protected.contains("\\{"))
        XCTAssertFalse(protected.contains("\\}"))
        XCTAssertFalse(replacements.isEmpty)
    }

    func testRestoreMathEscapes() {
        let input = "\\{ x \\}"

        let (protected, replacements) = input.protectMathEscapes()
        let restored = protected.restoreMathEscapes(replacements)

        XCTAssertEqual(restored, input)
    }

    func testProtectMultipleEscapes() {
        let input = "\\[ a \\] and \\( b \\)"

        let (protected, replacements) = input.protectMathEscapes()
        let restored = protected.restoreMathEscapes(replacements)

        XCTAssertEqual(restored, input)
    }

    // MARK: - processedForDisplay Tests

    func testProcessedForDisplay() {
        let input = "&lt;code&gt;```inline```&lt;/code&gt;"
        let result = input.processedForDisplay

        XCTAssertTrue(result.contains("<code>"))
        XCTAssertTrue(result.contains("`inline`"))
        XCTAssertFalse(result.contains("&lt;"))
        XCTAssertFalse(result.contains("```"))
    }
}
