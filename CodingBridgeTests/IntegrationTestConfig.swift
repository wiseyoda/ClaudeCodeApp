import Foundation
import XCTest
@testable import CodingBridge

enum IntegrationTestError: Error {
    case timeout
}

struct IntegrationTestConfig {
    let baseURL: URL
    let authToken: String
    let projectName: String
    let minTotal: Int
    let requireSummaries: Bool
    let allowMutations: Bool
    let deleteSessionId: String?
    let webSocketURL: URL

    static func require() throws -> IntegrationTestConfig {
        let env = ProcessInfo.processInfo.environment

        guard let baseURLString = env["CODINGBRIDGE_TEST_BACKEND_URL"],
              let baseURL = URL(string: baseURLString) else {
            throw XCTSkip("Set CODINGBRIDGE_TEST_BACKEND_URL to enable integration tests.")
        }

        guard let authToken = env["CODINGBRIDGE_TEST_AUTH_TOKEN"], !authToken.isEmpty else {
            throw XCTSkip("Set CODINGBRIDGE_TEST_AUTH_TOKEN to enable integration tests.")
        }

        let projectName: String
        if let encoded = env["CODINGBRIDGE_TEST_PROJECT_NAME"], !encoded.isEmpty {
            projectName = encoded
        } else if let path = env["CODINGBRIDGE_TEST_PROJECT_PATH"], !path.isEmpty {
            projectName = path.replacingOccurrences(of: "/", with: "-")
        } else {
            throw XCTSkip("Set CODINGBRIDGE_TEST_PROJECT_NAME or CODINGBRIDGE_TEST_PROJECT_PATH to enable integration tests.")
        }

        let minTotal = Int(env["CODINGBRIDGE_TEST_SESSION_MIN_TOTAL"] ?? "") ?? 6
        let requireSummaries = env["CODINGBRIDGE_TEST_REQUIRE_SUMMARIES"] == "1"
        let allowMutations = env["CODINGBRIDGE_TEST_ALLOW_MUTATIONS"] == "1"
        let deleteSessionId = env["CODINGBRIDGE_TEST_DELETE_SESSION_ID"]

        let webSocketURL = IntegrationTestConfig.webSocketURL(
            baseURL: baseURL,
            authToken: authToken,
            override: env["CODINGBRIDGE_TEST_WEBSOCKET_URL"]
        )

        return IntegrationTestConfig(
            baseURL: baseURL,
            authToken: authToken,
            projectName: projectName,
            minTotal: minTotal,
            requireSummaries: requireSummaries,
            allowMutations: allowMutations,
            deleteSessionId: deleteSessionId,
            webSocketURL: webSocketURL
        )
    }

    private static func webSocketURL(baseURL: URL, authToken: String, override: String?) -> URL {
        if let override = override, let url = URL(string: override) {
            return url
        }

        let wsScheme = baseURL.scheme == "https" ? "wss" : "ws"
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.scheme = wsScheme
        components?.path = "/ws"
        components?.queryItems = [URLQueryItem(name: "token", value: authToken)]
        return components?.url ?? baseURL
    }
}
