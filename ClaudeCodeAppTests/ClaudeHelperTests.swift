import XCTest
@testable import ClaudeCodeApp

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
}
