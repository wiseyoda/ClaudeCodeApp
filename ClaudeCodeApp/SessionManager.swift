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

    /// Track recently deleted session IDs to prevent re-adding from stale sources
    private var deletedSessionIds: Set<String> = []

    // MARK: - Dependencies

    private var sshManager: SSHManager { SSHManager.shared }

    private init() {}

    // MARK: - Session Loading

    /// Load all sessions for a project via SSH
    func loadSessions(for projectPath: String, settings: AppSettings) async {
        isLoading[projectPath] = true

        do {
            var sessions = try await sshManager.loadAllSessions(for: projectPath, settings: settings)

            // Filter out any sessions that were recently deleted (in case of race conditions)
            sessions = sessions.filter { !deletedSessionIds.contains($0.id) }

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
        deletedSessionIds.insert(session.id)

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
        // Don't add sessions that were recently deleted
        if deletedSessionIds.contains(session.id) {
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
}
