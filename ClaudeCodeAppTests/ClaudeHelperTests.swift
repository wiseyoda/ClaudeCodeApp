import XCTest
@testable import CodingBridge

@MainActor
final class ClaudeHelperTests: XCTestCase {
    func testParseSuggestedActionsParsesJSONPayload() {
        let helper = ClaudeHelper(settings: AppSettings())
        let response = """
        Prefix text
        [{"label":"Run tests","prompt":"Run the test suite","icon":"play.circle"},
         {"label":"Commit changes","prompt":"Commit staged files"},
         {"label":"Explain this","prompt":"Explain the changes","icon":"questionmark.circle"},
         {"label":"Extra","prompt":"Ignore me","icon":"xmark"}]
        Suffix text
        """

        let actions = helper.parseSuggestedActions(from: response)

        XCTAssertEqual(actions.count, 3)
        XCTAssertEqual(actions[0].label, "Run tests")
        XCTAssertEqual(actions[0].icon, "play.circle")
        XCTAssertEqual(actions[1].label, "Commit changes")
        XCTAssertEqual(actions[1].icon, "arrow.right.circle")
        XCTAssertEqual(actions[2].label, "Explain this")
    }

    func testParseSuggestedActionsFallsBackToDefaults() {
        let helper = ClaudeHelper(settings: AppSettings())
        let actions = helper.parseSuggestedActions(from: "No JSON here")

        XCTAssertEqual(actions.count, 3)
        XCTAssertEqual(actions.map(\.label), ["Continue", "Explain more", "Run tests"])
    }

    func testParseFileListFiltersAvailableAndSuffixMatches() {
        let helper = ClaudeHelper(settings: AppSettings())
        let response = """
        ["App.swift", "Sources/Utilities/Log.swift", "Missing.swift"]
        """
        let available = [
            "Sources/App.swift",
            "Sources/Utilities/Log.swift",
            "Tests/AppTests.swift"
        ]

        let files = helper.parseFileList(from: response, availableFiles: available)

        XCTAssertEqual(files, ["App.swift", "Sources/Utilities/Log.swift"])
    }

    func testParseEnhancedIdeaParsesJSON() {
        let helper = ClaudeHelper(settings: AppSettings())
        let response = """
        Noise
        {"expandedPrompt":"Do the thing","suggestedFollowups":["Next step","Another idea"]}
        More noise
        """

        let enhanced = helper.parseEnhancedIdea(from: response)

        XCTAssertEqual(enhanced?.expandedPrompt, "Do the thing")
        XCTAssertEqual(enhanced?.suggestedFollowups, ["Next step", "Another idea"])
    }

    func testParseEnhancedIdeaReturnsNilWithoutJSON() {
        let helper = ClaudeHelper(settings: AppSettings())
        let enhanced = helper.parseEnhancedIdea(from: "No object here")

        XCTAssertNil(enhanced)
    }

    // MARK: - Helper Session ID Tests

    func testCreateHelperSessionIdIsDeterministic() {
        // Same project path should always produce the same session ID
        let path = "/home/dev/workspace/ClaudeCodeApp"
        let id1 = ClaudeHelper.createHelperSessionId(for: path)
        let id2 = ClaudeHelper.createHelperSessionId(for: path)

        XCTAssertEqual(id1, id2, "Same path should produce same session ID")
    }

    func testCreateHelperSessionIdIsDifferentForDifferentPaths() {
        let path1 = "/home/dev/workspace/ClaudeCodeApp"
        let path2 = "/home/dev/workspace/OtherProject"

        let id1 = ClaudeHelper.createHelperSessionId(for: path1)
        let id2 = ClaudeHelper.createHelperSessionId(for: path2)

        XCTAssertNotEqual(id1, id2, "Different paths should produce different session IDs")
    }

    func testCreateHelperSessionIdIsValidUUIDFormat() {
        let path = "/home/dev/workspace/TestProject"
        let sessionId = ClaudeHelper.createHelperSessionId(for: path)

        // UUID format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
        let uuidRegex = try! NSRegularExpression(
            pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
            options: .caseInsensitive
        )
        let range = NSRange(sessionId.startIndex..., in: sessionId)
        let match = uuidRegex.firstMatch(in: sessionId, options: [], range: range)

        XCTAssertNotNil(match, "Session ID should be a valid UUID v4 format: \(sessionId)")
    }

    func testCreateHelperSessionIdHandlesEmptyPath() {
        let sessionId = ClaudeHelper.createHelperSessionId(for: "")

        // Should still produce a valid UUID
        XCTAssertEqual(sessionId.count, 36, "Should be 36 characters (UUID format)")
        XCTAssertTrue(sessionId.contains("-"), "Should contain dashes")
    }
}
