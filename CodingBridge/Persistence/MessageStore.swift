import Foundation

// MARK: - Message Persistence (File-based)

/// DTO for storing messages - separates image data to avoid large JSON
private struct ChatMessageDTO: Codable {
    let id: UUID
    let role: String
    let content: String
    let timestamp: Date
    let imageFilename: String?  // Reference to image file, not inline data
    let executionTime: TimeInterval?
    let tokenCount: Int?

    init(from message: ChatMessage, imageFilename: String?) {
        self.id = message.id
        self.role = message.role.rawValue
        self.content = message.content
        self.timestamp = message.timestamp
        self.imageFilename = imageFilename
        self.executionTime = message.executionTime
        self.tokenCount = message.tokenCount
    }

    func toChatMessage(imagePath: String?) -> ChatMessage {
        // Clean any corrupted content that has "AnyCodableValue(value: ...)" wrappers
        let cleanedContent = Self.cleanAnyCodableWrappers(content)
        return ChatMessage(
            role: ChatMessage.Role(rawValue: role) ?? .system,
            content: cleanedContent,
            timestamp: timestamp,
            imagePath: imagePath,
            executionTime: executionTime,
            tokenCount: tokenCount
        )
    }

    /// Clean AnyCodableValue wrappers from cached content (migration fix)
    ///
    /// **Legacy Migration Code**
    /// This cleans up cached messages saved before AnyCodableValue.stringValue was properly implemented.
    /// With the #37 fix (AnyCodable consolidation), new messages won't have wrapper patterns.
    /// This function can be removed in v1.0+ after users have migrated.
    private static func cleanAnyCodableWrappers(_ text: String) -> String {
        var result = text

        // Pattern: AnyCodableValue(value: "...") or AnyCodableValue(value: ...)
        // Replace with just the inner value
        while let range = result.range(of: "AnyCodableValue(value: ") {
            // Find the matching closing paren
            let startIndex = range.lowerBound
            let afterPrefix = range.upperBound

            // Check if value is quoted
            if result[afterPrefix] == "\"" {
                // Quoted string - find closing quote (handle escaped quotes)
                var idx = result.index(after: afterPrefix)
                var escaped = false
                while idx < result.endIndex {
                    let char = result[idx]
                    if escaped {
                        escaped = false
                    } else if char == "\\" {
                        escaped = true
                    } else if char == "\"" {
                        // Found closing quote, now expect )
                        let afterQuote = result.index(after: idx)
                        if afterQuote < result.endIndex && result[afterQuote] == ")" {
                            // Extract inner value (without quotes)
                            let innerValue = String(result[result.index(after: afterPrefix)..<idx])
                            result.replaceSubrange(startIndex...afterQuote, with: innerValue)
                            break
                        }
                    }
                    idx = result.index(after: idx)
                }
                // If we couldn't parse it properly, break to avoid infinite loop
                if idx >= result.endIndex { break }
            } else {
                // Unquoted - find closing paren (simple case, no nested parens)
                if let closeParen = result[afterPrefix...].firstIndex(of: ")") {
                    let innerValue = String(result[afterPrefix..<closeParen])
                    result.replaceSubrange(startIndex...closeParen, with: innerValue)
                } else {
                    break // No closing paren found
                }
            }
        }

        return result
    }
}

class MessageStore {
    /// Default message limit (used when no limit is specified)
    static let defaultMaxMessages = 50
    /// Serial queue for synchronized file access to prevent race conditions
    private static let fileQueue = DispatchQueue(label: "com.codingbridge.messagestore", qos: .userInitiated)

    // MARK: - Directory Setup

    private static var messagesDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Messages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func projectDirectory(for projectPath: String) -> URL {
        // Use standardized encoding (- for /)
        let safeKey = ProjectPathEncoder.encode(projectPath)
        let dir = messagesDirectory.appendingPathComponent(safeKey, isDirectory: true)

        // Migration: check for old encoding (_) and move to new (-) if needed
        let oldKey = projectPath
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        if oldKey != safeKey {
            let oldDir = messagesDirectory.appendingPathComponent(oldKey, isDirectory: true)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: oldDir.path, isDirectory: &isDir), isDir.boolValue {
                // Old directory exists, migrate to new location
                if !FileManager.default.fileExists(atPath: dir.path) {
                    try? FileManager.default.moveItem(at: oldDir, to: dir)
                    log.info("[MessageStore] Migrated messages from \(oldKey) to \(safeKey)")
                }
            }
        }

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func messagesFile(for projectPath: String) -> URL {
        projectDirectory(for: projectPath).appendingPathComponent("messages.json")
    }

    private static func imagesDirectory(for projectPath: String) -> URL {
        let dir = projectDirectory(for: projectPath).appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Load/Save Messages

    /// Load messages for a project (async to avoid blocking main thread)
    static func loadMessages(for projectPath: String) async -> [ChatMessage] {
        await withCheckedContinuation { continuation in
            fileQueue.async {
                let messages = loadMessagesUnsafe(for: projectPath)
                continuation.resume(returning: messages)
            }
        }
    }

    /// Internal load without synchronization (caller must hold fileQueue)
    private static func loadMessagesUnsafe(for projectPath: String) -> [ChatMessage] {
        let file = messagesFile(for: projectPath)

        guard let data = try? Data(contentsOf: file) else {
            // Try migrating from UserDefaults
            return migrateFromUserDefaults(for: projectPath)
        }

        do {
            let dtos = try JSONDecoder().decode([ChatMessageDTO].self, from: data)
            let imagesDir = imagesDirectory(for: projectPath)

            // Use lazy image loading - pass path instead of loading data eagerly
            let messages = dtos.map { dto -> ChatMessage in
                var imagePath: String?
                if let filename = dto.imageFilename {
                    imagePath = imagesDir.appendingPathComponent(filename).path
                }
                return dto.toChatMessage(imagePath: imagePath)
            }

            return messages
        } catch {
            log.error("Failed to decode messages: \(error)")
            return []
        }
    }

    /// Save messages for a project (keeps last N messages based on limit)
    static func saveMessages(_ messages: [ChatMessage], for projectPath: String, maxMessages: Int = defaultMaxMessages) {
        // Capture messages as DTOs to avoid retaining ChatMessage objects
        let persistableMessages = Array(messages
            .filter { !$0.isStreaming }
            .suffix(maxMessages))
        let dtos = persistableMessages.map { ChatMessageDTO(from: $0, imageFilename: $0.imageData != nil ? "\($0.id.uuidString).jpg" : nil) }
        let imageDataMap = Dictionary(uniqueKeysWithValues: persistableMessages.compactMap { msg -> (String, Data)? in
            guard let imageData = msg.imageData else { return nil }
            return ("\(msg.id.uuidString).jpg", imageData)
        })
        let validImageIds = Set(persistableMessages.compactMap { $0.imageData != nil ? $0.id : nil })

        fileQueue.async {
            let file = messagesFile(for: projectPath)
            let imagesDir = imagesDirectory(for: projectPath)

            // First, encode JSON to verify it will succeed before writing images
            let jsonData: Data
            do {
                jsonData = try JSONEncoder().encode(dtos)
            } catch {
                log.error("Failed to encode messages: \(error)")
                return
            }

            // Save images (now we know JSON encoding succeeded)
            for (filename, imageData) in imageDataMap {
                let imagePath = imagesDir.appendingPathComponent(filename)
                do {
                    try imageData.write(to: imagePath, options: .atomic)
                } catch {
                    log.warning("Failed to save image \(filename): \(error)")
                }
            }

            do {
                try jsonData.write(to: file, options: .atomic)
            } catch {
                log.error("Failed to save messages JSON: \(error)")
            }

            // Clean up old images that are no longer referenced
            cleanupOrphanedImages(for: projectPath, validIds: validImageIds)
        }
    }

    /// Clear messages for a project
    static func clearMessages(for projectPath: String) {
        fileQueue.async {
            let projectDir = projectDirectory(for: projectPath)
            try? FileManager.default.removeItem(at: projectDir)
        }
    }

    // MARK: - Migration from UserDefaults

    private static func migrateFromUserDefaults(for projectPath: String) -> [ChatMessage] {
        let safeKey = projectPath
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        let oldKey = "chat_messages_" + safeKey

        guard let data = UserDefaults.standard.data(forKey: oldKey) else {
            return []
        }

        do {
            let messages = try JSONDecoder().decode([ChatMessage].self, from: data)
            saveMessages(messages, for: projectPath)
            UserDefaults.standard.removeObject(forKey: oldKey)
            return messages
        } catch {
            log.error("Failed to migrate messages from UserDefaults: \(error)")
            return []
        }
    }

    // MARK: - Cleanup

    private static func cleanupOrphanedImages(for projectPath: String, validIds: Set<UUID>) {
        let imagesDir = imagesDirectory(for: projectPath)

        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: nil)
        } catch {
            // Directory doesn't exist or can't be read - not an error for cleanup
            return
        }

        for file in files {
            let filename = file.deletingPathExtension().lastPathComponent
            if let uuid = UUID(uuidString: filename), !validIds.contains(uuid) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    // MARK: - Draft Persistence (still uses UserDefaults - small text only)

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

    // MARK: - Session ID Persistence

    private static let sessionIdPrefix = "session_id_"

    private static func sessionIdKey(for projectPath: String) -> String {
        let safeKey = projectPath
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        return sessionIdPrefix + safeKey
    }

    /// Load the last session ID for a project
    static func loadSessionId(for projectPath: String) -> String? {
        let key = sessionIdKey(for: projectPath)
        return UserDefaults.standard.string(forKey: key)
    }

    /// Save the session ID for a project
    static func saveSessionId(_ sessionId: String?, for projectPath: String) {
        let key = sessionIdKey(for: projectPath)
        if let sessionId = sessionId, !sessionId.isEmpty {
            UserDefaults.standard.set(sessionId, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// Clear session ID for a project
    static func clearSessionId(for projectPath: String) {
        let key = sessionIdKey(for: projectPath)
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Processing State Persistence

    private static let processingPrefix = "processing_state_"

    private static func processingKey(for projectPath: String) -> String {
        let safeKey = projectPath
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        return processingPrefix + safeKey
    }

    /// Load whether processing was active when app last closed
    static func loadProcessingState(for projectPath: String) -> Bool {
        let key = processingKey(for: projectPath)
        return UserDefaults.standard.bool(forKey: key)
    }

    /// Save processing state for a project
    static func saveProcessingState(_ isProcessing: Bool, for projectPath: String) {
        let key = processingKey(for: projectPath)
        if isProcessing {
            UserDefaults.standard.set(true, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// Clear processing state for a project
    static func clearProcessingState(for projectPath: String) {
        let key = processingKey(for: projectPath)
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Global Recovery State (for background task handling)

    private static let globalProcessingKey = "global_was_processing"
    private static let globalSessionIdKey = "global_last_session_id"
    private static let globalProjectPathKey = "global_last_project_path"

    /// Get whether any processing was active when app backgrounded
    static var wasProcessingOnBackground: Bool {
        UserDefaults.standard.bool(forKey: globalProcessingKey)
    }

    /// Get the last session ID that was active
    static var lastBackgroundSessionId: String? {
        UserDefaults.standard.string(forKey: globalSessionIdKey)
    }

    /// Get the last project path that was active
    static var lastBackgroundProjectPath: String? {
        UserDefaults.standard.string(forKey: globalProjectPathKey)
    }

    /// Save global recovery state when entering background
    static func saveGlobalRecoveryState(
        wasProcessing: Bool,
        sessionId: String?,
        projectPath: String?
    ) {
        let defaults = UserDefaults.standard
        defaults.set(wasProcessing, forKey: globalProcessingKey)

        if let sessionId = sessionId {
            defaults.set(sessionId, forKey: globalSessionIdKey)
        } else {
            defaults.removeObject(forKey: globalSessionIdKey)
        }

        if let projectPath = projectPath {
            defaults.set(projectPath, forKey: globalProjectPathKey)
        } else {
            defaults.removeObject(forKey: globalProjectPathKey)
        }
    }

    /// Clear global recovery state after successful foreground return
    static func clearGlobalRecoveryState() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: globalProcessingKey)
        defaults.removeObject(forKey: globalSessionIdKey)
        defaults.removeObject(forKey: globalProjectPathKey)
    }
}
