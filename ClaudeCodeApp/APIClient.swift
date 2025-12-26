import Foundation

class APIClient: ObservableObject {
    private let settings: AppSettings
    @Published var isLoading = false
    @Published var isAuthenticated = false

    init(settings: AppSettings) {
        self.settings = settings
        // Check if we have a stored token
        self.isAuthenticated = !settings.authToken.isEmpty
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
        if !settings.authToken.isEmpty {
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

    // Note: Chat is now handled via WebSocket - see WebSocketManager
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
