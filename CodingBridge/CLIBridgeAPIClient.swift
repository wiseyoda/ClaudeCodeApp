import Foundation
import UIKit

// MARK: - CLI Bridge REST API Client
// HTTP client for cli-bridge server REST endpoints
// See: requirements/projects/cli-bridge-migration/PROTOCOL-MAPPING.md

@MainActor
class CLIBridgeAPIClient: ObservableObject {
    private let serverURL: String
    private let session: URLSession

    init(serverURL: String) {
        self.serverURL = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.session = URLSession.shared
    }

    // MARK: - Projects

    /// Fetch all projects with git status
    func fetchProjects() async throws -> [CLIProject] {
        let response: CLIProjectsResponse = try await get("/projects")
        return response.projects
    }

    /// Force refresh the project cache (re-scans for git repos)
    func refreshProjects() async throws -> [CLIProject] {
        let response: CLIProjectsResponse = try await post("/projects/refresh")
        return response.projects
    }

    /// Get detailed information about a single project
    func getProjectDetail(projectPath: String) async throws -> CLIProjectDetail {
        let encodedPath = encodeProjectPath(projectPath)
        return try await get("/projects/\(encodedPath)")
    }

    // MARK: - Sessions

    /// Fetch sessions for a project
    func fetchSessions(
        projectPath: String,
        limit: Int = 100,
        cursor: String? = nil,
        source: CLISessionMetadata.SessionSource? = nil
    ) async throws -> CLISessionsResponse {
        let encodedPath = encodeProjectPath(projectPath)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        if let source = source {
            queryItems.append(URLQueryItem(name: "source", value: source.rawValue))
        }

        return try await get("/projects/\(encodedPath)/sessions", queryItems: queryItems)
    }

    /// Fetch a single session
    func fetchSession(projectPath: String, sessionId: String) async throws -> CLISessionMetadata {
        let encodedPath = encodeProjectPath(projectPath)
        return try await get("/projects/\(encodedPath)/sessions/\(sessionId)")
    }

    /// Rename a session (set custom title)
    func renameSession(projectPath: String, sessionId: String, title: String?) async throws {
        let encodedPath = encodeProjectPath(projectPath)
        let body = CLIRenameSessionRequest(title: title)
        let _: EmptyResponse = try await put("/projects/\(encodedPath)/sessions/\(sessionId)", body: body)
    }

    /// Delete a session
    func deleteSession(projectPath: String, sessionId: String) async throws {
        let encodedPath = encodeProjectPath(projectPath)
        try await delete("/projects/\(encodedPath)/sessions/\(sessionId)")
    }

    /// Delete sessions older than specified days
    func deleteSessions(projectPath: String, olderThanDays: Int) async throws -> CLIBulkDeleteResponse {
        let encodedPath = encodeProjectPath(projectPath)
        let queryItems = [
            URLQueryItem(name: "filter", value: "older_than"),
            URLQueryItem(name: "days", value: String(olderThanDays))
        ]
        return try await delete("/projects/\(encodedPath)/sessions", queryItems: queryItems)
    }

    /// Fetch session messages (history)
    /// Note: This endpoint doesn't exist in cli-bridge. Use exportSession() instead.
    func fetchSessionMessages(projectPath: String, sessionId: String) async throws -> [CLISessionMessage] {
        // The /messages endpoint doesn't exist in cli-bridge
        // Callers should use exportSession(format: .json) and parse the content
        throw CLIBridgeAPIError.endpointNotAvailable("Session messages endpoint not available - use exportSession() instead")
    }

    /// Export a session as Markdown or JSON
    /// Note: cli-bridge returns raw content, not JSON wrapper
    /// - Parameters:
    ///   - includeStructuredContent: When true with JSON format, preserves content arrays with tool_use, tool_result, thinking blocks
    func exportSession(
        projectPath: String,
        sessionId: String,
        format: CLIExportFormat = .markdown,
        excludeThinking: Bool = false,
        includeStructuredContent: Bool = false
    ) async throws -> CLIExportResponse {
        let encodedPath = encodeProjectPath(projectPath)
        var queryItems = [
            URLQueryItem(name: "format", value: format.rawValue)
        ]
        if excludeThinking {
            queryItems.append(URLQueryItem(name: "excludeThinking", value: "true"))
        }
        if includeStructuredContent && format == .json {
            queryItems.append(URLQueryItem(name: "includeStructuredContent", value: "true"))
        }

        guard let url = buildURL("/projects/\(encodedPath)/sessions/\(sessionId)/export", queryItems: queryItems) else {
            throw CLIBridgeAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        // cli-bridge returns raw content, not JSON
        guard let content = String(data: data, encoding: .utf8) else {
            throw CLIBridgeAPIError.invalidResponse
        }

        // Determine format from Content-Type header
        let httpResponse = response as? HTTPURLResponse
        let contentType = httpResponse?.value(forHTTPHeaderField: "Content-Type") ?? ""
        let actualFormat: CLIExportFormat = contentType.contains("json") ? .json : .markdown

        return CLIExportResponse(
            sessionId: sessionId,
            format: actualFormat,
            content: content
        )
    }

    // MARK: - Files

    /// List files in a directory
    func listFiles(projectPath: String, directory: String = "/") async throws -> CLIFileListResponse {
        let encodedPath = encodeProjectPath(projectPath)
        let queryItems = [URLQueryItem(name: "dir", value: directory)]
        return try await get("/projects/\(encodedPath)/files", queryItems: queryItems)
    }

    /// Read file content
    func readFile(projectPath: String, filePath: String) async throws -> CLIFileContentResponse {
        let encodedPath = encodeProjectPath(projectPath)
        // URL encode the file path for the URL
        let encodedFilePath = filePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filePath
        return try await get("/projects/\(encodedPath)/files/\(encodedFilePath)")
    }

    // MARK: - Search

    /// Search across sessions with pagination and snippet highlighting
    /// - Parameters:
    ///   - query: Search keywords
    ///   - projectPath: Optional filter by project path
    ///   - limit: Results per page (default 20, max 100)
    ///   - offset: Pagination offset (default 0)
    /// - Returns: CLISearchResponse with results containing snippets and match positions
    func search(
        query: String,
        projectPath: String? = nil,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> CLISearchResponse {
        var queryItems = [
            URLQueryItem(name: "q", value: query)
        ]
        if let projectPath = projectPath {
            queryItems.append(URLQueryItem(name: "project", value: projectPath))
        }
        if limit != 20 {
            queryItems.append(URLQueryItem(name: "limit", value: String(min(limit, 100))))
        }
        if offset > 0 {
            queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        return try await get("/search", queryItems: queryItems)
    }

    // MARK: - Images

    /// Upload an image for an agent
    func uploadImage(agentId: String, imageData: Data, mimeType: String) async throws -> CLIImageUploadResponse {
        let endpoint = "/agents/\(agentId)/upload"
        guard let url = buildURL(endpoint) else {
            throw CLIBridgeAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(CLIImageUploadResponse.self, from: data)
    }

    // MARK: - Agents

    /// List active agents
    func listAgents() async throws -> CLIAgentsResponse {
        return try await get("/agents")
    }

    /// Get agent info
    func getAgent(agentId: String) async throws -> CLIAgentInfo {
        return try await get("/agents/\(agentId)")
    }

    // MARK: - Health

    /// Check server health
    func healthCheck() async throws -> CLIHealthResponse {
        return try await get("/health")
    }

    /// Get server metrics (counters, gauges, histograms)
    func getMetrics() async throws -> CLIMetricsResponse {
        return try await get("/metrics")
    }

    /// Get available models
    func getModels() async throws -> CLIModelsResponse {
        return try await get("/models")
    }

    /// Get available thinking modes
    func getThinkingModes() async throws -> CLIThinkingModesResponse {
        return try await get("/thinking-modes")
    }

    // MARK: - Permissions

    /// Get permission configuration from server
    func getPermissions() async throws -> PermissionConfig {
        return try await get("/permissions")
    }

    /// Update permission configuration (merges with existing)
    func updatePermissions(_ updates: PermissionConfigUpdate) async throws {
        let _: EmptyResponse = try await put("/permissions", body: updates)
    }

    // MARK: - Push Notifications

    /// Register FCM token for push notifications
    /// - Parameters:
    ///   - fcmToken: Firebase Cloud Messaging token
    ///   - environment: APNs environment ("sandbox" or "production")
    func registerPushToken(
        fcmToken: String,
        environment: String
    ) async throws -> CLIPushRegisterResponse {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let osVersion = UIDevice.current.systemVersion

        let request = CLIPushRegisterRequest(
            fcmToken: fcmToken,
            environment: environment,
            appVersion: appVersion,
            osVersion: osVersion
        )
        return try await postWithBody("/api/push/register", body: request)
    }

    /// Register Live Activity push token
    func registerLiveActivityToken(
        pushToken: String,
        pushToStartToken: String? = nil,
        activityId: String,
        sessionId: String,
        environment: String
    ) async throws -> CLILiveActivityRegisterResponse {
        let request = CLILiveActivityRegisterRequest(
            pushToken: pushToken,
            pushToStartToken: pushToStartToken,
            activityId: activityId,
            sessionId: sessionId,
            environment: environment
        )
        return try await postWithBody("/api/push/live-activity", body: request)
    }

    /// Invalidate a push token (on logout or token refresh)
    func invalidatePushToken(tokenType: CLIPushInvalidateRequest.TokenType, token: String) async throws {
        let request = CLIPushInvalidateRequest(tokenType: tokenType, token: token)
        let _: CLIPushSuccessResponse = try await deleteWithBody("/api/push/invalidate", body: request)
    }

    /// Get push registration status
    func getPushStatus() async throws -> CLIPushStatusResponse {
        return try await get("/api/push/status")
    }

    // MARK: - Private Helpers

    private func encodeProjectPath(_ path: String) -> String {
        // Convert /home/dev/project → -home-dev-project
        return path.replacingOccurrences(of: "/", with: "-")
    }

    private func buildURL(_ endpoint: String, queryItems: [URLQueryItem]? = nil) -> URL? {
        var urlString = serverURL + endpoint

        if let queryItems = queryItems, !queryItems.isEmpty {
            var components = URLComponents(string: urlString)
            components?.queryItems = queryItems
            return components?.url
        }

        return URL(string: urlString)
    }

    private func get<T: Decodable>(_ endpoint: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        guard let url = buildURL(endpoint, queryItems: queryItems) else {
            throw CLIBridgeAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<T: Decodable>(_ endpoint: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        guard let url = buildURL(endpoint, queryItems: queryItems) else {
            throw CLIBridgeAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func postWithBody<T: Decodable, B: Encodable>(_ endpoint: String, body: B) async throws -> T {
        guard let url = buildURL(endpoint) else {
            throw CLIBridgeAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add Authorization header with userId
        let userId = KeychainHelper.shared.getOrCreateUserId()
        request.setValue("Bearer \(userId)", forHTTPHeaderField: "Authorization")

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func put<T: Decodable, B: Encodable>(_ endpoint: String, body: B) async throws -> T {
        guard let url = buildURL(endpoint) else {
            throw CLIBridgeAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func delete(_ endpoint: String, queryItems: [URLQueryItem]? = nil) async throws {
        guard let url = buildURL(endpoint, queryItems: queryItems) else {
            throw CLIBridgeAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    private func delete<T: Decodable>(_ endpoint: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        guard let url = buildURL(endpoint, queryItems: queryItems) else {
            throw CLIBridgeAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func deleteWithBody<T: Decodable, B: Encodable>(_ endpoint: String, body: B) async throws -> T {
        guard let url = buildURL(endpoint) else {
            throw CLIBridgeAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add Authorization header with userId
        let userId = KeychainHelper.shared.getOrCreateUserId()
        request.setValue("Bearer \(userId)", forHTTPHeaderField: "Authorization")

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CLIBridgeAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 400:
            throw CLIBridgeAPIError.badRequest
        case 401:
            throw CLIBridgeAPIError.unauthorized
        case 403:
            throw CLIBridgeAPIError.forbidden
        case 404:
            throw CLIBridgeAPIError.notFound
        case 429:
            throw CLIBridgeAPIError.rateLimited
        case 500...599:
            throw CLIBridgeAPIError.serverError(httpResponse.statusCode)
        default:
            throw CLIBridgeAPIError.unexpectedStatus(httpResponse.statusCode)
        }
    }
}

// MARK: - API Response Types

struct CLIProjectsResponse: Decodable {
    let projects: [CLIProject]
}

struct CLISessionsResponse: Decodable {
    let sessions: [CLISessionMetadata]
    let cursor: String?
    let hasMore: Bool

    // Custom decoder to handle missing pagination fields
    // cli-bridge may only send { sessions: [...] } without cursor/hasMore
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessions = try container.decode([CLISessionMetadata].self, forKey: .sessions)
        cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case sessions, cursor, hasMore
    }
}

struct CLIRenameSessionRequest: Encodable {
    let title: String?
}

struct CLIBulkDeleteResponse: Decodable {
    let deleted: Int
    let sessionIds: [String]?  // Made optional: cli-bridge may only send { deleted: count }
}

struct CLISessionMessagesResponse: Decodable {
    let messages: [CLISessionMessage]
}

struct CLISessionMessage: Decodable {
    let role: String
    let content: String
    let timestamp: String?
    let toolName: String?
    let toolInput: String?
    let toolResult: String?
    let thinking: String?

    /// Convert to ChatMessage for UI display
    func toChatMessage() -> ChatMessage? {
        // Parse timestamp
        var date = Date()
        if let ts = timestamp {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let parsedDate = formatter.date(from: ts) {
                date = parsedDate
            } else {
                formatter.formatOptions = [.withInternetDateTime]
                date = formatter.date(from: ts) ?? Date()
            }
        }

        // Map role
        let msgRole: ChatMessage.Role
        switch role.lowercased() {
        case "user":
            msgRole = .user
        case "assistant":
            msgRole = .assistant
        case "system":
            msgRole = .system
        default:
            msgRole = .assistant
        }

        // Build content
        var fullContent = content

        // Add thinking if present
        if let thinkingContent = thinking, !thinkingContent.isEmpty {
            fullContent = "<thinking>\n\(thinkingContent)\n</thinking>\n\n" + fullContent
        }

        // Add tool result if present
        if let toolResult = toolResult, !toolResult.isEmpty {
            fullContent += "\n\n<tool_result>\n\(toolResult)\n</tool_result>"
        }

        return ChatMessage(role: msgRole, content: fullContent, timestamp: date)
    }
}

struct CLIImageUploadResponse: Decodable {
    let id: String
    let mimeType: String
    let size: Int
}

struct CLIAgentsResponse: Decodable {
    let agents: [CLIAgentInfo]
}

struct CLIAgentInfo: Decodable {
    let id: String
    let sessionId: String
    let project: String
    let model: String
    let state: CLIAgentState
    let createdAt: String
    let lastActivityAt: String
}

struct CLIHealthResponse: Decodable {
    let status: String
    let version: String
    let uptime: Int?
    let agents: Int?
}

/// Response from /metrics endpoint
struct CLIMetricsResponse: Decodable {
    let uptime: Int
    let version: String
    let agents: Int
    let counters: [String: Int]?
    let gauges: [String: Double]?
    let histograms: [String: CLIHistogramStats]?
}

struct CLIHistogramStats: Decodable {
    let min: Double
    let max: Double
    let avg: Double
    let p50: Double
    let p95: Double
    let count: Int
}

struct CLIModelsResponse: Decodable {
    let models: [CLIModelInfo]
    let defaultModel: String?
}

struct CLIModelInfo: Decodable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let contextWindow: Int?
    let isDefault: Bool?
}

struct CLIThinkingModesResponse: Decodable {
    let modes: [CLIThinkingModeInfo]
}

struct CLIThinkingModeInfo: Decodable, Identifiable {
    let id: String
    let name: String
    let description: String
    let phrase: String
    let budget: Int
}

struct EmptyResponse: Decodable {}

// MARK: - Errors

enum CLIBridgeAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case badRequest
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError(Int)
    case unexpectedStatus(Int)
    case decodingError(Error)
    case endpointNotAvailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid server response"
        case .badRequest:
            return "Bad request"
        case .unauthorized:
            return "Unauthorized - check credentials"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Rate limited - please wait"
        case .serverError(let code):
            return "Server error (\(code))"
        case .unexpectedStatus(let code):
            return "Unexpected response (\(code))"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .endpointNotAvailable(let message):
            return message
        }
    }
}

// Note: Uses global 'log' from Logger.swift
