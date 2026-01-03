import Foundation

// MARK: - Message for UI

struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    var isStreaming: Bool = false
    var imageData: Data?  // Optional image attachment (for newly attached images)
    var imagePath: String?  // Path to image file for lazy loading (persisted images)
    var executionTime: TimeInterval?  // Time taken for this response (in seconds)
    var tokenCount: Int?  // Token count for this message

    enum Role: String, Codable {
        case user
        case assistant
        case system
        case error
        case toolUse
        case toolResult
        case resultSuccess
        case thinking  // For reasoning/thinking blocks
        case localCommand  // For slash commands like /exit, /clear, /bump
        case localCommandStdout  // For command output (e.g., "See ya!")
    }

    init(
        role: Role,
        content: String,
        timestamp: Date = Date(),
        isStreaming: Bool = false,
        imageData: Data? = nil,
        imagePath: String? = nil,
        executionTime: TimeInterval? = nil,
        tokenCount: Int? = nil
    ) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.imageData = imageData
        self.imagePath = imagePath
        self.executionTime = executionTime
        self.tokenCount = tokenCount
    }

    /// Initializer with explicit ID - used for streaming messages to maintain stable identity
    init(
        id: UUID,
        role: Role,
        content: String,
        timestamp: Date = Date(),
        isStreaming: Bool = false,
        imageData: Data? = nil,
        imagePath: String? = nil,
        executionTime: TimeInterval? = nil,
        tokenCount: Int? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.imageData = imageData
        self.imagePath = imagePath
        self.executionTime = executionTime
        self.tokenCount = tokenCount
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

extension ChatMessage {
    var isDisplayable: Bool {
        guard role == .system else { return true }
        return SystemStreamMessage.isDisplayableContent(content)
    }
}
