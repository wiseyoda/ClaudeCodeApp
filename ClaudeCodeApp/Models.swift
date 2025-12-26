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
