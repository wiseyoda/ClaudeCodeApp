import XCTest
@testable import ClaudeCodeApp

final class IdeaTests: XCTestCase {
    func testFormattedPromptIncludesSections() {
        let idea = Idea(
            text: "Build a new feature",
            title: "Feature plan",
            tags: ["ios", "swift"],
            expandedPrompt: "Detailed prompt text",
            suggestedFollowups: ["Add tests", "Update docs"]
        )

        let prompt = idea.formattedPrompt

        XCTAssertTrue(prompt.contains("# Idea: Feature plan"))
        XCTAssertTrue(prompt.contains("## Description\nBuild a new feature"))
        XCTAssertTrue(prompt.contains("## Tags\n`ios` `swift`"))
        XCTAssertTrue(prompt.contains("## AI-Enhanced Prompt\nDetailed prompt text"))
        XCTAssertTrue(prompt.contains("## Suggested Follow-ups\n- Add tests\n- Update docs"))
    }

    func testFormattedPromptOmitsEmptySections() {
        let idea = Idea(text: "Minimal idea")
        let prompt = idea.formattedPrompt

        XCTAssertTrue(prompt.contains("# Idea"))
        XCTAssertTrue(prompt.contains("## Description\nMinimal idea"))
        XCTAssertFalse(prompt.contains("## Tags"))
        XCTAssertFalse(prompt.contains("## AI-Enhanced Prompt"))
        XCTAssertFalse(prompt.contains("## Suggested Follow-ups"))
    }
}
