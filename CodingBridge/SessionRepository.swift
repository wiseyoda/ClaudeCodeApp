import Foundation

// MARK: - Session Repository Protocol

/// Protocol defining session data operations
/// Abstraction layer between SessionStore and APIClient for testability
protocol SessionRepository {
    /// Fetch sessions for a project with pagination
    /// - Parameters:
    ///   - projectName: The encoded project name (e.g., "-Users-me-ClaudeCodeApp")
    ///   - limit: Maximum sessions to return
    ///   - offset: Pagination offset
    /// - Returns: SessionsResponse containing sessions, hasMore flag, and total count
    func fetchSessions(projectName: String, limit: Int, offset: Int) async throws -> SessionsResponse

    /// Delete a session from the server
    /// - Parameters:
    ///   - projectName: The encoded project name
    ///   - sessionId: The session ID to delete
    func deleteSession(projectName: String, sessionId: String) async throws

    // MARK: - New Session Management Methods

    /// Get session count with breakdown by source
    /// - Parameters:
    ///   - projectName: The encoded project name
    ///   - source: Optional source filter
    func getSessionCount(projectName: String, source: CLISessionMetadata.SessionSource?) async throws -> CLISessionCountResponse

    /// Search sessions by keyword
    /// - Parameters:
    ///   - projectName: The encoded project name
    ///   - query: Search query string
    ///   - limit: Maximum results to return
    ///   - offset: Pagination offset
    func searchSessions(projectName: String, query: String, limit: Int, offset: Int) async throws -> CLISessionSearchResponse

    /// Archive a session (soft delete)
    /// - Parameters:
    ///   - projectName: The encoded project name
    ///   - sessionId: Session ID to archive
    func archiveSession(projectName: String, sessionId: String) async throws -> CLISessionMetadata

    /// Unarchive a session (restore from archive)
    /// - Parameters:
    ///   - projectName: The encoded project name
    ///   - sessionId: Session ID to unarchive
    func unarchiveSession(projectName: String, sessionId: String) async throws -> CLISessionMetadata

    /// Execute bulk operation on multiple sessions
    /// - Parameters:
    ///   - projectName: The encoded project name
    ///   - sessionIds: Session IDs to operate on
    ///   - action: Operation type: "archive", "unarchive", "delete", "update"
    ///   - customTitle: For update action, the new custom title
    func bulkOperation(projectName: String, sessionIds: [String], action: String, customTitle: String?) async throws -> CLIBulkOperationResponse
}

// MARK: - Response Models

/// Response from sessions API endpoint
struct SessionsResponse: Codable {
    let sessions: [ProjectSession]
    let hasMore: Bool
    let total: Int

    /// Convert to ProjectSessionMeta
    var toMeta: ProjectSessionMeta {
        ProjectSessionMeta(hasMore: hasMore, total: total)
    }
}

// MARK: - CLI Bridge Session Repository Implementation

/// Implementation using CLIBridgeAPIClient for the cli-bridge backend
@MainActor
final class CLIBridgeSessionRepository: SessionRepository {
    private let apiClient: CLIBridgeAPIClient
    private let settings: AppSettings

    init(apiClient: CLIBridgeAPIClient, settings: AppSettings) {
        self.apiClient = apiClient
        self.settings = settings
    }

    func fetchSessions(projectName: String, limit: Int = 100, offset: Int = 0) async throws -> SessionsResponse {
        let projectPath = ProjectPathEncoder.decode(projectName)

        let response = try await apiClient.fetchSessions(
            projectPath: projectPath,
            limit: limit,
            cursor: offset > 0 ? String(offset) : nil
        )

        // DEBUG: Log first session title to verify API response
        if let first = response.sessions.first {
            log.debug("[SessionRepo] First session title from API: '\(first.title ?? "nil")' lastUser: '\(first.lastUserMessage ?? "nil")'")
        }

        // Convert CLISessionMetadata to ProjectSession
        let projectSessions = response.sessions.toProjectSessions()

        // DEBUG: Log converted session
        if let first = projectSessions.first {
            log.debug("[SessionRepo] After toProjectSession: summary='\(first.summary ?? "nil")' lastUser='\(first.lastUserMessage ?? "nil")'")
        }

        // Use the actual total from API if available, otherwise approximate
        let total = response.total ?? (projectSessions.count + (response.hasMore ? 1 : 0))

        return SessionsResponse(
            sessions: projectSessions,
            hasMore: response.hasMore,
            total: total
        )
    }

    func deleteSession(projectName: String, sessionId: String) async throws {
        let projectPath = ProjectPathEncoder.decode(projectName)
        try await apiClient.deleteSession(
            projectPath: projectPath,
            sessionId: sessionId
        )
    }

    // MARK: - New Session Management Methods

    func getSessionCount(projectName: String, source: CLISessionMetadata.SessionSource?) async throws -> CLISessionCountResponse {
        let projectPath = ProjectPathEncoder.decode(projectName)
        return try await apiClient.getSessionCount(
            projectPath: projectPath,
            source: source
        )
    }

    func searchSessions(projectName: String, query: String, limit: Int, offset: Int) async throws -> CLISessionSearchResponse {
        let projectPath = ProjectPathEncoder.decode(projectName)
        return try await apiClient.searchSessions(
            projectPath: projectPath,
            query: query,
            limit: limit,
            offset: offset
        )
    }

    func archiveSession(projectName: String, sessionId: String) async throws -> CLISessionMetadata {
        let projectPath = ProjectPathEncoder.decode(projectName)
        return try await apiClient.archiveSession(
            projectPath: projectPath,
            sessionId: sessionId
        )
    }

    func unarchiveSession(projectName: String, sessionId: String) async throws -> CLISessionMetadata {
        let projectPath = ProjectPathEncoder.decode(projectName)
        return try await apiClient.unarchiveSession(
            projectPath: projectPath,
            sessionId: sessionId
        )
    }

    func bulkOperation(projectName: String, sessionIds: [String], action: String, customTitle: String?) async throws -> CLIBulkOperationResponse {
        let projectPath = ProjectPathEncoder.decode(projectName)
        return try await apiClient.bulkSessionOperation(
            projectPath: projectPath,
            sessionIds: sessionIds,
            action: action,
            customTitle: customTitle
        )
    }
}

// MARK: - Mock Repository for Testing

#if DEBUG
/// Mock implementation for unit tests
final class MockSessionRepository: SessionRepository {
    var mockSessions: [ProjectSession] = []
    var mockTotal: Int = 0
    var mockHasMore: Bool = false
    var fetchSessionsCalled = false
    var deleteSessionCalled = false
    var shouldThrowError = false

    // New mock data
    var mockCountResponse = CLISessionCountResponse(total: 0, count: nil, source: nil, user: nil, agent: nil, helper: nil)
    var mockSearchResponse = CLISessionSearchResponse(query: "", total: 0, results: [], hasMore: false)
    var archiveSessionCalled = false
    var unarchiveSessionCalled = false
    var bulkOperationCalled = false
    var lastBulkAction: String?

    func fetchSessions(projectName: String, limit: Int, offset: Int) async throws -> SessionsResponse {
        fetchSessionsCalled = true
        if shouldThrowError {
            throw CLIBridgeAPIError.serverError(500)
        }

        // Simulate pagination
        let start = offset
        let end = min(offset + limit, mockSessions.count)
        let paginatedSessions = Array(mockSessions[start..<end])

        return SessionsResponse(
            sessions: paginatedSessions,
            hasMore: end < mockTotal,
            total: mockTotal
        )
    }

    func deleteSession(projectName: String, sessionId: String) async throws {
        deleteSessionCalled = true
        if shouldThrowError {
            throw CLIBridgeAPIError.serverError(500)
        }
        mockSessions.removeAll { $0.id == sessionId }
    }

    func getSessionCount(projectName: String, source: CLISessionMetadata.SessionSource?) async throws -> CLISessionCountResponse {
        if shouldThrowError {
            throw CLIBridgeAPIError.serverError(500)
        }
        return mockCountResponse
    }

    func searchSessions(projectName: String, query: String, limit: Int, offset: Int) async throws -> CLISessionSearchResponse {
        if shouldThrowError {
            throw CLIBridgeAPIError.serverError(500)
        }
        return mockSearchResponse
    }

    func archiveSession(projectName: String, sessionId: String) async throws -> CLISessionMetadata {
        archiveSessionCalled = true
        if shouldThrowError {
            throw CLIBridgeAPIError.serverError(500)
        }
        // Return a mock metadata - in real tests, you'd set this up properly
        fatalError("Mock archiveSession needs proper CLISessionMetadata setup")
    }

    func unarchiveSession(projectName: String, sessionId: String) async throws -> CLISessionMetadata {
        unarchiveSessionCalled = true
        if shouldThrowError {
            throw CLIBridgeAPIError.serverError(500)
        }
        fatalError("Mock unarchiveSession needs proper CLISessionMetadata setup")
    }

    func bulkOperation(projectName: String, sessionIds: [String], action: String, customTitle: String?) async throws -> CLIBulkOperationResponse {
        bulkOperationCalled = true
        lastBulkAction = action
        if shouldThrowError {
            throw CLIBridgeAPIError.serverError(500)
        }
        return CLIBulkOperationResponse(success: sessionIds, failed: [])
    }
}
#endif
