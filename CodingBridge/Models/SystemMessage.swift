import Foundation

// MARK: - System Message Model

/// Represents a parsed system message from Claude Code CLI session history.
/// System messages have various subtypes with different structures.
struct SystemMessage: Equatable, Sendable {
  /// The subtype of the system message
  let subtype: Subtype

  /// Display content for UI
  let displayContent: String

  /// Additional metadata for specific subtypes
  let metadata: Metadata?

  /// Whether this message should be displayed in the chat UI
  var shouldDisplay: Bool {
    switch subtype {
    case .compactBoundary, .apiError:
      return true
    case .localCommand:
      // Local commands are handled separately by LocalCommandParser
      return false
    case .stopHookSummary, .unknown:
      // Internal tracking messages - hide from user
      return false
    }
  }

  /// System message subtypes
  enum Subtype: String, Sendable {
    case stopHookSummary = "stop_hook_summary"
    case compactBoundary = "compact_boundary"
    case localCommand = "local_command"
    case apiError = "api_error"
    case unknown

    init(rawValue: String) {
      switch rawValue {
      case "stop_hook_summary": self = .stopHookSummary
      case "compact_boundary": self = .compactBoundary
      case "local_command": self = .localCommand
      case "api_error": self = .apiError
      default: self = .unknown
      }
    }
  }

  /// Metadata for specific subtypes
  enum Metadata: Equatable, Sendable {
    case compact(trigger: String, preTokens: Int)
    case apiError(status: Int, retryAttempt: Int, maxRetries: Int)
  }

  /// Icon for the system message (SF Symbol name)
  var icon: String {
    switch subtype {
    case .compactBoundary: return "rectangle.compress.vertical"
    case .apiError: return "exclamationmark.triangle"
    case .localCommand: return "terminal"
    case .stopHookSummary: return "gearshape"
    case .unknown: return "info.circle"
    }
  }
}

// MARK: - System Message Parser

enum SystemMessageParser {
  /// JSON keys for system message parsing
  private enum Keys {
    static let subtype = "subtype"
    static let content = "content"
    static let level = "level"
    static let error = "error"
    static let status = "status"
    static let retryAttempt = "retryAttempt"
    static let maxRetries = "maxRetries"
    static let compactMetadata = "compactMetadata"
    static let trigger = "trigger"
    static let preTokens = "preTokens"
  }

  /// Check if content is a system message JSON that we can parse
  /// Note: This is for raw JSON strings, not for SystemStreamMessage content
  static func isSystemMessageJSON(_ content: String) -> Bool {
    content.contains("\"type\":\"system\"") && content.contains("\"subtype\":")
  }

  /// Parse a system message from JSON string
  /// Returns nil if the content is not a valid system message
  static func parseJSON(_ jsonString: String) -> SystemMessage? {
    guard let data = jsonString.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let subtypeStr = json[Keys.subtype] as? String else {
      return nil
    }

    let subtype = SystemMessage.Subtype(rawValue: subtypeStr)

    switch subtype {
    case .compactBoundary:
      return parseCompactBoundary(json: json)
    case .apiError:
      return parseAPIError(json: json)
    case .localCommand:
      // Local commands handled by LocalCommandParser
      return SystemMessage(subtype: .localCommand, displayContent: "", metadata: nil)
    case .stopHookSummary:
      return SystemMessage(subtype: .stopHookSummary, displayContent: "", metadata: nil)
    case .unknown:
      let content = json[Keys.content] as? String ?? ""
      return SystemMessage(subtype: .unknown, displayContent: content, metadata: nil)
    }
  }

  /// Parse from subtype string and content (for SystemStreamMessage)
  /// This is used when we already have the subtype extracted
  static func parse(subtype: String, content: String, rawJSON: [String: Any]? = nil) -> SystemMessage? {
    let messageSubtype = SystemMessage.Subtype(rawValue: subtype)

    switch messageSubtype {
    case .compactBoundary:
      var metadata: SystemMessage.Metadata?
      if let compactMeta = rawJSON?[Keys.compactMetadata] as? [String: Any],
         let trigger = compactMeta[Keys.trigger] as? String,
         let preTokens = compactMeta[Keys.preTokens] as? Int {
        metadata = .compact(trigger: trigger, preTokens: preTokens)
      }
      let displayContent = formatCompactBoundary(content: content, metadata: metadata)
      return SystemMessage(subtype: .compactBoundary, displayContent: displayContent, metadata: metadata)

    case .apiError:
      var metadata: SystemMessage.Metadata?
      if let errorInfo = rawJSON?[Keys.error] as? [String: Any],
         let status = errorInfo[Keys.status] as? Int,
         let retryAttempt = rawJSON?[Keys.retryAttempt] as? Int,
         let maxRetries = rawJSON?[Keys.maxRetries] as? Int {
        metadata = .apiError(status: status, retryAttempt: retryAttempt, maxRetries: maxRetries)
      }
      let displayContent = formatAPIError(content: content, metadata: metadata)
      return SystemMessage(subtype: .apiError, displayContent: displayContent, metadata: metadata)

    case .localCommand:
      // Local commands are handled by LocalCommandParser
      return nil

    case .stopHookSummary:
      // Hide hook summaries
      return nil

    case .unknown:
      guard !content.isEmpty else { return nil }
      return SystemMessage(subtype: .unknown, displayContent: content, metadata: nil)
    }
  }

  // MARK: - Private Parsers

  private static func parseCompactBoundary(json: [String: Any]) -> SystemMessage {
    let content = json[Keys.content] as? String ?? "Conversation compacted"
    var metadata: SystemMessage.Metadata?

    if let compactMeta = json[Keys.compactMetadata] as? [String: Any],
       let trigger = compactMeta[Keys.trigger] as? String,
       let preTokens = compactMeta[Keys.preTokens] as? Int {
      metadata = .compact(trigger: trigger, preTokens: preTokens)
    }

    let displayContent = formatCompactBoundary(content: content, metadata: metadata)
    return SystemMessage(subtype: .compactBoundary, displayContent: displayContent, metadata: metadata)
  }

  private static func parseAPIError(json: [String: Any]) -> SystemMessage {
    var metadata: SystemMessage.Metadata?

    if let errorInfo = json[Keys.error] as? [String: Any],
       let status = errorInfo[Keys.status] as? Int,
       let retryAttempt = json[Keys.retryAttempt] as? Int,
       let maxRetries = json[Keys.maxRetries] as? Int {
      metadata = .apiError(status: status, retryAttempt: retryAttempt, maxRetries: maxRetries)
    }

    let displayContent = formatAPIError(content: nil, metadata: metadata)
    return SystemMessage(subtype: .apiError, displayContent: displayContent, metadata: metadata)
  }

  // MARK: - Formatters

  private static func formatCompactBoundary(content: String, metadata: SystemMessage.Metadata?) -> String {
    if case .compact(let trigger, let preTokens) = metadata {
      let tokenCount = formatTokenCount(preTokens)
      let triggerText = trigger == "auto" ? "Auto-compacted" : "Compacted"
      return "\(triggerText) (\(tokenCount) tokens)"
    }
    return content
  }

  private static func formatAPIError(content: String?, metadata: SystemMessage.Metadata?) -> String {
    if case .apiError(let status, let retryAttempt, let maxRetries) = metadata {
      return "API Error \(status) (retry \(retryAttempt)/\(maxRetries))"
    }
    return content ?? "API Error"
  }

  private static func formatTokenCount(_ tokens: Int) -> String {
    if tokens >= 1000 {
      let k = Double(tokens) / 1000.0
      return String(format: "%.1fk", k)
    }
    return "\(tokens)"
  }
}
