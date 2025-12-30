import SwiftUI
import UIKit
import XCTest
@testable import CodingBridge

final class ToolErrorClassificationTests: XCTestCase {

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

    private func assertCategory(
        _ category: ToolErrorCategory,
        icon: String,
        shortLabel: String,
        description: String,
        suggestedAction: String?,
        isTransient: Bool,
        lightColor: Color,
        darkColor: Color,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(category.icon, icon, file: file, line: line)
        XCTAssertEqual(category.shortLabel, shortLabel, file: file, line: line)
        XCTAssertEqual(category.description, description, file: file, line: line)
        XCTAssertEqual(category.suggestedAction, suggestedAction, file: file, line: line)
        XCTAssertEqual(category.isTransient, isTransient, file: file, line: line)
        assertColorEqual(category.color(for: .light), lightColor, file: file, line: line)
        assertColorEqual(category.color(for: .dark), darkColor, file: file, line: line)
    }

    // MARK: - ToolErrorCategory properties

    func test_toolErrorCategory_success_properties() {
        assertCategory(
            .success,
            icon: "checkmark.circle.fill",
            shortLabel: "OK",
            description: "Command completed successfully",
            suggestedAction: nil,
            isTransient: false,
            lightColor: CLITheme.green(for: .light),
            darkColor: CLITheme.green(for: .dark)
        )
    }

    func test_toolErrorCategory_gitError_properties() {
        assertCategory(
            .gitError,
            icon: "arrow.triangle.branch",
            shortLabel: "Git",
            description: "Git operation failed",
            suggestedAction: "Check git repository state and try again",
            isTransient: false,
            lightColor: Color(red: 0.85, green: 0.4, blue: 0.0),
            darkColor: Color(red: 1.0, green: 0.6, blue: 0.2)
        )
    }

    func test_toolErrorCategory_commandFailed_properties() {
        assertCategory(
            .commandFailed,
            icon: "xmark.circle",
            shortLabel: "Failed",
            description: "Command returned an error",
            suggestedAction: "Review command output for details",
            isTransient: false,
            lightColor: CLITheme.red(for: .light),
            darkColor: CLITheme.red(for: .dark)
        )
    }

    func test_toolErrorCategory_sshError_properties() {
        assertCategory(
            .sshError,
            icon: "network.slash",
            shortLabel: "SSH",
            description: "SSH connection issue",
            suggestedAction: "Connection will auto-retry; check network if persists",
            isTransient: true,
            lightColor: Color(red: 0.8, green: 0.2, blue: 0.2),
            darkColor: Color(red: 1.0, green: 0.4, blue: 0.4)
        )
    }

    func test_toolErrorCategory_invalidArgs_properties() {
        assertCategory(
            .invalidArgs,
            icon: "exclamationmark.triangle",
            shortLabel: "Args",
            description: "Invalid command arguments",
            suggestedAction: "Command syntax may be incorrect",
            isTransient: false,
            lightColor: CLITheme.yellow(for: .light),
            darkColor: CLITheme.yellow(for: .dark)
        )
    }

    func test_toolErrorCategory_commandNotFound_properties() {
        assertCategory(
            .commandNotFound,
            icon: "questionmark.app",
            shortLabel: "Not Found",
            description: "Command not found on system",
            suggestedAction: "Install the missing tool or check PATH",
            isTransient: false,
            lightColor: CLITheme.yellow(for: .light),
            darkColor: CLITheme.yellow(for: .dark)
        )
    }

    func test_toolErrorCategory_fileConflict_properties() {
        assertCategory(
            .fileConflict,
            icon: "doc.badge.clock",
            shortLabel: "Conflict",
            description: "File was modified by another process",
            suggestedAction: "Consider disabling editor formatOnSave",
            isTransient: false,
            lightColor: CLITheme.purple(for: .light),
            darkColor: CLITheme.purple(for: .dark)
        )
    }

    func test_toolErrorCategory_fileNotFound_properties() {
        assertCategory(
            .fileNotFound,
            icon: "doc.questionmark",
            shortLabel: "Missing",
            description: "File or path does not exist",
            suggestedAction: "Verify the file path exists",
            isTransient: false,
            lightColor: CLITheme.mutedText(for: .light),
            darkColor: CLITheme.mutedText(for: .dark)
        )
    }

    func test_toolErrorCategory_approvalRequired_properties() {
        assertCategory(
            .approvalRequired,
            icon: "lock.shield",
            shortLabel: "Approval",
            description: "Command requires user approval",
            suggestedAction: "Grant permission to continue",
            isTransient: false,
            lightColor: CLITheme.cyan(for: .light),
            darkColor: CLITheme.cyan(for: .dark)
        )
    }

    func test_toolErrorCategory_timeout_properties() {
        assertCategory(
            .timeout,
            icon: "clock.badge.exclamationmark",
            shortLabel: "Timeout",
            description: "Command timed out",
            suggestedAction: "Operation took too long; may need to retry",
            isTransient: true,
            lightColor: Color(red: 0.8, green: 0.5, blue: 0.0),
            darkColor: Color(red: 1.0, green: 0.7, blue: 0.3)
        )
    }

    func test_toolErrorCategory_permissionDenied_properties() {
        assertCategory(
            .permissionDenied,
            icon: "hand.raised",
            shortLabel: "Denied",
            description: "Permission denied",
            suggestedAction: "Check file/directory permissions",
            isTransient: false,
            lightColor: Color(red: 0.7, green: 0.3, blue: 0.5),
            darkColor: Color(red: 0.9, green: 0.5, blue: 0.7)
        )
    }

    func test_toolErrorCategory_unknown_properties() {
        assertCategory(
            .unknown,
            icon: "exclamationmark.circle",
            shortLabel: "Error",
            description: "An error occurred",
            suggestedAction: "Review the error details",
            isTransient: false,
            lightColor: CLITheme.red(for: .light),
            darkColor: CLITheme.red(for: .dark)
        )
    }

    // MARK: - ToolErrorCategory.from(exitCode:)

    func test_toolErrorCategory_fromExitCode_zero_isSuccess() {
        XCTAssertEqual(ToolErrorCategory.from(exitCode: 0), .success)
    }

    func test_toolErrorCategory_fromExitCode_one_isCommandFailed() {
        XCTAssertEqual(ToolErrorCategory.from(exitCode: 1), .commandFailed)
    }

    func test_toolErrorCategory_fromExitCode_126_isPermissionDenied() {
        XCTAssertEqual(ToolErrorCategory.from(exitCode: 126), .permissionDenied)
    }

    func test_toolErrorCategory_fromExitCode_127_isCommandNotFound() {
        XCTAssertEqual(ToolErrorCategory.from(exitCode: 127), .commandNotFound)
    }

    func test_toolErrorCategory_fromExitCode_128_isGitError() {
        XCTAssertEqual(ToolErrorCategory.from(exitCode: 128), .gitError)
    }

    func test_toolErrorCategory_fromExitCode_129_isInvalidArgs() {
        XCTAssertEqual(ToolErrorCategory.from(exitCode: 129), .invalidArgs)
    }

    func test_toolErrorCategory_fromExitCode_254_isSshError() {
        XCTAssertEqual(ToolErrorCategory.from(exitCode: 254), .sshError)
    }

    func test_toolErrorCategory_fromExitCode_signalRange_low() {
        XCTAssertEqual(ToolErrorCategory.from(exitCode: 130), .commandFailed)
    }

    func test_toolErrorCategory_fromExitCode_signalRange_high() {
        XCTAssertEqual(ToolErrorCategory.from(exitCode: 159), .commandFailed)
    }

    func test_toolErrorCategory_fromExitCode_160_isUnknown() {
        XCTAssertEqual(ToolErrorCategory.from(exitCode: 160), .unknown)
    }

    func test_toolErrorCategory_fromExitCode_other_isUnknown() {
        XCTAssertEqual(ToolErrorCategory.from(exitCode: 2), .unknown)
    }

    // MARK: - ToolErrorInfo

    func test_toolErrorInfo_initializesProperties() {
        let timestamp = Date(timeIntervalSince1970: 1234)
        let info = ToolErrorInfo(
            category: .commandFailed,
            exitCode: 1,
            stderr: "stderr",
            errorMessage: "error",
            rawOutput: "raw",
            toolName: "bash",
            timestamp: timestamp
        )

        XCTAssertEqual(info.category, .commandFailed)
        XCTAssertEqual(info.exitCode, 1)
        XCTAssertEqual(info.stderr, "stderr")
        XCTAssertEqual(info.errorMessage, "error")
        XCTAssertEqual(info.rawOutput, "raw")
        XCTAssertEqual(info.toolName, "bash")
        XCTAssertEqual(info.timestamp, timestamp)
    }

    func test_toolErrorInfo_isTransient_trueForTimeout() {
        let info = ToolErrorInfo(category: .timeout, rawOutput: "raw")

        XCTAssertTrue(info.isTransient)
    }

    func test_toolErrorInfo_isTransient_falseForCommandFailed() {
        let info = ToolErrorInfo(category: .commandFailed, rawOutput: "raw")

        XCTAssertFalse(info.isTransient)
    }

    func test_toolErrorInfo_errorSummary_prefersErrorMessageFirstLine() {
        let info = ToolErrorInfo(
            category: .commandFailed,
            stderr: "stderr",
            errorMessage: "Message line 1\nMessage line 2",
            rawOutput: "raw"
        )

        XCTAssertEqual(info.errorSummary, "Message line 1")
    }

    func test_toolErrorInfo_errorSummary_usesStderrWhenErrorMessageEmpty() {
        let info = ToolErrorInfo(
            category: .commandFailed,
            stderr: "stderr line 1\nstderr line 2",
            errorMessage: "",
            rawOutput: "raw"
        )

        XCTAssertEqual(info.errorSummary, "stderr line 1")
    }

    func test_toolErrorInfo_errorSummary_skipsExitCodePrefix() {
        let info = ToolErrorInfo(
            category: .commandFailed,
            rawOutput: "Exit code 1\nSomething bad\nMore"
        )

        XCTAssertEqual(info.errorSummary, "Something bad")
    }

    func test_toolErrorInfo_errorSummary_returnsFirstLineWhenNoExitCodePrefix() {
        let info = ToolErrorInfo(
            category: .commandFailed,
            rawOutput: "First line\nSecond line"
        )

        XCTAssertEqual(info.errorSummary, "First line")
    }

    func test_toolErrorInfo_errorSummary_returnsExitCodeLineWhenOnlyLine() {
        let info = ToolErrorInfo(
            category: .commandFailed,
            rawOutput: "Exit code 1"
        )

        XCTAssertEqual(info.errorSummary, "Exit code 1")
    }

    // MARK: - ToolResultParser.extractExitCode

    func test_extractExitCode_valid() {
        XCTAssertEqual(ToolResultParser.extractExitCode(from: "Exit code 128\nfatal"), 128)
    }

    func test_extractExitCode_validWithSuffix() {
        XCTAssertEqual(ToolResultParser.extractExitCode(from: "Exit code 1 fatal"), 1)
    }

    func test_extractExitCode_validZero() {
        XCTAssertEqual(ToolResultParser.extractExitCode(from: "Exit code 0"), 0)
    }

    func test_extractExitCode_invalidPrefix() {
        XCTAssertNil(ToolResultParser.extractExitCode(from: "exit code 1"))
    }

    func test_extractExitCode_invalidNumber() {
        XCTAssertNil(ToolResultParser.extractExitCode(from: "Exit code abc"))
    }

    func test_extractExitCode_missingNumber() {
        XCTAssertNil(ToolResultParser.extractExitCode(from: "Exit code "))
    }

    // MARK: - ToolResultParser.parse

    func test_parse_exitCodeSuccess_returnsSuccessCategory() {
        let result = ToolResultParser.parse("Exit code 0\nAll good")

        XCTAssertEqual(result.category, .success)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertNil(result.errorMessage)
    }

    func test_parse_exitCodeFailure_usesExitCodeCategory() {
        let result = ToolResultParser.parse("Exit code 128\nfatal: bad repo")

        XCTAssertEqual(result.category, .gitError)
        XCTAssertEqual(result.exitCode, 128)
    }

    func test_parse_fileConflictPattern_overridesExitCode() {
        let result = ToolResultParser.parse("Exit code 1\nFile was modified externally")

        XCTAssertEqual(result.category, .fileConflict)
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertEqual(result.errorMessage, "File was modified by another process (likely a linter)")
    }

    func test_parse_fileNotFound_extractsPath_noExitCode() {
        let result = ToolResultParser.parse("No such file or directory: /tmp/test.txt")

        XCTAssertEqual(result.category, .fileNotFound)
        XCTAssertEqual(result.errorMessage, "/tmp/test.txt")
        XCTAssertNil(result.exitCode)
    }

    func test_parse_fileNotFound_noPath_returnsNilErrorMessage() {
        let result = ToolResultParser.parse("File not found")

        XCTAssertEqual(result.category, .fileNotFound)
        XCTAssertNil(result.errorMessage)
    }

    func test_parse_fileNotFoundPattern_overridesExitCode() {
        let result = ToolResultParser.parse("Exit code 1\nNo such file or directory: /tmp/foo")

        XCTAssertEqual(result.category, .fileNotFound)
        XCTAssertEqual(result.errorMessage, "/tmp/foo")
        XCTAssertEqual(result.exitCode, 1)
    }

    func test_parse_approvalPattern_setsCategory() {
        let result = ToolResultParser.parse("This action requires approval")

        XCTAssertEqual(result.category, .approvalRequired)
    }

    func test_parse_approvalPattern_overridesExitCode() {
        let result = ToolResultParser.parse("Exit code 1\nApproval required")

        XCTAssertEqual(result.category, .approvalRequired)
        XCTAssertEqual(result.exitCode, 1)
    }

    func test_parse_permissionPattern_setsCategory() {
        let result = ToolResultParser.parse("Permission denied")

        XCTAssertEqual(result.category, .permissionDenied)
    }

    func test_parse_permissionPattern_overridesExitCode() {
        let result = ToolResultParser.parse("Exit code 1\nPermission denied")

        XCTAssertEqual(result.category, .permissionDenied)
        XCTAssertEqual(result.exitCode, 1)
    }

    func test_parse_timeoutPattern_setsCategory() {
        let result = ToolResultParser.parse("Operation timed out after 30s")

        XCTAssertEqual(result.category, .timeout)
    }

    func test_parse_timeoutPattern_overridesExitCode() {
        let result = ToolResultParser.parse("Exit code 1\noperation timed out")

        XCTAssertEqual(result.category, .timeout)
        XCTAssertEqual(result.exitCode, 1)
    }

    func test_parse_patternMatching_skippedForLongContentNoExitCode() {
        let longContent = String(repeating: "a", count: 510) + " timeout"
        let result = ToolResultParser.parse(longContent)

        XCTAssertEqual(result.category, .success)
        XCTAssertNil(result.exitCode)
    }

    func test_parse_patternMatching_appliesForLongContentWithExitCode() {
        let longContent = String(repeating: "a", count: 510) + " timed out"
        let result = ToolResultParser.parse("Exit code 1\n" + longContent)

        XCTAssertEqual(result.category, .timeout)
        XCTAssertEqual(result.exitCode, 1)
    }

    func test_parse_extractsStderr_fromJson() {
        let json = "{\"stderr\":\"boom\",\"stdout\":\"ok\"}"
        let result = ToolResultParser.parse(json)

        XCTAssertEqual(result.category, .success)
        XCTAssertEqual(result.stderr, "boom")
    }

    func test_parse_toolName_isPreserved() {
        let result = ToolResultParser.parse("Exit code 1\nerror", toolName: "bash")

        XCTAssertEqual(result.toolName, "bash")
    }

    func test_parse_noExitCode_shortContent_defaultsToSuccess() {
        let result = ToolResultParser.parse("All good")

        XCTAssertEqual(result.category, .success)
        XCTAssertNil(result.exitCode)
    }

    func test_parse_errorMessage_nilWhenNoPatternMatch() {
        let result = ToolResultParser.parse("Exit code 1\nSomething failed")

        XCTAssertEqual(result.category, .commandFailed)
        XCTAssertNil(result.errorMessage)
    }

    func test_parse_exitCodeZero_doesNotPatternMatchTimeout() {
        let result = ToolResultParser.parse("Exit code 0\nTimeout happened")

        XCTAssertEqual(result.category, .success)
        XCTAssertEqual(result.exitCode, 0)
    }
}
