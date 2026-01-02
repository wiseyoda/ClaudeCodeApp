import XCTest
@testable import CodingBridge

final class CLIBridgeTypesTests: XCTestCase {

    // MARK: - ConnectionState

    func test_connectionState_isConnected() {
        XCTAssertTrue(CLIConnectionState.connected(agentId: "agent-1").isConnected)
        XCTAssertFalse(CLIConnectionState.disconnected.isConnected)
        XCTAssertFalse(CLIConnectionState.connecting.isConnected)
        XCTAssertFalse(CLIConnectionState.reconnecting(attempt: 1).isConnected)
    }

    func test_connectionState_isConnecting() {
        XCTAssertTrue(CLIConnectionState.connecting.isConnecting)
        XCTAssertFalse(CLIConnectionState.connected(agentId: "agent-1").isConnecting)
        XCTAssertFalse(CLIConnectionState.disconnected.isConnecting)
        // Note: reconnecting is also considered "connecting"
        XCTAssertTrue(CLIConnectionState.reconnecting(attempt: 3).isConnecting)
    }

    func test_connectionState_displayText() {
        XCTAssertEqual(CLIConnectionState.disconnected.displayText, "Disconnected")
        XCTAssertEqual(CLIConnectionState.connecting.displayText, "Connecting...")
        XCTAssertEqual(CLIConnectionState.connected(agentId: "agent-1").displayText, "Connected")
        XCTAssertEqual(CLIConnectionState.reconnecting(attempt: 2).displayText, "Reconnecting (2)...")
    }

    func test_connectionState_accessibilityLabel() {
        XCTAssertEqual(CLIConnectionState.disconnected.accessibilityLabel, "Disconnected from server")
        XCTAssertEqual(CLIConnectionState.connecting.accessibilityLabel, "Connecting to server")
        XCTAssertEqual(CLIConnectionState.connected(agentId: "agent-1").accessibilityLabel, "Connected to server")
        XCTAssertEqual(
            CLIConnectionState.reconnecting(attempt: 5).accessibilityLabel,
            "Reconnecting, attempt 5"
        )
    }

    func test_connectionState_equatable() {
        XCTAssertEqual(CLIConnectionState.reconnecting(attempt: 1), CLIConnectionState.reconnecting(attempt: 1))
        XCTAssertNotEqual(CLIConnectionState.reconnecting(attempt: 1), CLIConnectionState.reconnecting(attempt: 2))
        XCTAssertNotEqual(CLIConnectionState.connected(agentId: "agent-1"), CLIConnectionState.disconnected)
    }

    func test_connectionState_agentId() {
        XCTAssertEqual(CLIConnectionState.connected(agentId: "agent-123").agentId, "agent-123")
        XCTAssertNil(CLIConnectionState.disconnected.agentId)
        XCTAssertNil(CLIConnectionState.connecting.agentId)
        XCTAssertNil(CLIConnectionState.reconnecting(attempt: 1).agentId)
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
        XCTAssertEqual(boolValue.value as? Bool, true)

        let intValue = try decodeAnyCodableValue("42")
        XCTAssertEqual(intValue.value as? Int, 42)

        let doubleValue = try decodeAnyCodableValue("3.5")
        XCTAssertEqual(doubleValue.value as? Double, 3.5)

        let stringValue = try decodeAnyCodableValue("\"hello\"")
        XCTAssertEqual(stringValue.value as? String, "hello")
    }

    func test_anyCodableValue_decodesCollections() throws {
        let arrayValue = try decodeAnyCodableValue("[1,\"two\",false]")
        guard let array = arrayValue.value as? [Any] else {
            XCTFail("Expected array value")
            return
        }
        XCTAssertEqual(array.count, 3)
        XCTAssertEqual(array[0] as? Int, 1)
        XCTAssertEqual(array[1] as? String, "two")
        XCTAssertEqual(array[2] as? Bool, false)

        let dictValue = try decodeAnyCodableValue("{\"a\":1,\"b\":\"two\"}")
        guard let dict = dictValue.value as? [String: Any] else {
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
        XCTAssertEqual((dictValue.value as? [String: Any])?["a"] as? Int, 1)

        let arrayValue = try decodeAnyCodableValue("[1]")
        XCTAssertEqual((arrayValue.value as? [Any])?.first as? Int, 1)

        let intValue = try decodeAnyCodableValue("7")
        XCTAssertEqual(intValue.value as? Int, 7)

        let boolValue = try decodeAnyCodableValue("false")
        XCTAssertEqual(boolValue.value as? Bool, false)
    }

    // MARK: - ClientMessage encoding

    func test_cliClientMessage_encodesStart() throws {
        let sessionId = "00000000-0000-0000-0000-000000000001"
        let payload = StartMessage(projectPath: "/tmp/project", sessionId: sessionId, model: "claude", helper: true)
        let json = try encodeClientMessage(.start(payload))

        XCTAssertEqual(json["type"] as? String, "start")
        XCTAssertEqual(json["projectPath"] as? String, "/tmp/project")
        XCTAssertEqual(json["sessionId"] as? String, sessionId)
        XCTAssertEqual(json["model"] as? String, "claude")
        XCTAssertEqual(json["helper"] as? Bool, true)
    }

    func test_cliClientMessage_encodesInput() throws {
        let images = [
            CLIImageAttachment(base64Data: "ZGF0YQ==", mimeType: "image/png"),
            CLIImageAttachment(referenceId: "img-1")
        ]
        let payload = InputMessage(
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
        let payload = PermissionResponseMessage(id: "perm-1", choice: .allow)
        let json = try encodeClientMessage(.permissionResponse(payload))

        XCTAssertEqual(json["type"] as? String, "permission_response")
        XCTAssertEqual(json["id"] as? String, "perm-1")
        XCTAssertEqual(json["choice"] as? String, "allow")
    }

    func test_cliClientMessage_encodesQuestionResponse() throws {
        let answers: [String: QuestionResponseMessageAnswersValue] = [
            "choice": QuestionResponseMessageAnswersValue("yes"),
            "count": QuestionResponseMessageAnswersValue(2)
        ]
        let payload = QuestionResponseMessage(id: "question-1", answers: answers)
        let json = try encodeClientMessage(.questionResponse(payload))

        XCTAssertEqual(json["type"] as? String, "question_response")
        XCTAssertEqual(json["id"] as? String, "question-1")

        guard let answersObject = json["answers"] as? [String: Any] else {
            XCTFail("Expected answers object")
            return
        }
        XCTAssertNotNil(answersObject["choice"])
        XCTAssertNotNil(answersObject["count"])
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
        let payload = SubscribeSessionsMessage(projectPath: "/tmp/project")
        let json = try encodeClientMessage(.subscribeSessions(payload))

        XCTAssertEqual(json["type"] as? String, "subscribe_sessions")
        XCTAssertEqual(json["projectPath"] as? String, "/tmp/project")
    }

    func test_cliClientMessage_encodesSetModel() throws {
        let payload = SetModelMessage(model: "claude-3")
        let json = try encodeClientMessage(.setModel(payload))

        XCTAssertEqual(json["type"] as? String, "set_model")
        XCTAssertEqual(json["model"] as? String, "claude-3")
    }

    func test_cliClientMessage_encodesSetPermissionMode() throws {
        let payload = SetPermissionModeMessage(mode: .bypasspermissions)
        let json = try encodeClientMessage(.setPermissionMode(payload))

        XCTAssertEqual(json["type"] as? String, "set_permission_mode")
        XCTAssertEqual(json["mode"] as? String, "bypassPermissions")
    }

    func test_cliClientMessage_encodesCancelQueued() throws {
        let json = try encodeClientMessage(.cancelQueued)

        XCTAssertEqual(json["type"] as? String, "cancel_queued")
    }

    func test_cliClientMessage_encodesRetry() throws {
        let payload = RetryMessage(messageId: "msg-2")
        let json = try encodeClientMessage(.retry(payload))

        XCTAssertEqual(json["type"] as? String, "retry")
        XCTAssertEqual(json["messageId"] as? String, "msg-2")
    }

    func test_cliClientMessage_encodesPing() throws {
        let json = try encodeClientMessage(.ping)

        XCTAssertEqual(json["type"] as? String, "ping")
    }

    // MARK: - ServerMessage decoding

    func test_cliServerMessage_decodesConnected() throws {
        let sessionId = "00000000-0000-0000-0000-000000000002"
        let message = try decodeServerMessage(from: [
            "type": "connected",
            "agentId": "agent-1",
            "sessionId": sessionId,
            "model": "claude-3",
            "version": "1.0.0",
            "protocolVersion": "1.0"
        ])

        guard case .typeConnectedMessage(let payload) = message else {
            XCTFail("Expected connected message")
            return
        }
        XCTAssertEqual(payload.agentId, "agent-1")
        XCTAssertEqual(payload.sessionIdString, sessionId)
        XCTAssertEqual(payload.model, "claude-3")
        XCTAssertEqual(payload.version, "1.0.0")
        XCTAssertEqual(payload.protocolVersionString, "1.0")
    }

    func test_cliServerMessage_decodesStream() throws {
        // Stream messages now include id and timestamp (unified format v0.3.5+)
        let testUUID = UUID()
        let message = try decodeServerMessage(from: [
            "type": "stream",
            "id": testUUID.uuidString,
            "timestamp": "2024-01-01T12:00:00.000Z",
            "message": [
                "type": "assistant",
                "content": "Hello",
                "delta": true
            ]
        ])

        guard case .typeStreamServerMessage(let payload) = message else {
            XCTFail("Expected stream message")
            return
        }
        XCTAssertEqual(payload.id, testUUID)
        XCTAssertNotNil(payload.timestamp)
        switch payload.message {
        case .typeAssistantStreamMessage(let content):
            XCTAssertEqual(content.content, "Hello")
            XCTAssertEqual(content.delta, true)
            XCTAssertFalse(content.isFinal)
        default:
            XCTFail("Expected assistant content")
        }
    }

    func test_cliStreamMessage_toStoredMessage() throws {
        // Test conversion from stream message to stored message format
        let testUUID = UUID()
        let streamMessage = try decodeServerMessage(from: [
            "type": "stream",
            "id": testUUID.uuidString,
            "timestamp": "2024-06-15T10:30:00.000Z",
            "message": [
                "type": "user",
                "content": "Hello Claude"
            ]
        ])

        guard case .typeStreamServerMessage(let payload) = streamMessage else {
            XCTFail("Expected stream message")
            return
        }

        let stored = payload.toStoredMessage()
        XCTAssertEqual(stored.id, testUUID)
        XCTAssertNotNil(stored.timestamp)

        // Verify the message content is preserved
        if case .typeUserStreamMessage(let content) = stored.message {
            XCTAssertEqual(content.content, "Hello Claude")
        } else {
            XCTFail("Expected user content")
        }
    }

    func test_storedMessage_toCLIStoredMessage_preservesId() throws {
        let testUUID = UUID()
        let streamMessage = try decodeServerMessage(from: [
            "type": "stream",
            "id": testUUID.uuidString,
            "timestamp": "2024-06-15T10:30:00.000Z",
            "message": [
                "type": "user",
                "content": "Test user message"
            ]
        ])

        guard case .typeStreamServerMessage(let payload) = streamMessage else {
            XCTFail("Expected stream message")
            return
        }

        let stored = payload.toStoredMessage()
        XCTAssertEqual(stored.id, testUUID)
        XCTAssertEqual(stored.idString, testUUID.uuidString)
    }

    func test_storedMessage_toCLIStoredMessage_preservesContent() throws {
        let testUUID = UUID()
        let streamMessage = try decodeServerMessage(from: [
            "type": "stream",
            "id": testUUID.uuidString,
            "timestamp": "2024-06-15T10:30:00.000Z",
            "message": [
                "type": "user",
                "content": "Test user message"
            ]
        ])

        guard case .typeStreamServerMessage(let payload) = streamMessage else {
            XCTFail("Expected stream message")
            return
        }

        let stored = payload.toStoredMessage()
        if case .typeUserStreamMessage(let content) = stored.message {
            XCTAssertEqual(content.content, "Test user message")
        } else {
            XCTFail("Expected user message content")
        }
    }

    func test_storedMessage_toCLIStoredMessage_assistantDelta() throws {
        let testUUID = UUID()
        let streamMessage = try decodeServerMessage(from: [
            "type": "stream",
            "id": testUUID.uuidString,
            "timestamp": "2024-06-15T10:31:00.000Z",
            "message": [
                "type": "assistant",
                "content": "Streaming...",
                "delta": true
            ]
        ])

        guard case .typeStreamServerMessage(let payload) = streamMessage else {
            XCTFail("Expected stream message")
            return
        }

        let stored = payload.toStoredMessage()
        if case .typeAssistantStreamMessage(let content) = stored.message {
            XCTAssertEqual(content.content, "Streaming...")
            XCTAssertEqual(content.delta, true)
        } else {
            XCTFail("Expected assistant message content")
        }
    }

    func test_storedMessage_toCLIStoredMessage_progressMessage() throws {
        let testUUID = UUID()
        let progressMessage = try decodeServerMessage(from: [
            "type": "stream",
            "id": testUUID.uuidString,
            "timestamp": "2024-06-15T10:32:00.000Z",
            "message": [
                "type": "progress",
                "id": "tool-1",
                "tool": "Bash",
                "elapsed": 5.0
            ]
        ])

        guard case .typeStreamServerMessage(let payload) = progressMessage else {
            XCTFail("Expected stream message")
            return
        }

        let stored = payload.toStoredMessage()
        if case .typeProgressStreamMessage(let content) = stored.message {
            XCTAssertEqual(content.tool, "Bash")
            XCTAssertEqual(content.elapsed, 5.0)
        } else {
            XCTFail("Expected progress message content")
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

        guard case .typePermissionRequestMessage(let payload) = message else {
            XCTFail("Expected permission message")
            return
        }
        XCTAssertEqual(payload.id, "perm-1")
        XCTAssertEqual(payload.tool, "Bash")
        XCTAssertEqual(payload.options, [.allow, .deny, .always])
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

        guard case .typeQuestionMessage(let payload) = message else {
            XCTFail("Expected question message")
            return
        }
        XCTAssertEqual(payload.id, "question-1")
        XCTAssertEqual(payload.questions.first?.question, "Pick one")
        XCTAssertEqual(payload.questions.first?.options.count, 2)
        XCTAssertEqual(payload.questions.first?.multiSelect, false)
    }

    func test_cliServerMessage_decodesSessionEvent() throws {
        let testUUID = UUID()
        let message = try decodeServerMessage(from: [
            "type": "session_event",
            "action": "created",
            "projectPath": "/tmp/project",
            "sessionId": testUUID.uuidString
        ])

        guard case .typeSessionEventMessage(let payload) = message else {
            XCTFail("Expected session_event message")
            return
        }
        XCTAssertEqual(payload.action, .created)
        XCTAssertEqual(payload.projectPath, "/tmp/project")
        XCTAssertEqual(payload.sessionId, testUUID)
    }

    func test_cliServerMessage_decodesHistory() throws {
        // History uses StreamMessage array format
        let message = try decodeServerMessage(from: [
            "type": "history",
            "messages": [
                [
                    "type": "user",
                    "content": "Hi"
                ]
            ],
            "hasMore": true,
            "cursor": "cursor-1"
        ])

        guard case .typeHistoryMessage(let payload) = message else {
            XCTFail("Expected history message")
            return
        }
        XCTAssertEqual(payload.messages.count, 1)
        if case .typeUserStreamMessage(let content) = payload.messages.first {
            XCTAssertEqual(content.content, "Hi")
        } else {
            XCTFail("Expected user message")
        }
        XCTAssertEqual(payload.hasMore, true)
        XCTAssertEqual(payload.cursor, "cursor-1")
    }

    func test_cliServerMessage_decodesModelChanged() throws {
        let message = try decodeServerMessage(from: [
            "type": "model_changed",
            "model": "claude-3",
            "previousModel": "claude-2"
        ])

        guard case .typeModelChangedMessage(let payload) = message else {
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

        guard case .typePermissionModeChangedMessage(let payload) = message else {
            XCTFail("Expected permission_mode_changed message")
            return
        }
        XCTAssertEqual(payload.mode, .acceptedits)
    }

    func test_cliServerMessage_decodesQueued() throws {
        let message = try decodeServerMessage(from: [
            "type": "queued",
            "position": 2
        ])

        guard case .typeQueuedMessage(let payload) = message else {
            XCTFail("Expected queued message")
            return
        }
        XCTAssertEqual(payload.position, 2)
    }

    func test_cliServerMessage_decodesQueueCleared() throws {
        let message = try decodeServerMessage(from: [
            "type": "queue_cleared"
        ])

        guard case .typeQueueClearedMessage = message else {
            XCTFail("Expected queue_cleared message")
            return
        }
    }

    func test_cliServerMessage_decodesError() throws {
        let message = try decodeServerMessage(from: [
            "type": "error",
            "code": "rate_limited",
            "message": "Slow down",
            "recoverable": true,
            "retryable": true,
            "retryAfter": 30.0
        ])

        guard case .typeErrorMessage(let payload) = message else {
            XCTFail("Expected error message")
            return
        }
        XCTAssertEqual(payload.code, "rate_limited")
        XCTAssertEqual(payload.message, "Slow down")
        XCTAssertEqual(payload.recoverable, true)
        XCTAssertEqual(payload.retryAfter, 30.0)
    }

    func test_cliServerMessage_decodesPong() throws {
        let message = try decodeServerMessage(from: [
            "type": "pong",
            "serverTime": 123.0
        ])

        guard case .typePongMessage(let payload) = message else {
            XCTFail("Expected pong message")
            return
        }
        XCTAssertEqual(payload.serverTime, 123.0)
    }

    func test_cliServerMessage_decodesStopped() throws {
        let message = try decodeServerMessage(from: [
            "type": "stopped",
            "reason": "user"
        ])

        guard case .typeStoppedMessage(let payload) = message else {
            XCTFail("Expected stopped message")
            return
        }
        XCTAssertEqual(payload.reason, .user)
    }

    func test_cliServerMessage_decodesInterrupted() throws {
        let message = try decodeServerMessage(from: [
            "type": "interrupted"
        ])

        guard case .typeInterruptedMessage = message else {
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

    // MARK: - WsErrorMessage
    // Note: errorCode uses snake_case values

    func test_cliErrorPayload_errorCode_agentNotFound() throws {
        let payload = try decodeCLIErrorPayload(code: "agent_not_found")

        XCTAssertEqual(payload.errorCode, .agentNotFound)
    }

    func test_cliErrorPayload_errorCode_sessionNotFound() throws {
        let payload = try decodeCLIErrorPayload(code: "session_not_found")

        XCTAssertEqual(payload.errorCode, .sessionNotFound)
    }

    func test_cliErrorPayload_errorCode_sessionInvalid() throws {
        let payload = try decodeCLIErrorPayload(code: "session_invalid")

        XCTAssertEqual(payload.errorCode, .sessionInvalid)
    }

    func test_cliErrorPayload_errorCode_sessionExpired() throws {
        let payload = try decodeCLIErrorPayload(code: "session_expired")

        XCTAssertEqual(payload.errorCode, .sessionExpired)
    }

    func test_cliErrorPayload_errorCode_queueFull() throws {
        let payload = try decodeCLIErrorPayload(code: "queue_full")

        XCTAssertEqual(payload.errorCode, .queueFull)
    }

    func test_cliErrorPayload_errorCode_rateLimited() throws {
        let payload = try decodeCLIErrorPayload(code: "rate_limited")

        XCTAssertEqual(payload.errorCode, .rateLimited)
    }

    func test_cliErrorPayload_errorCode_connectionReplaced() throws {
        let payload = try decodeCLIErrorPayload(code: "connection_replaced")

        XCTAssertEqual(payload.errorCode, .connectionReplaced)
    }

    func test_cliErrorPayload_errorCode_maxAgentsReached() throws {
        let payload = try decodeCLIErrorPayload(code: "max_agents_reached")

        XCTAssertEqual(payload.errorCode, .maxAgentsReached)
    }

    func test_cliErrorPayload_errorCode_authenticationFailed() throws {
        let payload = try decodeCLIErrorPayload(code: "authentication_failed")

        XCTAssertEqual(payload.errorCode, .authenticationFailed)
    }

    func test_cliErrorPayload_errorCode_cursorEvicted() throws {
        let payload = try decodeCLIErrorPayload(code: "cursor_evicted")

        XCTAssertEqual(payload.errorCode, .cursorEvicted)
    }

    func test_cliErrorPayload_errorCode_cursorInvalid() throws {
        let payload = try decodeCLIErrorPayload(code: "cursor_invalid")

        XCTAssertEqual(payload.errorCode, .cursorInvalid)
    }

    func test_cliErrorPayload_errorCode_unknown_returnsNil() throws {
        let payload = try decodeCLIErrorPayload(code: "MYSTERY")

        XCTAssertNil(payload.errorCode)
    }

    // MARK: - ConnectionError

    func test_connectionError_errorDescription_cases() {
        XCTAssertEqual(ConnectionError.serverAtCapacity.errorDescription, "Server is at capacity")
        XCTAssertEqual(ConnectionError.agentTimedOut.errorDescription, "Agent timed out")
        XCTAssertEqual(ConnectionError.connectionReplaced.errorDescription, "Connection replaced by another client")
        XCTAssertEqual(ConnectionError.queueFull.errorDescription, "Request queue is full")
        XCTAssertEqual(ConnectionError.rateLimited(30).errorDescription, "Rate limited, retry in 30 seconds")
        XCTAssertEqual(ConnectionError.reconnectFailed.errorDescription, "Failed to reconnect to session")
        XCTAssertEqual(ConnectionError.networkUnavailable.errorDescription, "Network is unavailable")
        XCTAssertEqual(ConnectionError.invalidServerURL.errorDescription, "Invalid server URL")
        XCTAssertEqual(ConnectionError.sessionNotFound.errorDescription, "Session not found")
        XCTAssertEqual(ConnectionError.sessionInvalid.errorDescription, "Session is invalid")
        XCTAssertEqual(ConnectionError.serverError(500, "Failure", nil).errorDescription, "Failure")
        XCTAssertEqual(ConnectionError.authenticationFailed.errorDescription, "Authentication failed")
        XCTAssertEqual(ConnectionError.sessionExpired.errorDescription, "Session expired")
        XCTAssertEqual(ConnectionError.connectionFailed("timeout").errorDescription, "Connection failed: timeout")
        XCTAssertEqual(ConnectionError.protocolError("invalid").errorDescription, "Protocol error: invalid")
        XCTAssertEqual(ConnectionError.unknown("something").errorDescription, "something")
    }

    func test_connectionError_from_connectionReplaced_mapsToConnectionReplaced() throws {
        let payload = try decodeCLIErrorPayload(code: "connection_replaced")
        let error = ConnectionError.from(payload)

        guard case .connectionReplaced = error else {
            XCTFail("Expected connectionReplaced, got \(error)")
            return
        }
    }

    func test_connectionError_from_sessionNotFound_mapsToSessionNotFound() throws {
        let payload = try decodeCLIErrorPayload(code: "session_not_found")
        let error = ConnectionError.from(payload)

        guard case .sessionNotFound = error else {
            XCTFail("Expected sessionNotFound, got \(error)")
            return
        }
    }

    func test_connectionError_from_sessionExpired_mapsToSessionExpired() throws {
        let payload = try decodeCLIErrorPayload(code: "session_expired")
        let error = ConnectionError.from(payload)

        guard case .sessionExpired = error else {
            XCTFail("Expected sessionExpired, got \(error)")
            return
        }
    }

    func test_connectionError_from_sessionInvalid_mapsToSessionInvalid() throws {
        let payload = try decodeCLIErrorPayload(code: "session_invalid")
        let error = ConnectionError.from(payload)

        guard case .sessionInvalid = error else {
            XCTFail("Expected sessionInvalid, got \(error)")
            return
        }
    }

    func test_connectionError_from_cursorInvalid_mapsToSessionInvalid() throws {
        let payload = try decodeCLIErrorPayload(code: "cursor_invalid")
        let error = ConnectionError.from(payload)

        guard case .sessionInvalid = error else {
            XCTFail("Expected sessionInvalid, got \(error)")
            return
        }
    }

    func test_connectionError_from_authenticationFailed_mapsToAuthenticationFailed() throws {
        let payload = try decodeCLIErrorPayload(code: "authentication_failed")
        let error = ConnectionError.from(payload)

        guard case .authenticationFailed = error else {
            XCTFail("Expected authenticationFailed, got \(error)")
            return
        }
    }

    func test_connectionError_from_unknownCode_mapsToProtocolError() throws {
        let payload = try decodeCLIErrorPayload(code: "unknown_error", message: "Something went wrong")
        let error = ConnectionError.from(payload)

        if case .protocolError(let msg) = error {
            XCTAssertEqual(msg, "Something went wrong")
        } else {
            XCTFail("Expected protocolError")
        }
    }

    // MARK: - CLIAgentState

    func test_cliAgentState_isProcessing() {
        XCTAssertTrue(CLIAgentState.thinking.isProcessing)
        XCTAssertTrue(CLIAgentState.executing.isProcessing)
        XCTAssertFalse(CLIAgentState.idle.isProcessing)
        XCTAssertFalse(CLIAgentState.starting.isProcessing)
        XCTAssertFalse(CLIAgentState.stopped.isProcessing)
        XCTAssertFalse(CLIAgentState.waitingInput.isProcessing)
        XCTAssertFalse(CLIAgentState.waitingPermission.isProcessing)
        XCTAssertFalse(CLIAgentState.recovering.isProcessing)
    }

    func test_cliAgentState_isWorking() {
        XCTAssertTrue(CLIAgentState.thinking.isWorking)
        XCTAssertTrue(CLIAgentState.executing.isWorking)
        XCTAssertTrue(CLIAgentState.recovering.isWorking)
        XCTAssertFalse(CLIAgentState.idle.isWorking)
        XCTAssertFalse(CLIAgentState.starting.isWorking)
        XCTAssertFalse(CLIAgentState.stopped.isWorking)
        XCTAssertFalse(CLIAgentState.waitingInput.isWorking)
        XCTAssertFalse(CLIAgentState.waitingPermission.isWorking)
    }

    func test_cliAgentState_initFromProtocolState() {
        XCTAssertEqual(CLIAgentState(from: .thinking), .thinking)
        XCTAssertEqual(CLIAgentState(from: .executing), .executing)
        XCTAssertEqual(CLIAgentState(from: .waitingInput), .waitingInput)
        XCTAssertEqual(CLIAgentState(from: .waitingPermission), .waitingPermission)
        XCTAssertEqual(CLIAgentState(from: .idle), .idle)
        XCTAssertEqual(CLIAgentState(from: .recovering), .recovering)
    }

    // MARK: - Helpers

    private func decodeAnyCodableValue(_ json: String) throws -> AnyCodableValue {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(AnyCodableValue.self, from: data)
    }

    private func encodeAnyCodableValueToObject(_ value: AnyCodableValue) throws -> Any {
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
    }

    private func encodeClientMessage(_ message: ClientMessage) throws -> [String: Any] {
        let data = try JSONEncoder().encode(message)
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        return object as? [String: Any] ?? [:]
    }

    private func decodeServerMessage(from object: [String: Any]) throws -> ServerMessage {
        let data = try JSONSerialization.data(withJSONObject: object, options: [])
        return try JSONDecoder().decode(ServerMessage.self, from: data)
    }

    private func decodeCLIErrorPayload(
        code: String,
        message: String = "Error",
        recoverable: Bool = false,
        retryAfter: Double? = nil
    ) throws -> WsErrorMessage {
        var object: [String: Any] = [
            "type": "error",
            "code": code,
            "message": message,
            "recoverable": recoverable
        ]
        if let retryAfter {
            object["retryAfter"] = retryAfter
        }
        let data = try JSONSerialization.data(withJSONObject: object, options: [])
        return try JSONDecoder().decode(WsErrorMessage.self, from: data)
    }
}
