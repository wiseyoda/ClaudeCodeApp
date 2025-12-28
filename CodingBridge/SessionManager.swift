import Foundation
import Combine

/// Centralized session management for the app.
/// Single source of truth for session state across all views.
@MainActor
class SessionManager: ObservableObject {
    static let shared = SessionManager()

    // MARK: - Published State

    /// Sessions per project path
    @Published private(set) var sessionsByProject: [String: [ProjectSession]] = [:]

    /// Session counts per project path (for quick display)
    @Published private(set) var sessionCounts: [String: Int] = [:]

    /// Currently active session ID per project
    @Published private(set) var activeSessionIds: [String: String] = [:]

    /// Loading state per project
    @Published private(set) var isLoading: [String: Bool] = [:]

    /// Track which projects have been loaded via SSH (don't use stale API data after this)
    private var hasLoadedFromSSH: Set<String> = []

    /// Track recently deleted session IDs with timestamps to prevent re-adding from stale sources
    /// Entries expire after `deletionTrackingTimeout` to prevent unbounded memory growth
    private var deletedSessionIds: [String: Date] = [:]

    /// How long to track deleted session IDs (5 minutes should cover any race conditions)
    private let deletionTrackingTimeout: TimeInterval = 300 // 5 minutes

    /// Maximum number of deleted session IDs to track (prevents memory leak if cleanup fails)
    private let maxDeletedSessionIds = 100

    // MARK: - Dependencies

    private var sshManager: SSHManager { SSHManager.shared }

    private init() {}

    // MARK: - Session Loading

    /// Load all sessions for a project via SSH
    func loadSessions(for projectPath: String, settings: AppSettings) async {
        isLoading[projectPath] = true

        // Clean up expired deletion tracking entries
        cleanupExpiredDeletions()

        do {
            var sessions = try await sshManager.loadAllSessions(for: projectPath, settings: settings)

            // Filter out any sessions that were recently deleted (in case of race conditions)
            let deletedIds = Set(deletedSessionIds.keys)
            let filteredCount = sessions.count
            sessions = sessions.filter { !deletedIds.contains($0.id) }

            if sessions.count < filteredCount {
                print("[SessionManager] Filtered out \(filteredCount - sessions.count) recently deleted sessions")
            }

            sessionsByProject[projectPath] = sessions
            sessionCounts[projectPath] = sessions.count
            hasLoadedFromSSH.insert(projectPath)
            print("[SessionManager] Loaded \(sessions.count) sessions for \(projectPath)")
        } catch {
            print("[SessionManager] Failed to load sessions for \(projectPath): \(error)")
        }

        isLoading[projectPath] = false
    }

    /// Check if sessions have been loaded from SSH for a project
    func hasLoaded(for projectPath: String) -> Bool {
        hasLoadedFromSSH.contains(projectPath)
    }

    /// Load session counts for multiple projects efficiently
    func loadSessionCounts(for projectPaths: [String], settings: AppSettings) async {
        do {
            let counts = try await sshManager.countSessionsForProjects(projectPaths, settings: settings)
            for (path, count) in counts {
                sessionCounts[path] = count
            }
            print("[SessionManager] Loaded counts for \(counts.count) projects")
        } catch {
            print("[SessionManager] Failed to load session counts: \(error)")
        }
    }

    // MARK: - Session CRUD

    /// Delete a session from server and update local state
    func deleteSession(_ session: ProjectSession, projectPath: String, settings: AppSettings) async -> Bool {
        let encodedPath = projectPath.replacingOccurrences(of: "/", with: "-")
        // Use $HOME instead of ~ for proper shell expansion
        let sessionFile = "$HOME/.claude/projects/\(encodedPath)/\(session.id).jsonl"

        print("[SessionManager] ========== DELETE SESSION ==========")
        print("[SessionManager] Session ID: \(session.id)")
        print("[SessionManager] Project path: \(projectPath)")
        print("[SessionManager] Encoded path: \(encodedPath)")
        print("[SessionManager] Session file: \(sessionFile)")

        // Track this session as deleted IMMEDIATELY to prevent race conditions
        // Store with timestamp for expiration-based cleanup
        trackDeletion(session.id)

        // Update local state IMMEDIATELY for responsive UI
        if var sessions = sessionsByProject[projectPath] {
            sessions.removeAll { $0.id == session.id }
            sessionsByProject[projectPath] = sessions
            sessionCounts[projectPath] = sessions.count
        }

        // Clear active session if it was deleted
        if activeSessionIds[projectPath] == session.id {
            activeSessionIds[projectPath] = nil
        }

        do {
            // Commands that always return 0 to avoid Citadel throwing on non-zero exit codes
            // Use double quotes to allow $HOME expansion (single quotes would prevent it)
            // Check if file exists (returns "EXISTS" or "NOT_FOUND")
            let checkCmd = "test -f \"\(sessionFile)\" && echo 'EXISTS' || echo 'NOT_FOUND'"
            let checkResult = try await sshManager.executeCommandWithAutoConnect(checkCmd, settings: settings)
            print("[SessionManager] Before delete - file check: \(checkResult.trimmingCharacters(in: .whitespacesAndNewlines))")

            if checkResult.contains("NOT_FOUND") {
                print("[SessionManager] ⚠️ File doesn't exist on server (already deleted?)")
                return true
            }

            // Delete the file on server (use || true to always return 0)
            let deleteCmd = "rm -f \"\(sessionFile)\" && echo 'DELETED' || echo 'DELETE_FAILED'"
            let deleteResult = try await sshManager.executeCommandWithAutoConnect(deleteCmd, settings: settings)
            print("[SessionManager] Delete command result: \(deleteResult.trimmingCharacters(in: .whitespacesAndNewlines))")

            // Verify deletion
            let verifyCmd = "test -f \"\(sessionFile)\" && echo 'STILL_EXISTS' || echo 'CONFIRMED_DELETED'"
            let verifyResult = try await sshManager.executeCommandWithAutoConnect(verifyCmd, settings: settings)
            print("[SessionManager] Verify result: \(verifyResult.trimmingCharacters(in: .whitespacesAndNewlines))")

            if verifyResult.contains("CONFIRMED_DELETED") {
                print("[SessionManager] ✅ Session deleted successfully from server")
                return true
            } else {
                print("[SessionManager] ❌ WARNING: Session file still exists on server!")
                print("[SessionManager] This should not happen - investigate permissions")
                return true  // Return true since local state is correct
            }
        } catch {
            print("[SessionManager] ❌ Failed to delete session from server: \(error)")
            return true  // Return true since local state is correct
        }
    }

    /// Add a newly created session to local state
    /// Returns true if session was added, false if rejected (e.g., was deleted)
    @discardableResult
    func addSession(_ session: ProjectSession, for projectPath: String) -> Bool {
        // Don't add sessions that were recently deleted (check with timestamp validation)
        if isRecentlyDeleted(session.id) {
            print("[SessionManager] Rejecting add of deleted session: \(session.id.prefix(8))...")
            return false
        }

        var sessions = sessionsByProject[projectPath] ?? []

        // Only add if not already present
        if !sessions.contains(where: { $0.id == session.id }) {
            sessions.insert(session, at: 0) // Add at beginning (most recent)
            sessionsByProject[projectPath] = sessions
            sessionCounts[projectPath] = sessions.count
            print("[SessionManager] Added new session: \(session.id.prefix(8))...")
            return true
        }
        return false
    }

    /// Set the active session for a project
    func setActiveSession(_ sessionId: String?, for projectPath: String) {
        activeSessionIds[projectPath] = sessionId
        if let sid = sessionId {
            print("[SessionManager] Active session for \(projectPath): \(sid.prefix(8))...")
        } else {
            print("[SessionManager] Cleared active session for \(projectPath)")
        }
    }

    // MARK: - Accessors

    /// Get sessions for a project (empty array if not loaded)
    func sessions(for projectPath: String) -> [ProjectSession] {
        sessionsByProject[projectPath] ?? []
    }

    /// Get session count for a project
    func sessionCount(for projectPath: String) -> Int {
        sessionCounts[projectPath] ?? 0
    }

    /// Get active session ID for a project
    func activeSessionId(for projectPath: String) -> String? {
        activeSessionIds[projectPath]
    }

    /// Check if sessions are loading for a project
    func isLoadingSessions(for projectPath: String) -> Bool {
        isLoading[projectPath] ?? false
    }

    // MARK: - Filtering

    /// Get filtered sessions for display (excludes helper and empty sessions)
    func displaySessions(for projectPath: String) -> [ProjectSession] {
        let helperSessionId = ClaudeHelper.createHelperSessionId(for: projectPath)
        let activeId = activeSessionIds[projectPath]

        return sessions(for: projectPath)
            .filter { session in
                // Always include active session
                if session.id == activeId { return true }
                // Exclude helper sessions
                if session.id == helperSessionId { return false }
                // Include sessions with messages
                guard let count = session.messageCount else { return true }
                return count >= 1
            }
            .sorted { s1, s2 in
                (s1.lastActivity ?? "") > (s2.lastActivity ?? "")
            }
    }

    // MARK: - Persistence

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

    // MARK: - Deletion Tracking (Race Condition Prevention)

    /// Track a session as deleted with current timestamp
    private func trackDeletion(_ sessionId: String) {
        // Clean up before adding if we're at capacity
        if deletedSessionIds.count >= maxDeletedSessionIds {
            cleanupExpiredDeletions()

            // If still at capacity after cleanup, remove oldest entries
            if deletedSessionIds.count >= maxDeletedSessionIds {
                let sorted = deletedSessionIds.sorted { $0.value < $1.value }
                let toRemove = sorted.prefix(deletedSessionIds.count - maxDeletedSessionIds + 1)
                for (id, _) in toRemove {
                    deletedSessionIds.removeValue(forKey: id)
                }
                print("[SessionManager] Pruned \(toRemove.count) oldest deletion tracking entries")
            }
        }

        deletedSessionIds[sessionId] = Date()
        print("[SessionManager] Tracking deletion of session: \(sessionId.prefix(8))... (tracking \(deletedSessionIds.count) deletions)")
    }

    /// Check if a session was recently deleted (within timeout window)
    private func isRecentlyDeleted(_ sessionId: String) -> Bool {
        guard let deletionTime = deletedSessionIds[sessionId] else {
            return false
        }

        // Check if deletion is still within the tracking window
        let elapsed = Date().timeIntervalSince(deletionTime)
        if elapsed > deletionTrackingTimeout {
            // Expired - remove and allow session
            deletedSessionIds.removeValue(forKey: sessionId)
            print("[SessionManager] Deletion tracking expired for session: \(sessionId.prefix(8))...")
            return false
        }

        return true
    }

    /// Remove expired deletion tracking entries
    private func cleanupExpiredDeletions() {
        let now = Date()
        let expiredIds = deletedSessionIds.filter { now.timeIntervalSince($0.value) > deletionTrackingTimeout }

        if !expiredIds.isEmpty {
            for id in expiredIds.keys {
                deletedSessionIds.removeValue(forKey: id)
            }
            print("[SessionManager] Cleaned up \(expiredIds.count) expired deletion tracking entries")
        }
    }

    // MARK: - Bulk Session Deletion

    /// Delete all sessions for a project
    /// - Parameters:
    ///   - projectPath: The project path
    ///   - keepActiveSession: If true, keeps the currently active session
    ///   - settings: App settings for SSH connection
    /// - Returns: Number of sessions deleted
    func deleteAllSessions(for projectPath: String, keepActiveSession: Bool, settings: AppSettings) async -> Int {
        let sessions = sessionsByProject[projectPath] ?? []
        let activeId = activeSessionIds[projectPath]

        var toDelete = sessions
        if keepActiveSession, let activeId = activeId {
            toDelete = sessions.filter { $0.id != activeId }
        }

        guard !toDelete.isEmpty else {
            print("[SessionManager] No sessions to delete")
            return 0
        }

        return await deleteSessions(toDelete, for: projectPath, settings: settings)
    }

    /// Delete sessions older than a specified date
    /// - Parameters:
    ///   - date: Sessions with lastActivity before this date will be deleted
    ///   - projectPath: The project path
    ///   - settings: App settings for SSH connection
    /// - Returns: Number of sessions deleted
    func deleteSessionsOlderThan(_ date: Date, for projectPath: String, settings: AppSettings) async -> Int {
        let sessions = sessionsByProject[projectPath] ?? []
        let activeId = activeSessionIds[projectPath]

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let toDelete = sessions.filter { session in
            // Never delete active session
            if session.id == activeId { return false }

            // Parse last activity date
            guard let activityStr = session.lastActivity else { return true } // No date = old
            if let activityDate = formatter.date(from: activityStr) {
                return activityDate < date
            }
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let activityDate = formatter.date(from: activityStr) {
                return activityDate < date
            }
            return true // Can't parse = treat as old
        }

        guard !toDelete.isEmpty else {
            print("[SessionManager] No sessions older than \(date) to delete")
            return 0
        }

        return await deleteSessions(toDelete, for: projectPath, settings: settings)
    }

    /// Keep only the N most recent sessions, delete the rest
    /// - Parameters:
    ///   - count: Number of sessions to keep
    ///   - projectPath: The project path
    ///   - settings: App settings for SSH connection
    /// - Returns: Number of sessions deleted
    func keepOnlyLastN(_ count: Int, for projectPath: String, settings: AppSettings) async -> Int {
        let sessions = sessionsByProject[projectPath] ?? []
        let activeId = activeSessionIds[projectPath]

        // Sort by lastActivity descending (most recent first)
        let sorted = sessions.sorted { s1, s2 in
            (s1.lastActivity ?? "") > (s2.lastActivity ?? "")
        }

        // Keep top N, but always include active session
        var toKeep = Set(sorted.prefix(count).map { $0.id })
        if let activeId = activeId {
            toKeep.insert(activeId)
        }

        let toDelete = sessions.filter { !toKeep.contains($0.id) }

        guard !toDelete.isEmpty else {
            print("[SessionManager] No sessions to delete (keeping \(count))")
            return 0
        }

        return await deleteSessions(toDelete, for: projectPath, settings: settings)
    }

    /// Count sessions that would be deleted by each bulk operation (for confirmation dialogs)
    func countSessionsToDelete(for projectPath: String) -> (all: Int, activeProtected: Bool) {
        let sessions = sessionsByProject[projectPath] ?? []
        let activeId = activeSessionIds[projectPath]
        let hasActive = activeId != nil && sessions.contains { $0.id == activeId }
        return (sessions.count, hasActive)
    }

    /// Count sessions older than a date (for confirmation)
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

    /// Count sessions that would be deleted by keepOnlyLastN (for confirmation)
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

    /// Internal helper to delete multiple sessions via SSH
    private func deleteSessions(_ sessions: [ProjectSession], for projectPath: String, settings: AppSettings) async -> Int {
        let encodedPath = projectPath.replacingOccurrences(of: "/", with: "-")
        let baseDir = "$HOME/.claude/projects/\(encodedPath)"

        print("[SessionManager] ========== BULK DELETE ==========")
        print("[SessionManager] Deleting \(sessions.count) sessions for \(projectPath)")

        // Track all deletions immediately
        for session in sessions {
            trackDeletion(session.id)
        }

        // Update local state immediately
        if var currentSessions = sessionsByProject[projectPath] {
            let deleteIds = Set(sessions.map { $0.id })
            currentSessions.removeAll { deleteIds.contains($0.id) }
            sessionsByProject[projectPath] = currentSessions
            sessionCounts[projectPath] = currentSessions.count
        }

        // Build file list and delete in batches (to avoid shell command length limits)
        let batchSize = 50
        var totalDeleted = 0

        for batch in stride(from: 0, to: sessions.count, by: batchSize) {
            let end = min(batch + batchSize, sessions.count)
            let batchSessions = Array(sessions[batch..<end])

            let fileList = batchSessions.map { "\"\(baseDir)/\($0.id).jsonl\"" }.joined(separator: " ")
            let deleteCmd = "rm -f \(fileList) && echo 'DELETED_\(batchSessions.count)' || echo 'DELETE_FAILED'"

            do {
                let result = try await sshManager.executeCommandWithAutoConnect(deleteCmd, settings: settings)
                if result.contains("DELETED") {
                    totalDeleted += batchSessions.count
                    print("[SessionManager] Deleted batch of \(batchSessions.count) sessions")
                } else {
                    print("[SessionManager] Failed to delete batch: \(result)")
                }
            } catch {
                print("[SessionManager] Error deleting batch: \(error)")
            }
        }

        print("[SessionManager] ✅ Bulk delete complete: \(totalDeleted)/\(sessions.count) deleted")
        return totalDeleted
    }
}
