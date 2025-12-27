import XCTest
@testable import ClaudeCodeApp

final class ModelEnumTests: XCTestCase {
    func testClaudeModelLabelsAndAliases() {
        let cases: [(ClaudeModel, String, String, String, String?, String)] = [
            (.opus, "Opus 4.5", "Opus", "Most capable for complex work", "opus", "brain.head.profile"),
            (.sonnet, "Sonnet 4.5", "Sonnet", "Best for everyday tasks", "sonnet", "sparkles"),
            (.haiku, "Haiku 4.5", "Haiku", "Fastest for quick answers", "haiku", "bolt.fill"),
            (.custom, "Custom", "Custom", "Custom model ID", nil, "gearshape")
        ]

        for (model, displayName, shortName, description, alias, icon) in cases {
            XCTAssertEqual(model.displayName, displayName)
            XCTAssertEqual(model.shortName, shortName)
            XCTAssertEqual(model.description, description)
            XCTAssertEqual(model.modelAlias, alias)
            XCTAssertEqual(model.icon, icon)
        }
    }

    func testGitStatusComputedProperties() {
        XCTAssertEqual(GitStatus.clean.icon, "checkmark.circle.fill")
        XCTAssertEqual(GitStatus.clean.colorName, "green")
        XCTAssertEqual(GitStatus.clean.accessibilityLabel, "Clean, up to date")
        XCTAssertFalse(GitStatus.clean.canAutoPull)
        XCTAssertFalse(GitStatus.clean.hasLocalChanges)

        let ahead = GitStatus.ahead(1)
        XCTAssertEqual(ahead.icon, "arrow.up.circle.fill")
        XCTAssertEqual(ahead.colorName, "blue")
        XCTAssertEqual(ahead.accessibilityLabel, "1 unpushed commit")
        XCTAssertFalse(ahead.canAutoPull)
        XCTAssertTrue(ahead.hasLocalChanges)

        let behind = GitStatus.behind(2)
        XCTAssertEqual(behind.icon, "arrow.down.circle.fill")
        XCTAssertEqual(behind.colorName, "cyan")
        XCTAssertEqual(behind.accessibilityLabel, "2 commits behind remote")
        XCTAssertTrue(behind.canAutoPull)
        XCTAssertFalse(behind.hasLocalChanges)

        let error = GitStatus.error("boom")
        XCTAssertEqual(error.icon, "xmark.circle")
        XCTAssertEqual(error.colorName, "red")
        XCTAssertEqual(error.accessibilityLabel, "Error: boom")

        XCTAssertTrue(GitStatus.dirtyAndAhead.hasLocalChanges)
        XCTAssertEqual(GitStatus.dirtyAndAhead.colorName, "orange")
    }
}
