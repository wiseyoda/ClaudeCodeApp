import Foundation

/// Persists pending WebSocket messages to survive backgrounding and termination
@MainActor
final class MessageQueuePersistence {
    static let shared = MessageQueuePersistence()

    private let fileURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pending-messages.json")
    }()

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Interface

    /// Save pending messages from WebSocketManager
    func save() async {
        // Get pending messages from a source
        // For now, we'll use a stored property that can be set externally
        guard !pendingMessages.isEmpty else {
            // Remove file if no pending messages
            try? FileManager.default.removeItem(at: fileURL)
            return
        }

        do {
            let data = try JSONEncoder().encode(pendingMessages)
            try data.write(to: fileURL)
            setDataProtection(for: fileURL)
            log.info("[Persistence] Saved \(pendingMessages.count) pending messages")
        } catch {
            log.error("[Persistence] Failed to save message queue: \(error)")
        }
    }

    /// Load pending messages from disk
    func load() async -> [PersistablePendingMessage] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let messages = try JSONDecoder().decode([PersistablePendingMessage].self, from: data)
            log.info("[Persistence] Loaded \(messages.count) pending messages")
            return messages
        } catch {
            log.error("[Persistence] Failed to load message queue: \(error)")
            return []
        }
    }

    /// Clear all pending messages
    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
        pendingMessages = []
        log.debug("[Persistence] Cleared pending messages")
    }

    // MARK: - Message Storage

    private var pendingMessages: [PersistablePendingMessage] = []

    /// Add a message to the pending queue
    func enqueue(_ message: PersistablePendingMessage) {
        pendingMessages.append(message)
    }

    /// Remove a message from the queue
    func dequeue(_ messageId: UUID) {
        pendingMessages.removeAll { $0.id == messageId }
    }

    /// Get current pending count
    var pendingCount: Int {
        pendingMessages.count
    }

    // MARK: - Data Protection

    private func setDataProtection(for url: URL) {
        // Use completeUntilFirstUserAuthentication to allow background access
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
    }
}

// MARK: - Persistable Message Type

/// A Codable version of pending message for persistence
struct PersistablePendingMessage: Codable, Identifiable {
    let id: UUID
    let message: String
    let projectPath: String
    let sessionId: String?
    let permissionMode: String?
    let hasImage: Bool  // Can't persist image data easily
    let model: String?
    var attempts: Int
    let createdAt: Date

    init(
        id: UUID = UUID(),
        message: String,
        projectPath: String,
        sessionId: String?,
        permissionMode: String?,
        hasImage: Bool,
        model: String?,
        attempts: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.message = message
        self.projectPath = projectPath
        self.sessionId = sessionId
        self.permissionMode = permissionMode
        self.hasImage = hasImage
        self.model = model
        self.attempts = attempts
        self.createdAt = createdAt
    }
}
