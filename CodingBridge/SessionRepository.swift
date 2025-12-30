import Foundation

// MARK: - Session Repository Protocol

/// Protocol defining session data operations
/// Abstraction layer between SessionStore and APIClient for testability
protocol SessionRepository {
    /// Fetch sessions for a project with pagination
    /// - Parameters:
    ///   - projectName: The encoded project name (e.g., "-home-dev-workspace-ClaudeCodeApp")
    ///   - limit: Maximum sessions to return
    ///   - offset: Pagination offset
    /// - Returns: SessionsResponse containing sessions, hasMore flag, and total count
    func fetchSessions(projectName: String, limit: Int, offset: Int) async throws -> SessionsResponse

    /// Delete a session from the server
    /// - Parameters:
    ///   - projectName: The encoded project name
    ///   - sessionId: The session ID to delete
    func deleteSession(projectName: String, sessionId: String) async throws
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
        // Convert project name back to path for cli-bridge API
        // Note: cli-bridge uses the path encoding directly in URL
        let projectPath = projectName.replacingOccurrences(of: "-", with: "/")

        let response = try await apiClient.fetchSessions(
            projectPath: projectPath,
            limit: limit,
            cursor: offset > 0 ? String(offset) : nil
        )

        // Convert CLISessionMetadata to ProjectSession
        let projectSessions = response.sessions.toProjectSessions()

        return SessionsResponse(
            sessions: projectSessions,
            hasMore: response.hasMore,
            total: projectSessions.count + (response.hasMore ? 1 : 0)  // Approximate total
        )
    }

    func deleteSession(projectName: String, sessionId: String) async throws {
        // Convert project name back to path
        let projectPath = projectName.replacingOccurrences(of: "-", with: "/")

        try await apiClient.deleteSession(
            projectPath: projectPath,
            sessionId: sessionId
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
}
#endif
