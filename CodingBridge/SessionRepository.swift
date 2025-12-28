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

// MARK: - API Session Repository Implementation

/// Production implementation using APIClient for HTTP requests
@MainActor
final class APISessionRepository: SessionRepository {
    private let apiClient: APIClient
    private let settings: AppSettings

    init(apiClient: APIClient, settings: AppSettings) {
        self.apiClient = apiClient
        self.settings = settings
    }

    func fetchSessions(projectName: String, limit: Int = 100, offset: Int = 0) async throws -> SessionsResponse {
        guard let baseURL = settings.baseURL else {
            throw APIError.invalidURL
        }

        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }

        // API endpoint: /api/projects/:projectName/sessions
        components.path = "/api/projects/\(projectName)/sessions"
        components.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        if !settings.authToken.isEmpty {
            request.setValue("Bearer \(settings.authToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError
        }

        if httpResponse.statusCode == 401 {
            throw APIError.authenticationFailed
        }

        guard httpResponse.statusCode == 200 else {
            log.error("Sessions fetch failed with status: \(httpResponse.statusCode)")
            throw APIError.serverError
        }

        do {
            let response = try JSONDecoder().decode(SessionsResponse.self, from: data)
            log.debug("[SessionRepository] Fetched \(response.sessions.count) sessions (total: \(response.total), hasMore: \(response.hasMore))")
            return response
        } catch {
            log.error("[SessionRepository] Failed to decode sessions response: \(error)")
            if let json = String(data: data, encoding: .utf8) {
                log.debug("[SessionRepository] Raw response: \(json.prefix(500))")
            }
            throw error
        }
    }

    func deleteSession(projectName: String, sessionId: String) async throws {
        guard let baseURL = settings.baseURL else {
            throw APIError.invalidURL
        }

        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }

        // API endpoint: DELETE /api/projects/:projectName/sessions/:sessionId
        components.path = "/api/projects/\(projectName)/sessions/\(sessionId)"

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if !settings.authToken.isEmpty {
            request.setValue("Bearer \(settings.authToken)", forHTTPHeaderField: "Authorization")
        }

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError
        }

        if httpResponse.statusCode == 401 {
            throw APIError.authenticationFailed
        }

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            log.error("Session delete failed with status: \(httpResponse.statusCode)")
            throw APIError.serverError
        }
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
            throw APIError.serverError
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
            throw APIError.serverError
        }
        mockSessions.removeAll { $0.id == sessionId }
    }
}
#endif
