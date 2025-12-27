import Foundation

// MARK: - Project Models (new claudecodeui API)

struct Project: Codable, Identifiable {
    let name: String
    let path: String
    let displayName: String?
    let fullPath: String?
    let sessions: [ProjectSession]?

    var id: String { path }

    // For display, prefer displayName, then name cleaned up
    var title: String {
        if let display = displayName, !display.isEmpty {
            return display
        }
        return name.replacingOccurrences(of: "-home-dev-workspace-", with: "")
    }

    enum CodingKeys: String, CodingKey {
        case name, path, displayName, fullPath, sessions
    }
}

struct ProjectSession: Codable, Identifiable {
    let id: String
    let summary: String?
    let messageCount: Int?
    let lastActivity: String?
    let lastUserMessage: String?
    let lastAssistantMessage: String?
}

// MARK: - Message for UI

struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    var isStreaming: Bool = false
    var imageData: Data?  // Optional image attachment

    enum Role: String, Codable {
        case user
        case assistant
        case system
        case error
        case toolUse
        case toolResult
        case resultSuccess
        case thinking  // For reasoning/thinking blocks
    }

    init(role: Role, content: String, timestamp: Date = Date(), isStreaming: Bool = false, imageData: Data? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.imageData = imageData
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Message Persistence

class MessageStore {
    private static let maxMessages = 50
    private static let keyPrefix = "chat_messages_"

    /// Get the storage key for a project
    private static func key(for projectPath: String) -> String {
        // Create a safe key from project path
        let safeKey = projectPath
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        return keyPrefix + safeKey
    }

    /// Load messages for a project
    static func loadMessages(for projectPath: String) -> [ChatMessage] {
        let key = key(for: projectPath)
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return []
        }

        do {
            let messages = try JSONDecoder().decode([ChatMessage].self, from: data)
            print("[MessageStore] Loaded \(messages.count) messages for \(projectPath)")
            return messages
        } catch {
            print("[MessageStore] Failed to decode messages: \(error)")
            return []
        }
    }

    /// Save messages for a project (keeps last 50)
    static func saveMessages(_ messages: [ChatMessage], for projectPath: String) {
        let key = key(for: projectPath)

        // Keep only the last maxMessages, excluding streaming messages
        let persistableMessages = messages
            .filter { !$0.isStreaming }
            .suffix(maxMessages)

        do {
            let data = try JSONEncoder().encode(Array(persistableMessages))
            UserDefaults.standard.set(data, forKey: key)
            print("[MessageStore] Saved \(persistableMessages.count) messages for \(projectPath)")
        } catch {
            print("[MessageStore] Failed to encode messages: \(error)")
        }
    }

    /// Clear messages for a project
    static func clearMessages(for projectPath: String) {
        let key = key(for: projectPath)
        UserDefaults.standard.removeObject(forKey: key)
        print("[MessageStore] Cleared messages for \(projectPath)")
    }

    // MARK: - Draft Persistence

    private static let draftPrefix = "draft_input_"

    private static func draftKey(for projectPath: String) -> String {
        let safeKey = projectPath
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        return draftPrefix + safeKey
    }

    /// Load draft input for a project
    static func loadDraft(for projectPath: String) -> String {
        let key = draftKey(for: projectPath)
        return UserDefaults.standard.string(forKey: key) ?? ""
    }

    /// Save draft input for a project
    static func saveDraft(_ text: String, for projectPath: String) {
        let key = draftKey(for: projectPath)
        if text.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(text, forKey: key)
        }
    }

    /// Clear draft for a project
    static func clearDraft(for projectPath: String) {
        let key = draftKey(for: projectPath)
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - Session History Loader

/// Loads full session history from JSONL files on the server via SSH
class SessionHistoryLoader {

    /// Parse a session JSONL file content into ChatMessages
    static func parseSessionHistory(_ jsonlContent: String) -> [ChatMessage] {
        var messages: [ChatMessage] = []
        let lines = jsonlContent.components(separatedBy: .newlines)

        for line in lines {
            guard !line.isEmpty else { continue }
            guard let data = line.data(using: .utf8) else { continue }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let chatMessage = parseJSONLLine(json) {
                        messages.append(chatMessage)
                    }
                }
            } catch {
                print("[SessionHistoryLoader] Failed to parse line: \(error)")
            }
        }

        return messages
    }

    private static func parseJSONLLine(_ json: [String: Any]) -> ChatMessage? {
        guard let type = json["type"] as? String else { return nil }
        guard let timestamp = parseTimestamp(json["timestamp"]) else { return nil }

        switch type {
        case "user":
            return parseUserMessage(json, timestamp: timestamp)
        case "assistant":
            return parseAssistantMessage(json, timestamp: timestamp)
        default:
            // Skip queue-operation, system, etc.
            return nil
        }
    }

    private static func parseTimestamp(_ value: Any?) -> Date? {
        guard let timestampStr = value as? String else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: timestampStr) {
            return date
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: timestampStr)
    }

    private static func parseUserMessage(_ json: [String: Any], timestamp: Date) -> ChatMessage? {
        guard let message = json["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else {
            return nil
        }

        // Check for tool_result (skip it, we'll get it from toolUseResult)
        if let firstItem = content.first, firstItem["type"] as? String == "tool_result" {
            // This is a tool result wrapped in user message - get from toolUseResult
            // Store full result - truncation is handled in display
            if let toolResult = json["toolUseResult"] as? String {
                return ChatMessage(role: .toolResult, content: toolResult, timestamp: timestamp)
            } else if let toolResultDict = json["toolUseResult"] as? [String: Any],
                      let stdout = toolResultDict["stdout"] as? String {
                return ChatMessage(role: .toolResult, content: stdout, timestamp: timestamp)
            }
            return nil
        }

        // Regular user text message
        if let firstItem = content.first, let text = firstItem["text"] as? String {
            return ChatMessage(role: .user, content: text, timestamp: timestamp)
        }

        return nil
    }

    private static func parseAssistantMessage(_ json: [String: Any], timestamp: Date) -> ChatMessage? {
        guard let message = json["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else {
            return nil
        }

        // Look for text content or tool_use
        for item in content {
            if let itemType = item["type"] as? String {
                switch itemType {
                case "text":
                    if let text = item["text"] as? String, !text.isEmpty {
                        return ChatMessage(role: .assistant, content: text, timestamp: timestamp)
                    }
                case "thinking":
                    if let thinking = item["thinking"] as? String, !thinking.isEmpty {
                        return ChatMessage(role: .thinking, content: thinking, timestamp: timestamp)
                    }
                case "tool_use":
                    if let name = item["name"] as? String {
                        var toolContent = name
                        if let input = item["input"] as? [String: Any] {
                            let inputStr = input.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
                            toolContent = "\(name)(\(inputStr))"
                        }
                        return ChatMessage(role: .toolUse, content: toolContent, timestamp: timestamp)
                    }
                default:
                    break
                }
            }
        }

        return nil
    }

    /// Get the path to session file on remote server
    static func sessionFilePath(projectPath: String, sessionId: String) -> String {
        // Convert project path to Claude's format (e.g., /home/dev/workspace -> -home-dev-workspace)
        // Note: The encoded path STARTS with a dash (slashes become dashes)
        let encodedPath = projectPath.replacingOccurrences(of: "/", with: "-")
        // Only trim trailing dashes if any
        let trimmedPath = encodedPath.hasSuffix("-")
            ? String(encodedPath.dropLast())
            : encodedPath

        return "~/.claude/projects/\(trimmedPath)/\(sessionId).jsonl"
    }
}

// MARK: - WebSocket Message Types (claudecodeui)

// Messages sent TO server
struct WSClaudeCommand: Encodable {
    let type: String = "claude-command"
    let command: String
    let options: WSCommandOptions
    let images: [WSImage]?
}

struct WSImage: Encodable {
    let type: String = "base64"
    let mediaType: String
    let data: String  // base64-encoded image data

    enum CodingKeys: String, CodingKey {
        case type
        case mediaType = "media_type"
        case data
    }
}

struct WSCommandOptions: Encodable {
    let cwd: String  // Working directory - server expects 'cwd', not 'projectPath'
    let sessionId: String?
    let model: String?
    let permissionMode: String?  // "default", "plan", or "bypassPermissions"
}

struct WSAbortSession: Encodable {
    let type: String = "abort-session"
    let sessionId: String
    let provider: String = "claude"
}

// Messages received FROM server
struct WSMessage: Decodable {
    let type: String
    let sessionId: String?
    let data: AnyCodable?
    let error: String?
    let exitCode: Int?
    let isNewSession: Bool?
}

// Helper for dynamic JSON
struct AnyCodable: Decodable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else {
            value = ""
        }
    }

    var stringValue: String {
        if let s = value as? String { return s }
        if let dict = value as? [String: Any] {
            if let data = try? JSONSerialization.data(withJSONObject: dict),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
        }
        return String(describing: value)
    }

    var dictValue: [String: Any]? {
        return value as? [String: Any]
    }
}

// MARK: - AskUserQuestion Tool Types

/// Represents a question option in AskUserQuestion
struct QuestionOption: Identifiable {
    let id = UUID()
    let label: String
    let description: String?

    init(label: String, description: String? = nil) {
        self.label = label
        self.description = description
    }

    /// Parse from dictionary
    static func from(_ dict: [String: Any]) -> QuestionOption? {
        guard let label = dict["label"] as? String else { return nil }
        let description = dict["description"] as? String
        return QuestionOption(label: label, description: description)
    }
}

/// Represents a single question in AskUserQuestion
struct UserQuestion: Identifiable {
    let id = UUID()
    let question: String
    let header: String?
    let options: [QuestionOption]
    let multiSelect: Bool

    /// The user's selected answer(s)
    var selectedOptions: Set<String> = []
    var customAnswer: String = ""  // For "Other" option

    init(question: String, header: String?, options: [QuestionOption], multiSelect: Bool) {
        self.question = question
        self.header = header
        self.options = options
        self.multiSelect = multiSelect
    }

    /// Parse from dictionary
    static func from(_ dict: [String: Any]) -> UserQuestion? {
        guard let question = dict["question"] as? String else { return nil }

        let header = dict["header"] as? String
        let multiSelect = dict["multiSelect"] as? Bool ?? false

        var options: [QuestionOption] = []
        if let optionsArray = dict["options"] as? [[String: Any]] {
            options = optionsArray.compactMap { QuestionOption.from($0) }
        }

        return UserQuestion(question: question, header: header, options: options, multiSelect: multiSelect)
    }
}

/// Represents the full AskUserQuestion tool input
struct AskUserQuestionData: Identifiable {
    let id = UUID()
    var questions: [UserQuestion]

    init(questions: [UserQuestion]) {
        self.questions = questions
    }

    /// Parse from the tool input dictionary
    static func from(_ input: [String: Any]) -> AskUserQuestionData? {
        guard let questionsArray = input["questions"] as? [[String: Any]] else {
            return nil
        }

        let questions = questionsArray.compactMap { UserQuestion.from($0) }
        guard !questions.isEmpty else { return nil }

        return AskUserQuestionData(questions: questions)
    }

    /// Format answers as a user-friendly response string
    func formatAnswers() -> String {
        var lines: [String] = []

        for question in questions {
            if let header = question.header {
                lines.append("**\(header)**")
            }

            if !question.customAnswer.isEmpty {
                // User provided custom "Other" answer
                lines.append(question.customAnswer)
            } else if !question.selectedOptions.isEmpty {
                // User selected from options
                let selected = question.selectedOptions.joined(separator: ", ")
                lines.append(selected)
            }

            lines.append("")  // Blank line between questions
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
