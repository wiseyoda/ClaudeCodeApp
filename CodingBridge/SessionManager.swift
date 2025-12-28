import Foundation
import Combine

/// Centralized session management for the app.
/// Now delegates to SessionStore for API-based session loading.
///
/// Migration: This class is being replaced by SessionStore.
/// Views should gradually migrate to use SessionStore.shared directly.
@MainActor
class SessionManager: ObservableObject {
    static let shared = SessionManager()

    // MARK: - Published State (delegate to SessionStore)

    /// Sessions per project path - delegates to SessionStore
    var sessionsByProject: [String: [ProjectSession]] {
        SessionStore.shared.sessionsByProject
    }

    /// Session counts per project path
    var sessionCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for path in SessionStore.shared.sessionsByProject.keys {
            counts[path] = SessionStore.shared.sessionCount(for: path)
        }
        return counts
    }

    /// Currently active session ID per project
    var activeSessionIds: [String: String] {
        SessionStore.shared.activeSessionIds
    }

    /// Loading state per project
    var isLoading: [String: Bool] {
        SessionStore.shared.isLoading
    }

    // MARK: - Dependencies

    private var sshManager: SSHManager { SSHManager.shared }

    private init() {}

    /// Configure SessionStore with API repository
    private func ensureConfigured(settings: AppSettings) {
        // Configure on first use
        let repository = APISessionRepository(
            apiClient: APIClient(settings: settings),
            settings: settings
        )
        SessionStore.shared.configure(with: repository)
    }

    // MARK: - Session Loading

    /// Load all sessions for a project via API (delegates to SessionStore)
    func loadSessions(for projectPath: String, settings: AppSettings) async {
        ensureConfigured(settings: settings)
        await SessionStore.shared.loadSessions(for: projectPath, forceRefresh: true)
    }

    /// Check if sessions have been loaded for a project
    func hasLoaded(for projectPath: String) -> Bool {
        SessionStore.shared.hasLoaded(for: projectPath)
    }

    /// Load session counts for multiple projects - now using API metadata
    func loadSessionCounts(for projectPaths: [String], settings: AppSettings) async {
        // Session counts are now included in the Project response from API
        // No separate loading needed - counts come with fetchProjects()
        log.debug("[SessionManager] loadSessionCounts called - counts now come from API Project response")
    }

    // MARK: - Session CRUD

    /// Delete a session from server and update local state
    func deleteSession(_ session: ProjectSession, projectPath: String, settings: AppSettings) async -> Bool {
        ensureConfigured(settings: settings)
        return await SessionStore.shared.deleteSession(session, for: projectPath)
    }

    /// Add a newly created session to local state
    @discardableResult
    func addSession(_ session: ProjectSession, for projectPath: String) -> Bool {
        SessionStore.shared.addSession(session, for: projectPath)
    }

    /// Set the active session for a project
    func setActiveSession(_ sessionId: String?, for projectPath: String) {
        SessionStore.shared.setActiveSession(sessionId, for: projectPath)
    }

    // MARK: - Accessors

    /// Get sessions for a project (empty array if not loaded)
    func sessions(for projectPath: String) -> [ProjectSession] {
        SessionStore.shared.sessions(for: projectPath)
    }

    /// Get session count for a project (raw/unfiltered)
    func sessionCount(for projectPath: String) -> Int {
        SessionStore.shared.sessionCount(for: projectPath)
    }

    /// Get filtered session count for display (excludes helper sessions)
    func displaySessionCount(for projectPath: String) -> Int {
        SessionStore.shared.displaySessionCount(for: projectPath)
    }

    /// Get active session ID for a project
    func activeSessionId(for projectPath: String) -> String? {
        SessionStore.shared.activeSessionId(for: projectPath)
    }

    /// Check if sessions are loading for a project
    func isLoadingSessions(for projectPath: String) -> Bool {
        SessionStore.shared.isLoadingSessions(for: projectPath)
    }

    // MARK: - Filtering

    /// Get filtered sessions for display (excludes helper and empty sessions)
    func displaySessions(for projectPath: String) -> [ProjectSession] {
        let activeId = SessionStore.shared.activeSessionId(for: projectPath)
        return sessions(for: projectPath)
            .filterAndSortForDisplay(projectPath: projectPath, activeSessionId: activeId)
    }

    // MARK: - Persistence

    /// Save active session ID to UserDefaults
    func saveActiveSessionId(for projectPath: String) {
        SessionStore.shared.saveActiveSessionId(for: projectPath)
    }

    /// Load active session ID from UserDefaults
    func loadActiveSessionId(for projectPath: String) -> String? {
        SessionStore.shared.loadActiveSessionId(for: projectPath)
    }

    /// Clear active session ID
    func clearActiveSessionId(for projectPath: String) {
        SessionStore.shared.clearActiveSessionId(for: projectPath)
    }

    // MARK: - Bulk Session Deletion

    /// Delete all sessions for a project
    func deleteAllSessions(for projectPath: String, keepActiveSession: Bool, settings: AppSettings) async -> Int {
        ensureConfigured(settings: settings)
        return await SessionStore.shared.deleteAllSessions(for: projectPath, keepActiveSession: keepActiveSession)
    }

    /// Delete sessions older than a specified date
    func deleteSessionsOlderThan(_ date: Date, for projectPath: String, settings: AppSettings) async -> Int {
        ensureConfigured(settings: settings)

        let sessions = SessionStore.shared.sessions(for: projectPath)
        let activeId = SessionStore.shared.activeSessionId(for: projectPath)

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
            if await SessionStore.shared.deleteSession(session, for: projectPath) {
                deleted += 1
            }
        }
        return deleted
    }

    /// Keep only the N most recent sessions, delete the rest
    func keepOnlyLastN(_ count: Int, for projectPath: String, settings: AppSettings) async -> Int {
        ensureConfigured(settings: settings)
        return await SessionStore.shared.keepOnlyLastN(count, for: projectPath)
    }

    /// Count sessions that would be deleted by each bulk operation (for confirmation dialogs)
    func countSessionsToDelete(for projectPath: String) -> (all: Int, activeProtected: Bool) {
        SessionStore.shared.countSessionsToDelete(for: projectPath)
    }

    /// Count sessions older than a date (for confirmation)
    func countSessionsOlderThan(_ date: Date, for projectPath: String) -> Int {
        let sessions = SessionStore.shared.sessions(for: projectPath)
        let activeId = SessionStore.shared.activeSessionId(for: projectPath)

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

    /// Count sessions that would be deleted by keepOnlyLastN (for confirmation)
    func countSessionsToDeleteKeepingN(_ count: Int, for projectPath: String) -> Int {
        let sessions = SessionStore.shared.sessions(for: projectPath)
        let activeId = SessionStore.shared.activeSessionId(for: projectPath)

        let sorted = sessions.sorted { s1, s2 in
            (s1.lastActivity ?? "") > (s2.lastActivity ?? "")
        }

        var toKeep = Set(sorted.prefix(count).map { $0.id })
        if let activeId = activeId {
            toKeep.insert(activeId)
        }

        return sessions.filter { !toKeep.contains($0.id) }.count
    }
}
