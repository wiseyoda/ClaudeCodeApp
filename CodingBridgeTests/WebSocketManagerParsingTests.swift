import XCTest
@testable import CodingBridge

@MainActor
final class WebSocketManagerParsingTests: XCTestCase {
    func testSessionCreatedUpdatesSessionIdAndCallback() throws {
        let manager = WebSocketManager(parseSynchronously: true)
        var capturedSessionId: String?
        manager.onSessionCreated = { capturedSessionId = $0 }

        let json = try makeMessage(type: "session-created", sessionId: "session-123")
        manager.processIncomingMessage(json)

        XCTAssertEqual(manager.sessionId, "session-123")
        XCTAssertEqual(capturedSessionId, "session-123")
    }

    func testTokenBudgetUpdatesTokenUsage() throws {
        let manager = WebSocketManager(parseSynchronously: true)

        let json = try makeMessage(type: "token-budget", data: ["used": 42, "total": 100])
        manager.processIncomingMessage(json)

        XCTAssertEqual(manager.tokenUsage?.used, 42)
        XCTAssertEqual(manager.tokenUsage?.total, 100)
    }

    func testPermissionRequestSetsPendingApprovalAndCallback() throws {
        let manager = WebSocketManager(parseSynchronously: true)
        var capturedRequest: ApprovalRequest?
        manager.onApprovalRequest = { capturedRequest = $0 }

        let data: [String: Any] = [
            "requestId": "req-123",
            "toolName": "Bash",
            "input": ["command": "ls -la"]
        ]
        let json = try makeMessage(type: "permission-request", data: data)
        manager.processIncomingMessage(json)

        XCTAssertEqual(manager.pendingApproval?.id, "req-123")
        XCTAssertEqual(capturedRequest?.toolName, "Bash")
        XCTAssertEqual(capturedRequest?.displayDescription, "ls -la")
    }

    func testAssistantTextAppendsAndCallsOnText() throws {
        let manager = WebSocketManager(parseSynchronously: true)
        var capturedText: String?
        manager.onText = { capturedText = $0 }

        let data: [String: Any] = [
            "type": "assistant",
            "message": [
                "content": [
                    ["type": "text", "text": "Hello"]
                ]
            ]
        ]
        let json = try makeMessage(type: "claude-response", data: data)
        manager.processIncomingMessage(json)

        XCTAssertEqual(manager.currentText, "Hello")
        XCTAssertEqual(capturedText, "Hello")
    }

    func testToolUseCommitsTextAndCallsToolUse() throws {
        let manager = WebSocketManager(parseSynchronously: true)
        var committedText: String?
        var toolName: String?
        var toolInput: String?
        manager.onTextCommit = { committedText = $0 }
        manager.onToolUse = { name, input in
            toolName = name
            toolInput = input
        }

        let data: [String: Any] = [
            "type": "assistant",
            "content": [
                ["type": "text", "text": "Working"],
                ["type": "tool_use", "name": "ReadFile", "input": ["path": "/tmp/file.txt"]]
            ]
        ]
        let json = try makeMessage(type: "claude-response", data: data)
        manager.processIncomingMessage(json)

        XCTAssertEqual(committedText, "Working")
        XCTAssertEqual(toolName, "ReadFile")
        XCTAssertTrue(toolInput?.contains("/tmp/file.txt") == true)
        XCTAssertEqual(manager.currentText, "")
    }

    func testAskUserQuestionTriggersCallback() throws {
        let manager = WebSocketManager(parseSynchronously: true)
        var receivedData: AskUserQuestionData?
        manager.onAskUserQuestion = { receivedData = $0 }

        let input: [String: Any] = [
            "questions": [
                [
                    "question": "Choose one",
                    "options": [
                        ["label": "A"],
                        ["label": "B"]
                    ]
                ]
            ]
        ]
        let data: [String: Any] = [
            "type": "assistant",
            "content": [
                ["type": "tool_use", "name": "AskUserQuestion", "input": input]
            ]
        ]
        let json = try makeMessage(type: "claude-response", data: data)
        manager.processIncomingMessage(json)

        XCTAssertEqual(receivedData?.questions.count, 1)
        XCTAssertEqual(receivedData?.questions.first?.question, "Choose one")
        XCTAssertEqual(receivedData?.questions.first?.options.count, 2)
    }

    func testModelSwitchConfirmationUpdatesModel() throws {
        let manager = WebSocketManager(parseSynchronously: true)
        manager.isSwitchingModel = true
        var capturedModelId: String?
        manager.onModelChanged = { _, modelId in
            capturedModelId = modelId
        }

        let data: [String: Any] = [
            "type": "assistant",
            "content": [
                ["type": "text", "text": "Set model to sonnet (claude-sonnet-4-5-20250929)"]
            ]
        ]
        let json = try makeMessage(type: "claude-response", data: data)
        manager.processIncomingMessage(json)

        XCTAssertEqual(manager.currentModel, .sonnet)
        XCTAssertEqual(manager.currentModelId, "claude-sonnet-4-5-20250929")
        XCTAssertEqual(capturedModelId, "claude-sonnet-4-5-20250929")
        XCTAssertFalse(manager.isSwitchingModel)
    }

    func testSessionErrorClearsSessionAndNotifiesRecovery() throws {
        let manager = WebSocketManager(parseSynchronously: true)
        manager.sessionId = "cbd6acb5-a212-4899-90c4-ab11937e21c0"
        var recovered = false
        var errorCalled = false
        manager.onSessionRecovered = { recovered = true }
        manager.onError = { _ in errorCalled = true }

        let json = try makeMessage(type: "claude-error", error: "Session not found")
        manager.processIncomingMessage(json)

        XCTAssertNil(manager.sessionId)
        XCTAssertEqual(manager.lastError, "Session expired, starting fresh...")
        XCTAssertTrue(recovered)
        XCTAssertFalse(errorCalled)
    }

    private func makeMessage(type: String, sessionId: String? = nil, data: Any? = nil, error: String? = nil) throws -> String {
        var payload: [String: Any] = ["type": type]
        if let sessionId = sessionId {
            payload["sessionId"] = sessionId
        }
        if let data = data {
            payload["data"] = data
        }
        if let error = error {
            payload["error"] = error
        }

        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        guard let json = String(data: jsonData, encoding: .utf8) else {
            throw NSError(domain: "WebSocketManagerParsingTests", code: 1, userInfo: nil)
        }
        return json
    }
}
