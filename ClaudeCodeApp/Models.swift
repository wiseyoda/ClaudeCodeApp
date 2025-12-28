import Foundation
import SwiftUI

// MARK: - Global Utility Functions

/// Convert Any value to a display string, handling nested types properly.
/// This avoids showing type wrappers like "AnyCodable(value: ...)" in the UI.
func stringifyAnyValue(_ value: Any) -> String {
    // Handle String directly
    if let str = value as? String {
        return str
    }
    // Handle numbers and bools
    if let num = value as? NSNumber {
        return num.stringValue
    }
    // Handle AnyCodable wrapper (defined later in this file)
    if let codable = value as? AnyCodable {
        return codable.stringValue
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

    /// The alias to send to /model command (nil for custom, which requires full model ID)
    var modelAlias: String? {
        switch self {
        case .opus: return "opus"
        case .sonnet: return "sonnet"
        case .haiku: return "haiku"
        case .custom: return nil
        }
    }

    /// The full model ID to pass in WebSocket message options (nil for custom)
    var modelId: String? {
        switch self {
        case .opus: return "claude-opus-4-5-20251101"
        case .sonnet: return "claude-sonnet-4-5-20250929"
        case .haiku: return "claude-3-5-haiku-20241022"
        case .custom: return nil
        }
    }
}

// MARK: - Git Status

/// Represents the git sync status of a project
enum GitStatus: Equatable {
    case unknown        // Status not yet checked
    case checking       // Currently checking status
    case notGitRepo     // Not a git repository
    case clean          // Clean, up to date with remote
    case dirty          // Has uncommitted local changes
    case ahead(Int)     // Has unpushed commits
    case behind(Int)    // Behind remote (can auto-pull)
    case diverged       // Both ahead and behind (needs manual resolution)
    case dirtyAndAhead  // Uncommitted changes + unpushed commits
    case error(String)  // Failed to check status

    /// Icon to display for this status
    var icon: String {
        switch self {
        case .unknown, .checking:
            return "circle.dotted"
        case .notGitRepo:
            return "minus.circle"
        case .clean:
            return "checkmark.circle.fill"
        case .dirty:
            return "exclamationmark.triangle.fill"
        case .ahead:
            return "arrow.up.circle.fill"
        case .behind:
            return "arrow.down.circle.fill"
        case .diverged:
            return "arrow.up.arrow.down.circle.fill"
        case .dirtyAndAhead:
            return "exclamationmark.arrow.triangle.2.circlepath"
        case .error:
            return "xmark.circle"
        }
    }

    /// Color name for the status icon
    var colorName: String {
        switch self {
        case .unknown, .checking, .notGitRepo:
            return "gray"
        case .clean:
            return "green"
        case .dirty, .dirtyAndAhead, .diverged:
            return "orange"
        case .ahead:
            return "blue"
        case .behind:
            return "cyan"
        case .error:
            return "red"
        }
    }

    /// Short description for accessibility
    var accessibilityLabel: String {
        switch self {
        case .unknown:
            return "Status unknown"
        case .checking:
            return "Checking status"
        case .notGitRepo:
            return "Not a git repository"
        case .clean:
            return "Clean, up to date"
        case .dirty:
            return "Has uncommitted changes"
        case .ahead(let count):
            return "\(count) unpushed commit\(count == 1 ? "" : "s")"
        case .behind(let count):
            return "\(count) commit\(count == 1 ? "" : "s") behind remote"
        case .diverged:
            return "Diverged from remote"
        case .dirtyAndAhead:
            return "Uncommitted changes and unpushed commits"
        case .error(let msg):
            return "Error: \(msg)"
        }
    }

    /// Whether auto-pull is safe for this status
    var canAutoPull: Bool {
        switch self {
        case .behind:
            return true
        default:
            return false
        }
    }

    /// Whether this status indicates local changes that need attention
    var hasLocalChanges: Bool {
        switch self {
        case .dirty, .ahead, .dirtyAndAhead, .diverged:
            return true
        default:
            return false
        }
    }
}

// MARK: - Multi-Repo Git Status

/// Represents a nested git repository within a project
struct SubRepo: Identifiable, Hashable {
    let id: UUID
    let relativePath: String  // e.g., "packages/api" or "services/auth"
    let fullPath: String      // Full path for git commands
    var status: GitStatus

    init(relativePath: String, fullPath: String, status: GitStatus = .unknown) {
        self.id = UUID()
        self.relativePath = relativePath
        self.fullPath = fullPath
        self.status = status
    }

    // Hashable conformance (exclude status for stable identity)
    func hash(into hasher: inout Hasher) {
        hasher.combine(relativePath)
        hasher.combine(fullPath)
    }

    static func == (lhs: SubRepo, rhs: SubRepo) -> Bool {
        lhs.relativePath == rhs.relativePath && lhs.fullPath == rhs.fullPath
    }
}

/// Aggregated status for a project with multiple nested git repositories
struct MultiRepoStatus {
    var subRepos: [SubRepo]
    var isScanning: Bool = false

    init(subRepos: [SubRepo] = [], isScanning: Bool = false) {
        self.subRepos = subRepos
        self.isScanning = isScanning
    }

    /// Human-readable summary of sub-repo statuses (e.g., "2 dirty, 1 behind")
    var summary: String {
        guard !subRepos.isEmpty else { return "" }

        var counts: [String: Int] = [:]

        for subRepo in subRepos {
            switch subRepo.status {
            case .dirty, .dirtyAndAhead:
                counts["dirty", default: 0] += 1
            case .behind:
                counts["behind", default: 0] += 1
            case .ahead:
                counts["ahead", default: 0] += 1
            case .diverged:
                counts["diverged", default: 0] += 1
            case .error:
                counts["error", default: 0] += 1
            case .clean:
                counts["clean", default: 0] += 1
            case .unknown, .checking, .notGitRepo:
                break
            }
        }

        // Build summary string, prioritizing actionable items
        var parts: [String] = []
        if let count = counts["dirty"], count > 0 {
            parts.append("\(count) dirty")
        }
        if let count = counts["behind"], count > 0 {
            parts.append("\(count) behind")
        }
        if let count = counts["ahead"], count > 0 {
            parts.append("\(count) ahead")
        }
        if let count = counts["diverged"], count > 0 {
            parts.append("\(count) diverged")
        }
        if let count = counts["error"], count > 0 {
            parts.append("\(count) error")
        }

        if parts.isEmpty {
            let cleanCount = counts["clean"] ?? 0
            if cleanCount == subRepos.count {
                return "all clean"
            }
            return "\(subRepos.count) repos"
        }

        return parts.joined(separator: ", ")
    }

    /// Returns the most actionable/urgent status for badge coloring
    var worstStatus: GitStatus {
        // Priority order: error > diverged > dirty > behind > ahead > clean > unknown
        var hasError = false
        var hasDiverged = false
        var hasDirty = false
        var hasBehind = false
        var hasAhead = false
        var hasClean = false

        for subRepo in subRepos {
            switch subRepo.status {
            case .error:
                hasError = true
            case .diverged:
                hasDiverged = true
            case .dirty, .dirtyAndAhead:
                hasDirty = true
            case .behind:
                hasBehind = true
            case .ahead:
                hasAhead = true
            case .clean:
                hasClean = true
            default:
                break
            }
        }

        if hasError { return .error("sub-repo error") }
        if hasDiverged { return .diverged }
        if hasDirty { return .dirty }
        if hasBehind { return .behind(1) }
        if hasAhead { return .ahead(1) }
        if hasClean { return .clean }
        return .unknown
    }

    /// Whether any sub-repo needs user attention
    var hasActionableItems: Bool {
        subRepos.contains { subRepo in
            switch subRepo.status {
            case .dirty, .dirtyAndAhead, .behind, .ahead, .diverged, .error:
                return true
            default:
                return false
            }
        }
    }

    /// Count of sub-repos that can be auto-pulled
    var pullableCount: Int {
        subRepos.filter { $0.status.canAutoPull }.count
    }

    /// Whether there are any sub-repos
    var hasSubRepos: Bool {
        !subRepos.isEmpty
    }
}

// MARK: - Project Models (new claudecodeui API)

struct Project: Codable, Identifiable, Hashable {
    let name: String
    let path: String
    let displayName: String?
    let fullPath: String?
    let sessions: [ProjectSession]?

    var id: String { path }

    // Hashable conformance based on unique path
    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }

    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.path == rhs.path
    }

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

// MARK: - Session Filtering

extension Array where Element == ProjectSession {
    /// Filter sessions to show only user conversation sessions.
    /// Excludes:
    /// - ClaudeHelper sessions (used for suggestions, not user conversations)
    /// - Empty sessions (messageCount == 0, never had any messages)
    /// - Always includes the activeSessionId if provided (current session)
    func filterForDisplay(projectPath: String, activeSessionId: String? = nil) -> [ProjectSession] {
        let helperSessionId = ClaudeHelper.createHelperSessionId(for: projectPath)

        return self.filter { session in
            // Always include the active/current session (even if it's new with few messages)
            if let activeId = activeSessionId, session.id == activeId {
                return true
            }
            // Filter out ClaudeHelper sessions
            if session.id == helperSessionId {
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
    /// Get filtered sessions for display (excludes helper and empty sessions)
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
    var imageData: Data?  // Optional image attachment
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

    init(role: Role, content: String, timestamp: Date = Date(), isStreaming: Bool = false, imageData: Data? = nil, executionTime: TimeInterval? = nil, tokenCount: Int? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.imageData = imageData
        self.executionTime = executionTime
        self.tokenCount = tokenCount
    }

    /// Initializer with explicit ID - used for streaming messages to maintain stable identity
    init(id: UUID, role: Role, content: String, timestamp: Date = Date(), isStreaming: Bool = false, imageData: Data? = nil, executionTime: TimeInterval? = nil, tokenCount: Int? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.imageData = imageData
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

    func toChatMessage(imageData: Data?) -> ChatMessage {
        // Clean any corrupted content that has "AnyCodableValue(value: ...)" wrappers
        let cleanedContent = Self.cleanAnyCodableWrappers(content)
        return ChatMessage(
            role: ChatMessage.Role(rawValue: role) ?? .system,
            content: cleanedContent,
            timestamp: timestamp,
            imageData: imageData,
            executionTime: executionTime,
            tokenCount: tokenCount
        )
    }

    /// Clean AnyCodableValue wrappers from cached content (migration fix)
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
    private static let fileQueue = DispatchQueue(label: "com.claudecodeapp.messagestore", qos: .userInitiated)

    // MARK: - Directory Setup

    private static var messagesDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Messages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func projectDirectory(for projectPath: String) -> URL {
        let safeKey = projectPath
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        let dir = messagesDirectory.appendingPathComponent(safeKey, isDirectory: true)
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

    /// Synchronous load for backward compatibility - DEPRECATED, use async version
    /// This blocks the calling thread and should only be used where async is not possible
    @available(*, deprecated, message: "Use async loadMessages(for:) instead to avoid blocking main thread")
    static func loadMessagesSync(for projectPath: String) -> [ChatMessage] {
        fileQueue.sync {
            loadMessagesUnsafe(for: projectPath)
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

            let messages = dtos.map { dto -> ChatMessage in
                var imageData: Data?
                if let filename = dto.imageFilename {
                    let imagePath = imagesDir.appendingPathComponent(filename)
                    imageData = try? Data(contentsOf: imagePath)
                }
                return dto.toChatMessage(imageData: imageData)
            }

            log.debug("Loaded \(messages.count) messages for \(projectPath)")
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

            // Save JSON atomically (if this fails, images are still valid for next save)
            do {
                try jsonData.write(to: file, options: .atomic)
                log.debug("Saved \(dtos.count) messages for \(projectPath)")
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
            log.debug("Cleared messages for \(projectPath)")
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
            log.info("Migrating \(messages.count) messages from UserDefaults for \(projectPath)")

            // Save to new file-based storage
            saveMessages(messages, for: projectPath)

            // Remove from UserDefaults
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
                do {
                    try FileManager.default.removeItem(at: file)
                    log.debug("Cleaned up orphaned image: \(filename)")
                } catch {
                    log.warning("Failed to remove orphaned image \(filename): \(error)")
                }
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
    private static let fileQueue = DispatchQueue(label: "com.claudecodeapp.bookmarkstore", qos: .userInitiated)

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

        // Perform file I/O on background queue to avoid blocking main thread
        BookmarkStore.fileQueue.async { [weak self] in
            guard let data = try? Data(contentsOf: url) else { return }
            do {
                let loadedBookmarks = try JSONDecoder().decode([BookmarkedMessage].self, from: data)
                Task { @MainActor [weak self] in
                    self?.bookmarks = loadedBookmarks
                    log.debug("Loaded \(loadedBookmarks.count) bookmarks")
                }
            } catch {
                log.error("Failed to load bookmarks: \(error)")
            }
        }
    }

    private func saveBookmarks() {
        // Capture data needed for background save
        let bookmarksToSave = bookmarks
        let url = bookmarksFile

        // Perform file I/O on background queue to avoid blocking main thread
        BookmarkStore.fileQueue.async {
            do {
                let data = try JSONEncoder().encode(bookmarksToSave)
                try data.write(to: url, options: .atomic)
                log.debug("Saved \(bookmarksToSave.count) bookmarks")
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

    /// Convert Any value to string - delegates to global stringifyAnyValue
    private static func stringifyValue(_ value: Any) -> String {
        // Handle AnyCodable wrapper (specific to this context)
        if let codable = value as? AnyCodable {
            return codable.stringValue
        }
        // Use global helper for everything else
        return stringifyAnyValue(value)
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
                            let inputStr = input.map { "\($0.key): \(stringifyValue($0.value))" }.joined(separator: ", ")
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

        // Use $HOME for consistent shell expansion (~ doesn't expand in all contexts)
        return "$HOME/.claude/projects/\(trimmedPath)/\(sessionId).jsonl"
    }
}

// MARK: - WebSocket Message Types (claudecodeui)

// Messages sent TO server
struct WSClaudeCommand: Encodable {
    let type: String = "claude-command"
    let command: String
    let options: WSCommandOptions
}

struct WSImage: Encodable {
    let data: String  // Full data URL: "data:image/png;base64,<base64data>"

    /// Create WSImage from raw image data
    init(mediaType: String, base64Data: String) {
        // Server expects: "data:image/png;base64,<base64data>"
        self.data = "data:\(mediaType);base64,\(base64Data)"
    }
}

struct WSCommandOptions: Encodable {
    let cwd: String  // Working directory - server expects 'cwd', not 'projectPath'
    let sessionId: String?
    let model: String?
    let permissionMode: String?  // "default", "plan", or "bypassPermissions"
    let images: [WSImage]?  // Images must be inside options, not at top level
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
struct AnyCodable: Decodable, CustomStringConvertible {
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

    /// CustomStringConvertible - returns just the value for string interpolation
    var description: String {
        stringValue
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
