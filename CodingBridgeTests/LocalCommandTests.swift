import XCTest
@testable import CodingBridge

final class LocalCommandTests: XCTestCase {
    // MARK: - isLocalCommand Tests

    func testIsLocalCommand_withCommandTags_returnsTrue() {
        let content = "<command-name>/exit</command-name><command-message>exit</command-message><command-args></command-args>"
        XCTAssertTrue(LocalCommandParser.isLocalCommand(content))
    }

    func testIsLocalCommand_withStdoutTag_returnsTrue() {
        let content = "<local-command-stdout>See ya!</local-command-stdout>"
        XCTAssertTrue(LocalCommandParser.isLocalCommand(content))
    }

    func testIsLocalCommand_withPlainText_returnsFalse() {
        let content = "Hello, how can I help you?"
        XCTAssertFalse(LocalCommandParser.isLocalCommand(content))
    }

    func testIsLocalCommand_withPartialTag_returnsFalse() {
        let content = "command-name without brackets"
        XCTAssertFalse(LocalCommandParser.isLocalCommand(content))
    }

    // MARK: - Command Parsing Tests

    func testParse_exitCommand_parsesCorrectly() {
        let content = "<command-name>/exit</command-name>\n            <command-message>exit</command-message>\n            <command-args></command-args>"
        let command = LocalCommandParser.parse(content)

        XCTAssertNotNil(command)
        XCTAssertEqual(command?.name, "/exit")
        XCTAssertEqual(command?.message, "exit")
        XCTAssertEqual(command?.args, "")
        XCTAssertFalse(command?.isStdout ?? true)
        XCTAssertEqual(command?.displayName, "/exit")
    }

    func testParse_bumpCommandWithArgs_parsesCorrectly() {
        let content = "<command-name>/bump</command-name>\n            <command-message>bump</command-message>\n            <command-args>patch</command-args>"
        let command = LocalCommandParser.parse(content)

        XCTAssertNotNil(command)
        XCTAssertEqual(command?.name, "/bump")
        XCTAssertEqual(command?.message, "bump")
        XCTAssertEqual(command?.args, "patch")
        XCTAssertFalse(command?.isStdout ?? true)
        XCTAssertEqual(command?.displayName, "/bump patch")
    }

    func testParse_compactCommandWithLongArgs_parsesCorrectly() {
        let content = "<command-name>/compact</command-name>\n            <command-message>compact</command-message>\n            <command-args>to compact & continue</command-args>"
        let command = LocalCommandParser.parse(content)

        XCTAssertNotNil(command)
        XCTAssertEqual(command?.name, "/compact")
        XCTAssertEqual(command?.args, "to compact & continue")
        XCTAssertEqual(command?.displayName, "/compact to compact & continue")
    }

    // MARK: - Stdout Parsing Tests

    func testParse_stdoutWithContent_parsesCorrectly() {
        let content = "<local-command-stdout>See ya!</local-command-stdout>"
        let command = LocalCommandParser.parse(content)

        XCTAssertNotNil(command)
        XCTAssertTrue(command?.isStdout ?? false)
        XCTAssertEqual(command?.stdout, "See ya!")
        XCTAssertTrue(command?.shouldDisplay ?? false)
    }

    func testParse_stdoutEmpty_parsesCorrectly() {
        let content = "<local-command-stdout></local-command-stdout>"
        let command = LocalCommandParser.parse(content)

        XCTAssertNotNil(command)
        XCTAssertTrue(command?.isStdout ?? false)
        XCTAssertEqual(command?.stdout, "")
        XCTAssertFalse(command?.shouldDisplay ?? true)
    }

    func testParse_stdoutWithWhitespaceOnly_shouldNotDisplay() {
        let content = "<local-command-stdout>   \n\t  </local-command-stdout>"
        let command = LocalCommandParser.parse(content)

        XCTAssertNotNil(command)
        XCTAssertFalse(command?.shouldDisplay ?? true)
    }

    func testParse_compactedStdout_parsesCorrectly() {
        let content = "<local-command-stdout>Compacted (ctrl+o to see full summary)</local-command-stdout>"
        let command = LocalCommandParser.parse(content)

        XCTAssertNotNil(command)
        XCTAssertTrue(command?.isStdout ?? false)
        XCTAssertEqual(command?.stdout, "Compacted (ctrl+o to see full summary)")
        XCTAssertTrue(command?.shouldDisplay ?? false)
    }

    func testParse_multilineStdout_parsesCorrectly() {
        let content = "<local-command-stdout>Line 1\nLine 2\nLine 3</local-command-stdout>"
        let command = LocalCommandParser.parse(content)

        XCTAssertNotNil(command)
        XCTAssertEqual(command?.stdout, "Line 1\nLine 2\nLine 3")
    }

    // MARK: - Invalid Input Tests

    func testParse_plainText_returnsNil() {
        let content = "Just some regular text without command tags"
        let command = LocalCommandParser.parse(content)
        XCTAssertNil(command)
    }

    func testParse_emptyString_returnsNil() {
        let content = ""
        let command = LocalCommandParser.parse(content)
        XCTAssertNil(command)
    }

    func testParse_malformedTags_returnsNil() {
        let content = "<command-name>/exit<command-name>"  // Missing closing tag
        let command = LocalCommandParser.parse(content)
        XCTAssertNil(command)
    }

    // MARK: - Icon Tests

    func testIcon_exitCommand() {
        let command = LocalCommand(name: "/exit", message: "exit", args: "", isStdout: false, stdout: nil)
        XCTAssertEqual(command.icon, "door.left.hand.open")
    }

    func testIcon_clearCommand() {
        let command = LocalCommand(name: "/clear", message: "clear", args: "", isStdout: false, stdout: nil)
        XCTAssertEqual(command.icon, "trash")
    }

    func testIcon_bumpCommand() {
        let command = LocalCommand(name: "/bump", message: "bump", args: "patch", isStdout: false, stdout: nil)
        XCTAssertEqual(command.icon, "arrow.up.circle")
    }

    func testIcon_unknownCommand() {
        let command = LocalCommand(name: "/custom", message: "custom", args: "", isStdout: false, stdout: nil)
        XCTAssertEqual(command.icon, "terminal")
    }

    func testIcon_stdoutMessage() {
        let command = LocalCommand(name: "", message: "", args: "", isStdout: true, stdout: "Output")
        XCTAssertEqual(command.icon, "text.bubble")
    }

    // MARK: - ANSI Escape Code Tests

    func testParse_stdoutWithANSICodes_stripsCorrectly() {
        // ANSI escape codes for colored text
        let content = "<local-command-stdout>\u{1B}[32mSuccess\u{1B}[0m</local-command-stdout>"
        let command = LocalCommandParser.parse(content)

        XCTAssertNotNil(command)
        XCTAssertEqual(command?.stdout, "Success")
    }

    func testParse_stdoutWithMultipleANSICodes_stripsAll() {
        let content = "<local-command-stdout>\u{1B}[1m\u{1B}[31mError:\u{1B}[0m Something went wrong</local-command-stdout>"
        let command = LocalCommandParser.parse(content)

        XCTAssertNotNil(command)
        XCTAssertEqual(command?.stdout, "Error: Something went wrong")
    }

    // MARK: - Edge Cases

    func testParse_commandWithSpecialCharactersInArgs() {
        let content = "<command-name>/model</command-name><command-message>model</command-message><command-args>claude-sonnet-4-20250514</command-args>"
        let command = LocalCommandParser.parse(content)

        XCTAssertNotNil(command)
        XCTAssertEqual(command?.args, "claude-sonnet-4-20250514")
    }

    func testParse_pluginCommand() {
        let content = "<command-name>/pr-review-toolkit:review-pr</command-name><command-message>pr-review-toolkit:review-pr</command-message><command-args></command-args>"
        let command = LocalCommandParser.parse(content)

        XCTAssertNotNil(command)
        XCTAssertEqual(command?.name, "/pr-review-toolkit:review-pr")
        XCTAssertEqual(command?.icon, "terminal")  // Falls back to terminal for unknown commands
    }

    // MARK: - Real-World Examples from JSONL

    func testParse_dialogDismissedStdout() {
        let content = "<local-command-stdout>Status dialog dismissed</local-command-stdout>"
        let command = LocalCommandParser.parse(content)

        XCTAssertNotNil(command)
        XCTAssertEqual(command?.stdout, "Status dialog dismissed")
        XCTAssertTrue(command?.shouldDisplay ?? false)
    }

    func testParse_noConversationsStdout() {
        let content = "<local-command-stdout>No conversations found to resume</local-command-stdout>"
        let command = LocalCommandParser.parse(content)

        XCTAssertNotNil(command)
        XCTAssertEqual(command?.stdout, "No conversations found to resume")
    }
}
