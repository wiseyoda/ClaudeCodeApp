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
    /// - Parameters:
    ///   - projectPath: Project directory path
    ///   - limit: Maximum sessions to return (default 100)
    ///   - cursor: Pagination cursor/offset
    ///   - source: Filter by session source (user/agent/helper)
    ///   - includeArchived: Include archived sessions in results (default false)
    ///   - archivedOnly: Only return archived sessions (default false)
    ///   - parentSessionId: Filter by parent session for lineage queries
    func fetchSessions(
        projectPath: String,
        limit: Int = 100,
        cursor: String? = nil,
        source: CLISessionMetadata.SessionSource? = nil,
        includeArchived: Bool = false,
        archivedOnly: Bool = false,
        parentSessionId: String? = nil
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
        if includeArchived {
            queryItems.append(URLQueryItem(name: "includeArchived", value: "true"))
        }
        if archivedOnly {
            queryItems.append(URLQueryItem(name: "archivedOnly", value: "true"))
        }
        if let parentSessionId = parentSessionId {
            queryItems.append(URLQueryItem(name: "parentSessionId", value: parentSessionId))
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

    /// Fetch recent sessions across all projects (for home screen activity feed)
    func fetchRecentSessions(limit: Int = 5) async throws -> [CLISessionMetadata] {
        let queryItems = [
            URLQueryItem(name: "limit", value: String(limit))
        ]
        let response: CLISessionsResponse = try await get("/sessions/recent", queryItems: queryItems)
        return response.sessions
    }

    // MARK: - Session Count

    /// Get session count with breakdown by source
    /// - Parameters:
    ///   - projectPath: Project directory path
    ///   - source: Optional source filter (returns single count if specified)
    func getSessionCount(
        projectPath: String,
        source: CLISessionMetadata.SessionSource? = nil
    ) async throws -> CLISessionCountResponse {
        let encodedPath = encodeProjectPath(projectPath)
        var queryItems: [URLQueryItem] = []

        if let source = source {
            queryItems.append(URLQueryItem(name: "source", value: source.rawValue))
        }

        return try await get(
            "/projects/\(encodedPath)/sessions/count",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
    }

    // MARK: - Session Search

    /// Search sessions by keyword
    /// - Parameters:
    ///   - projectPath: Project directory path
    ///   - query: Search query string
    ///   - limit: Maximum results to return (default 20)
    ///   - offset: Pagination offset (default 0)
    func searchSessions(
        projectPath: String,
        query: String,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> CLISessionSearchResponse {
        let encodedPath = encodeProjectPath(projectPath)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "q", value: query)
        ]

        if limit != 20 {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if offset > 0 {
            queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        }

        return try await get("/projects/\(encodedPath)/sessions/search", queryItems: queryItems)
    }

    // MARK: - Session Archive

    /// Archive a session (soft delete)
    /// - Parameters:
    ///   - projectPath: Project directory path
    ///   - sessionId: Session ID to archive
    /// - Returns: Updated session metadata with archivedAt timestamp
    func archiveSession(projectPath: String, sessionId: String) async throws -> CLISessionMetadata {
        let encodedPath = encodeProjectPath(projectPath)
        return try await post("/projects/\(encodedPath)/sessions/\(sessionId)/archive")
    }

    /// Unarchive a session (restore from archive)
    /// - Parameters:
    ///   - projectPath: Project directory path
    ///   - sessionId: Session ID to unarchive
    /// - Returns: Updated session metadata with archivedAt cleared
    func unarchiveSession(projectPath: String, sessionId: String) async throws -> CLISessionMetadata {
        let encodedPath = encodeProjectPath(projectPath)
        return try await post("/projects/\(encodedPath)/sessions/\(sessionId)/unarchive")
    }

    // MARK: - Session Children (Lineage)

    /// Get child sessions (sessions spawned by Task tool from this session)
    /// - Parameters:
    ///   - projectPath: Project directory path
    ///   - sessionId: Parent session ID
    ///   - limit: Maximum sessions to return (default 50)
    ///   - offset: Pagination offset (default 0)
    func getSessionChildren(
        projectPath: String,
        sessionId: String,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> CLISessionsResponse {
        let encodedPath = encodeProjectPath(projectPath)
        var queryItems: [URLQueryItem] = []

        if limit != 50 {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if offset > 0 {
            queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        }

        return try await get(
            "/projects/\(encodedPath)/sessions/\(sessionId)/children",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
    }

    // MARK: - Bulk Operations

    /// Execute bulk operation on multiple sessions
    /// - Parameters:
    ///   - projectPath: Project directory path
    ///   - sessionIds: Session IDs to operate on (max 100)
    ///   - action: Operation: "archive", "unarchive", "delete", "update"
    ///   - customTitle: For update action, the new custom title
    func bulkSessionOperation(
        projectPath: String,
        sessionIds: [String],
        action: String,
        customTitle: String? = nil
    ) async throws -> CLIBulkOperationResponse {
        let encodedPath = encodeProjectPath(projectPath)
        let request = CLIBulkOperationRequest(
            sessionIds: sessionIds,
            action: action,
            customTitle: customTitle
        )
        return try await postWithBody("/projects/\(encodedPath)/sessions/bulk", body: request)
    }

    /// Fetch session messages with pagination
    /// GET /projects/:path/sessions/:id/messages
    /// - Parameters:
    ///   - projectPath: Project directory path
    ///   - sessionId: Session ID
    ///   - limit: Max messages to return (1-100, default 25)
    ///   - offset: Skip N messages (for offset-based pagination)
    ///   - before: Cursor for older messages (message ID)
    ///   - after: Cursor for newer messages (message ID)
    ///   - types: Filter by message types (e.g., "user,assistant")
    ///   - order: Sort order ("asc" or "desc", default "desc")
    ///   - includeRawContent: Include tool_use, tool_result, thinking blocks
    func fetchMessages(
        projectPath: String,
        sessionId: String,
        limit: Int? = nil,
        offset: Int? = nil,
        before: String? = nil,
        after: String? = nil,
        types: String? = nil,
        order: String? = nil,
        includeRawContent: Bool? = nil
    ) async throws -> CLIPaginatedMessagesResponse {
        let encodedPath = encodeProjectPath(projectPath)
        let request = CLIPaginatedMessagesRequest(
            limit: limit,
            offset: offset,
            before: before,
            after: after,
            types: types,
            order: order,
            includeRawContent: includeRawContent
        )
        let queryItems = request.queryItems
        return try await get(
            "/projects/\(encodedPath)/sessions/\(sessionId)/messages",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
    }

    /// Convenience: Fetch initial messages for mobile (last N messages, newest first)
    func fetchInitialMessages(
        projectPath: String,
        sessionId: String,
        limit: Int = 25
    ) async throws -> CLIPaginatedMessagesResponse {
        try await fetchMessages(
            projectPath: projectPath,
            sessionId: sessionId,
            limit: limit,
            order: "desc",
            includeRawContent: true
        )
    }

    /// Convenience: Load more (older) messages for "scroll up" pagination
    func fetchOlderMessages(
        projectPath: String,
        sessionId: String,
        before: String,
        limit: Int = 25
    ) async throws -> CLIPaginatedMessagesResponse {
        try await fetchMessages(
            projectPath: projectPath,
            sessionId: sessionId,
            limit: limit,
            before: before,
            order: "desc",
            includeRawContent: true
        )
    }

    /// Convenience: Sync newer messages (real-time updates)
    func fetchNewerMessages(
        projectPath: String,
        sessionId: String,
        after: String
    ) async throws -> CLIPaginatedMessagesResponse {
        try await fetchMessages(
            projectPath: projectPath,
            sessionId: sessionId,
            after: after,
            order: "asc",
            includeRawContent: true
        )
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

    // MARK: - Project Management

    /// Create a new project directory
    func createProject(name: String, baseDir: String? = nil, initializeClaude: Bool = true) async throws -> CLICreateProjectResponse {
        let body = CLICreateProjectRequest(name: name, baseDir: baseDir, initializeClaude: initializeClaude)
        return try await postWithBody("/projects/create", body: body)
    }

    /// Clone a git repository
    func cloneProject(url: String, baseDir: String? = nil, initializeClaude: Bool = true) async throws -> CLICloneProjectResponse {
        let body = CLICloneProjectRequest(url: url, baseDir: baseDir, initializeClaude: initializeClaude)
        return try await postWithBody("/projects/clone", body: body)
    }

    /// Delete a project
    func deleteProject(projectPath: String, deleteFiles: Bool = false) async throws {
        let encodedPath = encodeProjectPath(projectPath)
        var queryItems: [URLQueryItem] = []
        if deleteFiles {
            queryItems.append(URLQueryItem(name: "deleteFiles", value: "true"))
        }
        let _: CLIDeleteProjectResponse = try await delete("/projects/\(encodedPath)", queryItems: queryItems.isEmpty ? nil : queryItems)
    }

    /// Git pull for a project
    func gitPull(projectPath: String) async throws -> CLIGitPullResponse {
        let encodedPath = encodeProjectPath(projectPath)
        return try await post("/projects/\(encodedPath)/git/pull")
    }

    /// Discover sub-repositories in a project
    func discoverSubRepos(projectPath: String, maxDepth: Int = 2) async throws -> [CLISubRepoInfo] {
        let encodedPath = encodeProjectPath(projectPath)
        let queryItems = [URLQueryItem(name: "maxDepth", value: String(maxDepth))]
        let response: CLISubReposResponse = try await get("/projects/\(encodedPath)/subrepos", queryItems: queryItems)
        return response.subrepos
    }

    /// Git pull for a sub-repository
    func pullSubRepo(projectPath: String, relativePath: String) async throws -> CLIGitPullResponse {
        let encodedPath = encodeProjectPath(projectPath)
        let encodedRelative = relativePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? relativePath
        return try await post("/projects/\(encodedPath)/subrepos/\(encodedRelative)/pull")
    }

    // MARK: - Private Helpers

    private func encodeProjectPath(_ path: String) -> String {
        // Convert /home/dev/project → -home-dev-project
        return path.replacingOccurrences(of: "/", with: "-")
    }

    private func buildURL(_ endpoint: String, queryItems: [URLQueryItem]? = nil) -> URL? {
        let urlString = serverURL + endpoint

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

        let start = CFAbsoluteTimeGetCurrent()
        log.debug("[API] GET \(url.absoluteString)")
        let (data, response) = try await session.data(for: request)
        log.debug("[API] GET \(endpoint) completed in \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - start) * 1000))ms")
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
    let total: Int?  // NEW: Total session count (cli-bridge now returns this)

    // Custom decoder to handle missing pagination fields
    // cli-bridge may only send { sessions: [...] } without cursor/hasMore/total
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessions = try container.decode([CLISessionMetadata].self, forKey: .sessions)
        cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
        total = try container.decodeIfPresent(Int.self, forKey: .total)
    }

    private enum CodingKeys: String, CodingKey {
        case sessions, cursor, hasMore, total
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

// MARK: - Project Management Types

struct CLICreateProjectRequest: Encodable {
    let name: String
    let baseDir: String?
    let initializeClaude: Bool?
}

struct CLICreateProjectResponse: Decodable {
    let success: Bool
    let path: String
    let initialized: Bool
}

struct CLICloneProjectRequest: Encodable {
    let url: String
    let baseDir: String?
    let initializeClaude: Bool?
}

struct CLICloneProjectResponse: Decodable {
    let success: Bool
    let path: String
    let initialized: Bool
}

struct CLIDeleteProjectResponse: Decodable {
    let success: Bool
}

struct CLIGitPullResponse: Decodable {
    let success: Bool
    let message: String
    let commits: Int
    let files: [String]?
}

struct CLISubRepoInfo: Decodable, Identifiable {
    let relativePath: String
    let git: CLIGitStatus

    var id: String { relativePath }
}

struct CLISubReposResponse: Decodable {
    let subrepos: [CLISubRepoInfo]
}

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
