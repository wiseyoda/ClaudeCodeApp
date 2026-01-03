import Foundation
import XCTest
@testable import CodingBridge

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "cli-bridge.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeJSONData(_ object: Any, file: StaticString = #filePath, line: UInt = #line) -> Data {
    do {
        return try JSONSerialization.data(withJSONObject: object, options: [])
    } catch {
        XCTFail("Failed to encode JSON: \(error)", file: file, line: line)
        return Data()
    }
}

private func makeResponse(
    for request: URLRequest,
    statusCode: Int = 200,
    headers: [String: String] = [:],
    json: Any? = nil,
    data: Data? = nil,
    file: StaticString = #filePath,
    line: UInt = #line
) -> (HTTPURLResponse, Data) {
    let payload: Data
    if let data = data {
        payload = data
    } else if let json = json {
        payload = makeJSONData(json, file: file, line: line)
    } else {
        payload = Data()
    }

    let url = request.url ?? URL(string: "http://cli-bridge.test")!
    let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: headers)!
    return (response, payload)
}

private func queryItems(from request: URLRequest) -> [String: String] {
    guard let url = request.url,
          let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        return [:]
    }

    return (components.queryItems ?? []).reduce(into: [String: String]()) { result, item in
        result[item.name] = item.value ?? ""
    }
}

private func assertRequest(
    _ request: URLRequest,
    method: String,
    path: String,
    query: [String: String] = [:],
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertEqual(request.httpMethod, method, file: file, line: line)
    XCTAssertEqual(request.url?.path, path, file: file, line: line)

    let items = queryItems(from: request)
    if query.isEmpty {
        XCTAssertTrue(items.isEmpty, file: file, line: line)
    } else {
        XCTAssertEqual(items, query, file: file, line: line)
    }
}

private func bodyData(from request: URLRequest, file: StaticString = #filePath, line: UInt = #line) -> Data? {
    if let body = request.httpBody {
        return body
    }

    guard let stream = request.httpBodyStream else {
        XCTFail("Expected request body", file: file, line: line)
        return nil
    }

    stream.open()
    defer { stream.close() }

    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)
    while stream.hasBytesAvailable {
        let readCount = stream.read(&buffer, maxLength: buffer.count)
        if readCount < 0 {
            if let error = stream.streamError {
                XCTFail("Failed to read request body stream: \(error)", file: file, line: line)
            }
            return nil
        }
        if readCount == 0 {
            break
        }
        data.append(buffer, count: readCount)
    }

    return data
}

private func jsonBody(from request: URLRequest, file: StaticString = #filePath, line: UInt = #line) -> [String: Any] {
    guard let body = bodyData(from: request, file: file, line: line) else {
        return [:]
    }

    do {
        let object = try JSONSerialization.jsonObject(with: body, options: [])
        return object as? [String: Any] ?? [:]
    } catch {
        XCTFail("Failed to decode JSON body: \(error)", file: file, line: line)
        return [:]
    }
}

private func assertAPIError(
    _ error: Error,
    matches expected: CLIBridgeAPIError,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard let apiError = error as? CLIBridgeAPIError else {
        XCTFail("Expected CLIBridgeAPIError, got \(error)", file: file, line: line)
        return
    }

    switch (apiError, expected) {
    case (.unauthorized, .unauthorized),
         (.notFound, .notFound),
         (.badRequest, .badRequest):
        return
    case (.serverError(let code), .serverError(let expectedCode)):
        XCTAssertEqual(code, expectedCode, file: file, line: line)
    case (.unexpectedStatus(let code), .unexpectedStatus(let expectedCode)):
        XCTAssertEqual(code, expectedCode, file: file, line: line)
    default:
        XCTFail("Unexpected error: \(apiError)", file: file, line: line)
    }
}

private func projectJSON(path: String = "/Users/me/App", name: String = "App") -> [String: Any] {
    [
        "path": path,
        "name": name,
        "lastUsed": "2024-01-01T00:00:00Z",
        "sessionCount": 3
    ]
}

private func projectDetailJSON(path: String = "/Users/me/App", name: String = "App") -> [String: Any] {
    [
        "path": path,
        "name": name,
        "lastUsed": "2024-01-01T00:00:00.000Z",
        "sessionCount": 3,
        "readme": "Hello",
        "structure": [
            "hasCLAUDE": true,
            "hasPackageJSON": true,
            "hasPyprojectToml": false,
            "primaryLanguage": "Swift"
        ]
    ]
}

private func sessionMetadataJSON(
    id: String = "00000000-0000-0000-0000-000000000001",
    projectPath: String = "/Users/me/App",
    archivedAt: String? = nil
) -> [String: Any] {
    // Ensure id is a valid UUID format for SessionMetadata decoding
    let uuidId = UUID(uuidString: id) != nil ? id : "00000000-0000-0000-0000-000000000001"
    var payload: [String: Any] = [
        "id": uuidId,
        "projectPath": projectPath,
        "source": "user",
        "messageCount": 2,
        "createdAt": "2024-01-01T00:00:00.000Z",
        "lastActivityAt": "2024-01-01T01:00:00.000Z",
        "title": "Session \(uuidId)"
    ]
    if let archivedAt = archivedAt {
        payload["archivedAt"] = archivedAt
    }
    return payload
}

private func sessionsResponseJSON(
    sessions: [[String: Any]],
    cursor: String? = nil,
    hasMore: Bool? = nil,
    total: Int? = nil
) -> [String: Any] {
    var payload: [String: Any] = ["sessions": sessions]
    if let cursor = cursor {
        payload["cursor"] = cursor
    }
    if let hasMore = hasMore {
        payload["hasMore"] = hasMore
    }
    if let total = total {
        payload["total"] = total
    }
    return payload
}

private func sessionSearchResponseJSON(
    query: String = "error",
    total: Int = 1,
    hasMore: Bool = false
) -> [String: Any] {
    // Snippet matches the ProjectsEncodedPathSessionsSearchGet200ResponseAllOfResultsInnerAllOfSnippetsInner schema
    let snippet: [String: Any] = [
        "type": "user",
        "text": "...found an error in the code...",
        "matchStart": 12,
        "matchLength": 5
    ]
    // Result matches ProjectsEncodedPathSessionsSearchGet200ResponseAllOfResultsInner schema
    let result: [String: Any] = [
        "sessionId": "session-1",
        "projectPath": "/Users/me/App",
        "score": 0.9,
        "snippets": [snippet],
        "timestamp": "2024-01-01T00:00:00.000Z"
    ]
    return [
        "query": query,
        "total": total,
        "results": [result],
        "hasMore": hasMore
    ]
}

private func fileEntryJSON(name: String, type: String) -> [String: Any] {
    var payload: [String: Any] = [
        "name": name,
        "type": type,
        "size": 12,
        "modified": "2024-01-01T00:00:00Z"
    ]
    if type == "file" {
        payload["extension"] = (name as NSString).pathExtension
    } else if type == "directory" {
        payload["childCount"] = 2
    }
    return payload
}

private func fileListResponseJSON(
    path: String = "/",
    entries: [[String: Any]],
    parent: String? = nil
) -> [String: Any] {
    var payload: [String: Any] = [
        "path": path,
        "entries": entries
    ]
    if let parent = parent {
        payload["parent"] = parent
    }
    return payload
}

private func fileContentResponseJSON(
    path: String = "/README.md",
    content: String = "Hello"
) -> [String: Any] {
    [
        "path": path,
        "content": content,
        "size": content.utf8.count,
        "modified": "2024-01-01T00:00:00.000Z",
        "mimeType": "text/plain"
    ]
}

private func permissionsResponseJSON() -> [String: Any] {
    [
        "global": [
            "bypass_all": true,
            "default_mode": "acceptEdits"
        ],
        "projects": [
            "/Users/me/App": [
                "permission_mode": "bypassPermissions",
                "bypass_all": false,
                "always_allow": ["git status"],
                "always_deny": ["rm -rf"]
            ]
        ]
    ]
}

private func imageUploadResponseJSON(
    id: String = "image-1",
    mimeType: String = "image/png",
    size: Int = 12
) -> [String: Any] {
    [
        "id": id,
        "mimeType": mimeType,
        "size": size
    ]
}

private func pushStatusResponseJSON() -> [String: Any] {
    [
        "provider": "fcm",
        "providerEnabled": true,
        "fcmTokenRegistered": true,
        "fcmTokenLastUpdated": "2024-01-01T00:00:00.000Z",
        "liveActivityTokens": [
            [
                "activityId": "activity-1",
                "sessionId": "session-1",
                "registeredAt": "2024-01-01T00:00:00.000Z",
                "hasUpdateToken": true,
                "hasPushToStartToken": false
            ]
        ],
        "recentDeliveries": []
    ]
}

@MainActor
final class CLIBridgeAPIClientTests: XCTestCase {
    private var mockSession: URLSession!

    override func setUp() {
        super.setUp()
        MockURLProtocol.requestHandler = nil
        // Create a session configuration that uses our MockURLProtocol
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        mockSession = nil
        super.tearDown()
    }

    private func makeClient(serverURL: String = "http://cli-bridge.test") -> CLIBridgeAPIClient {
        CLIBridgeAPIClient(serverURL: serverURL, session: mockSession)
    }

    // MARK: - Initialization

    func test_init_stripsTrailingSlash() async throws {
        let payload = ["projects": []]
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "http://cli-bridge.test/projects")
            return makeResponse(for: request, json: payload)
        }

        let client = makeClient(serverURL: "http://cli-bridge.test/")
        _ = try await client.fetchProjects()
    }

    func test_init_preservesBaseURL() async throws {
        let payload = ["projects": []]
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "http://cli-bridge.test/api/projects")
            return makeResponse(for: request, json: payload)
        }

        let client = makeClient(serverURL: "http://cli-bridge.test/api")
        _ = try await client.fetchProjects()
    }

    func test_init_addsSchemeWhenMissing() async throws {
        let payload = ["projects": []]
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "http://cli-bridge.test:3100/projects")
            return makeResponse(for: request, json: payload)
        }

        let client = makeClient(serverURL: "cli-bridge.test:3100")
        _ = try await client.fetchProjects()
    }

    func test_init_convertsWebSocketSchemeToHTTPS() async throws {
        let payload = ["projects": []]
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://cli-bridge.test/projects")
            return makeResponse(for: request, json: payload)
        }

        let client = makeClient(serverURL: "wss://cli-bridge.test")
        _ = try await client.fetchProjects()
    }

    // MARK: - Projects

    func test_fetchProjects_success() async throws {
        let payload = [
            "projects": [
                projectJSON(path: "/Users/me/App", name: "App"),
                projectJSON(path: "/Users/me/Other", name: "Other")
            ]
        ]
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "GET", path: "/projects")
            return makeResponse(for: request, json: payload)
        }

        let projects = try await makeClient().fetchProjects()

        XCTAssertEqual(projects.map(\.name), ["App", "Other"])
    }

    func test_fetchProjects_emptyList() async throws {
        let payload = ["projects": []]
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "GET", path: "/projects")
            return makeResponse(for: request, json: payload)
        }

        let projects = try await makeClient().fetchProjects()

        XCTAssertTrue(projects.isEmpty)
    }

    func test_fetchProjects_networkError() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await makeClient().fetchProjects()
            XCTFail("Expected fetchProjects to throw")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_refreshProjects_success() async throws {
        let payload = ["projects": [projectJSON()]]
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "POST", path: "/projects/refresh")
            return makeResponse(for: request, json: payload)
        }

        let projects = try await makeClient().refreshProjects()

        XCTAssertEqual(projects.count, 1)
    }

    func test_getProjectDetail_success() async throws {
        let payload = projectDetailJSON()
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "GET", path: "/projects/-Users-me-App")
            return makeResponse(for: request, json: payload)
        }

        let detail = try await makeClient().getProjectDetail(projectPath: "/Users/me/App")

        XCTAssertEqual(detail.name, "App")
        XCTAssertEqual(detail.readme, "Hello")
    }

    func test_getProjectDetail_notFound() async {
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "GET", path: "/projects/-Users-me-App")
            return makeResponse(for: request, statusCode: 404)
        }

        do {
            _ = try await makeClient().getProjectDetail(projectPath: "/Users/me/App")
            XCTFail("Expected getProjectDetail to throw")
        } catch {
            assertAPIError(error, matches: .notFound)
        }
    }

    // MARK: - Sessions

    func test_fetchSessions_defaultParameters() async throws {
        let payload = sessionsResponseJSON(sessions: [sessionMetadataJSON()])
        MockURLProtocol.requestHandler = { request in
            assertRequest(
                request,
                method: "GET",
                path: "/projects/-Users-me-App/sessions",
                query: ["limit": "100"]
            )
            return makeResponse(for: request, json: payload)
        }

        let response = try await makeClient().fetchSessions(projectPath: "/Users/me/App")

        XCTAssertEqual(response.sessions.count, 1)
        XCTAssertFalse(response.hasMore)
    }

    func test_fetchSessions_withLimit() async throws {
        let payload = sessionsResponseJSON(sessions: [sessionMetadataJSON()])
        MockURLProtocol.requestHandler = { request in
            assertRequest(
                request,
                method: "GET",
                path: "/projects/-Users-me-App/sessions",
                query: ["limit": "25"]
            )
            return makeResponse(for: request, json: payload)
        }

        _ = try await makeClient().fetchSessions(projectPath: "/Users/me/App", limit: 25)
    }

    func test_fetchSessions_withCursor() async throws {
        let payload = sessionsResponseJSON(sessions: [sessionMetadataJSON()], cursor: "next", hasMore: true)
        MockURLProtocol.requestHandler = { request in
            assertRequest(
                request,
                method: "GET",
                path: "/projects/-Users-me-App/sessions",
                query: ["limit": "100", "cursor": "next"]
            )
            return makeResponse(for: request, json: payload)
        }

        _ = try await makeClient().fetchSessions(projectPath: "/Users/me/App", cursor: "next")
    }

    func test_fetchSessions_withSourceFilter() async throws {
        let payload = sessionsResponseJSON(sessions: [sessionMetadataJSON()])
        MockURLProtocol.requestHandler = { request in
            assertRequest(
                request,
                method: "GET",
                path: "/projects/-Users-me-App/sessions",
                query: ["limit": "100", "source": "agent"]
            )
            return makeResponse(for: request, json: payload)
        }

        _ = try await makeClient().fetchSessions(projectPath: "/Users/me/App", source: .agent)
    }

    func test_fetchSessions_includeArchived() async throws {
        let payload = sessionsResponseJSON(sessions: [sessionMetadataJSON()])
        MockURLProtocol.requestHandler = { request in
            assertRequest(
                request,
                method: "GET",
                path: "/projects/-Users-me-App/sessions",
                query: ["limit": "100", "includeArchived": "true"]
            )
            return makeResponse(for: request, json: payload)
        }

        _ = try await makeClient().fetchSessions(projectPath: "/Users/me/App", includeArchived: true)
    }

    func test_fetchSessions_archivedOnly() async throws {
        let payload = sessionsResponseJSON(sessions: [sessionMetadataJSON()])
        MockURLProtocol.requestHandler = { request in
            assertRequest(
                request,
                method: "GET",
                path: "/projects/-Users-me-App/sessions",
                query: ["limit": "100", "archivedOnly": "true"]
            )
            return makeResponse(for: request, json: payload)
        }

        _ = try await makeClient().fetchSessions(projectPath: "/Users/me/App", archivedOnly: true)
    }

    func test_fetchSessions_withParentSessionId() async throws {
        let payload = sessionsResponseJSON(sessions: [sessionMetadataJSON()])
        MockURLProtocol.requestHandler = { request in
            assertRequest(
                request,
                method: "GET",
                path: "/projects/-Users-me-App/sessions",
                query: ["limit": "100", "parentSessionId": "parent-1"]
            )
            return makeResponse(for: request, json: payload)
        }

        _ = try await makeClient().fetchSessions(projectPath: "/Users/me/App", parentSessionId: "parent-1")
    }

    func test_fetchSession_success() async throws {
        let testSessionId = "00000000-0000-0000-0000-000000000001"
        let payload = sessionMetadataJSON(id: testSessionId)
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "GET", path: "/projects/-Users-me-App/sessions/\(testSessionId)")
            return makeResponse(for: request, json: payload)
        }

        let session = try await makeClient().fetchSession(projectPath: "/Users/me/App", sessionId: testSessionId)

        XCTAssertEqual(session.id, UUID(uuidString: testSessionId))
    }

    func test_fetchSession_notFound() async {
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "GET", path: "/projects/-Users-me-App/sessions/session-1")
            return makeResponse(for: request, statusCode: 404)
        }

        do {
            _ = try await makeClient().fetchSession(projectPath: "/Users/me/App", sessionId: "session-1")
            XCTFail("Expected fetchSession to throw")
        } catch {
            assertAPIError(error, matches: .notFound)
        }
    }

    func test_renameSession_withTitle() async throws {
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "PUT", path: "/projects/-Users-me-App/sessions/session-1")
            let body = jsonBody(from: request)
            XCTAssertEqual(body["title"] as? String, "New Title")
            return makeResponse(for: request, json: [:])
        }

        try await makeClient().renameSession(
            projectPath: "/Users/me/App",
            sessionId: "session-1",
            title: "New Title"
        )
    }

    func test_renameSession_clearTitle() async throws {
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "PUT", path: "/projects/-Users-me-App/sessions/session-1")
            let body = jsonBody(from: request)
            XCTAssertTrue(body.isEmpty)
            return makeResponse(for: request, json: [:])
        }

        try await makeClient().renameSession(
            projectPath: "/Users/me/App",
            sessionId: "session-1",
            title: nil
        )
    }

    func test_deleteSession_success() async throws {
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "DELETE", path: "/projects/-Users-me-App/sessions/session-1")
            return makeResponse(for: request, statusCode: 204)
        }

        try await makeClient().deleteSession(projectPath: "/Users/me/App", sessionId: "session-1")
    }

    func test_deleteSession_notFound() async {
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "DELETE", path: "/projects/-Users-me-App/sessions/session-1")
            return makeResponse(for: request, statusCode: 404)
        }

        do {
            try await makeClient().deleteSession(projectPath: "/Users/me/App", sessionId: "session-1")
            XCTFail("Expected deleteSession to throw")
        } catch {
            assertAPIError(error, matches: .notFound)
        }
    }

    func test_archiveSession_success() async throws {
        let payload = sessionMetadataJSON(id: "session-1", archivedAt: "2024-02-01T00:00:00Z")
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "POST", path: "/projects/-Users-me-App/sessions/session-1/archive")
            return makeResponse(for: request, json: payload)
        }

        let session = try await makeClient().archiveSession(projectPath: "/Users/me/App", sessionId: "session-1")

        XCTAssertNotNil(session.archivedAt)
        XCTAssertTrue(session.isArchived)
    }

    func test_unarchiveSession_success() async throws {
        let payload = sessionMetadataJSON(id: "session-1")
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "POST", path: "/projects/-Users-me-App/sessions/session-1/unarchive")
            return makeResponse(for: request, json: payload)
        }

        let session = try await makeClient().unarchiveSession(projectPath: "/Users/me/App", sessionId: "session-1")

        XCTAssertNil(session.archivedAt)
        XCTAssertFalse(session.isArchived)
    }

    // MARK: - Files

    func test_listFiles_rootDirectory() async throws {
        let entries = [
            fileEntryJSON(name: "README.md", type: "file"),
            fileEntryJSON(name: "Sources", type: "directory")
        ]
        let payload = fileListResponseJSON(path: "/", entries: entries)
        MockURLProtocol.requestHandler = { request in
            assertRequest(
                request,
                method: "GET",
                path: "/projects/-Users-me-App/files",
                query: ["dir": "/"]
            )
            return makeResponse(for: request, json: payload)
        }

        let response = try await makeClient().listFiles(projectPath: "/Users/me/App")

        XCTAssertEqual(response.path, "/")
        XCTAssertEqual(response.entries.first?.name, "README.md")
    }

    func test_listFiles_withPath() async throws {
        let entries = [fileEntryJSON(name: "main.swift", type: "file")]
        let payload = fileListResponseJSON(path: "/src", entries: entries, parent: "/")
        MockURLProtocol.requestHandler = { request in
            assertRequest(
                request,
                method: "GET",
                path: "/projects/-Users-me-App/files",
                query: ["dir": "/src"]
            )
            return makeResponse(for: request, json: payload)
        }

        let response = try await makeClient().listFiles(projectPath: "/Users/me/App", directory: "/src")

        XCTAssertEqual(response.entries.first?.name, "main.swift")
        XCTAssertEqual(response.path, "/src")
    }

    func test_readFile_success() async throws {
        let payload = fileContentResponseJSON(content: "Hello World")
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "GET", path: "/projects/-Users-me-App/files/README.md")
            return makeResponse(for: request, json: payload)
        }

        let response = try await makeClient().readFile(projectPath: "/Users/me/App", filePath: "README.md")

        XCTAssertEqual(response.content, "Hello World")
    }

    func test_readFile_notFound() async {
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "GET", path: "/projects/-Users-me-App/files/README.md")
            return makeResponse(for: request, statusCode: 404)
        }

        do {
            _ = try await makeClient().readFile(projectPath: "/Users/me/App", filePath: "README.md")
            XCTFail("Expected readFile to throw")
        } catch {
            assertAPIError(error, matches: .notFound)
        }
    }

    func test_readFile_tooLarge() async {
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "GET", path: "/projects/-Users-me-App/files/README.md")
            return makeResponse(for: request, statusCode: 413)
        }

        do {
            _ = try await makeClient().readFile(projectPath: "/Users/me/App", filePath: "README.md")
            XCTFail("Expected readFile to throw")
        } catch {
            assertAPIError(error, matches: .unexpectedStatus(413))
        }
    }

    func test_uploadImage_success() async throws {
        let imageData = Data([0x00, 0x01, 0x02])
        let payload = imageUploadResponseJSON()
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "POST", path: "/agents/agent-1/upload")
            let contentType = request.value(forHTTPHeaderField: "Content-Type") ?? ""
            XCTAssertTrue(contentType.contains("multipart/form-data"))
            if let body = bodyData(from: request) {
                XCTAssertNotNil(body.range(of: imageData))
            }
            return makeResponse(for: request, json: payload)
        }

        let response = try await makeClient().uploadImage(
            agentId: "agent-1",
            imageData: imageData,
            mimeType: "image/png"
        )

        XCTAssertEqual(response.id, "image-1")
    }

    func test_uploadImage_invalidMimeType() async {
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "POST", path: "/agents/agent-1/upload")
            return makeResponse(for: request, statusCode: 400)
        }

        do {
            _ = try await makeClient().uploadImage(
                agentId: "agent-1",
                imageData: Data(),
                mimeType: "image/unknown"
            )
            XCTFail("Expected uploadImage to throw")
        } catch {
            assertAPIError(error, matches: .badRequest)
        }
    }

    // MARK: - Permissions

    func test_getPermissions_success() async throws {
        let payload = permissionsResponseJSON()
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "GET", path: "/permissions")
            return makeResponse(for: request, json: payload)
        }

        let config = try await makeClient().getPermissions()

        XCTAssertEqual(config.global.defaultMode, .acceptEdits)
        XCTAssertEqual(config.global.bypassAll, true)
        XCTAssertEqual(config.projects["/Users/me/App"]?.permissionMode, .bypassPermissions)
    }

    func test_getPermissions_notFound() async {
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "GET", path: "/permissions")
            return makeResponse(for: request, statusCode: 404)
        }

        do {
            _ = try await makeClient().getPermissions()
            XCTFail("Expected getPermissions to throw")
        } catch {
            assertAPIError(error, matches: .notFound)
        }
    }

    func test_updatePermissions_globalMode() async throws {
        let updates = PermissionConfigUpdate(
            global: GlobalPermissionsUpdate(bypassAll: true, defaultMode: .acceptEdits)
        )
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "PUT", path: "/permissions")
            let body = jsonBody(from: request)
            let global = body["global"] as? [String: Any]
            XCTAssertEqual(global?["bypass_all"] as? Bool, true)
            XCTAssertEqual(global?["default_mode"] as? String, "acceptEdits")
            XCTAssertNil(body["projects"])
            return makeResponse(for: request, json: [:])
        }

        try await makeClient().updatePermissions(updates)
    }

    func test_updatePermissions_projectMode() async throws {
        let updates = PermissionConfigUpdate(
            projects: [
                "/Users/me/App": ProjectPermissionsUpdate(permissionMode: .bypassPermissions)
            ]
        )
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "PUT", path: "/permissions")
            let body = jsonBody(from: request)
            let projects = body["projects"] as? [String: Any]
            let project = projects?["/Users/me/App"] as? [String: Any]
            XCTAssertEqual(project?["permission_mode"] as? String, "bypassPermissions")
            return makeResponse(for: request, json: [:])
        }

        try await makeClient().updatePermissions(updates)
    }

    func test_updatePermissions_alwaysAllow() async throws {
        let updates = PermissionConfigUpdate(
            projects: [
                "/Users/me/App": ProjectPermissionsUpdate(alwaysAllow: ["git status"])
            ]
        )
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "PUT", path: "/permissions")
            let body = jsonBody(from: request)
            let projects = body["projects"] as? [String: Any]
            let project = projects?["/Users/me/App"] as? [String: Any]
            XCTAssertEqual(project?["always_allow"] as? [String], ["git status"])
            return makeResponse(for: request, json: [:])
        }

        try await makeClient().updatePermissions(updates)
    }

    func test_updatePermissions_alwaysDeny() async throws {
        let updates = PermissionConfigUpdate(
            projects: [
                "/Users/me/App": ProjectPermissionsUpdate(alwaysDeny: ["rm -rf"])
            ]
        )
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "PUT", path: "/permissions")
            let body = jsonBody(from: request)
            let projects = body["projects"] as? [String: Any]
            let project = projects?["/Users/me/App"] as? [String: Any]
            XCTAssertEqual(project?["always_deny"] as? [String], ["rm -rf"])
            return makeResponse(for: request, json: [:])
        }

        try await makeClient().updatePermissions(updates)
    }

    // MARK: - Search

    func test_searchSessions_basicQuery() async throws {
        let payload = sessionSearchResponseJSON(query: "error")
        MockURLProtocol.requestHandler = { request in
            assertRequest(
                request,
                method: "GET",
                path: "/projects/-Users-me-App/sessions/search",
                query: ["q": "error"]
            )
            return makeResponse(for: request, json: payload)
        }

        let response = try await makeClient().searchSessions(projectPath: "/Users/me/App", query: "error")

        XCTAssertEqual(response.total, 1)
        XCTAssertEqual(response.results.count, 1)
    }

    func test_searchSessions_withProjectFilter() async throws {
        let payload = sessionSearchResponseJSON(query: "find")
        MockURLProtocol.requestHandler = { request in
            assertRequest(
                request,
                method: "GET",
                path: "/projects/-Users-me-Project B/sessions/search",
                query: ["q": "find"]
            )
            return makeResponse(for: request, json: payload)
        }

        _ = try await makeClient().searchSessions(projectPath: "/Users/me/Project B", query: "find")
    }

    func test_searchSessions_withDateRange() async throws {
        let query = "error after:2024-01-01 before:2024-01-31"
        let payload = sessionSearchResponseJSON(query: query)
        MockURLProtocol.requestHandler = { request in
            assertRequest(
                request,
                method: "GET",
                path: "/projects/-Users-me-App/sessions/search",
                query: ["q": query]
            )
            return makeResponse(for: request, json: payload)
        }

        _ = try await makeClient().searchSessions(projectPath: "/Users/me/App", query: query)
    }

    func test_searchSessions_pagination() async throws {
        let payload = sessionSearchResponseJSON(query: "error", total: 2, hasMore: true)
        MockURLProtocol.requestHandler = { request in
            assertRequest(
                request,
                method: "GET",
                path: "/projects/-Users-me-App/sessions/search",
                query: ["q": "error", "limit": "10", "offset": "5"]
            )
            return makeResponse(for: request, json: payload)
        }

        _ = try await makeClient().searchSessions(
            projectPath: "/Users/me/App",
            query: "error",
            limit: 10,
            offset: 5
        )
    }

    func test_searchSessions_noResults() async throws {
        let payload: [String: Any] = [
            "query": "none",
            "total": 0,
            "results": [],
            "hasMore": false
        ]
        MockURLProtocol.requestHandler = { request in
            assertRequest(
                request,
                method: "GET",
                path: "/projects/-Users-me-App/sessions/search",
                query: ["q": "none"]
            )
            return makeResponse(for: request, json: payload)
        }

        let response = try await makeClient().searchSessions(projectPath: "/Users/me/App", query: "none")

        XCTAssertTrue(response.results.isEmpty)
        XCTAssertEqual(response.total, 0)
    }

    func test_exportSession_markdown() async throws {
        let markdown = "## Title\n\nContent"
        MockURLProtocol.requestHandler = { request in
            assertRequest(
                request,
                method: "GET",
                path: "/projects/-Users-me-App/sessions/session-1/export",
                query: ["format": "markdown"]
            )
            let headers = ["Content-Type": "text/markdown"]
            return makeResponse(for: request, headers: headers, data: Data(markdown.utf8))
        }

        let response = try await makeClient().exportSession(
            projectPath: "/Users/me/App",
            sessionId: "session-1",
            format: .markdown
        )

        XCTAssertEqual(response.format, .markdown)
        XCTAssertEqual(response.content, markdown)
    }

    func test_exportSession_json() async throws {
        let content = "{\"ok\":true}"
        MockURLProtocol.requestHandler = { request in
            assertRequest(
                request,
                method: "GET",
                path: "/projects/-Users-me-App/sessions/session-1/export",
                query: ["format": "json", "includeStructuredContent": "true"]
            )
            let headers = ["Content-Type": "application/json; charset=utf-8"]
            return makeResponse(for: request, headers: headers, data: Data(content.utf8))
        }

        let response = try await makeClient().exportSession(
            projectPath: "/Users/me/App",
            sessionId: "session-1",
            format: .json,
            includeStructuredContent: true
        )

        XCTAssertEqual(response.format, .json)
        XCTAssertEqual(response.content, content)
    }

    // MARK: - Push Notifications

    func test_registerPushToken_success() async throws {
        let payload: [String: Any] = ["success": true, "tokenId": "token-1"]
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "POST", path: "/api/push/register")
            let body = jsonBody(from: request)
            XCTAssertEqual(body["fcmToken"] as? String, "token-123")
            XCTAssertEqual(body["environment"] as? String, "sandbox")
            XCTAssertEqual(body["platform"] as? String, "ios")
            return makeResponse(for: request, json: payload)
        }

        let response = try await makeClient().registerPushToken(fcmToken: "token-123", environment: .sandbox)

        XCTAssertEqual(response.success, true)
        XCTAssertEqual(response.tokenId, "token-1")
    }

    func test_invalidatePushToken_success() async throws {
        let payload: [String: Any] = ["success": true]
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "DELETE", path: "/api/push/invalidate")
            let body = jsonBody(from: request)
            XCTAssertEqual(body["tokenType"] as? String, "fcm")
            XCTAssertEqual(body["token"] as? String, "token-123")
            return makeResponse(for: request, json: payload)
        }

        try await makeClient().invalidatePushToken(tokenType: .fcm, token: "token-123")
    }

    func test_registerLiveActivityToken_success() async throws {
        let testSessionId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let payload: [String: Any] = ["success": true, "activityTokenId": "activity-token-1"]
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "POST", path: "/api/push/live-activity")
            let body = jsonBody(from: request)
            XCTAssertEqual(body["pushToken"] as? String, "push-1")
            XCTAssertEqual(body["pushToStartToken"] as? String, "start-1")
            XCTAssertEqual(body["activityId"] as? String, "activity-1")
            XCTAssertEqual(body["sessionId"] as? String, testSessionId.uuidString)
            XCTAssertEqual(body["environment"] as? String, "sandbox")
            // platform is optional and not set by the API client
            return makeResponse(for: request, json: payload)
        }

        let response = try await makeClient().registerLiveActivityToken(
            pushToken: "push-1",
            pushToStartToken: "start-1",
            activityId: "activity-1",
            sessionId: testSessionId,
            environment: .sandbox
        )

        XCTAssertEqual(response.success, true)
        XCTAssertEqual(response.activityTokenId, "activity-token-1")
    }

    func test_invalidateLiveActivityToken_success() async throws {
        let payload: [String: Any] = ["success": true]
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "DELETE", path: "/api/push/invalidate")
            let body = jsonBody(from: request)
            XCTAssertEqual(body["tokenType"] as? String, "live_activity")
            XCTAssertEqual(body["token"] as? String, "live-1")
            return makeResponse(for: request, json: payload)
        }

        try await makeClient().invalidatePushToken(tokenType: .liveActivity, token: "live-1")
    }

    func test_getPushStatus_success() async throws {
        let payload = pushStatusResponseJSON()
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "GET", path: "/api/push/status")
            return makeResponse(for: request, json: payload)
        }

        let status = try await makeClient().getPushStatus()

        XCTAssertEqual(status.provider, "fcm")
        XCTAssertEqual(status.liveActivityTokens.count, 1)
    }

    // MARK: - Error Handling

    func test_error_unauthorized() async {
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "GET", path: "/projects")
            return makeResponse(for: request, statusCode: 401)
        }

        do {
            _ = try await makeClient().fetchProjects()
            XCTFail("Expected fetchProjects to throw")
        } catch {
            assertAPIError(error, matches: .unauthorized)
        }
    }

    func test_error_notFound() async {
        MockURLProtocol.requestHandler = { request in
            assertRequest(
                request,
                method: "GET",
                path: "/projects/-Users-me-App/files",
                query: ["dir": "/"]
            )
            return makeResponse(for: request, statusCode: 404)
        }

        do {
            _ = try await makeClient().listFiles(projectPath: "/Users/me/App")
            XCTFail("Expected listFiles to throw")
        } catch {
            assertAPIError(error, matches: .notFound)
        }
    }

    func test_error_serverError() async {
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "GET", path: "/projects")
            return makeResponse(for: request, statusCode: 500)
        }

        do {
            _ = try await makeClient().fetchProjects()
            XCTFail("Expected fetchProjects to throw")
        } catch {
            assertAPIError(error, matches: .serverError(500))
        }
    }

    func test_error_networkTimeout() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.timedOut)
        }

        do {
            _ = try await makeClient().fetchProjects()
            XCTFail("Expected fetchProjects to throw")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .timedOut)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_error_invalidJSON() async {
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "GET", path: "/projects")
            return makeResponse(for: request, data: Data("invalid json".utf8))
        }

        do {
            _ = try await makeClient().fetchProjects()
            XCTFail("Expected fetchProjects to throw")
        } catch let error as DecodingError {
            switch error {
            case .dataCorrupted:
                break
            default:
                XCTFail("Expected dataCorrupted, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_error_decodingFailure() async {
        let payload: [String: Any] = [
            "projects": [
                ["name": "Missing Path"]
            ]
        ]
        MockURLProtocol.requestHandler = { request in
            assertRequest(request, method: "GET", path: "/projects")
            return makeResponse(for: request, json: payload)
        }

        do {
            _ = try await makeClient().fetchProjects()
            XCTFail("Expected fetchProjects to throw")
        } catch let error as DecodingError {
            switch error {
            case .keyNotFound:
                break
            default:
                XCTFail("Expected keyNotFound, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Path Encoding

    func test_encodeProjectPath_simpleSlashes() async throws {
        let payload = sessionsResponseJSON(sessions: [sessionMetadataJSON()])
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/projects/-Users-me-MyProject/sessions")
            return makeResponse(for: request, json: payload)
        }

        _ = try await makeClient().fetchSessions(projectPath: "/Users/me/MyProject")
    }

    func test_encodeProjectPath_withSpaces() async throws {
        let payload = sessionsResponseJSON(sessions: [sessionMetadataJSON()])
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/projects/-Users-me-My Project/sessions")
            XCTAssertEqual(
                request.url?.absoluteString,
                "http://cli-bridge.test/projects/-Users-me-My%20Project/sessions?limit=100"
            )
            return makeResponse(for: request, json: payload)
        }

        _ = try await makeClient().fetchSessions(projectPath: "/Users/me/My Project")
    }

    func test_encodeProjectPath_withSpecialChars() async throws {
        let payload = sessionsResponseJSON(sessions: [sessionMetadataJSON()])
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/projects/-Users-me-Project+Name@2024/sessions")
            return makeResponse(for: request, json: payload)
        }

        _ = try await makeClient().fetchSessions(projectPath: "/Users/me/Project+Name@2024")
    }

    func test_encodeProjectPath_emptyPath() async throws {
        let payload = sessionsResponseJSON(sessions: [sessionMetadataJSON()])
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/projects//sessions")
            return makeResponse(for: request, json: payload)
        }

        _ = try await makeClient().fetchSessions(projectPath: "")
    }
}
