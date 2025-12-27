import XCTest
@testable import ClaudeCodeApp

final class TruncatableTextTests: XCTestCase {
    func testLineLimitDefaultsForPlainText() {
        XCTAssertEqual(TruncatableText.lineLimit(for: "Just some text."), 8)
    }

    func testLineLimitDetectsStackTraceKeywords() {
        let errorContent = "Error: Something failed\nat line 42"
        XCTAssertEqual(TruncatableText.lineLimit(for: errorContent), 15)

        let tracebackContent = "Traceback (most recent call last):"
        XCTAssertEqual(TruncatableText.lineLimit(for: tracebackContent), 15)
    }

    func testLineLimitDetectsJsonContentBeforeToolName() {
        let jsonContent = "{ \"key\": \"value\" }"
        XCTAssertEqual(TruncatableText.lineLimit(for: jsonContent, toolName: "read"), 10)
    }

    func testLineLimitUsesToolSpecificOverrides() {
        XCTAssertEqual(TruncatableText.lineLimit(for: "output", toolName: "grep"), 12)
        XCTAssertEqual(TruncatableText.lineLimit(for: "output", toolName: "READ"), 20)
        XCTAssertEqual(TruncatableText.lineLimit(for: "output", toolName: "glob"), 15)
        XCTAssertEqual(TruncatableText.lineLimit(for: "output", toolName: "bash"), 8)
        XCTAssertEqual(TruncatableText.lineLimit(for: "output", toolName: "unknown"), 8)
    }
}
