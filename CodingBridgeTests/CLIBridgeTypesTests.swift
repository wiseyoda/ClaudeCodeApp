import XCTest
@testable import CodingBridge

final class CLIBridgeTypesTests: XCTestCase {

    // MARK: - ConnectionState

    func test_connectionState_isConnected() {
        XCTAssertTrue(ConnectionState.connected.isConnected)
        XCTAssertFalse(ConnectionState.disconnected.isConnected)
        XCTAssertFalse(ConnectionState.connecting.isConnected)
        XCTAssertFalse(ConnectionState.reconnecting(attempt: 1).isConnected)
    }

    func test_connectionState_isDisconnected() {
        XCTAssertTrue(ConnectionState.disconnected.isDisconnected)
        XCTAssertFalse(ConnectionState.connected.isDisconnected)
        XCTAssertFalse(ConnectionState.connecting.isDisconnected)
        XCTAssertFalse(ConnectionState.reconnecting(attempt: 2).isDisconnected)
    }

    func test_connectionState_isConnecting() {
        XCTAssertTrue(ConnectionState.connecting.isConnecting)
        XCTAssertFalse(ConnectionState.connected.isConnecting)
        XCTAssertFalse(ConnectionState.disconnected.isConnecting)
        XCTAssertFalse(ConnectionState.reconnecting(attempt: 3).isConnecting)
    }

    func test_connectionState_isReconnecting() {
        XCTAssertTrue(ConnectionState.reconnecting(attempt: 4).isReconnecting)
        XCTAssertFalse(ConnectionState.connected.isReconnecting)
        XCTAssertFalse(ConnectionState.disconnected.isReconnecting)
        XCTAssertFalse(ConnectionState.connecting.isReconnecting)
    }

    func test_connectionState_displayText() {
        XCTAssertEqual(ConnectionState.disconnected.displayText, "Disconnected")
        XCTAssertEqual(ConnectionState.connecting.displayText, "Connecting...")
        XCTAssertEqual(ConnectionState.connected.displayText, "Connected")
        XCTAssertEqual(ConnectionState.reconnecting(attempt: 2).displayText, "Reconnecting (2)...")
    }

    func test_connectionState_accessibilityLabel() {
        XCTAssertEqual(ConnectionState.disconnected.accessibilityLabel, "Connection status: Disconnected")
        XCTAssertEqual(ConnectionState.connecting.accessibilityLabel, "Connection status: Connecting")
        XCTAssertEqual(ConnectionState.connected.accessibilityLabel, "Connection status: Connected")
        XCTAssertEqual(
            ConnectionState.reconnecting(attempt: 5).accessibilityLabel,
            "Connection status: Reconnecting, attempt 5"
        )
    }

    func test_connectionState_equatable() {
        XCTAssertEqual(ConnectionState.reconnecting(attempt: 1), ConnectionState.reconnecting(attempt: 1))
        XCTAssertNotEqual(ConnectionState.reconnecting(attempt: 1), ConnectionState.reconnecting(attempt: 2))
        XCTAssertNotEqual(ConnectionState.connected, ConnectionState.disconnected)
    }

    // MARK: - TokenUsage

    func test_tokenUsage_percentage_calculates() {
        let usage = TokenUsage(used: 25, total: 100)

        XCTAssertEqual(usage.percentage, 25.0, accuracy: 0.0001)
    }

    func test_tokenUsage_percentage_zeroTotal_returnsZero() {
        let usage = TokenUsage(used: 25, total: 0)

        XCTAssertEqual(usage.percentage, 0.0, accuracy: 0.0001)
    }

    // MARK: - AnyCodableValue decoding/encoding

    func test_anyCodableValue_decodesPrimitiveTypes() throws {
        let boolValue = try decodeAnyCodableValue("true")
        XCTAssertEqual(boolValue.boolValue, true)

        let intValue = try decodeAnyCodableValue("42")
        XCTAssertEqual(intValue.intValue, 42)

        let doubleValue = try decodeAnyCodableValue("3.5")
        XCTAssertEqual(doubleValue.value as? Double, 3.5)

        let stringValue = try decodeAnyCodableValue("\"hello\"")
        XCTAssertEqual(stringValue.value as? String, "hello")
    }

    func test_anyCodableValue_decodesCollections() throws {
        let arrayValue = try decodeAnyCodableValue("[1,\"two\",false]")
        guard let array = arrayValue.arrayValue else {
            XCTFail("Expected array value")
            return
        }
        XCTAssertEqual(array.count, 3)
        XCTAssertEqual(array[0] as? Int, 1)
        XCTAssertEqual(array[1] as? String, "two")
        XCTAssertEqual(array[2] as? Bool, false)

        let dictValue = try decodeAnyCodableValue("{\"a\":1,\"b\":\"two\"}")
        guard let dict = dictValue.dictValue else {
            XCTFail("Expected dict value")
            return
        }
        XCTAssertEqual(dict["a"] as? Int, 1)
        XCTAssertEqual(dict["b"] as? String, "two")
    }

    func test_anyCodableValue_decodesNull() throws {
        let nullValue = try decodeAnyCodableValue("null")
        XCTAssertTrue(nullValue.value is NSNull)
    }

    func test_anyCodableValue_encodesPrimitiveTypes() throws {
        let boolObject = try encodeAnyCodableValueToObject(AnyCodableValue(true))
        XCTAssertEqual(boolObject as? Bool, true)

        let intObject = try encodeAnyCodableValueToObject(AnyCodableValue(7))
        XCTAssertEqual((intObject as? NSNumber)?.intValue, 7)

        let doubleObject = try encodeAnyCodableValueToObject(AnyCodableValue(1.25))
        guard let doubleValue = (doubleObject as? NSNumber)?.doubleValue else {
            XCTFail("Expected double value")
            return
        }
        XCTAssertEqual(doubleValue, 1.25, accuracy: 0.0001)

        let stringObject = try encodeAnyCodableValueToObject(AnyCodableValue("hi"))
        XCTAssertEqual(stringObject as? String, "hi")
    }

    func test_anyCodableValue_encodesCollections() throws {
        let arrayObject = try encodeAnyCodableValueToObject(AnyCodableValue([1, "two"]))
        guard let array = arrayObject as? [Any] else {
            XCTFail("Expected array object")
            return
        }
        XCTAssertEqual(array.count, 2)
        XCTAssertEqual(array[0] as? Int, 1)
        XCTAssertEqual(array[1] as? String, "two")

        let dictObject = try encodeAnyCodableValueToObject(AnyCodableValue(["a": 1, "b": "two"]))
        guard let dict = dictObject as? [String: Any] else {
            XCTFail("Expected dict object")
            return
        }
        XCTAssertEqual(dict["a"] as? Int, 1)
        XCTAssertEqual(dict["b"] as? String, "two")
    }

    func test_anyCodableValue_encodesNull() throws {
        let nullObject = try encodeAnyCodableValueToObject(AnyCodableValue(NSNull()))

        XCTAssertTrue(nullObject is NSNull)
    }

    func test_anyCodableValue_equatable_primitives() {
        XCTAssertEqual(AnyCodableValue(true), AnyCodableValue(true))
        XCTAssertEqual(AnyCodableValue(42), AnyCodableValue(42))
        XCTAssertEqual(AnyCodableValue(2.5), AnyCodableValue(2.5))
        XCTAssertEqual(AnyCodableValue("ok"), AnyCodableValue("ok"))
    }

    func test_anyCodableValue_equatable_null() {
        XCTAssertEqual(AnyCodableValue(NSNull()), AnyCodableValue(NSNull()))
    }

    func test_anyCodableValue_equatable_mismatch() {
        XCTAssertNotEqual(AnyCodableValue(1), AnyCodableValue("1"))
    }

    func test_anyCodableValue_stringValue_forString() {
        let value = AnyCodableValue("hello")

        XCTAssertEqual(value.stringValue, "hello")
    }

    func test_anyCodableValue_stringValue_prefersStdout() throws {
        let value = try decodeAnyCodableValue("{\"stdout\":\"ok\",\"code\":0}")

        XCTAssertEqual(value.stringValue, "ok")
    }

    func test_anyCodableValue_stringValue_serializesDictionary() throws {
        let value = try decodeAnyCodableValue("{\"error\":\"bad\"}")
        guard let dict = value.value as? [String: Any] else {
            XCTFail("Expected dict value")
            return
        }
        let data = try JSONSerialization.data(withJSONObject: dict)
        let expected = String(data: data, encoding: .utf8)

        XCTAssertEqual(value.stringValue, expected)
    }

    func test_anyCodableValue_stringValue_serializesArray() throws {
        let value = try decodeAnyCodableValue("[\"a\",1]")
        guard let array = value.value as? [Any] else {
            XCTFail("Expected array value")
            return
        }
        let data = try JSONSerialization.data(withJSONObject: array)
        let expected = String(data: data, encoding: .utf8)

        XCTAssertEqual(value.stringValue, expected)
    }

    func test_anyCodableValue_accessors() throws {
        let dictValue = try decodeAnyCodableValue("{\"a\":1}")
        XCTAssertEqual(dictValue.dictValue?["a"] as? Int, 1)

        let arrayValue = try decodeAnyCodableValue("[1]")
        XCTAssertEqual(arrayValue.arrayValue?.first as? Int, 1)

        let intValue = try decodeAnyCodableValue("7")
        XCTAssertEqual(intValue.intValue, 7)

        let boolValue = try decodeAnyCodableValue("false")
        XCTAssertEqual(boolValue.boolValue, false)
    }

    // MARK: - CLIClientMessage encoding

    func test_cliClientMessage_encodesStart() throws {
        let payload = CLIStartPayload(projectPath: "/tmp/project", sessionId: "session-1", model: "claude", helper: true)
        let json = try encodeClientMessage(.start(payload))

        XCTAssertEqual(json["type"] as? String, "start")
        XCTAssertEqual(json["projectPath"] as? String, "/tmp/project")
        XCTAssertEqual(json["sessionId"] as? String, "session-1")
        XCTAssertEqual(json["model"] as? String, "claude")
        XCTAssertEqual(json["helper"] as? Bool, true)
    }

    func test_cliClientMessage_encodesInput() throws {
        let images = [
            CLIImageAttachment(base64Data: "ZGF0YQ==", mimeType: "image/png"),
            CLIImageAttachment(referenceId: "img-1")
        ]
        let payload = CLIInputPayload(
            text: "hello",
            images: images,
            messageId: "msg-1",
            thinkingMode: "think_hard"
        )
        let json = try encodeClientMessage(.input(payload))

        XCTAssertEqual(json["type"] as? String, "input")
        XCTAssertEqual(json["text"] as? String, "hello")
        XCTAssertEqual(json["messageId"] as? String, "msg-1")
        XCTAssertEqual(json["thinkingMode"] as? String, "think_hard")

        guard let imageObjects = json["images"] as? [[String: Any]] else {
            XCTFail("Expected images array")
            return
        }
        XCTAssertEqual(imageObjects.count, 2)

        let base64Image = imageObjects[0]
        XCTAssertEqual(base64Image["type"] as? String, "base64")
        XCTAssertEqual(base64Image["data"] as? String, "ZGF0YQ==")
        XCTAssertEqual(base64Image["mimeType"] as? String, "image/png")
        XCTAssertNil(base64Image["id"])

        let referenceImage = imageObjects[1]
        XCTAssertEqual(referenceImage["type"] as? String, "reference")
        XCTAssertEqual(referenceImage["id"] as? String, "img-1")
        XCTAssertNil(referenceImage["data"])
        XCTAssertNil(referenceImage["mimeType"])
    }

    func test_cliClientMessage_encodesPermissionResponse() throws {
        let payload = CLIPermissionResponsePayload(id: "perm-1", choice: .allow)
        let json = try encodeClientMessage(.permissionResponse(payload))

        XCTAssertEqual(json["type"] as? String, "permission_response")
        XCTAssertEqual(json["id"] as? String, "perm-1")
        XCTAssertEqual(json["choice"] as? String, "allow")
    }

    func test_cliClientMessage_encodesQuestionResponse() throws {
        let answers: [String: AnyCodableValue] = [
            "choice": AnyCodableValue("yes"),
            "count": AnyCodableValue(2)
        ]
        let payload = CLIQuestionResponsePayload(id: "question-1", answers: answers)
        let json = try encodeClientMessage(.questionResponse(payload))

        XCTAssertEqual(json["type"] as? String, "question_response")
        XCTAssertEqual(json["id"] as? String, "question-1")

        guard let answersObject = json["answers"] as? [String: Any] else {
            XCTFail("Expected answers object")
            return
        }
        XCTAssertEqual(answersObject["choice"] as? String, "yes")
        XCTAssertEqual((answersObject["count"] as? NSNumber)?.intValue, 2)
    }

    func test_cliClientMessage_encodesInterrupt() throws {
        let json = try encodeClientMessage(.interrupt)

        XCTAssertEqual(json["type"] as? String, "interrupt")
    }

    func test_cliClientMessage_encodesStop() throws {
        let json = try encodeClientMessage(.stop)

        XCTAssertEqual(json["type"] as? String, "stop")
    }

    func test_cliClientMessage_encodesSubscribeSessions() throws {
        let payload = CLISubscribeSessionsPayload(projectPath: "/tmp/project")
        let json = try encodeClientMessage(.subscribeSessions(payload))

        XCTAssertEqual(json["type"] as? String, "subscribe_sessions")
        XCTAssertEqual(json["projectPath"] as? String, "/tmp/project")
    }

    func test_cliClientMessage_encodesSetModel() throws {
        let payload = CLISetModelPayload(model: "claude-3")
        let json = try encodeClientMessage(.setModel(payload))

        XCTAssertEqual(json["type"] as? String, "set_model")
        XCTAssertEqual(json["model"] as? String, "claude-3")
    }

    func test_cliClientMessage_encodesSetPermissionMode() throws {
        let payload = CLISetPermissionModePayload(mode: .bypassPermissions)
        let json = try encodeClientMessage(.setPermissionMode(payload))

        XCTAssertEqual(json["type"] as? String, "set_permission_mode")
        XCTAssertEqual(json["mode"] as? String, "bypassPermissions")
    }

    func test_cliClientMessage_encodesCancelQueued() throws {
        let json = try encodeClientMessage(.cancelQueued)

        XCTAssertEqual(json["type"] as? String, "cancel_queued")
    }

    func test_cliClientMessage_encodesRetry() throws {
        let payload = CLIRetryPayload(messageId: "msg-2")
        let json = try encodeClientMessage(.retry(payload))

        XCTAssertEqual(json["type"] as? String, "retry")
        XCTAssertEqual(json["messageId"] as? String, "msg-2")
    }

    func test_cliClientMessage_encodesPing() throws {
        let json = try encodeClientMessage(.ping)

        XCTAssertEqual(json["type"] as? String, "ping")
    }

    // MARK: - CLIServerMessage decoding

    func test_cliServerMessage_decodesConnected() throws {
        let message = try decodeServerMessage(from: [
            "type": "connected",
            "agentId": "agent-1",
            "sessionId": "session-1",
            "model": "claude-3",
            "version": "1.0.0",
            "protocolVersion": "2"
        ])

        guard case .connected(let payload) = message else {
            XCTFail("Expected connected message")
            return
        }
        XCTAssertEqual(payload.agentId, "agent-1")
        XCTAssertEqual(payload.sessionId, "session-1")
        XCTAssertEqual(payload.model, "claude-3")
        XCTAssertEqual(payload.version, "1.0.0")
        XCTAssertEqual(payload.protocolVersion, "2")
    }

    func test_cliServerMessage_decodesStream() throws {
        let message = try decodeServerMessage(from: [
            "type": "stream",
            "message": [
                "type": "assistant",
                "content": "Hello",
                "delta": true
            ]
        ])

        guard case .stream(let payload) = message else {
            XCTFail("Expected stream message")
            return
        }
        switch payload.message {
        case .assistant(let content):
            XCTAssertEqual(content.content, "Hello")
            XCTAssertEqual(content.delta, true)
            XCTAssertFalse(content.isFinal)
        default:
            XCTFail("Expected assistant content")
        }
    }

    func test_cliServerMessage_decodesPermission() throws {
        let message = try decodeServerMessage(from: [
            "type": "permission",
            "id": "perm-1",
            "tool": "Bash",
            "input": [
                "command": "ls -la"
            ],
            "options": ["allow", "deny", "always"]
        ])

        guard case .permission(let payload) = message else {
            XCTFail("Expected permission message")
            return
        }
        XCTAssertEqual(payload.id, "perm-1")
        XCTAssertEqual(payload.tool, "Bash")
        XCTAssertEqual(payload.options, ["allow", "deny", "always"])
        XCTAssertEqual(payload.input["command"]?.stringValue, "ls -la")
    }

    func test_cliServerMessage_decodesQuestion() throws {
        let message = try decodeServerMessage(from: [
            "type": "question",
            "id": "question-1",
            "questions": [
                [
                    "question": "Pick one",
                    "header": "Header",
                    "options": [
                        ["label": "A", "description": "Option A"],
                        ["label": "B"]
                    ],
                    "multiSelect": false
                ]
            ]
        ])

        guard case .question(let payload) = message else {
            XCTFail("Expected question message")
            return
        }
        XCTAssertEqual(payload.id, "question-1")
        XCTAssertEqual(payload.questions.first?.question, "Pick one")
        XCTAssertEqual(payload.questions.first?.options.count, 2)
        XCTAssertEqual(payload.questions.first?.multiSelect, false)
    }

    func test_cliServerMessage_decodesSessionEvent() throws {
        let message = try decodeServerMessage(from: [
            "type": "session_event",
            "action": "created",
            "projectPath": "/tmp/project",
            "sessionId": "session-1"
        ])

        guard case .sessionEvent(let payload) = message else {
            XCTFail("Expected session_event message")
            return
        }
        XCTAssertEqual(payload.action, .created)
        XCTAssertEqual(payload.projectPath, "/tmp/project")
        XCTAssertEqual(payload.sessionId, "session-1")
    }

    func test_cliServerMessage_decodesHistory() throws {
        let message = try decodeServerMessage(from: [
            "type": "history",
            "messages": [
                [
                    "type": "user",
                    "id": "msg-1",
                    "content": "Hi",
                    "timestamp": "2024-01-01T00:00:00Z"
                ]
            ],
            "hasMore": true,
            "cursor": "cursor-1"
        ])

        guard case .history(let payload) = message else {
            XCTFail("Expected history message")
            return
        }
        XCTAssertEqual(payload.messages.first?.type, "user")
        XCTAssertEqual(payload.messages.first?.content, "Hi")
        XCTAssertEqual(payload.hasMore, true)
        XCTAssertEqual(payload.cursor, "cursor-1")
    }

    func test_cliServerMessage_decodesModelChanged() throws {
        let message = try decodeServerMessage(from: [
            "type": "model_changed",
            "model": "claude-3",
            "previousModel": "claude-2"
        ])

        guard case .modelChanged(let payload) = message else {
            XCTFail("Expected model_changed message")
            return
        }
        XCTAssertEqual(payload.model, "claude-3")
        XCTAssertEqual(payload.previousModel, "claude-2")
    }

    func test_cliServerMessage_decodesPermissionModeChanged() throws {
        let message = try decodeServerMessage(from: [
            "type": "permission_mode_changed",
            "mode": "acceptEdits"
        ])

        guard case .permissionModeChanged(let payload) = message else {
            XCTFail("Expected permission_mode_changed message")
            return
        }
        XCTAssertEqual(payload.mode, "acceptEdits")
    }

    func test_cliServerMessage_decodesQueued() throws {
        let message = try decodeServerMessage(from: [
            "type": "queued",
            "position": 2
        ])

        guard case .queued(let payload) = message else {
            XCTFail("Expected queued message")
            return
        }
        XCTAssertEqual(payload.position, 2)
    }

    func test_cliServerMessage_decodesQueueCleared() throws {
        let message = try decodeServerMessage(from: [
            "type": "queue_cleared"
        ])

        guard case .queueCleared = message else {
            XCTFail("Expected queue_cleared message")
            return
        }
    }

    func test_cliServerMessage_decodesError() throws {
        let message = try decodeServerMessage(from: [
            "type": "error",
            "code": "RATE_LIMITED",
            "message": "Slow down",
            "recoverable": true,
            "retryable": true,
            "retryAfter": 30
        ])

        guard case .error(let payload) = message else {
            XCTFail("Expected error message")
            return
        }
        XCTAssertEqual(payload.code, "RATE_LIMITED")
        XCTAssertEqual(payload.message, "Slow down")
        XCTAssertEqual(payload.recoverable, true)
        XCTAssertEqual(payload.retryAfter, 30)
    }

    func test_cliServerMessage_decodesPong() throws {
        let message = try decodeServerMessage(from: [
            "type": "pong",
            "serverTime": 123
        ])

        guard case .pong(let payload) = message else {
            XCTFail("Expected pong message")
            return
        }
        XCTAssertEqual(payload.serverTime, 123)
    }

    func test_cliServerMessage_decodesStopped() throws {
        let message = try decodeServerMessage(from: [
            "type": "stopped",
            "reason": "user_stop"
        ])

        guard case .stopped(let payload) = message else {
            XCTFail("Expected stopped message")
            return
        }
        XCTAssertEqual(payload.reason, "user_stop")
    }

    func test_cliServerMessage_decodesInterrupted() throws {
        let message = try decodeServerMessage(from: [
            "type": "interrupted"
        ])

        guard case .interrupted = message else {
            XCTFail("Expected interrupted message")
            return
        }
    }

    func test_cliServerMessage_decodesUnknownType_throws() {
        XCTAssertThrowsError(try decodeServerMessage(from: ["type": "mystery"])) { error in
            guard case DecodingError.dataCorrupted = error else {
                XCTFail("Expected dataCorrupted error")
                return
            }
        }
    }

    // MARK: - CLIErrorPayload

    func test_cliErrorPayload_errorCode_invalidMessage() throws {
        let payload = try decodeCLIErrorPayload(code: "INVALID_MESSAGE")

        XCTAssertEqual(payload.errorCode, .invalidMessage)
    }

    func test_cliErrorPayload_errorCode_noAgent() throws {
        let payload = try decodeCLIErrorPayload(code: "NO_AGENT")

        XCTAssertEqual(payload.errorCode, .noAgent)
    }

    func test_cliErrorPayload_errorCode_agentNotFound() throws {
        let payload = try decodeCLIErrorPayload(code: "AGENT_NOT_FOUND")

        XCTAssertEqual(payload.errorCode, .agentNotFound)
    }

    func test_cliErrorPayload_errorCode_agentBusy() throws {
        let payload = try decodeCLIErrorPayload(code: "AGENT_BUSY")

        XCTAssertEqual(payload.errorCode, .agentBusy)
    }

    func test_cliErrorPayload_errorCode_sessionNotFound() throws {
        let payload = try decodeCLIErrorPayload(code: "SESSION_NOT_FOUND")

        XCTAssertEqual(payload.errorCode, .sessionNotFound)
    }

    func test_cliErrorPayload_errorCode_sessionInvalid() throws {
        let payload = try decodeCLIErrorPayload(code: "SESSION_INVALID")

        XCTAssertEqual(payload.errorCode, .sessionInvalid)
    }

    func test_cliErrorPayload_errorCode_projectNotFound() throws {
        let payload = try decodeCLIErrorPayload(code: "PROJECT_NOT_FOUND")

        XCTAssertEqual(payload.errorCode, .projectNotFound)
    }

    func test_cliErrorPayload_errorCode_queueFull() throws {
        let payload = try decodeCLIErrorPayload(code: "QUEUE_FULL")

        XCTAssertEqual(payload.errorCode, .queueFull)
    }

    func test_cliErrorPayload_errorCode_rateLimited() throws {
        let payload = try decodeCLIErrorPayload(code: "RATE_LIMITED")

        XCTAssertEqual(payload.errorCode, .rateLimited)
    }

    func test_cliErrorPayload_errorCode_connectionReplaced() throws {
        let payload = try decodeCLIErrorPayload(code: "CONNECTION_REPLACED")

        XCTAssertEqual(payload.errorCode, .connectionReplaced)
    }

    func test_cliErrorPayload_errorCode_permissionDenied() throws {
        let payload = try decodeCLIErrorPayload(code: "PERMISSION_DENIED")

        XCTAssertEqual(payload.errorCode, .permissionDenied)
    }

    func test_cliErrorPayload_errorCode_maxAgentsReached() throws {
        let payload = try decodeCLIErrorPayload(code: "MAX_AGENTS_REACHED")

        XCTAssertEqual(payload.errorCode, .maxAgentsReached)
    }

    func test_cliErrorPayload_errorCode_agentError() throws {
        let payload = try decodeCLIErrorPayload(code: "AGENT_ERROR")

        XCTAssertEqual(payload.errorCode, .agentError)
    }

    func test_cliErrorPayload_errorCode_unknown_returnsNil() throws {
        let payload = try decodeCLIErrorPayload(code: "MYSTERY")

        XCTAssertNil(payload.errorCode)
    }

    // MARK: - ConnectionError

    func test_connectionError_errorDescription_cases() {
        let cases: [(ConnectionError, String)] = [
            (.serverAtCapacity, "Server is at capacity. Please try again later."),
            (.agentTimedOut, "Session timed out due to inactivity."),
            (.connectionReplaced, "Session opened on another device."),
            (.queueFull, "Input queue is full. Please wait."),
            (.rateLimited(retryAfter: 30), "Rate limited. Retry in 30 seconds."),
            (.reconnectFailed, "Failed to reconnect after multiple attempts."),
            (.networkUnavailable, "No network connection available."),
            (.invalidServerURL, "Invalid server URL."),
            (.sessionNotFound, "Session not found."),
            (.sessionInvalid, "Session is corrupted and cannot be restored."),
            (.serverError(code: "ERR", message: "Failure", recoverable: false), "Failure")
        ]

        for (error, expected) in cases {
            XCTAssertEqual(error.errorDescription, expected)
        }
    }

    func test_connectionError_isRetryable_cases() {
        let cases: [(ConnectionError, Bool)] = [
            (.serverAtCapacity, true),
            (.agentTimedOut, false),
            (.connectionReplaced, false),
            (.queueFull, false),
            (.rateLimited(retryAfter: 10), true),
            (.reconnectFailed, false),
            (.networkUnavailable, true),
            (.invalidServerURL, false),
            (.sessionNotFound, false),
            (.sessionInvalid, false),
            (.serverError(code: "ERR", message: "Failure", recoverable: true), true),
            (.serverError(code: "ERR", message: "Failure", recoverable: false), false)
        ]

        for (error, expected) in cases {
            XCTAssertEqual(error.isRetryable, expected)
        }
    }

    func test_connectionError_requiresUserAction_cases() {
        let cases: [(ConnectionError, Bool)] = [
            (.serverAtCapacity, false),
            (.connectionReplaced, true),
            (.sessionNotFound, true),
            (.sessionInvalid, true),
            (.rateLimited(retryAfter: 5), false)
        ]

        for (error, expected) in cases {
            XCTAssertEqual(error.requiresUserAction, expected)
        }
    }

    func test_connectionError_equatable_matchingCases() {
        XCTAssertEqual(ConnectionError.serverAtCapacity, ConnectionError.serverAtCapacity)
        XCTAssertEqual(ConnectionError.rateLimited(retryAfter: 3), ConnectionError.rateLimited(retryAfter: 3))
        XCTAssertEqual(
            ConnectionError.serverError(code: "ERR", message: "Failure", recoverable: true),
            ConnectionError.serverError(code: "ERR", message: "Failure", recoverable: true)
        )
    }

    func test_connectionError_equatable_differentCases() {
        XCTAssertNotEqual(ConnectionError.rateLimited(retryAfter: 3), ConnectionError.rateLimited(retryAfter: 4))
        XCTAssertNotEqual(ConnectionError.serverAtCapacity, ConnectionError.queueFull)
        XCTAssertNotEqual(
            ConnectionError.serverError(code: "ERR", message: "Failure", recoverable: true),
            ConnectionError.serverError(code: "ERR", message: "Other", recoverable: true)
        )
    }

    func test_connectionError_from_maxAgentsReached_mapsToServerAtCapacity() throws {
        let payload = try decodeCLIErrorPayload(code: "MAX_AGENTS_REACHED")

        XCTAssertEqual(ConnectionError.from(payload), .serverAtCapacity)
    }

    func test_connectionError_from_agentNotFound_mapsToAgentTimedOut() throws {
        let payload = try decodeCLIErrorPayload(code: "AGENT_NOT_FOUND")

        XCTAssertEqual(ConnectionError.from(payload), .agentTimedOut)
    }

    func test_connectionError_from_connectionReplaced_mapsToConnectionReplaced() throws {
        let payload = try decodeCLIErrorPayload(code: "CONNECTION_REPLACED")

        XCTAssertEqual(ConnectionError.from(payload), .connectionReplaced)
    }

    func test_connectionError_from_queueFull_mapsToQueueFull() throws {
        let payload = try decodeCLIErrorPayload(code: "QUEUE_FULL")

        XCTAssertEqual(ConnectionError.from(payload), .queueFull)
    }

    func test_connectionError_from_rateLimited_usesRetryAfter_and_defaults() throws {
        let payloadWithRetry = try decodeCLIErrorPayload(code: "RATE_LIMITED", retryAfter: 45)
        XCTAssertEqual(ConnectionError.from(payloadWithRetry), .rateLimited(retryAfter: 45))

        let payloadWithoutRetry = try decodeCLIErrorPayload(code: "RATE_LIMITED")
        XCTAssertEqual(ConnectionError.from(payloadWithoutRetry), .rateLimited(retryAfter: 60))
    }

    func test_connectionError_from_sessionNotFound_mapsToSessionNotFound() throws {
        let payload = try decodeCLIErrorPayload(code: "SESSION_NOT_FOUND")

        XCTAssertEqual(ConnectionError.from(payload), .sessionNotFound)
    }

    func test_connectionError_from_sessionInvalid_mapsToSessionInvalid() throws {
        let payload = try decodeCLIErrorPayload(code: "SESSION_INVALID")

        XCTAssertEqual(ConnectionError.from(payload), .sessionInvalid)
    }

    func test_connectionError_from_unknownCode_mapsToServerError() throws {
        let payload = try decodeCLIErrorPayload(code: "PERMISSION_DENIED", message: "Denied", recoverable: false)
        let error = ConnectionError.from(payload)

        XCTAssertEqual(error, .serverError(code: "PERMISSION_DENIED", message: "Denied", recoverable: false))
    }

    // MARK: - CLIAgentState

    func test_cliAgentState_displayText() {
        XCTAssertEqual(CLIAgentState.starting.displayText, "Starting...")
        XCTAssertEqual(CLIAgentState.thinking.displayText, "Thinking...")
        XCTAssertEqual(CLIAgentState.executing.displayText, "Running tool...")
        XCTAssertEqual(CLIAgentState.waitingInput.displayText, "Waiting for input...")
        XCTAssertEqual(CLIAgentState.waitingPermission.displayText, "Waiting for approval...")
        XCTAssertEqual(CLIAgentState.idle.displayText, "Ready")
        XCTAssertEqual(CLIAgentState.recovering.displayText, "Recovering...")
        XCTAssertEqual(CLIAgentState.stopped.displayText, "Stopped")
    }

    func test_cliAgentState_isProcessing() {
        XCTAssertTrue(CLIAgentState.thinking.isProcessing)
        XCTAssertTrue(CLIAgentState.executing.isProcessing)
        XCTAssertFalse(CLIAgentState.idle.isProcessing)
    }

    func test_cliAgentState_isConnecting() {
        XCTAssertTrue(CLIAgentState.starting.isConnecting)
        XCTAssertFalse(CLIAgentState.thinking.isConnecting)
    }

    func test_cliAgentState_isWaiting() {
        XCTAssertTrue(CLIAgentState.waitingInput.isWaiting)
        XCTAssertTrue(CLIAgentState.waitingPermission.isWaiting)
        XCTAssertFalse(CLIAgentState.executing.isWaiting)
    }

    func test_cliAgentState_canSendInput() {
        XCTAssertTrue(CLIAgentState.idle.canSendInput)
        XCTAssertTrue(CLIAgentState.thinking.canSendInput)
        XCTAssertTrue(CLIAgentState.executing.canSendInput)
        XCTAssertFalse(CLIAgentState.waitingInput.canSendInput)
    }

    func test_cliAgentState_isActive() {
        XCTAssertFalse(CLIAgentState.stopped.isActive)
        XCTAssertTrue(CLIAgentState.idle.isActive)
    }

    // MARK: - Helpers

    private func decodeAnyCodableValue(_ json: String) throws -> AnyCodableValue {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(AnyCodableValue.self, from: data)
    }

    private func encodeAnyCodableValueToObject(_ value: AnyCodableValue) throws -> Any {
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data, options: [])
    }

    private func encodeClientMessage(_ message: CLIClientMessage) throws -> [String: Any] {
        let data = try JSONEncoder().encode(message)
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        return object as? [String: Any] ?? [:]
    }

    private func decodeServerMessage(from object: [String: Any]) throws -> CLIServerMessage {
        let data = try JSONSerialization.data(withJSONObject: object, options: [])
        return try JSONDecoder().decode(CLIServerMessage.self, from: data)
    }

    private func decodeCLIErrorPayload(
        code: String,
        message: String = "Error",
        recoverable: Bool = false,
        retryAfter: Int? = nil
    ) throws -> CLIErrorPayload {
        var object: [String: Any] = [
            "code": code,
            "message": message,
            "recoverable": recoverable
        ]
        if let retryAfter {
            object["retryAfter"] = retryAfter
        }
        let data = try JSONSerialization.data(withJSONObject: object, options: [])
        return try JSONDecoder().decode(CLIErrorPayload.self, from: data)
    }
}
