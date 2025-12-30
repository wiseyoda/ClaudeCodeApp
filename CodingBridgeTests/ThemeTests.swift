import SwiftUI
import UIKit
import XCTest
@testable import CodingBridge

final class ThemeTests: XCTestCase {

    // MARK: - Base Colors

    func test_cliTheme_backgroundColor_dark() {
        assertColorEqual(
            CLITheme.background(for: .dark),
            Color(red: 0.08, green: 0.08, blue: 0.08)
        )
    }

    func test_cliTheme_backgroundColor_light() {
        assertColorEqual(
            CLITheme.background(for: .light),
            Color(red: 0.96, green: 0.96, blue: 0.96)
        )
    }

    func test_cliTheme_secondaryBackgroundColor_dark() {
        assertColorEqual(
            CLITheme.secondaryBackground(for: .dark),
            Color(red: 0.12, green: 0.12, blue: 0.12)
        )
    }

    func test_cliTheme_secondaryBackgroundColor_light() {
        assertColorEqual(
            CLITheme.secondaryBackground(for: .light),
            Color.white
        )
    }

    func test_cliTheme_primaryText_dark() {
        assertColorEqual(
            CLITheme.primaryText(for: .dark),
            Color.white
        )
    }

    func test_cliTheme_primaryText_light() {
        assertColorEqual(
            CLITheme.primaryText(for: .light),
            Color(red: 0.1, green: 0.1, blue: 0.1)
        )
    }

    func test_cliTheme_secondaryText_dark() {
        assertColorEqual(
            CLITheme.secondaryText(for: .dark),
            Color(white: 0.6)
        )
    }

    func test_cliTheme_secondaryText_light() {
        assertColorEqual(
            CLITheme.secondaryText(for: .light),
            Color(white: 0.4)
        )
    }

    func test_cliTheme_mutedText_dark() {
        assertColorEqual(
            CLITheme.mutedText(for: .dark),
            Color(white: 0.4)
        )
    }

    func test_cliTheme_mutedText_light() {
        assertColorEqual(
            CLITheme.mutedText(for: .light),
            Color(white: 0.55)
        )
    }

    // MARK: - Accent Colors

    func test_cliTheme_green_dark() {
        assertColorEqual(
            CLITheme.green(for: .dark),
            Color(red: 0.4, green: 0.8, blue: 0.4)
        )
    }

    func test_cliTheme_green_light() {
        assertColorEqual(
            CLITheme.green(for: .light),
            Color(red: 0.2, green: 0.6, blue: 0.2)
        )
    }

    func test_cliTheme_yellow_dark() {
        assertColorEqual(
            CLITheme.yellow(for: .dark),
            Color(red: 0.9, green: 0.8, blue: 0.4)
        )
    }

    func test_cliTheme_yellow_light() {
        assertColorEqual(
            CLITheme.yellow(for: .light),
            Color(red: 0.7, green: 0.55, blue: 0.0)
        )
    }

    func test_cliTheme_orange_dark() {
        assertColorEqual(
            CLITheme.orange(for: .dark),
            Color(red: 0.9, green: 0.6, blue: 0.3)
        )
    }

    func test_cliTheme_orange_light() {
        assertColorEqual(
            CLITheme.orange(for: .light),
            Color(red: 0.85, green: 0.45, blue: 0.1)
        )
    }

    func test_cliTheme_red_dark() {
        assertColorEqual(
            CLITheme.red(for: .dark),
            Color(red: 0.9, green: 0.4, blue: 0.4)
        )
    }

    func test_cliTheme_red_light() {
        assertColorEqual(
            CLITheme.red(for: .light),
            Color(red: 0.8, green: 0.25, blue: 0.25)
        )
    }

    func test_cliTheme_cyan_dark() {
        assertColorEqual(
            CLITheme.cyan(for: .dark),
            Color(red: 0.4, green: 0.8, blue: 0.9)
        )
    }

    func test_cliTheme_cyan_light() {
        assertColorEqual(
            CLITheme.cyan(for: .light),
            Color(red: 0.0, green: 0.55, blue: 0.7)
        )
    }

    func test_cliTheme_purple_dark() {
        assertColorEqual(
            CLITheme.purple(for: .dark),
            Color(red: 0.7, green: 0.5, blue: 0.9)
        )
    }

    func test_cliTheme_purple_light() {
        assertColorEqual(
            CLITheme.purple(for: .light),
            Color(red: 0.5, green: 0.3, blue: 0.7)
        )
    }

    func test_cliTheme_blue_dark() {
        assertColorEqual(
            CLITheme.blue(for: .dark),
            Color(red: 0.4, green: 0.6, blue: 0.9)
        )
    }

    func test_cliTheme_blue_light() {
        assertColorEqual(
            CLITheme.blue(for: .light),
            Color(red: 0.2, green: 0.4, blue: 0.8)
        )
    }

    // MARK: - Tool Type

    func test_cliTheme_toolType_allCasesCount() {
        XCTAssertEqual(CLITheme.ToolType.allCases.count, 14)
    }

    func test_cliTheme_toolType_from_parsesKnownTypes() {
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
            ("LSP(request: completion)", .lsp),
            ("TaskOutput(result: ok)", .taskOutput),
            ("UnknownTool", .other)
        ]

        for (content, expected) in cases {
            XCTAssertEqual(CLITheme.ToolType.from(content), expected)
        }
    }

    func test_cliTheme_toolType_iconAndDisplayName() {
        let cases: [(CLITheme.ToolType, String, String)] = [
            (.bash, "terminal", "Terminal"),
            (.read, "doc.text", "Read"),
            (.write, "doc.badge.plus", "Write"),
            (.edit, "pencil.line", "Edit"),
            (.grep, "magnifyingglass", "Search"),
            (.glob, "folder.badge.questionmark", "Find"),
            (.task, "person.crop.circle.badge.clock", "Agent"),
            (.todoWrite, "checklist", "Todo"),
            (.webFetch, "globe", "Fetch"),
            (.webSearch, "globe.badge.chevron.backward", "Web"),
            (.askUser, "questionmark.circle", "Ask"),
            (.lsp, "chevron.left.forwardslash.chevron.right", "LSP"),
            (.taskOutput, "arrow.down.doc", "Output"),
            (.other, "wrench", "Tool")
        ]

        for (tool, icon, displayName) in cases {
            XCTAssertEqual(tool.icon, icon)
            XCTAssertEqual(tool.displayName, displayName)
        }
    }

    // MARK: - Tool Colors

    func test_cliTheme_toolColor_dark() {
        let cases: [(CLITheme.ToolType, Color)] = [
            (.bash, Color(red: 1.0, green: 0.6, blue: 0.2)),
            (.read, Color(red: 0.4, green: 0.7, blue: 1.0)),
            (.write, Color(red: 0.3, green: 0.85, blue: 0.5)),
            (.edit, Color(red: 1.0, green: 0.85, blue: 0.3)),
            (.grep, Color(red: 0.8, green: 0.5, blue: 1.0)),
            (.glob, Color(red: 0.4, green: 0.9, blue: 0.9)),
            (.task, Color(red: 1.0, green: 0.5, blue: 0.7)),
            (.todoWrite, Color(red: 0.5, green: 0.9, blue: 0.5)),
            (.webFetch, Color(red: 0.4, green: 0.8, blue: 0.9)),
            (.webSearch, Color(red: 0.4, green: 0.8, blue: 0.9)),
            (.askUser, Color(red: 0.9, green: 0.7, blue: 0.3)),
            (.lsp, Color(red: 0.6, green: 0.8, blue: 1.0)),
            (.taskOutput, Color(red: 0.7, green: 0.9, blue: 0.6)),
            (.other, Color(red: 0.6, green: 0.6, blue: 0.6))
        ]

        for (tool, expected) in cases {
            assertColorEqual(CLITheme.toolColor(for: tool, scheme: .dark), expected)
        }
    }

    func test_cliTheme_toolColor_light() {
        let cases: [(CLITheme.ToolType, Color)] = [
            (.bash, Color(red: 0.85, green: 0.4, blue: 0.0)),
            (.read, Color(red: 0.2, green: 0.5, blue: 0.9)),
            (.write, Color(red: 0.15, green: 0.65, blue: 0.3)),
            (.edit, Color(red: 0.75, green: 0.6, blue: 0.0)),
            (.grep, Color(red: 0.55, green: 0.3, blue: 0.8)),
            (.glob, Color(red: 0.0, green: 0.6, blue: 0.7)),
            (.task, Color(red: 0.85, green: 0.3, blue: 0.5)),
            (.todoWrite, Color(red: 0.2, green: 0.7, blue: 0.3)),
            (.webFetch, Color(red: 0.1, green: 0.55, blue: 0.65)),
            (.webSearch, Color(red: 0.1, green: 0.55, blue: 0.65)),
            (.askUser, Color(red: 0.7, green: 0.5, blue: 0.1)),
            (.lsp, Color(red: 0.3, green: 0.5, blue: 0.8)),
            (.taskOutput, Color(red: 0.4, green: 0.65, blue: 0.3)),
            (.other, Color(red: 0.4, green: 0.4, blue: 0.4))
        ]

        for (tool, expected) in cases {
            assertColorEqual(CLITheme.toolColor(for: tool, scheme: .light), expected)
        }
    }

    // MARK: - Diff Colors

    func test_cliTheme_diffAdded_dark() {
        assertColorEqual(
            CLITheme.diffAdded(for: .dark),
            Color(red: 0.2, green: 0.3, blue: 0.2)
        )
    }

    func test_cliTheme_diffAdded_light() {
        assertColorEqual(
            CLITheme.diffAdded(for: .light),
            Color(red: 0.85, green: 0.95, blue: 0.85)
        )
    }

    func test_cliTheme_diffRemoved_dark() {
        assertColorEqual(
            CLITheme.diffRemoved(for: .dark),
            Color(red: 0.3, green: 0.2, blue: 0.2)
        )
    }

    func test_cliTheme_diffRemoved_light() {
        assertColorEqual(
            CLITheme.diffRemoved(for: .light),
            Color(red: 0.95, green: 0.85, blue: 0.85)
        )
    }

    func test_cliTheme_diffAddedText_dark() {
        assertColorEqual(
            CLITheme.diffAddedText(for: .dark),
            Color(red: 0.5, green: 0.9, blue: 0.5)
        )
    }

    func test_cliTheme_diffAddedText_light() {
        assertColorEqual(
            CLITheme.diffAddedText(for: .light),
            Color(red: 0.15, green: 0.5, blue: 0.15)
        )
    }

    func test_cliTheme_diffRemovedText_dark() {
        assertColorEqual(
            CLITheme.diffRemovedText(for: .dark),
            Color(red: 0.9, green: 0.5, blue: 0.5)
        )
    }

    func test_cliTheme_diffRemovedText_light() {
        assertColorEqual(
            CLITheme.diffRemovedText(for: .light),
            Color(red: 0.6, green: 0.15, blue: 0.15)
        )
    }

    // MARK: - Glass Tint

    func test_cliTheme_glassTint_colors_dark() {
        let scheme: ColorScheme = .dark
        let cases: [(CLITheme.GlassTint, Color)] = [
            (.primary, CLITheme.blue(for: scheme)),
            (.success, CLITheme.green(for: scheme)),
            (.warning, CLITheme.yellow(for: scheme)),
            (.error, CLITheme.red(for: scheme)),
            (.info, CLITheme.cyan(for: scheme)),
            (.accent, CLITheme.purple(for: scheme)),
            (.neutral, CLITheme.mutedText(for: scheme))
        ]

        for (tint, expected) in cases {
            assertColorEqual(tint.color(for: scheme), expected)
        }
    }

    func test_cliTheme_glassTint_colors_light() {
        let scheme: ColorScheme = .light
        let cases: [(CLITheme.GlassTint, Color)] = [
            (.primary, CLITheme.blue(for: scheme)),
            (.success, CLITheme.green(for: scheme)),
            (.warning, CLITheme.yellow(for: scheme)),
            (.error, CLITheme.red(for: scheme)),
            (.info, CLITheme.cyan(for: scheme)),
            (.accent, CLITheme.purple(for: scheme)),
            (.neutral, CLITheme.mutedText(for: scheme))
        ]

        for (tint, expected) in cases {
            assertColorEqual(tint.color(for: scheme), expected)
        }
    }

    // MARK: - Connection Status Indicator

    func test_connectionStatusIndicator_dotColor_dark() {
        let scheme: ColorScheme = .dark
        assertColorEqual(ConnectionStatusIndicator.dotColor(for: .connected, scheme: scheme), CLITheme.green(for: scheme))
        assertColorEqual(ConnectionStatusIndicator.dotColor(for: .connecting, scheme: scheme), CLITheme.yellow(for: scheme))
        assertColorEqual(ConnectionStatusIndicator.dotColor(for: .reconnecting(attempt: 1), scheme: scheme), CLITheme.yellow(for: scheme))
        assertColorEqual(ConnectionStatusIndicator.dotColor(for: .disconnected, scheme: scheme), CLITheme.red(for: scheme))
    }

    func test_connectionStatusIndicator_dotColor_light() {
        let scheme: ColorScheme = .light
        assertColorEqual(ConnectionStatusIndicator.dotColor(for: .connected, scheme: scheme), CLITheme.green(for: scheme))
        assertColorEqual(ConnectionStatusIndicator.dotColor(for: .connecting, scheme: scheme), CLITheme.yellow(for: scheme))
        assertColorEqual(ConnectionStatusIndicator.dotColor(for: .reconnecting(attempt: 2), scheme: scheme), CLITheme.yellow(for: scheme))
        assertColorEqual(ConnectionStatusIndicator.dotColor(for: .disconnected, scheme: scheme), CLITheme.red(for: scheme))
    }

    // MARK: - Helpers

    private func rgbaComponents(for color: Color) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return (red, green, blue, alpha)
        }
        var white: CGFloat = 0
        if uiColor.getWhite(&white, alpha: &alpha) {
            return (white, white, white, alpha)
        }
        return (0, 0, 0, 0)
    }

    private func assertColorEqual(
        _ actual: Color,
        _ expected: Color,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actualComponents = rgbaComponents(for: actual)
        let expectedComponents = rgbaComponents(for: expected)
        XCTAssertEqual(actualComponents.0, expectedComponents.0, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(actualComponents.1, expectedComponents.1, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(actualComponents.2, expectedComponents.2, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(actualComponents.3, expectedComponents.3, accuracy: 0.01, file: file, line: line)
    }
}
