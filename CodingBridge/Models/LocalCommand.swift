import Foundation

// MARK: - Local Command Model

/// Represents a local slash command executed in Claude Code CLI.
/// These commands are stored in session history with XML tags like:
/// `<command-name>/exit</command-name><command-message>exit</command-message><command-args></command-args>`
/// And their outputs:
/// `<local-command-stdout>See ya!</local-command-stdout>`
struct LocalCommand: Equatable, Sendable {
  /// The command name with slash (e.g., "/exit", "/clear", "/bump")
  let name: String

  /// The command message without slash (e.g., "exit", "clear", "bump")
  let message: String

  /// Arguments passed to the command (e.g., "patch" for /bump patch)
  let args: String

  /// Whether this is a command invocation or a stdout response
  let isStdout: Bool

  /// The stdout content (only set when isStdout is true)
  let stdout: String?

  /// Display-friendly command string
  var displayName: String {
    if isStdout {
      return stdout ?? ""
    }
    if args.isEmpty {
      return name
    }
    return "\(name) \(args)"
  }

  /// Icon for the command (SF Symbol name)
  var icon: String {
    if isStdout {
      return "text.bubble"
    }
    switch name {
    case "/exit": return "door.left.hand.open"
    case "/clear": return "trash"
    case "/compact": return "rectangle.compress.vertical"
    case "/bump": return "arrow.up.circle"
    case "/agents": return "person.3"
    case "/usage": return "chart.bar"
    case "/mcp": return "server.rack"
    case "/model": return "cpu"
    case "/resume": return "play.circle"
    case "/init": return "play"
    case "/help": return "questionmark.circle"
    case "/doctor": return "stethoscope"
    case "/stats": return "chart.line.uptrend.xyaxis"
    case "/login": return "person.badge.key"
    case "/theme": return "paintpalette"
    case "/plugin": return "puzzlepiece"
    default: return "terminal"
    }
  }

  /// Whether the command should be displayed (some commands like /clear have empty stdout)
  var shouldDisplay: Bool {
    if isStdout {
      // Show stdout if it has meaningful content
      guard let output = stdout else { return false }
      let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
      return !trimmed.isEmpty
    }
    return true
  }
}

// MARK: - Local Command Parser

enum LocalCommandParser {
  /// XML tag patterns for command parsing
  private static let commandNamePattern = "<command-name>([^<]*)</command-name>"
  private static let commandMessagePattern = "<command-message>([^<]*)</command-message>"
  private static let commandArgsPattern = "<command-args>([^<]*)</command-args>"
  private static let localCommandStdoutPattern = "<local-command-stdout>([\\s\\S]*?)</local-command-stdout>"

  /// Check if content contains local command XML tags
  static func isLocalCommand(_ content: String) -> Bool {
    content.contains("<command-name>") || content.contains("<local-command-stdout>")
  }

  /// Parse local command from XML content
  /// Returns nil if content doesn't contain valid command tags
  static func parse(_ content: String) -> LocalCommand? {
    // Check for stdout first (it's simpler)
    if content.contains("<local-command-stdout>") {
      if let stdout = extractTag(from: content, pattern: localCommandStdoutPattern) {
        // Strip ANSI escape codes from stdout
        let cleanedStdout = stripANSICodes(stdout)
        return LocalCommand(
          name: "",
          message: "",
          args: "",
          isStdout: true,
          stdout: cleanedStdout
        )
      }
    }

    // Parse command invocation
    guard content.contains("<command-name>") else { return nil }

    let name = extractTag(from: content, pattern: commandNamePattern) ?? ""
    let message = extractTag(from: content, pattern: commandMessagePattern) ?? ""
    let args = extractTag(from: content, pattern: commandArgsPattern) ?? ""

    // Require at least a command name
    guard !name.isEmpty else { return nil }

    return LocalCommand(
      name: name,
      message: message,
      args: args.trimmingCharacters(in: .whitespacesAndNewlines),
      isStdout: false,
      stdout: nil
    )
  }

  /// Extract content from XML tag using regex
  private static func extractTag(from content: String, pattern: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
          let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
          let range = Range(match.range(at: 1), in: content) else {
      return nil
    }
    return String(content[range])
  }

  /// Strip ANSI escape codes from terminal output
  private static func stripANSICodes(_ text: String) -> String {
    // Match ANSI escape sequences: ESC [ ... m (and other variants)
    let pattern = "\\x1B\\[[0-9;]*[a-zA-Z]"
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
      return text
    }
    let range = NSRange(text.startIndex..., in: text)
    return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
  }
}
