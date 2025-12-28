import XCTest
@testable import CodingBridge

final class SessionWebSocketIntegrationTests: XCTestCase {
    func testSessionsUpdatedPushOnDeletion() async throws {
        let config = try IntegrationTestConfig.require()
        try XCTSkipIf(!config.allowMutations, "Set CODINGBRIDGE_TEST_ALLOW_MUTATIONS=1 to enable WebSocket deletion tests.")

        guard let deleteSessionId = config.deleteSessionId, !deleteSessionId.isEmpty else {
            throw XCTSkip("Set CODINGBRIDGE_TEST_DELETE_SESSION_ID to enable WebSocket deletion tests.")
        }

        let client = SessionAPIClient(config: config)
        let before = try await client.fetchSessions(limit: 100, offset: 0)
        try XCTSkipIf(!before.sessions.contains(where: { $0.id == deleteSessionId }), "Session ID not found in test project.")

        let task = URLSession.shared.webSocketTask(with: config.webSocketURL)
        task.resume()
        defer { task.cancel(with: .normalClosure, reason: nil) }

        try await waitForWebSocketReady(task)

        async let update = waitForSessionsUpdated(task: task, timeout: 8)

        try await client.deleteSession(sessionId: deleteSessionId)

        let payload = try await update
        XCTAssertEqual(payload["action"] as? String, "deleted")
        XCTAssertEqual(payload["sessionId"] as? String, deleteSessionId)
        if let projectName = payload["projectName"] as? String {
            XCTAssertEqual(projectName, config.projectName)
        }
    }
}

private func waitForWebSocketReady(_ task: URLSessionWebSocketTask) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        task.sendPing { error in
            if let error = error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: ())
            }
        }
    }
}

private func waitForSessionsUpdated(task: URLSessionWebSocketTask, timeout: TimeInterval) async throws -> [String: Any] {
    let deadline = Date().addingTimeInterval(timeout)

    while Date() < deadline {
        let remaining = max(deadline.timeIntervalSinceNow, 0.1)
        let message = try await receiveMessage(from: task, timeout: remaining)
        let wsMessage: WSMessage?
        do {
            wsMessage = try decodeWSMessage(from: message)
        } catch {
            continue
        }
        guard let wsMessage = wsMessage else { continue }

        if wsMessage.type == "sessions-updated",
           let data = wsMessage.data?.value as? [String: Any] {
            return data
        }
    }

    throw IntegrationTestError.timeout
}

private func receiveMessage(from task: URLSessionWebSocketTask, timeout: TimeInterval) async throws -> URLSessionWebSocketTask.Message {
    try await withThrowingTaskGroup(of: URLSessionWebSocketTask.Message.self) { group in
        group.addTask {
            try await task.receive()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            throw IntegrationTestError.timeout
        }

        let result = try await group.next()
        group.cancelAll()

        guard let message = result else {
            throw IntegrationTestError.timeout
        }

        return message
    }
}

private func decodeWSMessage(from message: URLSessionWebSocketTask.Message) throws -> WSMessage? {
    let data: Data
    switch message {
    case .string(let text):
        data = Data(text.utf8)
    case .data(let binary):
        data = binary
    @unknown default:
        return nil
    }

    return try JSONDecoder().decode(WSMessage.self, from: data)
}
