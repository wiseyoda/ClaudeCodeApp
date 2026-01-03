import XCTest
@testable import CodingBridge

final class SystemMessageTests: XCTestCase {
    // MARK: - SystemMessage Subtype Tests

    func testSubtype_stopHookSummary_parsesCorrectly() {
        let subtype = SystemMessage.Subtype(rawValue: "stop_hook_summary")
        XCTAssertEqual(subtype, .stopHookSummary)
    }

    func testSubtype_compactBoundary_parsesCorrectly() {
        let subtype = SystemMessage.Subtype(rawValue: "compact_boundary")
        XCTAssertEqual(subtype, .compactBoundary)
    }

    func testSubtype_localCommand_parsesCorrectly() {
        let subtype = SystemMessage.Subtype(rawValue: "local_command")
        XCTAssertEqual(subtype, .localCommand)
    }

    func testSubtype_apiError_parsesCorrectly() {
        let subtype = SystemMessage.Subtype(rawValue: "api_error")
        XCTAssertEqual(subtype, .apiError)
    }

    func testSubtype_unknown_handlesUnknownValues() {
        let subtype = SystemMessage.Subtype(rawValue: "some_unknown_type")
        XCTAssertEqual(subtype, .unknown)
    }

    // MARK: - shouldDisplay Tests

    func testShouldDisplay_compactBoundary_returnsTrue() {
        let message = SystemMessage(subtype: .compactBoundary, displayContent: "Conversation compacted", metadata: nil)
        XCTAssertTrue(message.shouldDisplay)
    }

    func testShouldDisplay_apiError_returnsTrue() {
        let message = SystemMessage(subtype: .apiError, displayContent: "API Error 503", metadata: nil)
        XCTAssertTrue(message.shouldDisplay)
    }

    func testShouldDisplay_stopHookSummary_returnsFalse() {
        let message = SystemMessage(subtype: .stopHookSummary, displayContent: "", metadata: nil)
        XCTAssertFalse(message.shouldDisplay)
    }

    func testShouldDisplay_localCommand_returnsFalse() {
        // Local commands are handled by LocalCommandParser
        let message = SystemMessage(subtype: .localCommand, displayContent: "", metadata: nil)
        XCTAssertFalse(message.shouldDisplay)
    }

    func testShouldDisplay_unknown_returnsFalse() {
        let message = SystemMessage(subtype: .unknown, displayContent: "some content", metadata: nil)
        XCTAssertFalse(message.shouldDisplay)
    }

    // MARK: - Icon Tests

    func testIcon_compactBoundary() {
        let message = SystemMessage(subtype: .compactBoundary, displayContent: "", metadata: nil)
        XCTAssertEqual(message.icon, "rectangle.compress.vertical")
    }

    func testIcon_apiError() {
        let message = SystemMessage(subtype: .apiError, displayContent: "", metadata: nil)
        XCTAssertEqual(message.icon, "exclamationmark.triangle")
    }

    func testIcon_localCommand() {
        let message = SystemMessage(subtype: .localCommand, displayContent: "", metadata: nil)
        XCTAssertEqual(message.icon, "terminal")
    }

    // MARK: - SystemMessageParser Tests

    func testParse_compactBoundary_parsesCorrectly() {
        let result = SystemMessageParser.parse(subtype: "compact_boundary", content: "Conversation compacted")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.subtype, .compactBoundary)
        XCTAssertTrue(result?.shouldDisplay ?? false)
    }

    func testParse_compactBoundary_withMetadata_formatsCorrectly() {
        let rawJSON: [String: Any] = [
            "compactMetadata": [
                "trigger": "auto",
                "preTokens": 155252
            ]
        ]
        let result = SystemMessageParser.parse(subtype: "compact_boundary", content: "Conversation compacted", rawJSON: rawJSON)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.displayContent, "Auto-compacted (155.3k tokens)")
        if case .compact(let trigger, let preTokens) = result?.metadata {
            XCTAssertEqual(trigger, "auto")
            XCTAssertEqual(preTokens, 155252)
        } else {
            XCTFail("Expected compact metadata")
        }
    }

    func testParse_compactBoundary_manualTrigger_formatsCorrectly() {
        let rawJSON: [String: Any] = [
            "compactMetadata": [
                "trigger": "manual",
                "preTokens": 50000
            ]
        ]
        let result = SystemMessageParser.parse(subtype: "compact_boundary", content: "Conversation compacted", rawJSON: rawJSON)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.displayContent, "Compacted (50.0k tokens)")
    }

    func testParse_apiError_parsesCorrectly() {
        let rawJSON: [String: Any] = [
            "error": ["status": 503],
            "retryAttempt": 2,
            "maxRetries": 10
        ]
        let result = SystemMessageParser.parse(subtype: "api_error", content: "", rawJSON: rawJSON)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.subtype, .apiError)
        XCTAssertEqual(result?.displayContent, "API Error 503 (retry 2/10)")
        XCTAssertTrue(result?.shouldDisplay ?? false)
    }

    func testParse_stopHookSummary_returnsNil() {
        let result = SystemMessageParser.parse(subtype: "stop_hook_summary", content: "")
        XCTAssertNil(result)
    }

    func testParse_localCommand_returnsNil() {
        // Local commands are handled by LocalCommandParser, not SystemMessageParser
        let result = SystemMessageParser.parse(subtype: "local_command", content: "<command-name>/exit</command-name>")
        XCTAssertNil(result)
    }

    // MARK: - SystemStreamMessage Extension Tests

    func testIsDisplayableContent_conversationCompacted_returnsTrue() {
        XCTAssertTrue(SystemStreamMessage.isDisplayableContent("Conversation compacted"))
    }

    func testIsDisplayableContent_sessionInitialized_returnsFalse() {
        XCTAssertFalse(SystemStreamMessage.isDisplayableContent("Session initialized with id: abc123"))
    }

    func testIsDisplayableContent_localCommand_returnsFalse() {
        let content = "<command-name>/exit</command-name><command-message>exit</command-message><command-args></command-args>"
        XCTAssertFalse(SystemStreamMessage.isDisplayableContent(content))
    }

    func testIsDisplayableContent_emptyString_returnsFalse() {
        XCTAssertFalse(SystemStreamMessage.isDisplayableContent(""))
    }

    func testIsDisplayableContent_whitespaceOnly_returnsFalse() {
        XCTAssertFalse(SystemStreamMessage.isDisplayableContent("   \n\t   "))
    }

    func testIsDisplayableContent_normalContent_returnsTrue() {
        XCTAssertTrue(SystemStreamMessage.isDisplayableContent("Some system message"))
    }

    // MARK: - formatContent Tests

    func testFormatContent_conversationCompacted_formatsAsDivider() {
        let result = SystemStreamMessage.formatContent("Conversation compacted")
        XCTAssertEqual(result, "── Context compacted ──")
    }

    func testFormatContent_normalContent_passesThrough() {
        let result = SystemStreamMessage.formatContent("Some other system message")
        XCTAssertEqual(result, "Some other system message")
    }

    func testFormatContent_trimsWhitespace() {
        let result = SystemStreamMessage.formatContent("   Some message   \n")
        XCTAssertEqual(result, "Some message")
    }

    // MARK: - JSON Parsing Tests

    func testParseJSON_compactBoundary_parsesFromJSONL() {
        let jsonString = """
        {"type":"system","subtype":"compact_boundary","content":"Conversation compacted","level":"info","compactMetadata":{"trigger":"auto","preTokens":155252}}
        """
        let result = SystemMessageParser.parseJSON(jsonString)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.subtype, .compactBoundary)
    }

    func testParseJSON_apiError_parsesFromJSONL() {
        let jsonString = """
        {"type":"system","subtype":"api_error","level":"error","error":{"status":520},"retryAttempt":1,"maxRetries":10}
        """
        let result = SystemMessageParser.parseJSON(jsonString)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.subtype, .apiError)
    }

    func testParseJSON_invalidJSON_returnsNil() {
        let result = SystemMessageParser.parseJSON("not valid json")
        XCTAssertNil(result)
    }

    func testParseJSON_missingSubtype_returnsNil() {
        let jsonString = """
        {"type":"system","content":"Some message"}
        """
        let result = SystemMessageParser.parseJSON(jsonString)
        XCTAssertNil(result)
    }

    // MARK: - isSystemMessageJSON Tests

    func testIsSystemMessageJSON_validSystemMessage_returnsTrue() {
        let json = """
        {"type":"system","subtype":"compact_boundary","content":"test"}
        """
        XCTAssertTrue(SystemMessageParser.isSystemMessageJSON(json))
    }

    func testIsSystemMessageJSON_nonSystemMessage_returnsFalse() {
        let json = """
        {"type":"user","content":"hello"}
        """
        XCTAssertFalse(SystemMessageParser.isSystemMessageJSON(json))
    }

    func testIsSystemMessageJSON_missingSubtype_returnsFalse() {
        let json = """
        {"type":"system","content":"hello"}
        """
        XCTAssertFalse(SystemMessageParser.isSystemMessageJSON(json))
    }
}
