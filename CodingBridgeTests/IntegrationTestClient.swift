import Foundation
@testable import CodingBridge

struct SessionAPIClient {
    let config: IntegrationTestConfig

    func fetchSessions(limit: Int, offset: Int) async throws -> SessionsResponse {
        guard var components = URLComponents(url: config.baseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }

        components.path = "/api/projects/\(config.projectName)/sessions"
        components.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(config.authToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(SessionsResponse.self, from: data)
    }

    func deleteSession(sessionId: String) async throws {
        guard var components = URLComponents(url: config.baseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }

        components.path = "/api/projects/\(config.projectName)/sessions/\(sessionId)"
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(config.authToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            throw URLError(.badServerResponse)
        }
    }
}
