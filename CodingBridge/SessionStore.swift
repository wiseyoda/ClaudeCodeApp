import Foundation
import Combine

/// Centralized session management using API-based data fetching.
/// Replaces SSH-based SessionManager with Clean Architecture approach.
///
/// Architecture: Views → SessionStore → SessionRepository → APIClient → Backend
///
/// This store is the single source of truth for session data.
/// Sessions are fetched from the API with pagination support.
/// WebSocket push events trigger automatic refreshes.
@MainActor
final class SessionStore: ObservableObject {
    static let shared = SessionStore()

    // MARK: - Published State

    /// Sessions per project path
    @Published private(set) var sessionsByProject: [String: [ProjectSession]] = [:]

    /// Session metadata per project (hasMore, total)
    @Published private(set) var metaByProject: [String: ProjectSessionMeta] = [:]

    /// Loading state per project
    @Published private(set) var isLoading: [String: Bool] = [:]

    /// Error state per project
    @Published private(set) var errorByProject: [String: Error] = [:]

    /// Currently active session ID per project
    @Published private(set) var activeSessionIds: [String: String] = [:]

    // MARK: - Dependencies

    private var repository: SessionRepository?

    private init() {}

    /// Configure the store with a repository (call during app setup)
    func configure(with repository: SessionRepository) {
        self.repository = repository
    }

    /// Convenience method to configure with AppSettings
    /// Creates an APISessionRepository internally
    func configure(with settings: AppSettings) {
        let repository = APISessionRepository(
            apiClient: APIClient(settings: settings),
            settings: settings
        )
        configure(with: repository)
    }

    // MARK: - Session Loading

    /// Load sessions for a project from API
    /// - Parameters:
    ///   - projectPath: The project's path (e.g., /home/dev/workspace/ClaudeCodeApp)
    ///   - forceRefresh: If true, clears existing sessions before loading
    func loadSessions(for projectPath: String, forceRefresh: Bool = false) async {
        guard let repository = repository else {
            log.error("[SessionStore] Repository not configured")
            return
        }

        // Convert project path to encoded project name for API
        let projectName = encodeProjectPath(projectPath)

        isLoading[projectPath] = true
        errorByProject.removeValue(forKey: projectPath)

        if forceRefresh {
            sessionsByProject[projectPath] = nil
            metaByProject[projectPath] = nil
        }

        do {
            let response = try await repository.fetchSessions(
                projectName: projectName,
                limit: 50,
                offset: 0
            )

            // Store raw sessions - filtering happens at display time
            sessionsByProject[projectPath] = response.sessions
            metaByProject[projectPath] = response.toMeta
        } catch {
            log.error("[SessionStore] Failed to load sessions: \(error)")
            errorByProject[projectPath] = error
        }

        isLoading[projectPath] = false
    }

    /// Load more sessions for a project (pagination)
    func loadMore(for projectPath: String) async {
        guard let repository = repository else { return }
        guard hasMore(for: projectPath) else { return }
        guard isLoading[projectPath] != true else { return }

        let projectName = encodeProjectPath(projectPath)
        let currentCount = sessionsByProject[projectPath]?.count ?? 0

        isLoading[projectPath] = true

        do {
            let response = try await repository.fetchSessions(
                projectName: projectName,
                limit: 50,
                offset: currentCount
            )

            // Append raw sessions - filtering happens at display time
            var sessions = sessionsByProject[projectPath] ?? []
            sessions.append(contentsOf: response.sessions)
            sessionsByProject[projectPath] = sessions

            metaByProject[projectPath] = response.toMeta
        } catch {
            log.error("[SessionStore] Failed to load more sessions: \(error)")
            errorByProject[projectPath] = error
        }

        isLoading[projectPath] = false
    }

    // MARK: - Session Deletion

    /// Delete a session
    func deleteSession(_ session: ProjectSession, for projectPath: String) async -> Bool {
        guard let repository = repository else { return false }

        let projectName = encodeProjectPath(projectPath)

        // Update local state immediately for responsive UI
        if var sessions = sessionsByProject[projectPath] {
            sessions.removeAll { $0.id == session.id }
            sessionsByProject[projectPath] = sessions

            // Update meta count
            if var meta = metaByProject[projectPath] {
                meta = ProjectSessionMeta(hasMore: meta.hasMore, total: max(0, meta.total - 1))
                metaByProject[projectPath] = meta
            }
        }

        // Clear active session if it was deleted
        if activeSessionIds[projectPath] == session.id {
            activeSessionIds[projectPath] = nil
        }

        do {
            try await repository.deleteSession(projectName: projectName, sessionId: session.id)
            return true
        } catch {
            log.error("[SessionStore] Failed to delete session: \(error)")
            // Reload to get correct state
            await loadSessions(for: projectPath, forceRefresh: true)
            return false
        }
    }

    /// Delete all sessions for a project (optionally keeping active session)
    func deleteAllSessions(for projectPath: String, keepActiveSession: Bool = true) async -> Int {
        let sessions = sessionsByProject[projectPath] ?? []
        let activeId = activeSessionIds[projectPath]

        var toDelete = sessions
        if keepActiveSession, let activeId = activeId {
            toDelete = sessions.filter { $0.id != activeId }
        }

        var deleted = 0
        for session in toDelete {
            if await deleteSession(session, for: projectPath) {
                deleted += 1
            }
        }

        return deleted
    }

    // MARK: - Session Addition

    /// Add a newly created session to local state
    @discardableResult
    func addSession(_ session: ProjectSession, for projectPath: String) -> Bool {
        var sessions = sessionsByProject[projectPath] ?? []

        // Only add if not already present
        if !sessions.contains(where: { $0.id == session.id }) {
            sessions.insert(session, at: 0) // Add at beginning (most recent)
            sessionsByProject[projectPath] = sessions

            // Update meta count
            if var meta = metaByProject[projectPath] {
                meta = ProjectSessionMeta(hasMore: meta.hasMore, total: meta.total + 1)
                metaByProject[projectPath] = meta
            }

            return true
        }
        return false
    }

    // MARK: - Active Session Management

    /// Set the active session for a project
    func setActiveSession(_ sessionId: String?, for projectPath: String) {
        activeSessionIds[projectPath] = sessionId
    }

    /// Save active session ID to UserDefaults
    func saveActiveSessionId(for projectPath: String) {
        if let sessionId = activeSessionIds[projectPath] {
            MessageStore.saveSessionId(sessionId, for: projectPath)
        }
    }

    /// Load active session ID from UserDefaults
    func loadActiveSessionId(for projectPath: String) -> String? {
        let sessionId = MessageStore.loadSessionId(for: projectPath)
        if let sid = sessionId {
            activeSessionIds[projectPath] = sid
        }
        return sessionId
    }

    /// Clear active session ID
    func clearActiveSessionId(for projectPath: String) {
        activeSessionIds[projectPath] = nil
        MessageStore.clearSessionId(for: projectPath)
    }

    // MARK: - Accessors

    /// Get sessions for a project
    func sessions(for projectPath: String) -> [ProjectSession] {
        sessionsByProject[projectPath] ?? []
    }

    /// Get session count for a project (from API meta or local count)
    /// Note: This returns the raw/unfiltered count from the API.
    func sessionCount(for projectPath: String) -> Int {
        metaByProject[projectPath]?.total ?? sessionsByProject[projectPath]?.count ?? 0
    }

    /// Get filtered session count for display (excludes helper sessions)
    func displaySessionCount(for projectPath: String) -> Int {
        let sessions = sessionsByProject[projectPath] ?? []
        let activeId = activeSessionIds[projectPath]
        return sessions.filterForDisplay(projectPath: projectPath, activeSessionId: activeId).count
    }

    /// Check if more sessions are available
    func hasMore(for projectPath: String) -> Bool {
        metaByProject[projectPath]?.hasMore ?? false
    }

    /// Get active session ID for a project
    func activeSessionId(for projectPath: String) -> String? {
        activeSessionIds[projectPath]
    }

    /// Check if sessions are loading for a project
    func isLoadingSessions(for projectPath: String) -> Bool {
        isLoading[projectPath] ?? false
    }

    /// Check if sessions have been loaded for a project
    func hasLoaded(for projectPath: String) -> Bool {
        sessionsByProject[projectPath] != nil
    }

    /// Get filtered sessions for display (excludes helper and empty sessions)
    func displaySessions(for projectPath: String) -> [ProjectSession] {
        let activeId = activeSessionIds[projectPath]
        return sessions(for: projectPath)
            .filterAndSortForDisplay(projectPath: projectPath, activeSessionId: activeId)
    }

    // MARK: - WebSocket Event Handling

    /// Handle session update from WebSocket push
    func handleSessionsUpdated(projectName: String, sessionId: String, action: String) async {
        // Find project path from encoded name
        // The projectName is already encoded (e.g., "-home-dev-workspace-project")
        // We need to find which loaded project matches
        let matchingPath = sessionsByProject.keys.first { path in
            encodeProjectPath(path) == projectName
        }

        guard let projectPath = matchingPath else { return }

        switch action {
        case "deleted":
            if var sessions = sessionsByProject[projectPath] {
                sessions.removeAll { $0.id == sessionId }
                sessionsByProject[projectPath] = sessions
            }
            if activeSessionIds[projectPath] == sessionId {
                activeSessionIds[projectPath] = nil
            }

        case "created", "updated":
            await loadSessions(for: projectPath, forceRefresh: true)

        default:
            break
        }
    }

    // MARK: - Helpers

    /// Encode project path to project name format used by API
    /// /home/dev/workspace/ClaudeCodeApp → -home-dev-workspace-ClaudeCodeApp
    private func encodeProjectPath(_ path: String) -> String {
        path.replacingOccurrences(of: "/", with: "-")
    }
}

// MARK: - Bulk Operations

extension SessionStore {
    /// Count sessions that would be deleted by deleteAll (for confirmation dialogs)
    func countSessionsToDelete(for projectPath: String) -> (all: Int, activeProtected: Bool) {
        let sessions = sessionsByProject[projectPath] ?? []
        let activeId = activeSessionIds[projectPath]
        let hasActive = activeId != nil && sessions.contains { $0.id == activeId }
        return (sessions.count, hasActive)
    }

    /// Keep only the N most recent sessions
    func keepOnlyLastN(_ count: Int, for projectPath: String) async -> Int {
        let sessions = sessionsByProject[projectPath] ?? []
        let activeId = activeSessionIds[projectPath]

        // Sort by lastActivity descending
        let sorted = sessions.sorted { s1, s2 in
            (s1.lastActivity ?? "") > (s2.lastActivity ?? "")
        }

        // Keep top N + active
        var toKeep = Set(sorted.prefix(count).map { $0.id })
        if let activeId = activeId {
            toKeep.insert(activeId)
        }

        let toDelete = sessions.filter { !toKeep.contains($0.id) }

        var deleted = 0
        for session in toDelete {
            if await deleteSession(session, for: projectPath) {
                deleted += 1
            }
        }

        return deleted
    }

    /// Count sessions older than a date (for confirmation dialogs)
    func countSessionsOlderThan(_ date: Date, for projectPath: String) -> Int {
        let sessions = sessionsByProject[projectPath] ?? []
        let activeId = activeSessionIds[projectPath]

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return sessions.filter { session in
            if session.id == activeId { return false }
            guard let activityStr = session.lastActivity else { return true }
            if let activityDate = formatter.date(from: activityStr) {
                return activityDate < date
            }
            formatter.formatOptions = [.withInternetDateTime]
            if let activityDate = formatter.date(from: activityStr) {
                return activityDate < date
            }
            return true
        }.count
    }

    /// Count sessions that would be deleted by keepOnlyLastN (for confirmation dialogs)
    func countSessionsToDeleteKeepingN(_ count: Int, for projectPath: String) -> Int {
        let sessions = sessionsByProject[projectPath] ?? []
        let activeId = activeSessionIds[projectPath]

        let sorted = sessions.sorted { s1, s2 in
            (s1.lastActivity ?? "") > (s2.lastActivity ?? "")
        }

        var toKeep = Set(sorted.prefix(count).map { $0.id })
        if let activeId = activeId {
            toKeep.insert(activeId)
        }

        return sessions.filter { !toKeep.contains($0.id) }.count
    }

    /// Delete sessions older than a specified date
    func deleteSessionsOlderThan(_ date: Date, for projectPath: String) async -> Int {
        let sessions = sessionsByProject[projectPath] ?? []
        let activeId = activeSessionIds[projectPath]

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let toDelete = sessions.filter { session in
            // Never delete active session
            if session.id == activeId { return false }

            // Parse last activity date
            guard let activityStr = session.lastActivity else { return true }
            if let activityDate = formatter.date(from: activityStr) {
                return activityDate < date
            }
            formatter.formatOptions = [.withInternetDateTime]
            if let activityDate = formatter.date(from: activityStr) {
                return activityDate < date
            }
            return true
        }

        var deleted = 0
        for session in toDelete {
            if await deleteSession(session, for: projectPath) {
                deleted += 1
            }
        }
        return deleted
    }
}
