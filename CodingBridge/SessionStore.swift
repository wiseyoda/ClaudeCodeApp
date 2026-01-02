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

    // MARK: - New Session Management State

    /// Session count breakdown by source per project
    @Published private(set) var countsByProject: [String: CLISessionCountResponse] = [:]

    /// Search results per project
    @Published private(set) var searchResults: [String: CLISessionSearchResponse] = [:]

    /// Search loading state per project
    @Published private(set) var isSearching: [String: Bool] = [:]

    /// Toggle to show archived sessions
    @Published var showArchivedSessions: Bool = false

    // MARK: - Dependencies

    private var repository: SessionRepository?

    /// Current serverURL for change detection
    private var currentServerURL: String = ""

    /// Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupServerURLObserver()
    }

    /// Observe serverURL changes and reconfigure automatically
    private func setupServerURLObserver() {
        AppSettings.serverURLPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newURL in
                guard let self = self else { return }
                guard newURL != self.currentServerURL, self.isConfigured else { return }
                log.info("[SessionStore] Server URL changed to \(newURL) - reconfiguring repository")
                self.reconfigure(serverURL: newURL)
            }
            .store(in: &cancellables)
    }

    /// Reconfigure the repository with a new server URL (preserves cached data)
    private func reconfigure(serverURL: String) {
        currentServerURL = serverURL
        let cliClient = CLIBridgeAPIClient(serverURL: serverURL)
        // We need settings for the repository, but since we're reconfiguring,
        // we create a minimal repository with just the new API client
        if let existingRepo = repository as? CLIBridgeSessionRepository {
            // Re-use the existing settings reference
            repository = CLIBridgeSessionRepository(
                apiClient: cliClient,
                settings: existingRepo.settings
            )
        }
    }

    /// Configure the store with a repository (call during app setup)
    /// Idempotent - subsequent calls are no-ops
    func configure(with repository: SessionRepository) {
        guard self.repository == nil else { return }
        self.repository = repository
    }

    /// Convenience method to configure with AppSettings
    /// Creates CLIBridgeSessionRepository for the cli-bridge backend
    /// Idempotent - subsequent calls are no-ops (check isConfigured first)
    func configure(with settings: AppSettings) {
        guard !isConfigured else { return }
        currentServerURL = settings.serverURL
        let cliClient = CLIBridgeAPIClient(serverURL: settings.serverURL)
        let repository = CLIBridgeSessionRepository(
            apiClient: cliClient,
            settings: settings
        )
        log.info("[SessionStore] Configured with CLIBridgeSessionRepository")
        self.repository = repository
    }

    /// Check if the store is already configured
    var isConfigured: Bool {
        repository != nil
    }

    #if DEBUG
    /// Reset the store for testing - allows reconfiguration with a new repository
    func resetForTesting() {
        repository = nil
        sessionsByProject.removeAll()
        metaByProject.removeAll()
        isLoading.removeAll()
        errorByProject.removeAll()
        activeSessionIds.removeAll()
        countsByProject.removeAll()
        searchResults.removeAll()
        isSearching.removeAll()
    }
    #endif

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
        let projectName = ProjectPathEncoder.encode(projectPath)

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
        } catch let error as URLError where error.code == .cancelled {
            // Request was cancelled (e.g., user navigated away or view refreshed) - ignore
            log.debug("[SessionStore] Session load cancelled for \(projectPath)")
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

        let projectName = ProjectPathEncoder.encode(projectPath)
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
        } catch let error as URLError where error.code == .cancelled {
            // Request was cancelled - ignore
            log.debug("[SessionStore] Load more cancelled for \(projectPath)")
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

        let projectName = ProjectPathEncoder.encode(projectPath)

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

    /// Set a specific session as selected for navigation (from search results)
    /// This saves the session ID so ChatView will load it when opening the project
    func setSelectedSession(_ sessionId: String, for projectPath: String) {
        activeSessionIds[projectPath] = sessionId
        MessageStore.saveSessionId(sessionId, for: projectPath)
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
        // The projectName is already encoded (e.g., "-Users-me-project")
        // We need to find which loaded project matches
        let matchingPath = sessionsByProject.keys.first { path in
            ProjectPathEncoder.encode(path) == projectName
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

    /// Handle session event from CLI Bridge WebSocket
    /// - Parameter event: The session event from cli-bridge
    func handleCLISessionEvent(_ event: CLISessionEvent) async {
        let projectPath = event.projectPath

        switch event.action {
        case .deleted:
            if var sessions = sessionsByProject[projectPath] {
                sessions.removeAll { $0.id == event.sessionId.uuidString }
                sessionsByProject[projectPath] = sessions
            }
            if activeSessionIds[projectPath] == event.sessionId.uuidString {
                activeSessionIds[projectPath] = nil
            }

        case .created:
            // Add the new session from metadata if available
            if let metadata = event.metadata {
                let session = metadata.toProjectSession()
                addSession(session, for: projectPath)
            } else {
                // Fallback: reload sessions
                await loadSessions(for: projectPath, forceRefresh: true)
            }

        case .updated:
            // Update the session in place if metadata available
            if let metadata = event.metadata {
                if var sessions = sessionsByProject[projectPath] {
                    if let index = sessions.firstIndex(where: { $0.id == event.sessionId.uuidString }) {
                        sessions[index] = metadata.toProjectSession()
                        sessionsByProject[projectPath] = sessions
                    }
                }
            } else {
                await loadSessions(for: projectPath, forceRefresh: true)
            }
        }
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

        return sessions.filter { session in
            if session.id == activeId { return false }
            guard let activityStr = session.lastActivity else { return true }
            guard let activityDate = CLIDateFormatter.parseDate(activityStr) else { return true }
            return activityDate < date
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

        let toDelete = sessions.filter { session in
            // Never delete active session
            if session.id == activeId { return false }

            // Parse last activity date
            guard let activityStr = session.lastActivity else { return true }
            guard let activityDate = CLIDateFormatter.parseDate(activityStr) else { return true }
            return activityDate < date
        }

        var deleted = 0
        for session in toDelete {
            if await deleteSession(session, for: projectPath) {
                deleted += 1
            }
        }
        return deleted
    }

    // MARK: - Session Count

    /// Populate session counts from projects response (batch operation - no API calls)
    /// This avoids N+1 API calls by using the sessionCount from GET /projects response
    /// - Parameter projects: Array of CLIProject with sessionCount from API
    func populateCountsFromProjects(_ projects: [CLIProject]) {
        var updated = 0
        for project in projects {
            if let count = project.sessionCount {
                // Create a CLISessionCountResponse with total count only
                // The user/agent/helper breakdown is not available from the projects endpoint
                // but the total is sufficient for display purposes
                let countResponse = CLISessionCountResponse(
                    total: count,
                    count: nil,
                    source: nil,
                    user: count,  // Default to total for display - detailed counts loaded on demand
                    agent: nil,
                    helper: nil
                )
                countsByProject[project.path] = countResponse
                updated += 1
            }
        }
        if updated > 0 {
            log.debug("[SessionStore] Populated counts for \(updated) projects from batch response")
        }
    }

    /// Load session counts from the API for a single project
    /// Use this when detailed user/agent/helper breakdown is needed
    /// For initial display, prefer populateCountsFromProjects() which uses batch data
    func loadSessionCounts(for projectPath: String) async {
        guard let repository = repository else {
            log.error("[SessionStore] Repository not configured")
            return
        }

        let projectName = ProjectPathEncoder.encode(projectPath)

        do {
            let counts = try await repository.getSessionCount(projectName: projectName, source: nil)
            countsByProject[projectPath] = counts
            log.debug("[SessionStore] Loaded counts for \(projectPath): total=\(counts.total ?? 0), user=\(counts.user ?? 0), agent=\(counts.agent ?? 0)")
        } catch let error as URLError where error.code == .cancelled {
            // Request was cancelled (e.g., user navigated away or view refreshed) - ignore
            log.debug("[SessionStore] Session count request cancelled for \(projectPath)")
        } catch {
            log.error("[SessionStore] Failed to load session counts: \(error)")
        }
    }

    /// Check if counts have been loaded from the count API
    func hasCountsLoaded(for projectPath: String) -> Bool {
        countsByProject[projectPath] != nil
    }

    /// Get user session count for a project (excludes agent/helper)
    func userSessionCount(for projectPath: String) -> Int {
        countsByProject[projectPath]?.user ?? 0
    }

    /// Get total session count from count endpoint
    func totalSessionCount(for projectPath: String) -> Int {
        countsByProject[projectPath]?.total ?? sessionCount(for: projectPath)
    }

    // MARK: - Session Search

    /// Search sessions for a project
    /// - Parameters:
    ///   - projectPath: Project path
    ///   - query: Search query string
    func searchSessions(for projectPath: String, query: String) async {
        guard let repository = repository else {
            log.error("[SessionStore] Repository not configured")
            return
        }

        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults[projectPath] = nil
            return
        }

        let projectName = ProjectPathEncoder.encode(projectPath)
        isSearching[projectPath] = true

        do {
            let results = try await repository.searchSessions(
                projectName: projectName,
                query: query,
                limit: 20,
                offset: 0
            )
            searchResults[projectPath] = results
            log.debug("[SessionStore] Search '\(query)' found \(results.total) results")
        } catch let error as URLError where error.code == .cancelled {
            // Search was cancelled (e.g., user typed more characters) - ignore
            log.debug("[SessionStore] Search cancelled for '\(query)'")
        } catch {
            log.error("[SessionStore] Search failed: \(error)")
            searchResults[projectPath] = nil
        }

        isSearching[projectPath] = false
    }

    /// Clear search results for a project
    func clearSearch(for projectPath: String) {
        searchResults[projectPath] = nil
    }

    /// Check if currently searching for a project
    func isSearchingSessions(for projectPath: String) -> Bool {
        isSearching[projectPath] ?? false
    }

    // MARK: - Session Archive

    /// Archive a session (soft delete)
    /// - Parameters:
    ///   - session: Session to archive
    ///   - projectPath: Project path
    /// - Returns: True if successful
    @discardableResult
    func archiveSession(_ session: ProjectSession, for projectPath: String) async -> Bool {
        guard let repository = repository else {
            log.error("[SessionStore] Repository not configured")
            return false
        }

        let projectName = ProjectPathEncoder.encode(projectPath)

        // Optimistic update - remove from list immediately
        var backup: [ProjectSession]?
        if var sessions = sessionsByProject[projectPath] {
            backup = sessions
            sessions.removeAll { $0.id == session.id }
            sessionsByProject[projectPath] = sessions
        }

        do {
            _ = try await repository.archiveSession(projectName: projectName, sessionId: session.id)
            log.info("[SessionStore] Archived session \(session.id)")

            // Reload counts
            await loadSessionCounts(for: projectPath)
            return true
        } catch {
            log.error("[SessionStore] Failed to archive session: \(error)")
            // Rollback on failure
            if let backup = backup {
                sessionsByProject[projectPath] = backup
            }
            return false
        }
    }

    /// Unarchive a session (restore from archive)
    /// - Parameters:
    ///   - session: Session to unarchive
    ///   - projectPath: Project path
    /// - Returns: True if successful
    @discardableResult
    func unarchiveSession(_ session: ProjectSession, for projectPath: String) async -> Bool {
        guard let repository = repository else {
            log.error("[SessionStore] Repository not configured")
            return false
        }

        let projectName = ProjectPathEncoder.encode(projectPath)

        do {
            let metadata = try await repository.unarchiveSession(projectName: projectName, sessionId: session.id)
            log.info("[SessionStore] Unarchived session \(session.id)")

            // Add back to list using the returned metadata
            addSession(metadata.toProjectSession(), for: projectPath)

            // Reload counts
            await loadSessionCounts(for: projectPath)
            return true
        } catch {
            log.error("[SessionStore] Failed to unarchive session: \(error)")
            return false
        }
    }

    // MARK: - Bulk Operations

    /// Bulk archive sessions
    /// - Parameters:
    ///   - sessionIds: Session IDs to archive
    ///   - projectPath: Project path
    /// - Returns: Tuple of (successful count, failed count)
    func bulkArchive(sessionIds: [String], for projectPath: String) async -> (success: Int, failed: Int) {
        guard let repository = repository else {
            log.error("[SessionStore] Repository not configured")
            return (0, sessionIds.count)
        }

        let projectName = ProjectPathEncoder.encode(projectPath)

        do {
            let result = try await repository.bulkOperation(
                projectName: projectName,
                sessionIds: sessionIds,
                action: "archive",
                customTitle: nil
            )

            // Update local state - remove archived sessions
            if var sessions = sessionsByProject[projectPath] {
                sessions.removeAll { result.success.contains($0.id) }
                sessionsByProject[projectPath] = sessions
            }

            log.info("[SessionStore] Bulk archived \(result.successCount) sessions, \(result.failedCount) failed")

            // Reload counts
            await loadSessionCounts(for: projectPath)

            return (result.successCount, result.failedCount)
        } catch {
            log.error("[SessionStore] Bulk archive failed: \(error)")
            return (0, sessionIds.count)
        }
    }

    /// Bulk delete sessions (permanent)
    /// - Parameters:
    ///   - sessionIds: Session IDs to delete
    ///   - projectPath: Project path
    /// - Returns: Tuple of (successful count, failed count)
    func bulkDelete(sessionIds: [String], for projectPath: String) async -> (success: Int, failed: Int) {
        guard let repository = repository else {
            log.error("[SessionStore] Repository not configured")
            return (0, sessionIds.count)
        }

        let projectName = ProjectPathEncoder.encode(projectPath)

        do {
            let result = try await repository.bulkOperation(
                projectName: projectName,
                sessionIds: sessionIds,
                action: "delete",
                customTitle: nil
            )

            // Update local state - remove deleted sessions
            if var sessions = sessionsByProject[projectPath] {
                sessions.removeAll { result.success.contains($0.id) }
                sessionsByProject[projectPath] = sessions
            }

            // Clear active session if it was deleted
            if let activeId = activeSessionIds[projectPath], result.success.contains(activeId) {
                activeSessionIds[projectPath] = nil
                MessageStore.clearSessionId(for: projectPath)
            }

            log.info("[SessionStore] Bulk deleted \(result.successCount) sessions, \(result.failedCount) failed")

            // Reload counts
            await loadSessionCounts(for: projectPath)

            return (result.successCount, result.failedCount)
        } catch {
            log.error("[SessionStore] Bulk delete failed: \(error)")
            return (0, sessionIds.count)
        }
    }
}
