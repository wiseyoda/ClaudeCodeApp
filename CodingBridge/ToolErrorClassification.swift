import Foundation
import SwiftUI

// MARK: - Tool Error Category

/// Categories of errors that occur during Claude CLI tool execution
enum ToolErrorCategory: String, Codable, CaseIterable {
    case success            // Exit code 0 - no error
    case gitError           // Exit code 128 - git operations failed
    case commandFailed      // Exit code 1 - general command failure
    case sshError           // Exit code 254 - SSH connection issues
    case invalidArgs        // Exit code 129 - invalid command arguments
    case commandNotFound    // Exit code 127 - command doesn't exist
    case fileConflict       // "File modified since read" - linter conflicts
    case fileNotFound       // Read tool on non-existent files
    case approvalRequired   // Bash command needs user permission
    case timeout            // Command timed out
    case permissionDenied   // Exit code 126 or permission errors
    case unknown            // Unclassified error

    // MARK: - Display Properties

    /// SF Symbol icon for this error category
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .gitError: return "arrow.triangle.branch"
        case .commandFailed: return "xmark.circle"
        case .sshError: return "network.slash"
        case .invalidArgs: return "exclamationmark.triangle"
        case .commandNotFound: return "questionmark.app"
        case .fileConflict: return "doc.badge.clock"
        case .fileNotFound: return "doc.questionmark"
        case .approvalRequired: return "lock.shield"
        case .timeout: return "clock.badge.exclamationmark"
        case .permissionDenied: return "hand.raised"
        case .unknown: return "exclamationmark.circle"
        }
    }

    /// Short label for badge display
    var shortLabel: String {
        switch self {
        case .success: return "OK"
        case .gitError: return "Git"
        case .commandFailed: return "Failed"
        case .sshError: return "SSH"
        case .invalidArgs: return "Args"
        case .commandNotFound: return "Not Found"
        case .fileConflict: return "Conflict"
        case .fileNotFound: return "Missing"
        case .approvalRequired: return "Approval"
        case .timeout: return "Timeout"
        case .permissionDenied: return "Denied"
        case .unknown: return "Error"
        }
    }

    /// Full description for error details
    var description: String {
        switch self {
        case .success: return "Command completed successfully"
        case .gitError: return "Git operation failed"
        case .commandFailed: return "Command returned an error"
        case .sshError: return "SSH connection issue"
        case .invalidArgs: return "Invalid command arguments"
        case .commandNotFound: return "Command not found on system"
        case .fileConflict: return "File was modified by another process"
        case .fileNotFound: return "File or path does not exist"
        case .approvalRequired: return "Command requires user approval"
        case .timeout: return "Command timed out"
        case .permissionDenied: return "Permission denied"
        case .unknown: return "An error occurred"
        }
    }

    /// Color for the error category
    func color(for scheme: ColorScheme) -> Color {
        switch self {
        case .success:
            return CLITheme.green(for: scheme)
        case .gitError:
            return scheme == .dark
                ? Color(red: 1.0, green: 0.6, blue: 0.2)  // Orange
                : Color(red: 0.85, green: 0.4, blue: 0.0)
        case .commandFailed, .unknown:
            return CLITheme.red(for: scheme)
        case .sshError:
            return scheme == .dark
                ? Color(red: 1.0, green: 0.4, blue: 0.4)  // Bright red
                : Color(red: 0.8, green: 0.2, blue: 0.2)
        case .invalidArgs, .commandNotFound:
            return CLITheme.yellow(for: scheme)
        case .fileConflict:
            return CLITheme.purple(for: scheme)
        case .fileNotFound:
            return CLITheme.mutedText(for: scheme)
        case .approvalRequired:
            return CLITheme.cyan(for: scheme)
        case .timeout:
            return scheme == .dark
                ? Color(red: 1.0, green: 0.7, blue: 0.3)  // Amber
                : Color(red: 0.8, green: 0.5, blue: 0.0)
        case .permissionDenied:
            return scheme == .dark
                ? Color(red: 0.9, green: 0.5, blue: 0.7)  // Pink
                : Color(red: 0.7, green: 0.3, blue: 0.5)
        }
    }

    /// Whether this error type is typically transient (can be retried)
    var isTransient: Bool {
        switch self {
        case .sshError, .timeout:
            return true
        default:
            return false
        }
    }

    /// Suggested action for the user
    var suggestedAction: String? {
        switch self {
        case .success: return nil
        case .gitError: return "Check git repository state and try again"
        case .commandFailed: return "Review command output for details"
        case .sshError: return "Connection will auto-retry; check network if persists"
        case .invalidArgs: return "Command syntax may be incorrect"
        case .commandNotFound: return "Install the missing tool or check PATH"
        case .fileConflict: return "Consider disabling editor formatOnSave"
        case .fileNotFound: return "Verify the file path exists"
        case .approvalRequired: return "Grant permission to continue"
        case .timeout: return "Operation took too long; may need to retry"
        case .permissionDenied: return "Check file/directory permissions"
        case .unknown: return "Review the error details"
        }
    }

    // MARK: - Exit Code Mapping

    /// Create category from exit code
    static func from(exitCode: Int) -> ToolErrorCategory {
        switch exitCode {
        case 0: return .success
        case 1: return .commandFailed
        case 126: return .permissionDenied
        case 127: return .commandNotFound
        case 128: return .gitError
        case 129: return .invalidArgs
        case 254: return .sshError
        default:
            // Exit codes 128+ are often signal-related (128 + signal number)
            if exitCode > 128 && exitCode < 160 {
                return .commandFailed
            }
            return .unknown
        }
    }
}

// MARK: - Tool Error Info

/// Detailed information about a tool execution error
struct ToolErrorInfo: Codable, Equatable {
    let category: ToolErrorCategory
    let exitCode: Int?
    let stderr: String?
    let errorMessage: String?
    let rawOutput: String
    let toolName: String?
    let timestamp: Date

    /// Whether this error can likely be resolved by retrying
    var isTransient: Bool {
        category.isTransient
    }

    /// First line of error output for quick display
    var errorSummary: String {
        // Priority: explicit error message > first stderr line > first output line
        if let msg = errorMessage, !msg.isEmpty {
            return msg.components(separatedBy: "\n").first ?? msg
        }
        if let err = stderr, !err.isEmpty {
            return err.components(separatedBy: "\n").first ?? err
        }
        // Skip the "Exit code X" prefix if present
        let lines = rawOutput.components(separatedBy: "\n")
        if lines.count > 1 && lines[0].hasPrefix("Exit code ") {
            return lines[1]
        }
        return lines.first ?? rawOutput
    }

    init(
        category: ToolErrorCategory,
        exitCode: Int? = nil,
        stderr: String? = nil,
        errorMessage: String? = nil,
        rawOutput: String,
        toolName: String? = nil,
        timestamp: Date = Date()
    ) {
        self.category = category
        self.exitCode = exitCode
        self.stderr = stderr
        self.errorMessage = errorMessage
        self.rawOutput = rawOutput
        self.toolName = toolName
        self.timestamp = timestamp
    }
}

// MARK: - Tool Result Parser

/// Parses tool results to extract structured error information
struct ToolResultParser {

    // MARK: - Pattern Detection

    /// Patterns that indicate "file modified since read" errors
    private static let fileConflictPatterns = [
        "file has been modified since reading",
        "File was modified externally",
        "content mismatch",
        "file changed since last read",
        "The file has been modified"
    ]

    /// Patterns that indicate file not found
    private static let fileNotFoundPatterns = [
        "No such file or directory",
        "File not found",
        "does not exist",
        "ENOENT",
        "path not found"
    ]

    /// Patterns that indicate approval is required
    private static let approvalPatterns = [
        "requires approval",
        "approval required",
        "Approval required",
        "permission denied by user",
        "user rejected"
    ]

    /// Patterns that indicate permission denied
    private static let permissionPatterns = [
        "Permission denied",
        "EACCES",
        "Operation not permitted",
        "access denied"
    ]

    /// Patterns that indicate timeout
    private static let timeoutPatterns = [
        "timed out",
        "timeout",
        "Timeout",
        "operation timed out",
        "exceeded time limit"
    ]

    // MARK: - Parsing

    /// Parse a tool result string into structured error info
    /// - Parameters:
    ///   - content: The raw tool result content
    ///   - toolName: Optional name of the tool that produced this result
    /// - Returns: Parsed error info, or nil if this is a success with no special handling needed
    static func parse(_ content: String, toolName: String? = nil) -> ToolErrorInfo {
        // First, try to extract exit code from bash-style results
        let exitCode = extractExitCode(from: content)
        var category: ToolErrorCategory = .unknown
        var stderr: String? = nil
        var errorMessage: String? = nil

        // Determine category from exit code first
        if let code = exitCode {
            category = ToolErrorCategory.from(exitCode: code)
        }

        // Only apply pattern matching if we have evidence of an error:
        // 1. Exit code indicates failure, OR
        // 2. Content is short (likely an error message, not file content)
        // This prevents false positives like "timeout" appearing in code being read
        let shouldPatternMatch = (exitCode != nil && exitCode != 0) ||
                                 (exitCode == nil && content.count < 500)

        if shouldPatternMatch {
            // Override category based on pattern matching for more specificity
            if matchesAnyPattern(content, patterns: fileConflictPatterns) {
                category = .fileConflict
                errorMessage = "File was modified by another process (likely a linter)"
            } else if matchesAnyPattern(content, patterns: fileNotFoundPatterns) {
                category = .fileNotFound
                errorMessage = extractFileNotFoundPath(from: content)
            } else if matchesAnyPattern(content, patterns: approvalPatterns) {
                category = .approvalRequired
            } else if matchesAnyPattern(content, patterns: permissionPatterns) {
                category = .permissionDenied
            } else if matchesAnyPattern(content, patterns: timeoutPatterns) {
                category = .timeout
            }
        }

        // Try to extract stderr if present in structured output
        stderr = extractStderr(from: content)

        // If no exit code and no pattern matched, check if it looks like success
        if exitCode == nil && category == .unknown {
            // Assume success if no error indicators
            category = .success
        }

        return ToolErrorInfo(
            category: category,
            exitCode: exitCode,
            stderr: stderr,
            errorMessage: errorMessage,
            rawOutput: content,
            toolName: toolName
        )
    }

    // MARK: - Extraction Helpers

    /// Extract exit code from content like "Exit code 128\nfatal: ..."
    static func extractExitCode(from content: String) -> Int? {
        guard content.hasPrefix("Exit code ") else { return nil }
        let scanner = Scanner(string: content)
        _ = scanner.scanString("Exit code ")
        var exitCode: Int = 0
        if scanner.scanInt(&exitCode) {
            return exitCode
        }
        return nil
    }

    /// Extract stderr from structured output (JSON with stderr field)
    private static func extractStderr(from content: String) -> String? {
        // Try to parse as JSON with stderr field
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let stderr = json["stderr"] as? String,
              !stderr.isEmpty else {
            return nil
        }
        return stderr
    }

    /// Extract file path from "file not found" errors
    private static func extractFileNotFoundPath(from content: String) -> String? {
        // Pattern: "No such file or directory: /path/to/file"
        if let range = content.range(of: "No such file or directory:") {
            let remainder = String(content[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            return remainder.components(separatedBy: "\n").first
        }
        // Pattern: "File not found: /path/to/file"
        if let range = content.range(of: "not found:") {
            let remainder = String(content[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            return remainder.components(separatedBy: "\n").first
        }
        return nil
    }

    /// Check if content matches any of the given patterns (case-insensitive)
    private static func matchesAnyPattern(_ content: String, patterns: [String]) -> Bool {
        let lowercased = content.lowercased()
        return patterns.contains { lowercased.contains($0.lowercased()) }
    }
}
