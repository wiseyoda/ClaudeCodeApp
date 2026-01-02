import Foundation

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
