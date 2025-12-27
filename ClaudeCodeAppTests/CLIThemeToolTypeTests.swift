import XCTest
@testable import ClaudeCodeApp

final class CLIThemeToolTypeTests: XCTestCase {
    func testToolTypeFromParsesNamesFromContent() {
        let cases: [(String, CLITheme.ToolType)] = [
            ("Bash(command: ls)", .bash),
            ("Read(file: README.md)", .read),
            ("Write content here", .write),
            ("Edit(file_path: /tmp/test)", .edit),
            ("Grep(pattern: foo)", .grep),
            ("Glob(pattern: *.swift)", .glob),
            ("Task(description: work)", .task),
            ("TodoWrite(todos: [])", .todoWrite),
            ("WebFetch(url: https://example.com)", .webFetch),
            ("WebSearch(query: swift)", .webSearch),
            ("AskUserQuestion(data: example)", .askUser),
            ("UnknownTool", .other)
        ]

        for (content, expected) in cases {
            XCTAssertEqual(CLITheme.ToolType.from(content), expected)
        }
    }

    func testToolTypeDisplayNameAndIcon() {
        let cases: [(CLITheme.ToolType, String, String)] = [
            (.bash, "Terminal", "terminal"),
            (.read, "Read", "doc.text"),
            (.write, "Write", "doc.badge.plus"),
            (.edit, "Edit", "pencil.line"),
            (.grep, "Search", "magnifyingglass"),
            (.glob, "Find", "folder.badge.questionmark"),
            (.task, "Agent", "person.crop.circle.badge.clock"),
            (.todoWrite, "Todo", "checklist"),
            (.webFetch, "Fetch", "globe"),
            (.webSearch, "Web", "globe.badge.chevron.backward"),
            (.askUser, "Ask", "questionmark.circle"),
            (.other, "Tool", "wrench")
        ]

        for (tool, displayName, icon) in cases {
            XCTAssertEqual(tool.displayName, displayName)
            XCTAssertEqual(tool.icon, icon)
        }
    }
}
