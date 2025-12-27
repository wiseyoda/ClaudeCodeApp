import Foundation

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
            await MainActor.run {
                settings.authToken = loginResponse.token
                isAuthenticated = true
            }
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
        await MainActor.run {
            settings.authToken = loginResponse.token
            isAuthenticated = true
        }
    }

    private func authorizedRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        // Prefer API Key if available, otherwise use JWT token
        if !settings.apiKey.isEmpty {
            request.setValue(settings.apiKey, forHTTPHeaderField: "X-API-Key")
        } else if !settings.authToken.isEmpty {
            request.setValue("Bearer \(settings.authToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    // MARK: - Projects

    func fetchProjects() async throws -> [Project] {
        guard let url = settings.baseURL?.appendingPathComponent("api/projects") else {
            throw APIError.invalidURL
        }

        let request = authorizedRequest(for: url)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError
        }

        if httpResponse.statusCode == 401 {
            // Try to login and retry
            try await login()
            return try await fetchProjects()
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }

        // New API returns array directly, not wrapped
        let projects = try JSONDecoder().decode([Project].self, from: data)
        return projects
    }

    // MARK: - Session History

    /// Fetch session messages from API (replaces SSH-based history loading)
    func fetchSessionMessages(projectName: String, sessionId: String, limit: Int = 100, offset: Int = 0) async throws -> [SessionMessage] {
        guard let baseURL = settings.baseURL else {
            throw APIError.invalidURL
        }

        // Build URL: /api/projects/:projectName/sessions/:sessionId/messages
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/api/projects/\(projectName)/sessions/\(sessionId)/messages"
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

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/api/projects/\(projectName)/sessions/\(sessionId)/token-usage"

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

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/api/projects/\(projectName)/upload-images"

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        // Create multipart form data
        let boundary = UUID().uuidString
        var request = authorizedRequest(for: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"images\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)

        // Detect MIME type
        let mimeType = ImageUtilities.detectMediaType(from: imageData)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

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
            // Check if this is a tool result
            if let content = message?.content, let first = content.first {
                if first.type == "tool_result" {
                    // Get tool result text
                    if let resultText = toolUseResult?.stringValue {
                        return ChatMessage(role: .toolResult, content: resultText, timestamp: date)
                    }
                    return nil
                }
                // Regular user message
                if let text = first.text, !text.isEmpty {
                    return ChatMessage(role: .user, content: text, timestamp: date)
                }
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
                                let inputStr = input.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
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
}

struct SessionContentItem: Codable {
    let type: String
    let text: String?
    let thinking: String?
    let name: String?  // For tool_use
    let input: [String: AnyCodableValue]?  // For tool_use
}

/// Flexible value type for JSON parsing
struct AnyCodableValue: Codable {
    let value: Any

    var stringValue: String {
        if let s = value as? String { return s }
        if let dict = value as? [String: Any] {
            if let stdout = dict["stdout"] as? String { return stdout }
            if let data = try? JSONSerialization.data(withJSONObject: dict),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
        }
        return String(describing: value)
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
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?
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
