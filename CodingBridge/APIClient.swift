import Foundation

@MainActor
class APIClient: ObservableObject {
    private var settings: AppSettings
    @Published var isLoading = false
    @Published var isAuthenticated = false

    /// Initialize with optional settings. Call configure() in onAppear with the EnvironmentObject.
    init(settings: AppSettings? = nil) {
        // Use provided settings or create temporary placeholder
        // The real settings should be provided via configure() in onAppear
        self.settings = settings ?? AppSettings()
        // Check if we have a stored token
        self.isAuthenticated = !self.settings.authToken.isEmpty
    }

    /// Update settings reference (call from onAppear with actual EnvironmentObject)
    func configure(with newSettings: AppSettings) {
        self.settings = newSettings
        self.isAuthenticated = !newSettings.authToken.isEmpty
    }

    // MARK: - Authentication

    func login() async throws {
        guard let url = settings.baseURL?.appendingPathComponent("api/auth/login") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let loginData = ["username": settings.authUsername, "password": settings.authPassword]
        request.httpBody = try JSONEncoder().encode(loginData)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError
        }

        if httpResponse.statusCode == 200 {
            let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
            settings.authToken = loginResponse.token
            isAuthenticated = true
        } else {
            throw APIError.authenticationFailed
        }
    }

    func checkAuthStatus() async throws -> Bool {
        guard let url = settings.baseURL?.appendingPathComponent("api/auth/status") else {
            throw APIError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let status = try JSONDecoder().decode(AuthStatus.self, from: data)

        if status.needsSetup {
            // Register first user
            try await register()
            return true
        }

        return !settings.authToken.isEmpty
    }

    private func register() async throws {
        guard let url = settings.baseURL?.appendingPathComponent("api/auth/register") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let registerData = ["username": settings.authUsername, "password": settings.authPassword]
        request.httpBody = try JSONEncoder().encode(registerData)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }

        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        settings.authToken = loginResponse.token
        isAuthenticated = true
    }

    private func authorizedRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        // Use JWT token from login (apiKey field is deprecated - ck_ keys only work for /api/agent)
        if !settings.authToken.isEmpty {
            request.setValue("Bearer \(settings.authToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    // MARK: - Projects

    /// Fetch all projects from the API.
    /// - Parameter retryCount: Internal counter to prevent infinite retry loops (max 1 retry after re-auth)
    func fetchProjects(retryCount: Int = 0) async throws -> [Project] {
        guard let url = settings.baseURL?.appendingPathComponent("api/projects") else {
            throw APIError.invalidURL
        }

        let request = authorizedRequest(for: url)
        log.debug("Fetching projects from: \(url)")
        // Redact the actual token value for security - only log presence/type
        let authHeaderStatus: String
        if let authHeader = request.value(forHTTPHeaderField: "Authorization") {
            if authHeader.hasPrefix("Bearer ") {
                authHeaderStatus = "Bearer [REDACTED]"
            } else {
                authHeaderStatus = "[REDACTED]"
            }
        } else {
            authHeaderStatus = "none"
        }
        log.debug("Auth header: \(authHeaderStatus)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError
        }

        log.debug("Projects response status: \(httpResponse.statusCode)")

        if httpResponse.statusCode == 401 {
            // Only retry once to prevent infinite loop
            guard retryCount < 1 else {
                log.error("Auth retry limit reached, giving up")
                throw APIError.authenticationFailed
            }
            // Try to login with username/password and retry
            log.debug("Got 401, attempting login (retry \(retryCount + 1)/1)...")
            try await login()
            return try await fetchProjects(retryCount: retryCount + 1)
        }

        guard httpResponse.statusCode == 200 else {
            log.error("Projects fetch failed with status: \(httpResponse.statusCode)")
            if let responseText = String(data: data, encoding: .utf8) {
                log.error("Response: \(responseText)")
            }
            throw APIError.serverError
        }

        // New API returns array directly, not wrapped
        let projects = try JSONDecoder().decode([Project].self, from: data)

        // Debug: Log session counts for each project
        for project in projects {
            let sessionCount = project.sessions?.count ?? 0
            log.debug("Project '\(project.name)' has \(sessionCount) sessions from API")
            if sessionCount > 0, let sessions = project.sessions {
                for session in sessions.prefix(3) {
                    log.debug("  - Session \(session.id.prefix(8)): '\(session.summary ?? "nil")' (\(session.messageCount ?? 0) msgs)")
                }
                if sessionCount > 3 {
                    log.debug("  ... and \(sessionCount - 3) more sessions")
                }
            }
        }

        return projects
    }

    // MARK: - Session History

    /// Fetch session messages from API (replaces SSH-based history loading)
    func fetchSessionMessages(projectName: String, sessionId: String, limit: Int = 100, offset: Int = 0) async throws -> [SessionMessage] {
        guard let baseURL = settings.baseURL else {
            throw APIError.invalidURL
        }

        // Build URL: /api/projects/:projectName/sessions/:sessionId/messages
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        // URL-encode path components to handle spaces and special characters
        let encodedProjectName = projectName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? projectName
        let encodedSessionId = sessionId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? sessionId
        components.path = "/api/projects/\(encodedProjectName)/sessions/\(encodedSessionId)/messages"
        components.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        let request = authorizedRequest(for: url)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError
        }

        if httpResponse.statusCode == 401 {
            throw APIError.authenticationFailed
        }

        guard httpResponse.statusCode == 200 else {
            log.error("Session messages failed with status: \(httpResponse.statusCode)")
            throw APIError.serverError
        }

        let messagesResponse = try JSONDecoder().decode(SessionMessagesResponse.self, from: data)
        return messagesResponse.messages
    }

    /// Get token usage for a session
    func fetchSessionTokenUsage(projectName: String, sessionId: String) async throws -> SessionTokenUsage {
        guard let baseURL = settings.baseURL else {
            throw APIError.invalidURL
        }

        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        // URL-encode path components to handle spaces and special characters
        let encodedProjectName = projectName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? projectName
        let encodedSessionId = sessionId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? sessionId
        components.path = "/api/projects/\(encodedProjectName)/sessions/\(encodedSessionId)/token-usage"

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        let request = authorizedRequest(for: url)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }

        return try JSONDecoder().decode(SessionTokenUsage.self, from: data)
    }

    // MARK: - Image Upload

    /// Upload image via API and get back the processed image with base64 data
    func uploadImage(projectName: String, imageData: Data, filename: String = "image.png") async throws -> UploadedImage {
        guard let baseURL = settings.baseURL else {
            throw APIError.invalidURL
        }

        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        // URL-encode path components to handle spaces and special characters
        let encodedProjectName = projectName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? projectName
        components.path = "/api/projects/\(encodedProjectName)/upload-images"

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        // Create multipart form data
        let boundary = UUID().uuidString
        var request = authorizedRequest(for: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add image data using UTF-8 appends to avoid extra helpers
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"images\"; filename=\"\(filename)\"\r\n".utf8))

        // Detect MIME type
        let mimeType = ImageUtilities.detectMediaType(from: imageData)
        body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(imageData)
        body.append(Data("\r\n".utf8))
        body.append(Data("--\(boundary)--\r\n".utf8))

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError
        }

        if httpResponse.statusCode == 401 {
            throw APIError.authenticationFailed
        }

        guard httpResponse.statusCode == 200 else {
            log.error("Image upload failed with status: \(httpResponse.statusCode)")
            if let errorText = String(data: data, encoding: .utf8) {
                log.error("Error: \(errorText)")
            }
            throw APIError.serverError
        }

        let uploadResponse = try JSONDecoder().decode(ImageUploadResponse.self, from: data)
        guard let firstImage = uploadResponse.images.first else {
            throw APIError.serverError
        }

        return firstImage
    }

    // Note: Chat is now handled via WebSocket - see WebSocketManager
}

// MARK: - Session Messages Types

struct SessionMessagesResponse: Codable {
    let messages: [SessionMessage]
    let pagination: SessionPagination?
}

struct SessionPagination: Codable {
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool
}

struct SessionMessage: Codable {
    let type: String  // "user", "assistant", "system"
    let timestamp: String?
    let message: SessionMessageContent?
    let toolUseResult: AnyCodableValue?  // Can be string or object

    // Convert to ChatMessage for display
    func toChatMessage() -> ChatMessage? {
        let date = parseTimestamp(timestamp) ?? Date()

        switch type {
        case "user":
            guard let content = message?.content else { return nil }

            // Check if this is a tool result
            if let first = content.first, first.type == "tool_result" {
                if let resultText = toolUseResult?.stringValue {
                    return ChatMessage(role: .toolResult, content: resultText, timestamp: date)
                }
                return nil
            }

            // Look for text and image content in all items
            var textContent: String?
            var imageData: Data?

            for item in content {
                switch item.type {
                case "text":
                    if let text = item.text, !text.isEmpty {
                        textContent = text
                    }
                case "image":
                    // Decode base64 image data
                    if let source = item.source,
                       source.type == "base64",
                       let base64Data = source.data,
                       let data = Data(base64Encoded: base64Data) {
                        imageData = data
                    }
                default:
                    break
                }
            }

            // Return message if we have text or image
            if let text = textContent {
                return ChatMessage(role: .user, content: text, timestamp: date, imageData: imageData)
            } else if imageData != nil {
                // Image-only message
                return ChatMessage(role: .user, content: "[Image]", timestamp: date, imageData: imageData)
            }
            return nil

        case "assistant":
            if let content = message?.content {
                for item in content {
                    switch item.type {
                    case "text":
                        if let text = item.text, !text.isEmpty {
                            return ChatMessage(role: .assistant, content: text, timestamp: date)
                        }
                    case "thinking":
                        if let thinking = item.thinking, !thinking.isEmpty {
                            return ChatMessage(role: .thinking, content: thinking, timestamp: date)
                        }
                    case "tool_use":
                        if let name = item.name {
                            var toolContent = name
                            if let input = item.input {
                                let inputStr = input.map { "\($0.key): \($0.value.stringValue)" }.joined(separator: ", ")
                                toolContent = "\(name)(\(inputStr))"
                            }
                            return ChatMessage(role: .toolUse, content: toolContent, timestamp: date)
                        }
                    default:
                        break
                    }
                }
            }
            return nil

        default:
            return nil
        }
    }

    private func parseTimestamp(_ value: String?) -> Date? {
        guard let timestampStr = value else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: timestampStr) {
            return date
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: timestampStr)
    }
}

struct SessionMessageContent: Codable {
    let role: String?
    let content: [SessionContentItem]?

    enum CodingKeys: String, CodingKey {
        case role, content
    }

    /// Memberwise initializer for tests and direct construction
    init(role: String?, content: [SessionContentItem]?) {
        self.role = role
        self.content = content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = try container.decodeIfPresent(String.self, forKey: .role)

        // Handle content as either array or string
        if let contentArray = try? container.decodeIfPresent([SessionContentItem].self, forKey: .content) {
            content = contentArray
        } else if let contentString = try? container.decodeIfPresent(String.self, forKey: .content) {
            // Convert string to array with single text item
            content = [SessionContentItem(type: "text", text: contentString, thinking: nil, name: nil, input: nil, source: nil, toolUseId: nil, content: nil, isError: nil)]
        } else {
            content = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encodeIfPresent(content, forKey: .content)
    }
}

struct SessionContentItem: Codable {
    let type: String
    let text: String?
    let thinking: String?
    let name: String?  // For tool_use
    let input: [String: AnyCodableValue]?  // For tool_use
    let source: ImageSource?  // For image content
    let toolUseId: String?  // For tool_result
    let content: AnyCodableValue?  // For tool_result (can be string or array)
    let isError: Bool?  // For tool_result

    enum CodingKeys: String, CodingKey {
        case type, text, thinking, name, input, source, content
        case toolUseId = "tool_use_id"
        case isError = "is_error"
    }

    /// Manual initializer for creating items programmatically (e.g., when converting string content to array)
    init(type: String, text: String?, thinking: String?, name: String?, input: [String: AnyCodableValue]?, source: ImageSource?, toolUseId: String?, content: AnyCodableValue?, isError: Bool?) {
        self.type = type
        self.text = text
        self.thinking = thinking
        self.name = name
        self.input = input
        self.source = source
        self.toolUseId = toolUseId
        self.content = content
        self.isError = isError
    }
}

/// Image source in Claude API format
struct ImageSource: Codable {
    let type: String  // "base64" or "url"
    let mediaType: String?  // e.g., "image/jpeg"
    let data: String?  // base64 data
    let url: String?  // URL for url type

    enum CodingKeys: String, CodingKey {
        case type
        case mediaType = "media_type"
        case data
        case url
    }
}

/// Flexible value type for JSON parsing
struct AnyCodableValue: Codable, CustomStringConvertible {
    let value: Any

    /// CustomStringConvertible - returns just the value for string interpolation
    var description: String {
        stringValue
    }

    var stringValue: String {
        // Use global stringifyAnyValue for proper type handling
        // This avoids "AnyCodableValue(value: ...)" appearing in output
        return stringifyAnyValue(value)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let dict = try? container.decode([String: AnyCodableValue].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodableValue].self) {
            value = array.map { $0.value }
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else {
            try container.encodeNil()
        }
    }
}

struct SessionTokenUsage: Codable {
    let used: Int
    let total: Int
    let breakdown: TokenBreakdown?

    struct TokenBreakdown: Codable {
        let input: Int
        let cacheCreation: Int?
        let cacheRead: Int?
    }
}

struct ImageUploadResponse: Codable {
    let images: [UploadedImage]
}

struct UploadedImage: Codable {
    let name: String
    let data: String  // "data:image/png;base64,..."
    let size: Int
    let mimeType: String

    /// Extract just the base64 part (without data: prefix)
    var base64Data: String {
        if let range = data.range(of: "base64,") {
            return String(data[range.upperBound...])
        }
        return data
    }

    /// Extract media type for WebSocket message
    var mediaType: String {
        // data:image/png;base64,... -> image/png
        if let start = data.range(of: "data:"),
           let end = data.range(of: ";base64") {
            return String(data[start.upperBound..<end.lowerBound])
        }
        return mimeType
    }
}

// MARK: - Types

struct LoginResponse: Codable {
    let success: Bool
    let user: LoginUser?
    let token: String
}

struct LoginUser: Codable {
    let id: Int
    let username: String
}

struct AuthStatus: Codable {
    let needsSetup: Bool
    let isAuthenticated: Bool
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case serverError
    case decodingError
    case authenticationFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .serverError: return "Server error"
        case .decodingError: return "Failed to decode response"
        case .authenticationFailed: return "Authentication failed"
        }
    }
}
