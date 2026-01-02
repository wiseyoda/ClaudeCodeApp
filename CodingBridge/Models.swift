import Foundation
import SwiftUI

// MARK: - Global Utility Functions

/// Convert Any value to a display string, handling nested types properly.
/// This avoids showing type wrappers like "AnyCodable(value: ...)" in the UI.
///
/// **Note**: This function uses explicit type checks rather than Mirror reflection
/// because it's more performant and handles the specific types we care about:
/// - String: Return as-is
/// - NSNumber: Use stringValue
/// - AnyCodableValue: Use stringValue property
/// - Dictionary: Extract "stdout" for bash results, or serialize to JSON
/// - Array: Serialize to JSON
/// - Fallback: Strip wrapper patterns from String(describing:)
func stringifyAnyValue(_ value: Any) -> String {
    // Handle String directly
    if let str = value as? String {
        return str
    }
    // Handle numbers and bools
    if let num = value as? NSNumber {
        return num.stringValue
    }
    // Handle AnyCodableValue wrapper (from CLIBridgeAppTypes.swift)
    if let codable = value as? AnyCodableValue, let str = codable.stringValue {
        return str
    }
    // Handle dictionaries - convert to JSON or extract common fields
    if let dict = value as? [String: Any] {
        // Try to extract "stdout" for bash results
        if let stdout = dict["stdout"] as? String {
            return stdout
        }
        // Convert to JSON
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
    }
    // Handle arrays
    if let array = value as? [Any] {
        if let data = try? JSONSerialization.data(withJSONObject: array, options: []),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
    }
    // Fallback - use String(describing:) but avoid showing type names
    let description = String(describing: value)
    // Strip common wrapper patterns like "AnyCodable(value: ...)" or "Optional(...)"
    if description.hasPrefix("AnyCodable(value: ") && description.hasSuffix(")") {
        let inner = description.dropFirst("AnyCodable(value: ".count).dropLast()
        return String(inner)
    }
    if description.hasPrefix("AnyCodableValue(value: ") && description.hasSuffix(")") {
        let inner = description.dropFirst("AnyCodableValue(value: ".count).dropLast()
        return String(inner)
    }
    return description
}

// MARK: - Claude Model Selection

/// Available Claude models for the app
enum ClaudeModel: String, CaseIterable, Identifiable, Codable {
    case opus = "opus"
    case sonnet = "sonnet"
    case haiku = "haiku"
    case custom = "custom"

    var id: String { rawValue }

    /// Display name shown in UI
    var displayName: String {
        switch self {
        case .opus: return "Opus 4.5"
        case .sonnet: return "Sonnet 4.5"
        case .haiku: return "Haiku 4.5"
        case .custom: return "Custom"
        }
    }

    /// Short label for nav bar pill
    var shortName: String {
        switch self {
        case .opus: return "Opus"
        case .sonnet: return "Sonnet"
        case .haiku: return "Haiku"
        case .custom: return "Custom"
        }
    }

    /// Description of the model's characteristics
    var description: String {
        switch self {
        case .opus: return "Most capable for complex work"
        case .sonnet: return "Best for everyday tasks"
        case .haiku: return "Fastest for quick answers"
        case .custom: return "Custom model ID"
        }
    }

    /// Icon for the model
    var icon: String {
        switch self {
        case .opus: return "brain.head.profile"
        case .sonnet: return "sparkles"
        case .haiku: return "bolt.fill"
        case .custom: return "gearshape"
        }
    }

    /// Color for the model indicator
    func color(for scheme: ColorScheme) -> Color {
        switch self {
        case .opus:
            return scheme == .dark
                ? Color(red: 0.7, green: 0.5, blue: 0.9)  // Purple
                : Color(red: 0.5, green: 0.3, blue: 0.7)
        case .sonnet:
            return scheme == .dark
                ? Color(red: 0.4, green: 0.8, blue: 0.9)  // Cyan
                : Color(red: 0.0, green: 0.55, blue: 0.7)
        case .haiku:
            return scheme == .dark
                ? Color(red: 0.9, green: 0.8, blue: 0.4)  // Yellow
                : Color(red: 0.7, green: 0.55, blue: 0.0)
        case .custom:
            return scheme == .dark
                ? Color(white: 0.6)
                : Color(white: 0.4)
        }
    }

    /// The model identifier to send to cli-bridge
    /// Standard models use aliases ("opus", "sonnet", "haiku") - server resolves to full SDK model IDs
    /// Custom model requires user to enter full model ID
    var modelId: String? {
        switch self {
        case .opus: return "opus"
        case .sonnet: return "sonnet"
        case .haiku: return "haiku"
        case .custom: return nil  // User provides full model ID via settings
        }
    }
}

// MARK: - Project Models

struct Project: Codable, Identifiable, Hashable {
    let name: String
    let path: String
    let displayName: String?
    let fullPath: String?
    let sessions: [ProjectSession]?
    let sessionMeta: ProjectSessionMeta?

    var id: String { path }

    // Hashable conformance based on unique path
    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }

    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.path == rhs.path
    }

    /// Display title: prefer server displayName, otherwise use name (which is already the basename)
    var title: String {
        if let display = displayName, !display.isEmpty {
            return display
        }
        return name
    }

    /// Total session count (from API metadata or bundled sessions count)
    var totalSessionCount: Int {
        sessionMeta?.total ?? sessions?.count ?? 0
    }

    /// Whether more sessions are available via pagination
    var hasMoreSessions: Bool {
        sessionMeta?.hasMore ?? false
    }

    enum CodingKeys: String, CodingKey {
        case name, path, displayName, fullPath, sessions, sessionMeta
    }
}

/// Metadata about sessions for a project (included in API response)
struct ProjectSessionMeta: Codable, Hashable {
    let hasMore: Bool
    let total: Int
}

struct ProjectSession: Codable, Identifiable {
    let id: String
    let projectPath: String?
    let summary: String?
    let messageCount: Int?
    let lastActivity: String?
    let lastUserMessage: String?
    let lastAssistantMessage: String?
    let archivedAt: String?

    /// Initialize with all fields
    init(
        id: String,
        projectPath: String? = nil,
        summary: String?,
        lastActivity: String?,
        messageCount: Int?,
        lastUserMessage: String?,
        lastAssistantMessage: String?,
        archivedAt: String? = nil
    ) {
        self.id = id
        self.projectPath = projectPath
        self.summary = summary
        self.lastActivity = lastActivity
        self.messageCount = messageCount
        self.lastUserMessage = lastUserMessage
        self.lastAssistantMessage = lastAssistantMessage
        self.archivedAt = archivedAt
    }

    /// Whether this session is archived
    var isArchived: Bool {
        archivedAt != nil
    }
}

// MARK: - Session Filtering

extension Array where Element == ProjectSession {
    /// Filter sessions to show only user conversation sessions.
    /// Excludes:
    /// - Empty sessions (messageCount == 0, never had any messages)
    /// - Agent sub-sessions (Task tool spawns these with specific ID patterns)
    /// - Always includes the activeSessionId if provided (current session)
    func filterForDisplay(projectPath: String, activeSessionId: String? = nil) -> [ProjectSession] {
        return self.filter { session in
            // Always include the active/current session (even if it's new with few messages)
            if let activeId = activeSessionId, session.id == activeId {
                return true
            }
            // Filter out agent sub-sessions (Task tool spawns these with UUIDs containing "agent")
            if session.id.contains("agent") {
                return false
            }
            // Filter out truly empty sessions (messageCount == 0)
            // Keep sessions with 1+ messages (user's first message counts!)
            // Sessions with nil messageCount are kept (might be valid but missing data)
            guard let count = session.messageCount else { return true }
            return count >= 1
        }
    }

    /// Filter and sort sessions by last activity (most recent first)
    func filterAndSortForDisplay(projectPath: String, activeSessionId: String? = nil) -> [ProjectSession] {
        filterForDisplay(projectPath: projectPath, activeSessionId: activeSessionId)
            .sorted { s1, s2 in
                let date1 = s1.lastActivity ?? ""
                let date2 = s2.lastActivity ?? ""
                return date1 > date2
            }
    }
}

extension Project {
    /// Get filtered sessions for display (excludes empty sessions)
    var displaySessions: [ProjectSession] {
        (sessions ?? []).filterForDisplay(projectPath: path)
    }

    /// Get filtered and sorted sessions for display
    var sortedDisplaySessions: [ProjectSession] {
        (sessions ?? []).filterAndSortForDisplay(projectPath: path)
    }
}

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
    }

    init(role: Role, content: String, timestamp: Date = Date(), isStreaming: Bool = false, imageData: Data? = nil, imagePath: String? = nil, executionTime: TimeInterval? = nil, tokenCount: Int? = nil) {
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
    init(id: UUID, role: Role, content: String, timestamp: Date = Date(), isStreaming: Bool = false, imageData: Data? = nil, imagePath: String? = nil, executionTime: TimeInterval? = nil, tokenCount: Int? = nil) {
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

// MARK: - Archived Projects Store

/// Stores archived project paths
@MainActor
class ArchivedProjectsStore: ObservableObject {
    static let shared = ArchivedProjectsStore()

    @Published private(set) var archivedPaths: Set<String> = []

    private static let storageKey = "archived_project_paths"

    init() {
        loadArchived()
    }

    /// Check if a project is archived
    func isArchived(_ projectPath: String) -> Bool {
        archivedPaths.contains(projectPath)
    }

    /// Archive a project
    func archive(_ projectPath: String) {
        archivedPaths.insert(projectPath)
        saveArchived()
    }

    /// Unarchive a project
    func unarchive(_ projectPath: String) {
        archivedPaths.remove(projectPath)
        saveArchived()
    }

    /// Toggle archive status
    func toggleArchive(_ projectPath: String) {
        if isArchived(projectPath) {
            unarchive(projectPath)
        } else {
            archive(projectPath)
        }
    }

    private func loadArchived() {
        if let paths = UserDefaults.standard.array(forKey: Self.storageKey) as? [String] {
            archivedPaths = Set(paths)
        }
    }

    private func saveArchived() {
        UserDefaults.standard.set(Array(archivedPaths), forKey: Self.storageKey)
    }
}

// MARK: - Bookmark Store

/// Stores bookmarked messages across all projects
@MainActor
class BookmarkStore: ObservableObject {
    static let shared = BookmarkStore()

    @Published private(set) var bookmarks: [BookmarkedMessage] = []

    private static var defaultBookmarksFile: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("bookmarks.json")
    }

    /// Background queue for file I/O to avoid blocking main thread
    private static let fileQueue = DispatchQueue(label: "com.codingbridge.bookmarkstore", qos: .userInitiated)

    private let bookmarksFile: URL

    init(bookmarksFile: URL? = nil) {
        self.bookmarksFile = bookmarksFile ?? Self.defaultBookmarksFile
        loadBookmarks()
    }

    /// Check if a message is bookmarked
    func isBookmarked(messageId: UUID) -> Bool {
        bookmarks.contains { $0.messageId == messageId }
    }

    /// Toggle bookmark status for a message
    func toggleBookmark(message: ChatMessage, projectPath: String, projectTitle: String) {
        if let index = bookmarks.firstIndex(where: { $0.messageId == message.id }) {
            bookmarks.remove(at: index)
        } else {
            let bookmark = BookmarkedMessage(
                messageId: message.id,
                role: message.role,
                content: message.content,
                timestamp: message.timestamp,
                projectPath: projectPath,
                projectTitle: projectTitle,
                bookmarkedAt: Date()
            )
            bookmarks.insert(bookmark, at: 0)
        }
        saveBookmarks()
    }

    /// Remove a bookmark
    func removeBookmark(messageId: UUID) {
        bookmarks.removeAll { $0.messageId == messageId }
        saveBookmarks()
    }

    /// Search bookmarks
    func searchBookmarks(_ query: String) -> [BookmarkedMessage] {
        guard !query.isEmpty else { return bookmarks }
        return bookmarks.filter {
            $0.content.localizedCaseInsensitiveContains(query) ||
            $0.projectTitle.localizedCaseInsensitiveContains(query)
        }
    }

    private func loadBookmarks() {
        let url = bookmarksFile

        BookmarkStore.fileQueue.async { [weak self] in
            guard let data = try? Data(contentsOf: url) else { return }
            do {
                let loadedBookmarks = try JSONDecoder().decode([BookmarkedMessage].self, from: data)
                Task { @MainActor [weak self] in
                    self?.bookmarks = loadedBookmarks
                }
            } catch {
                log.error("Failed to load bookmarks: \(error)")
            }
        }
    }

    private func saveBookmarks() {
        let bookmarksToSave = bookmarks
        let url = bookmarksFile

        BookmarkStore.fileQueue.async {
            do {
                let data = try JSONEncoder().encode(bookmarksToSave)
                try data.write(to: url, options: .atomic)
            } catch {
                log.error("Failed to save bookmarks: \(error)")
            }
        }
    }
}

/// A bookmarked message with project context
struct BookmarkedMessage: Identifiable, Codable {
    let id: UUID
    let messageId: UUID
    let role: ChatMessage.Role
    let content: String
    let timestamp: Date
    let projectPath: String
    let projectTitle: String
    let bookmarkedAt: Date

    init(messageId: UUID, role: ChatMessage.Role, content: String, timestamp: Date, projectPath: String, projectTitle: String, bookmarkedAt: Date) {
        self.id = UUID()
        self.messageId = messageId
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.projectPath = projectPath
        self.projectTitle = projectTitle
        self.bookmarkedAt = bookmarkedAt
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
    /// The server's request ID - needed for respondToQuestion API call
    let requestId: String
    var questions: [UserQuestion]

    init(requestId: String, questions: [UserQuestion]) {
        self.requestId = requestId
        self.questions = questions
    }

    /// Parse from the tool input dictionary
    static func from(_ input: [String: Any], requestId: String) -> AskUserQuestionData? {
        guard let questionsArray = input["questions"] as? [[String: Any]] else {
            return nil
        }

        let questions = questionsArray.compactMap { UserQuestion.from($0) }
        guard !questions.isEmpty else { return nil }

        return AskUserQuestionData(requestId: requestId, questions: questions)
    }

    /// Format answers as a user-friendly response string (for display in chat)
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

    /// Format answers as a dictionary for the respondToQuestion API
    /// Returns dict keyed by question index (as string) with answer value
    func answersDict() -> [String: Any] {
        var result: [String: Any] = [:]

        for (index, question) in questions.enumerated() {
            let key = String(index)

            if !question.customAnswer.isEmpty {
                // User provided custom "Other" answer
                result[key] = question.customAnswer
            } else if question.multiSelect {
                // Multi-select: return array of selected options
                result[key] = Array(question.selectedOptions)
            } else if let first = question.selectedOptions.first {
                // Single select: return the selected option
                result[key] = first
            }
        }

        return result
    }
}

// MARK: - Permission Approval Types

/// Represents a pending permission request from Claude CLI
/// When bypass permissions mode is OFF, Claude CLI sends these requests
/// for user approval before executing certain tools
struct ApprovalRequest: Identifiable, Equatable {
    let id: String  // requestId from server
    let toolName: String
    let input: [String: Any]
    let receivedAt: Date

    // MARK: - Display Properties

    /// Icon for the tool type
    var toolIcon: String {
        switch toolName.lowercased() {
        case "bash":
            return "terminal"
        case "read":
            return "doc.text"
        case "write":
            return "doc.badge.plus"
        case "edit":
            return "pencil"
        case "glob", "grep":
            return "magnifyingglass"
        case "task":
            return "arrow.triangle.branch"
        default:
            return "wrench"
        }
    }

    /// Short display title for the banner
    var displayTitle: String {
        toolName
    }

    /// Description extracted from input for display
    var displayDescription: String {
        // Try to extract meaningful preview from input
        if let command = input["command"] as? String {
            // For Bash - show the command
            return command.prefix(80).description + (command.count > 80 ? "..." : "")
        }
        if let filePath = input["file_path"] as? String {
            // For Read/Write/Edit - show the file path
            return filePath
        }
        if let pattern = input["pattern"] as? String {
            // For Glob/Grep - show the pattern
            return pattern
        }
        if let description = input["description"] as? String {
            // Fallback to description if available
            return description
        }
        // Last resort - just show tool name
        return "Requesting permission..."
    }

    // MARK: - Equatable

    static func == (lhs: ApprovalRequest, rhs: ApprovalRequest) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Parsing

    /// Parse from WebSocket message data
    static func from(_ data: [String: Any]) -> ApprovalRequest? {
        guard let requestId = data["requestId"] as? String,
              let toolName = data["toolName"] as? String else {
            return nil
        }

        let input = data["input"] as? [String: Any] ?? [:]

        return ApprovalRequest(
            id: requestId,
            toolName: toolName,
            input: input,
            receivedAt: Date()
        )
    }
}

/// Response to send back to server for a permission request
/// Backend expects: { type, requestId, decision, alwaysAllow }
/// - decision: "allow" or "deny" (NOT "allow-session" - that breaks backend logic)
/// - alwaysAllow: true to remember decision for this session
struct ApprovalResponse: Encodable {
    let type: String = "permission-response"
    let requestId: String
    let decision: String      // "allow" or "deny"
    let alwaysAllow: Bool     // true = remember for session

    init(requestId: String, allow: Bool, alwaysAllow: Bool = false) {
        self.requestId = requestId
        self.decision = allow ? "allow" : "deny"
        self.alwaysAllow = alwaysAllow
    }
}
