import Combine
import XCTest
@testable import CodingBridge

@MainActor
final class CLIBridgeManagerTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    private final class MockURLSessionWebSocketTask: WebSocketTasking {
        private let stream: AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>
        private let continuation: AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>.Continuation
        private var iterator: AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>.AsyncIterator
        private let lock = NSLock()

        private(set) var sentMessages: [URLSessionWebSocketTask.Message] = []
        private(set) var resumeCount = 0
        private(set) var cancelCount = 0
        private(set) var closeCode: URLSessionWebSocketTask.CloseCode?
        private(set) var closeReason: Data?
        var onSend: ((URLSessionWebSocketTask.Message) -> Void)?

        init() {
            var continuation: AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>.Continuation!
            let stream = AsyncThrowingStream<URLSessionWebSocketTask.Message, Error> { streamContinuation in
                continuation = streamContinuation
            }
            self.stream = stream
            self.continuation = continuation
            self.iterator = stream.makeAsyncIterator()
        }

        func resume() {
            resumeCount += 1
        }

        func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
            cancelCount += 1
            self.closeCode = closeCode
            self.closeReason = reason
            continuation.finish(throwing: URLError(.cancelled))
        }

        func send(_ message: URLSessionWebSocketTask.Message) async throws {
            lock.lock()
            sentMessages.append(message)
            lock.unlock()
            onSend?(message)
        }

        func receive() async throws -> URLSessionWebSocketTask.Message {
            if let message = try await iterator.next() {
                return message
            }
            throw URLError(.cancelled)
        }

        func queueIncoming(_ message: URLSessionWebSocketTask.Message) {
            continuation.yield(message)
        }
    }

    private final class MockURLSession: WebSocketSessioning {
        private let task: MockURLSessionWebSocketTask
        private(set) var createdURLs: [URL] = []
        private(set) var createdTasks: [MockURLSessionWebSocketTask] = []

        init(task: MockURLSessionWebSocketTask = MockURLSessionWebSocketTask()) {
            self.task = task
        }

        func makeWebSocketTask(with url: URL) -> WebSocketTasking {
            createdURLs.append(url)
            createdTasks.append(task)
            return task
        }
    }

    private struct MockError: Error {}

    private func makeManager(serverURL: String = "ws://example.com") -> (CLIBridgeManager, MockURLSession, MockURLSessionWebSocketTask) {
        let task = MockURLSessionWebSocketTask()
        let session = MockURLSession(task: task)
        let manager = CLIBridgeManager(serverURL: serverURL, webSocketSession: session)
        return (manager, session, task)
    }

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    private func jsonObject(from message: URLSessionWebSocketTask.Message, file: StaticString = #filePath, line: UInt = #line) -> [String: Any] {
        guard case .string(let text) = message else {
            XCTFail("Expected string message", file: file, line: line)
            return [:]
        }
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Failed to decode JSON", file: file, line: line)
            return [:]
        }
        return object
    }

    private func firstSentJSON(from task: MockURLSessionWebSocketTask, file: StaticString = #filePath, line: UInt = #line) -> [String: Any] {
        guard let message = task.sentMessages.first else {
            XCTFail("No messages sent", file: file, line: line)
            return [:]
        }
        return jsonObject(from: message, file: file, line: line)
    }

    private func lastSentJSON(from task: MockURLSessionWebSocketTask, file: StaticString = #filePath, line: UInt = #line) -> [String: Any] {
        guard let message = task.sentMessages.last else {
            XCTFail("No messages sent", file: file, line: line)
            return [:]
        }
        return jsonObject(from: message, file: file, line: line)
    }

    private func assistantStreamContent(text: String, delta: Bool?) -> CLIStreamContent {
        var payload: [String: Any] = [
            "type": "assistant",
            "content": text
        ]
        if let delta = delta {
            payload["delta"] = delta
        }
        let data = try! JSONSerialization.data(withJSONObject: payload)
        return try! JSONDecoder().decode(CLIStreamContent.self, from: data)
    }

    /// Helper to create a StoredMessage from CLIStreamContent for test_handleStreamMessage
    private func storedMessage(from content: CLIStreamContent, id: String = UUID().uuidString, timestamp: String = "2024-01-01T00:00:00.000Z") -> StoredMessage {
        StoredMessage(id: id, timestamp: timestamp, message: content)
    }

    private func messageString(from object: [String: Any], file: StaticString = #filePath, line: UInt = #line) -> URLSessionWebSocketTask.Message {
        do {
            let data = try JSONSerialization.data(withJSONObject: object, options: [])
            guard let text = String(data: data, encoding: .utf8) else {
                XCTFail("Failed to encode JSON string", file: file, line: line)
                return .string("{}")
            }
            return .string(text)
        } catch {
            XCTFail("Failed to encode JSON: \(error)", file: file, line: line)
            return .string("{}")
        }
    }

    private func connectedMessage(
        agentId: String = "agent-1",
        sessionId: String = "session-1"
    ) -> URLSessionWebSocketTask.Message {
        messageString(from: [
            "type": "connected",
            "agentId": agentId,
            "sessionId": sessionId,
            "model": "claude",
            "version": "1",
            "protocolVersion": "1"
        ])
    }

    private func assistantStreamMessage(content: String, delta: Bool, id: String = "msg-\(UUID().uuidString)", timestamp: String = "2024-01-01T00:00:00.000Z") -> URLSessionWebSocketTask.Message {
        messageString(from: [
            "type": "stream",
            "id": id,
            "timestamp": timestamp,
            "message": [
                "type": "assistant",
                "content": content,
                "delta": delta
            ]
        ])
    }

    func test_connectionState_disconnectedIsNotConnected() {
        XCTAssertFalse(CLIConnectionState.disconnected.isConnected)
    }

    func test_connectionState_connectingIsNotConnected() {
        XCTAssertFalse(CLIConnectionState.connecting.isConnected)
    }

    func test_connectionState_connectedIsConnected() {
        XCTAssertTrue(CLIConnectionState.connected(agentId: "agent").isConnected)
    }

    func test_connectionState_reconnectingIsNotConnected() {
        XCTAssertFalse(CLIConnectionState.reconnecting(attempt: 1).isConnected)
    }

    func test_connectionState_isConnectingForConnecting() {
        XCTAssertTrue(CLIConnectionState.connecting.isConnecting)
    }

    func test_connectionState_isConnectingForReconnecting() {
        XCTAssertTrue(CLIConnectionState.reconnecting(attempt: 2).isConnecting)
    }

    func test_connectionState_displayTextAllCases() {
        XCTAssertEqual(CLIConnectionState.disconnected.displayText, "Disconnected")
        XCTAssertEqual(CLIConnectionState.connecting.displayText, "Connecting...")
        XCTAssertEqual(CLIConnectionState.connected(agentId: "agent").displayText, "Connected")
        XCTAssertEqual(CLIConnectionState.reconnecting(attempt: 3).displayText, "Reconnecting (3)...")
    }

    func test_connectionState_agentIdExtraction() {
        XCTAssertNil(CLIConnectionState.disconnected.agentId)
        XCTAssertEqual(CLIConnectionState.connected(agentId: "agent-1").agentId, "agent-1")
    }

    func test_connectionState_equatable() {
        XCTAssertEqual(CLIConnectionState.connecting, .connecting)
        XCTAssertNotEqual(CLIConnectionState.connecting, .disconnected)
        XCTAssertEqual(CLIConnectionState.connected(agentId: "a"), .connected(agentId: "a"))
        XCTAssertNotEqual(CLIConnectionState.connected(agentId: "a"), .connected(agentId: "b"))
    }

    func test_init_defaultsToDisconnected() {
        let (manager, _, _) = makeManager()

        XCTAssertEqual(manager.connectionState, .disconnected)
    }

    func test_init_agentStateIsIdle() {
        let (manager, _, _) = makeManager()

        XCTAssertEqual(manager.agentState, .idle)
    }

    func test_init_noSessionId() {
        let (manager, _, _) = makeManager()

        XCTAssertNil(manager.sessionId)
    }

    func test_init_noCurrentText() {
        let (manager, _, _) = makeManager()

        XCTAssertEqual(manager.currentText, "")
    }

    func test_updateServerURL_updatesURL() async {
        let (manager, session, _) = makeManager(serverURL: "http://old.example.com")
        manager.test_setNetworkAvailable(true)
        manager.updateServerURL("http://updated.example.com/")

        await manager.connect(projectPath: "/tmp/project")

        XCTAssertEqual(session.createdURLs.first?.absoluteString, "ws://updated.example.com/ws")
        manager.disconnect()
    }

    func test_connect_setsConnectingState() async {
        let (manager, _, _) = makeManager()
        manager.test_setNetworkAvailable(true)

        await manager.connect(projectPath: "/tmp/project")

        XCTAssertEqual(manager.connectionState, .connecting)
        manager.disconnect()
    }

    func test_connect_withSessionIdIncludesInRequest() async {
        let (manager, _, task) = makeManager()
        manager.test_setNetworkAvailable(true)

        await manager.connect(projectPath: "/tmp/project", sessionId: "session-1")

        let json = firstSentJSON(from: task)
        XCTAssertEqual(json["type"] as? String, "start")
        XCTAssertEqual(json["sessionId"] as? String, "session-1")
        manager.disconnect()
    }

    func test_connect_withModelIncludesInRequest() async {
        let (manager, _, task) = makeManager()
        manager.test_setNetworkAvailable(true)

        await manager.connect(projectPath: "/tmp/project", model: "claude-3")

        let json = firstSentJSON(from: task)
        XCTAssertEqual(json["type"] as? String, "start")
        XCTAssertEqual(json["model"] as? String, "claude-3")
        manager.disconnect()
    }

    func test_disconnect_setsDisconnectedState() {
        let (manager, _, _) = makeManager()
        manager.connectionState = .connected(agentId: "agent-1")

        manager.disconnect()

        XCTAssertEqual(manager.connectionState, .disconnected)
    }

    func test_disconnect_clearsSessionId() {
        let (manager, _, _) = makeManager()
        manager.sessionId = "session-1"

        manager.disconnect()

        XCTAssertNil(manager.sessionId)
    }

    func test_disconnect_cancelsWebSocket() async {
        let (manager, _, task) = makeManager()
        manager.test_setNetworkAvailable(true)

        await manager.connect(projectPath: "/tmp/project")
        manager.disconnect()

        XCTAssertEqual(task.cancelCount, 1)
    }

    func test_disconnect_isManualDisconnect() {
        let (manager, _, _) = makeManager()

        manager.disconnect()

        XCTAssertTrue(manager.test_isManualDisconnect)
    }

    func test_parseMessage_systemConnectedExtractsAgentId() async {
        let (manager, _, _) = makeManager()
        let payload = CLIConnectedPayload(
            agentId: "agent-1",
            sessionId: "session-1",
            model: "claude",
            version: "1",
            protocolVersion: "1"
        )

        await manager.test_processServerMessage(.connected(payload))

        XCTAssertEqual(manager.connectionState, .connected(agentId: "agent-1"))
        XCTAssertEqual(manager.connectionState.agentId, "agent-1")
    }

    func test_parseMessage_systemSessionIdExtractsSessionId() async {
        let (manager, _, _) = makeManager()
        let payload = CLIConnectedPayload(
            agentId: "agent-1",
            sessionId: "session-1",
            model: "claude",
            version: "1",
            protocolVersion: "1"
        )

        await manager.test_processServerMessage(.connected(payload))

        XCTAssertEqual(manager.sessionId, "session-1")
    }

    func test_parseMessage_assistantTextSetsCurrentText() {
        // Server now sends only complete messages (delta filtering done server-side)
        let (manager, _, _) = makeManager()
        let content = assistantStreamContent(text: "Complete", delta: false)

        manager.test_handleStreamMessage(storedMessage(from: content))

        XCTAssertEqual(manager.currentText, "Complete")
    }

    func test_parseMessage_thinkingCallsCallback() async {
        let (manager, _, _) = makeManager()
        let expectation = expectation(description: "thinking callback")
        manager.onThinking = { content in
            XCTAssertEqual(content, "Thinking...")
            expectation.fulfill()
        }

        manager.test_handleStreamMessage(storedMessage(from: .thinking(CLIThinkingContent(content: "Thinking..."))))

        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_parseMessage_toolUseCallsCallback() async {
        let (manager, _, _) = makeManager()
        let expectation = expectation(description: "tool start")
        manager.onToolStart = { id, tool, input in
            XCTAssertEqual(id, "tool-1")
            XCTAssertEqual(tool, "Bash")
            XCTAssertEqual(input["command"] as? String, "ls")
            expectation.fulfill()
        }

        let toolContent = CLIToolUseContent(
            id: "tool-1",
            name: "Bash",
            input: ["command": AnyCodableValue("ls")]
        )
        manager.test_handleStreamMessage(storedMessage(from: .toolUse(toolContent)))

        XCTAssertEqual(manager.agentState, .executing)
        XCTAssertNil(manager.toolProgress)
        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_parseMessage_toolResultCallsCallback() async {
        let (manager, _, _) = makeManager()
        let expectation = expectation(description: "tool result")
        manager.onToolResult = { id, tool, output, success in
            XCTAssertEqual(id, "tool-1")
            XCTAssertEqual(tool, "Bash")
            XCTAssertEqual(output, "done")
            XCTAssertTrue(success)
            expectation.fulfill()
        }

        let resultContent = CLIToolResultContent(
            id: "tool-1",
            tool: "Bash",
            output: "done",
            success: true,
            isError: nil
        )
        manager.test_handleStreamMessage(storedMessage(from: .toolResult(resultContent)))

        XCTAssertEqual(manager.agentState, .thinking)
        XCTAssertNil(manager.toolProgress)
        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_parseMessage_progressUpdatesToolProgress() {
        let (manager, _, _) = makeManager()
        manager.agentState = .executing
        let progress = CLIProgressContent(id: "tool-1", tool: "Bash", elapsed: 2, progress: 50, detail: "Half")

        manager.test_handleStreamMessage(storedMessage(from: .progress(progress)))

        XCTAssertEqual(manager.toolProgress?.id, "tool-1")
        XCTAssertEqual(manager.toolProgress?.progress, 50)
    }

    func test_parseMessage_usageUpdatesTokenUsage() {
        let (manager, _, _) = makeManager()
        let usage = CLIUsageContent(
            inputTokens: 10,
            outputTokens: 5,
            cacheReadTokens: nil,
            cacheCreateTokens: nil,
            totalCost: nil,
            contextUsed: nil,
            contextLimit: nil
        )

        manager.test_handleStreamMessage(storedMessage(from: .usage(usage)))

        XCTAssertEqual(manager.tokenUsage?.inputTokens, 10)
        XCTAssertEqual(manager.tokenUsage?.outputTokens, 5)
    }

    func test_parseMessage_stateUpdatesAgentState() {
        let (manager, _, _) = makeManager()
        let state = CLIStateContent(state: .executing, tool: "Bash")

        manager.test_handleStreamMessage(storedMessage(from: .state(state)))

        XCTAssertEqual(manager.agentState, .executing)
    }

    func test_parseMessage_permissionRequestStoresRequest() {
        let (manager, _, _) = makeManager()
        let request = CLIPermissionRequest(
            id: "perm-1",
            tool: "Bash",
            input: ["command": AnyCodableValue("ls")],
            options: ["allow", "deny", "always"]
        )

        manager.test_handleStreamMessage(storedMessage(from: .permission(request)))

        XCTAssertEqual(manager.pendingPermission?.id, "perm-1")
        XCTAssertEqual(manager.agentState, .waitingPermission)
        XCTAssertNil(manager.toolProgress)
    }

    func test_parseMessage_questionRequestStoresQuestion() {
        let (manager, _, _) = makeManager()
        let question = CLIQuestionRequest(
            id: "question-1",
            questions: [
                CLIQuestionItem(
                    question: "Ready?",
                    header: "Status",
                    options: [CLIQuestionOption(label: "Yes", description: nil)],
                    multiSelect: false
                )
            ]
        )

        manager.test_handleStreamMessage(storedMessage(from: .question(question)))

        XCTAssertEqual(manager.pendingQuestion?.id, "question-1")
        XCTAssertEqual(manager.agentState, .waitingInput)
        XCTAssertNil(manager.toolProgress)
    }

    func test_parseMessage_errorCallsCallback() async {
        let (manager, _, _) = makeManager()
        let expectation = expectation(description: "error callback")
        manager.onError = { payload in
            XCTAssertEqual(payload.message, "Boom")
            expectation.fulfill()
        }

        let payload = CLIErrorPayload(
            code: "AGENT_ERROR",
            message: "Boom",
            recoverable: true,
            retryable: nil,
            retryAfter: nil
        )

        await manager.test_processServerMessage(.error(payload))

        XCTAssertEqual(manager.lastError, "Boom")
        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_parseMessage_stoppedCallsCallback() async {
        let (manager, _, _) = makeManager()
        let expectation = expectation(description: "stopped callback")
        manager.onStopped = { reason in
            XCTAssertEqual(reason, "done")
            expectation.fulfill()
        }

        await manager.test_processServerMessage(.stopped(CLIStoppedPayload(reason: "done")))

        XCTAssertEqual(manager.agentState, .idle)
        XCTAssertNil(manager.toolProgress)
        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_parseMessage_subagentStartCallsCallback() async {
        let (manager, _, _) = makeManager()
        let expectation = expectation(description: "subagent start")
        manager.onSubagentStart = { content in
            XCTAssertEqual(content.id, "sub-1")
            expectation.fulfill()
        }

        let subagent = CLISubagentStartContent(id: "sub-1", description: "Helper", agentType: "helper")
        manager.test_handleStreamMessage(storedMessage(from: .subagentStart(subagent)))

        XCTAssertEqual(manager.activeSubagent?.id, "sub-1")
        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_parseMessage_subagentCompleteCallsCallback() async {
        let (manager, _, _) = makeManager()
        manager.activeSubagent = CLISubagentStartContent(id: "sub-1", description: "Helper", agentType: "helper")
        let expectation = expectation(description: "subagent complete")
        manager.onSubagentComplete = { content in
            XCTAssertEqual(content.id, "sub-1")
            expectation.fulfill()
        }

        let complete = CLISubagentCompleteContent(id: "sub-1", summary: "Done")
        manager.test_handleStreamMessage(storedMessage(from: .subagentComplete(complete)))

        XCTAssertNil(manager.activeSubagent)
        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_parseMessage_sessionEventCallsCallback() async {
        let (manager, _, _) = makeManager()
        let expectation = expectation(description: "session event")
        manager.onSessionEvent = { event in
            XCTAssertEqual(event.sessionId, "session-1")
            expectation.fulfill()
        }

        let event = CLISessionEvent(action: .created, projectPath: "/tmp", sessionId: "session-1", metadata: nil)
        await manager.test_processServerMessage(.sessionEvent(event))

        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_parseMessage_historyCallsCallback() async {
        let (manager, _, _) = makeManager()
        let expectation = expectation(description: "history")
        manager.onHistory = { payload in
            XCTAssertEqual(payload.hasMore, false)
            expectation.fulfill()
        }

        let history = CLIHistoryPayload(messages: [], hasMore: false, cursor: nil)
        await manager.test_processServerMessage(.history(history))

        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_parseMessage_unknownTypeIgnored() async {
        let (manager, _, _) = makeManager()
        let message = URLSessionWebSocketTask.Message.string("{\"type\":\"mystery\"}")

        await manager.test_handleMessage(message)

        XCTAssertEqual(manager.connectionState, .disconnected)
        XCTAssertNil(manager.sessionId)
        XCTAssertNil(manager.lastError)
    }

    func test_reconnect_incrementsAttempt() async {
        let (manager, _, _) = makeManager()
        manager.test_reconnectAttempt = 0

        await manager.test_attemptReconnect()

        XCTAssertEqual(manager.test_reconnectAttempt, 1)
        XCTAssertEqual(manager.connectionState, .reconnecting(attempt: 1))
        manager.disconnect()
    }

    func test_reconnect_stopsAfterMaxAttempts() async {
        let (manager, _, _) = makeManager()
        manager.connectionState = .connected(agentId: "agent-1")
        manager.agentState = .executing
        manager.sessionId = "session-1"
        manager.test_reconnectAttempt = 5
        manager.test_isManualDisconnect = false
        manager.test_setNetworkAvailable(true)
        let expectation = expectation(description: "reconnect failed")
        manager.onConnectionError = { error in
            XCTAssertEqual(error, .reconnectFailed)
            expectation.fulfill()
        }

        await manager.test_handleDisconnect(error: MockError())

        XCTAssertEqual(manager.connectionState, .disconnected)
        XCTAssertEqual(manager.agentState, .stopped)
        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_reconnect_usesExponentialBackoff() async {
        let (manager, _, _) = makeManager()
        manager.test_reconnectAttempt = 2
        let expectation = expectation(description: "reconnecting")
        var capturedDelay: TimeInterval = 0
        var capturedAttempt = 0
        manager.onReconnecting = { attempt, delay in
            capturedAttempt = attempt
            capturedDelay = delay
            expectation.fulfill()
        }

        await manager.test_attemptReconnect()

        XCTAssertEqual(capturedAttempt, 3)
        XCTAssertGreaterThanOrEqual(capturedDelay, 4.0)
        XCTAssertLessThanOrEqual(capturedDelay, 4.6)
        await fulfillment(of: [expectation], timeout: 1)
        manager.disconnect()
    }

    func test_reconnect_notTriggeredForManualDisconnect() async {
        let (manager, _, _) = makeManager()
        manager.connectionState = .connected(agentId: "agent-1")
        manager.test_isManualDisconnect = true
        manager.sessionId = "session-1"
        manager.test_setNetworkAvailable(true)
        let expectation = expectation(description: "no reconnect")
        expectation.isInverted = true
        manager.onReconnecting = { _, _ in
            expectation.fulfill()
        }

        await manager.test_handleDisconnect(error: MockError())

        XCTAssertEqual(manager.connectionState, .connected(agentId: "agent-1"))
        await fulfillment(of: [expectation], timeout: 0.2)
    }

    func test_reconnect_resumesWithSameSessionId() async {
        let (manager, _, task) = makeManager()
        manager.test_setNetworkAvailable(true)
        manager.sessionId = "session-1"
        manager.test_setPendingConnection(projectPath: "/tmp/project", sessionId: "old-session", model: "claude", helper: false)
        let expectation = expectation(description: "send start")
        task.onSend = { _ in
            expectation.fulfill()
        }

        manager.test_reconnectWithExistingSession()

        await fulfillment(of: [expectation], timeout: 1)
        let json = firstSentJSON(from: task)
        XCTAssertEqual(json["sessionId"] as? String, "session-1")
        manager.disconnect()
    }

    func test_sendInput_setsProcessingState() async throws {
        let (manager, _, task) = makeManager()
        manager.test_setWebSocket(task)
        manager.agentState = .idle

        try await manager.sendInput("Hello")

        XCTAssertEqual(manager.agentState, .thinking)
    }

    func test_sendInput_withImagesIncludesImages() async throws {
        let (manager, _, task) = makeManager()
        manager.test_setWebSocket(task)
        let image = CLIImageAttachment(base64Data: "Zm9v", mimeType: "image/png")

        try await manager.sendInput("Hello", images: [image])

        let json = lastSentJSON(from: task)
        XCTAssertEqual(json["type"] as? String, "input")
        let images = json["images"] as? [[String: Any]]
        XCTAssertEqual(images?.first?["type"] as? String, "base64")
        XCTAssertEqual(images?.first?["data"] as? String, "Zm9v")
        XCTAssertEqual(images?.first?["mimeType"] as? String, "image/png")
    }

    func test_sendInput_withThinkingModeIncludesMode() async throws {
        let (manager, _, task) = makeManager()
        manager.test_setWebSocket(task)

        try await manager.sendInput("Hello", thinkingMode: "think_hard")

        let json = lastSentJSON(from: task)
        XCTAssertEqual(json["thinkingMode"] as? String, "think_hard")
    }

    func test_sendInput_whenNotConnectedThrows() async {
        let (manager, _, _) = makeManager()
        do {
            try await manager.sendInput("Hello")
            XCTFail("Expected error to be thrown")
        } catch let error as CLIBridgeError {
            guard case .notConnected = error else {
                XCTFail("Expected notConnected error")
                return
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_respondToPermission_allowSendsCorrectMessage() async throws {
        let (manager, _, task) = makeManager()
        manager.test_setWebSocket(task)
        manager.pendingPermission = CLIPermissionRequest(id: "perm-1", tool: "Bash", input: [:], options: [])

        try await manager.respondToPermission(id: "perm-1", choice: .allow)

        let json = lastSentJSON(from: task)
        XCTAssertEqual(json["type"] as? String, "permission_response")
        XCTAssertEqual(json["id"] as? String, "perm-1")
        XCTAssertEqual(json["choice"] as? String, "allow")
        XCTAssertNil(manager.pendingPermission)
    }

    func test_respondToPermission_denySendsCorrectMessage() async throws {
        let (manager, _, task) = makeManager()
        manager.test_setWebSocket(task)
        manager.pendingPermission = CLIPermissionRequest(id: "perm-1", tool: "Bash", input: [:], options: [])

        try await manager.respondToPermission(id: "perm-1", choice: .deny)

        let json = lastSentJSON(from: task)
        XCTAssertEqual(json["type"] as? String, "permission_response")
        XCTAssertEqual(json["choice"] as? String, "deny")
        XCTAssertNil(manager.pendingPermission)
    }

    func test_respondToPermission_alwaysSendsCorrectMessage() async throws {
        let (manager, _, task) = makeManager()
        manager.test_setWebSocket(task)
        manager.pendingPermission = CLIPermissionRequest(id: "perm-1", tool: "Bash", input: [:], options: [])

        try await manager.respondToPermission(id: "perm-1", choice: .always)

        let json = lastSentJSON(from: task)
        XCTAssertEqual(json["type"] as? String, "permission_response")
        XCTAssertEqual(json["choice"] as? String, "always")
        XCTAssertNil(manager.pendingPermission)
    }

    func test_respondToQuestion_sendsAnswers() async throws {
        let (manager, _, task) = makeManager()
        manager.test_setWebSocket(task)
        manager.pendingQuestion = CLIQuestionRequest(id: "question-1", questions: [])

        try await manager.respondToQuestion(id: "question-1", answers: ["choice": "yes", "count": 2])

        let json = lastSentJSON(from: task)
        XCTAssertEqual(json["type"] as? String, "question_response")
        XCTAssertEqual(json["id"] as? String, "question-1")
        let answers = json["answers"] as? [String: Any]
        XCTAssertEqual(answers?["choice"] as? String, "yes")
        XCTAssertEqual(answers?["count"] as? Int, 2)
        XCTAssertNil(manager.pendingQuestion)
    }

    func test_interrupt_sendsInterruptMessage() async throws {
        let (manager, _, task) = makeManager()
        manager.test_setWebSocket(task)

        try await manager.interrupt()

        let json = lastSentJSON(from: task)
        XCTAssertEqual(json["type"] as? String, "interrupt")
    }

    func test_setModel_sendsSetModelMessage() async throws {
        let (manager, _, task) = makeManager()
        manager.test_setWebSocket(task)

        try await manager.setModel("claude-3")

        let json = lastSentJSON(from: task)
        XCTAssertEqual(json["type"] as? String, "set_model")
        XCTAssertEqual(json["model"] as? String, "claude-3")
    }

    func test_setPermissionMode_sendsCorrectMode() async throws {
        let (manager, _, task) = makeManager()
        manager.test_setWebSocket(task)

        try await manager.setPermissionMode(.bypassPermissions)

        let json = lastSentJSON(from: task)
        XCTAssertEqual(json["type"] as? String, "set_permission_mode")
        XCTAssertEqual(json["mode"] as? String, "bypassPermissions")
    }

    func test_cancelQueuedInput_sendsCancelMessage() async throws {
        let (manager, _, task) = makeManager()
        manager.test_setWebSocket(task)

        try await manager.cancelQueuedInput()

        let json = lastSentJSON(from: task)
        XCTAssertEqual(json["type"] as? String, "cancel_queued")
    }

    func test_clearCurrentText_clearsText() {
        // Server sends complete messages, clearCurrentText just resets currentText
        let (manager, _, _) = makeManager()
        let content = assistantStreamContent(text: "Hello", delta: false)

        manager.test_handleStreamMessage(storedMessage(from: content))
        XCTAssertEqual(manager.currentText, "Hello")

        manager.clearCurrentText()
        XCTAssertEqual(manager.currentText, "")
    }

    func test_onText_calledWithFinalContent() async {
        // Server now only sends complete messages (delta=false)
        let (manager, _, _) = makeManager()
        let expectation = expectation(description: "onText")
        manager.onText = { content, isFinal in
            XCTAssertEqual(content, "Hi")
            XCTAssertTrue(isFinal)  // Always final now
            expectation.fulfill()
        }

        manager.test_handleStreamMessage(storedMessage(from: assistantStreamContent(text: "Hi", delta: false)))

        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_onThinking_calledWithContent() async {
        let (manager, _, _) = makeManager()
        let expectation = expectation(description: "onThinking")
        manager.onThinking = { content in
            XCTAssertEqual(content, "Reasoning")
            expectation.fulfill()
        }

        manager.test_handleStreamMessage(storedMessage(from: .thinking(CLIThinkingContent(content: "Reasoning"))))

        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_onToolStart_calledWithIdToolInput() async {
        let (manager, _, _) = makeManager()
        let expectation = expectation(description: "onToolStart")
        manager.onToolStart = { id, tool, input in
            XCTAssertEqual(id, "tool-1")
            XCTAssertEqual(tool, "Bash")
            XCTAssertEqual(input["command"] as? String, "ls")
            expectation.fulfill()
        }

        let toolContent = CLIToolUseContent(
            id: "tool-1",
            name: "Bash",
            input: ["command": AnyCodableValue("ls")]
        )
        manager.test_handleStreamMessage(storedMessage(from: .toolUse(toolContent)))

        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_onToolResult_calledWithIdToolOutputSuccess() async {
        let (manager, _, _) = makeManager()
        let expectation = expectation(description: "onToolResult")
        manager.onToolResult = { id, tool, output, success in
            XCTAssertEqual(id, "tool-1")
            XCTAssertEqual(tool, "Bash")
            XCTAssertEqual(output, "done")
            XCTAssertTrue(success)
            expectation.fulfill()
        }

        let resultContent = CLIToolResultContent(
            id: "tool-1",
            tool: "Bash",
            output: "done",
            success: true,
            isError: nil
        )
        manager.test_handleStreamMessage(storedMessage(from: .toolResult(resultContent)))

        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_onStopped_calledWithReason() async {
        let (manager, _, _) = makeManager()
        let expectation = expectation(description: "onStopped")
        manager.onStopped = { reason in
            XCTAssertEqual(reason, "interrupted")
            expectation.fulfill()
        }

        await manager.test_processServerMessage(.interrupted)

        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_onError_calledWithPayload() async {
        let (manager, _, _) = makeManager()
        let expectation = expectation(description: "onError")
        manager.onError = { payload in
            XCTAssertEqual(payload.message, "Oops")
            expectation.fulfill()
        }

        let payload = CLIErrorPayload(
            code: "INVALID_MESSAGE",
            message: "Oops",
            recoverable: false,
            retryable: nil,
            retryAfter: nil
        )

        await manager.test_processServerMessage(.error(payload))

        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_onSessionConnected_calledWithSessionId() async {
        let (manager, _, _) = makeManager()
        let expectation = expectation(description: "onSessionConnected")
        manager.onSessionConnected = { sessionId in
            XCTAssertEqual(sessionId, "session-1")
            expectation.fulfill()
        }

        let payload = CLIConnectedPayload(
            agentId: "agent-1",
            sessionId: "session-1",
            model: "claude",
            version: "1",
            protocolVersion: "1"
        )
        await manager.test_processServerMessage(.connected(payload))

        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_onModelChanged_calledWithModelId() async {
        let (manager, _, _) = makeManager()
        let expectation = expectation(description: "onModelChanged")
        manager.onModelChanged = { model in
            XCTAssertEqual(model, "claude-3")
            expectation.fulfill()
        }

        let payload = CLIModelChangedPayload(model: "claude-3", previousModel: "claude-2")
        await manager.test_processServerMessage(.modelChanged(payload))

        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_connect_whileAlreadyConnecting_doesNotStartSecondConnection() async throws {
        let (manager, session, task) = makeManager()
        manager.test_setNetworkAvailable(true)

        await manager.connect(projectPath: "/tmp/project-1")
        await manager.connect(projectPath: "/tmp/project-2")

        XCTAssertEqual(session.createdURLs.count, 1)
        XCTAssertEqual(task.sentMessages.count, 1)
        let json = firstSentJSON(from: task)
        XCTAssertEqual(json["projectPath"] as? String, "/tmp/project-1")
        manager.disconnect()
    }

    func test_connect_withInvalidURL_setsErrorState() async throws {
        let (manager, session, _) = makeManager(serverURL: "http://bad url")
        manager.test_setNetworkAvailable(true)
        let expectation = expectation(description: "invalid url")
        manager.onConnectionError = { error in
            XCTAssertEqual(error, .invalidServerURL)
            expectation.fulfill()
        }

        await manager.connect(projectPath: "/tmp/project")

        XCTAssertEqual(manager.connectionState, .disconnected)
        XCTAssertEqual(manager.agentState, .stopped)
        XCTAssertEqual(manager.lastError, "Invalid server URL")
        XCTAssertTrue(session.createdURLs.isEmpty)
        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_connect_timeout_retriesWithBackoff() async throws {
        let (manager, _, _) = makeManager()
        manager.connectionState = .connecting
        manager.agentState = .starting
        manager.sessionId = "session-1"
        manager.test_setNetworkAvailable(true)
        manager.test_reconnectAttempt = 0
        let expectation = expectation(description: "reconnecting")
        var capturedDelay: TimeInterval = 0
        var capturedAttempt = 0
        manager.onReconnecting = { attempt, delay in
            capturedAttempt = attempt
            capturedDelay = delay
            expectation.fulfill()
        }

        await manager.test_handleDisconnect(error: MockError())

        XCTAssertEqual(manager.connectionState, .reconnecting(attempt: 1))
        XCTAssertEqual(manager.agentState, .recovering)
        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertEqual(capturedAttempt, 1)
        XCTAssertGreaterThanOrEqual(capturedDelay, 1.0)
        XCTAssertLessThanOrEqual(capturedDelay, 1.5)
        manager.disconnect()
    }

    func test_connect_networkUnreachable_setsDisconnectedState() async throws {
        let (manager, session, _) = makeManager()
        manager.test_setNetworkAvailable(false)
        let expectation = expectation(description: "network unavailable")
        manager.onConnectionError = { error in
            XCTAssertEqual(error, .networkUnavailable)
            expectation.fulfill()
        }

        await manager.connect(projectPath: "/tmp/project")

        XCTAssertEqual(manager.connectionState, .disconnected)
        XCTAssertEqual(manager.agentState, .idle)
        XCTAssertEqual(manager.lastError, "No network connection")
        XCTAssertTrue(session.createdURLs.isEmpty)
        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_disconnect_whileProcessing_abortsFirst() {
        let (manager, _, task) = makeManager()
        manager.test_setWebSocket(task)
        manager.connectionState = .connected(agentId: "agent-1")
        manager.agentState = .thinking
        manager.sessionId = "session-1"
        manager.currentText = "Working"
        manager.pendingPermission = CLIPermissionRequest(
            id: "perm-1",
            tool: "Bash",
            input: ["command": AnyCodableValue("ls")],
            options: ["allow"]
        )
        manager.pendingQuestion = CLIQuestionRequest(
            id: "question-1",
            questions: [
                CLIQuestionItem(
                    question: "Proceed?",
                    header: "Confirm",
                    options: [CLIQuestionOption(label: "Yes", description: nil)],
                    multiSelect: false
                )
            ]
        )
        manager.isInputQueued = true
        manager.queuePosition = 2
        manager.activeSubagent = CLISubagentStartContent(id: "sub-1", description: "Helper", agentType: "helper")
        manager.toolProgress = CLIProgressContent(id: "tool-1", tool: "Bash", elapsed: 1, progress: 20, detail: "Start")

        manager.disconnect()

        XCTAssertEqual(manager.connectionState, .disconnected)
        XCTAssertEqual(manager.agentState, .stopped)
        XCTAssertNil(manager.sessionId)
        XCTAssertEqual(manager.currentText, "")
        XCTAssertNil(manager.pendingPermission)
        XCTAssertNil(manager.pendingQuestion)
        XCTAssertFalse(manager.isInputQueued)
        XCTAssertNil(manager.activeSubagent)
        XCTAssertNil(manager.toolProgress)
        XCTAssertEqual(task.cancelCount, 1)
    }

    func test_disconnect_duringReconnect_cancelsReconnect() async throws {
        let (manager, session, task) = makeManager()
        manager.test_setNetworkAvailable(true)
        manager.sessionId = "session-1"
        manager.test_setPendingConnection(projectPath: "/tmp/project", sessionId: "session-1", model: nil, helper: false)
        let reconnectExpectation = expectation(description: "reconnecting")
        var delay: TimeInterval = 0
        manager.onReconnecting = { _, capturedDelay in
            delay = capturedDelay
            reconnectExpectation.fulfill()
        }

        await manager.test_attemptReconnect()

        await fulfillment(of: [reconnectExpectation], timeout: 1)
        manager.disconnect()

        let waitNanos = UInt64((delay + 0.2) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: waitNanos)

        XCTAssertTrue(session.createdURLs.isEmpty)
        XCTAssertTrue(task.sentMessages.isEmpty)
        XCTAssertEqual(manager.connectionState, .disconnected)
    }

    func test_disconnect_preserveSession_maintainsSessionId() {
        let (manager, _, _) = makeManager()
        manager.sessionId = "session-1"

        manager.disconnect(preserveSession: true)

        XCTAssertEqual(manager.sessionId, "session-1")
    }

    func test_reconnect_afterNetworkRestore_resumesSession() async throws {
        let (manager, _, task) = makeManager()
        manager.test_setNetworkAvailable(true)
        manager.sessionId = "session-1"
        manager.test_setPendingConnection(projectPath: "/tmp/project", sessionId: "session-1", model: "claude", helper: false)
        let expectation = expectation(description: "reconnect send")
        task.onSend = { _ in
            expectation.fulfill()
        }

        manager.test_handleNetworkRestored()

        await fulfillment(of: [expectation], timeout: 1)
        let json = firstSentJSON(from: task)
        XCTAssertEqual(json["sessionId"] as? String, "session-1")
        manager.disconnect()
    }

    func test_stream_partialEvent_buffersUntilComplete() async throws {
        let (manager, _, _) = makeManager()

        await manager.test_handleMessage(.string("{\"type\":\"connected\""))

        XCTAssertEqual(manager.connectionState, .disconnected)
        XCTAssertNil(manager.sessionId)

        await manager.test_handleMessage(connectedMessage())

        XCTAssertEqual(manager.connectionState, .connected(agentId: "agent-1"))
        XCTAssertEqual(manager.sessionId, "session-1")
    }

    func test_stream_malformedJSON_logsErrorContinues() async throws {
        let (manager, _, _) = makeManager()

        await manager.test_handleMessage(.string("not json"))

        XCTAssertEqual(manager.currentText, "")

        // Server sends complete messages (delta=false)
        await manager.test_handleMessage(assistantStreamMessage(content: "Hi", delta: false))

        XCTAssertEqual(manager.currentText, "Hi")
    }

    func test_stream_unexpectedEventType_ignoresGracefully() async throws {
        let (manager, _, _) = makeManager()
        let message = messageString(from: [
            "type": "stream",
            "message": [
                "type": "mystery"
            ]
        ])

        await manager.test_handleMessage(message)

        XCTAssertEqual(manager.connectionState, .disconnected)
        XCTAssertNil(manager.pendingPermission)
        XCTAssertNil(manager.pendingQuestion)
    }

    func test_stream_connectionReset_triggersReconnect() async throws {
        let (manager, _, _) = makeManager()
        manager.connectionState = .connected(agentId: "agent-1")
        manager.agentState = .executing
        manager.sessionId = "session-1"
        manager.test_setPendingConnection(projectPath: "/tmp/project", sessionId: "session-1", model: nil, helper: false)
        manager.test_setNetworkAvailable(true)
        let expectation = expectation(description: "reconnecting")
        manager.onReconnecting = { _, _ in
            expectation.fulfill()
        }

        await manager.test_handleDisconnect(error: URLError(.networkConnectionLost))

        XCTAssertEqual(manager.connectionState, .reconnecting(attempt: 1))
        XCTAssertEqual(manager.agentState, .recovering)
        await fulfillment(of: [expectation], timeout: 1)
        manager.disconnect()
    }

    func test_sendInput_serverError500_propagatesError() async throws {
        let (manager, _, _) = makeManager()
        let expectation = expectation(description: "server error")
        manager.onConnectionError = { error in
            XCTAssertEqual(
                error,
                .serverError(code: "AGENT_ERROR", message: "Server error", recoverable: false)
            )
            expectation.fulfill()
        }

        let payload = CLIErrorPayload(
            code: "AGENT_ERROR",
            message: "Server error",
            recoverable: false,
            retryable: nil,
            retryAfter: nil
        )
        await manager.test_processServerMessage(.error(payload))

        XCTAssertEqual(manager.lastError, "Server error")
        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_sendInput_unauthorized401_clearsSessionAndNotifies() async throws {
        let (manager, _, _) = makeManager()
        manager.sessionId = "session-1"
        manager.test_setPendingConnection(projectPath: "/tmp/project", sessionId: "session-1", model: nil, helper: false)
        manager.agentState = .executing
        let expectation = expectation(description: "session invalid")
        manager.onConnectionError = { error in
            XCTAssertEqual(error, .sessionInvalid)
            expectation.fulfill()
        }

        let payload = CLIErrorPayload(
            code: "SESSION_INVALID",
            message: "Unauthorized",
            recoverable: false,
            retryable: nil,
            retryAfter: nil
        )
        await manager.test_processServerMessage(.error(payload))

        XCTAssertNil(manager.sessionId)
        XCTAssertEqual(manager.agentState, .stopped)
        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_sendInput_rateLimited429_queuesForRetry() async throws {
        let (manager, _, task) = makeManager()
        manager.test_setNetworkAvailable(true)
        manager.sessionId = "session-1"
        manager.test_setPendingConnection(projectPath: "/tmp/project", sessionId: "session-1", model: nil, helper: false)
        let errorExpectation = expectation(description: "rate limited")
        manager.onConnectionError = { error in
            XCTAssertEqual(error, .rateLimited(retryAfter: 0))
            errorExpectation.fulfill()
        }
        let sendExpectation = expectation(description: "retry connect")
        task.onSend = { _ in
            sendExpectation.fulfill()
        }

        let payload = CLIErrorPayload(
            code: "RATE_LIMITED",
            message: "Too many",
            recoverable: true,
            retryable: true,
            retryAfter: 0
        )
        await manager.test_processServerMessage(.error(payload))

        await fulfillment(of: [errorExpectation, sendExpectation], timeout: 1)
        let json = firstSentJSON(from: task)
        XCTAssertEqual(json["type"] as? String, "start")
        manager.disconnect()
    }

    func test_agentState_transitionsCorrectly_throughLifecycle() async throws {
        let (manager, _, _) = makeManager()
        manager.test_setNetworkAvailable(true)

        var observedStates: [CLIAgentState] = []
        let expectation = expectation(description: "agent state sequence")
        manager.$agentState.dropFirst().sink { state in
            observedStates.append(state)
            if observedStates.count == 6 {
                expectation.fulfill()
            }
        }.store(in: &cancellables)

        await manager.connect(projectPath: "/tmp/project")

        let connectedPayload = CLIConnectedPayload(
            agentId: "agent-1",
            sessionId: "session-1",
            model: "claude",
            version: "1",
            protocolVersion: "1"
        )
        await manager.test_processServerMessage(.connected(connectedPayload))

        try await manager.sendInput("Hello")

        let toolUse = CLIToolUseContent(
            id: "tool-1",
            name: "Bash",
            input: ["command": AnyCodableValue("ls")]
        )
        manager.test_handleStreamMessage(storedMessage(from: .toolUse(toolUse)))

        let toolResult = CLIToolResultContent(
            id: "tool-1",
            tool: "Bash",
            output: "done",
            success: true,
            isError: nil
        )
        manager.test_handleStreamMessage(storedMessage(from: .toolResult(toolResult)))

        await manager.test_processServerMessage(.stopped(CLIStoppedPayload(reason: "done")))

        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertEqual(
            observedStates,
            [.starting, .idle, .thinking, .executing, .thinking, .idle]
        )
        manager.disconnect()
    }
}
