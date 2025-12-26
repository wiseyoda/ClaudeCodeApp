import Foundation

// MARK: - Project Models

struct Project: Codable, Identifiable {
    let path: String
    let encodedName: String

    var id: String { path }
    var name: String {
        path.components(separatedBy: "/").last ?? path
    }
}

struct ProjectsResponse: Codable {
    let projects: [Project]
}

// MARK: - Chat Models

struct ChatRequest: Codable {
    let message: String
    let sessionId: String?
    let requestId: String
    let workingDirectory: String
    let allowedTools: [String]?
}

// MARK: - Message for UI

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp: Date
    var isStreaming: Bool = false

    enum Role: String {
        case user
        case assistant
        case system
        case error
        case toolUse
        case toolResult
        case resultSuccess
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Claude Streaming JSON Types

// Outer wrapper from claude-code-webui
struct StreamLine: Decodable {
    let type: String  // "claude_json" or "done"
    let data: ClaudeStreamEvent?
}

struct ClaudeStreamEvent: Decodable {
    let type: String
    let message: ClaudeMessage?
    let session_id: String?
    let subtype: String?
    let tool_name: String?
    let tool_input: [String: AnyCodable]?
    let content: String?
    let result: String?  // For result type events
    // System init fields
    let cwd: String?
    let tools: [String]?
    let model: String?
    let permissionMode: String?
    // Result fields
    let duration_ms: Int?
    let duration_api_ms: Int?
    let num_turns: Int?
    let is_error: Bool?
    let cost: Double?
    let input_tokens: Int?
    let output_tokens: Int?
}

struct ClaudeMessage: Decodable {
    let content: [ClaudeContent]?
    let role: String?
    let model: String?
}

struct ClaudeContent: Decodable {
    let type: String
    let text: String?
    let name: String?
    let input: [String: AnyCodable]?
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
}
