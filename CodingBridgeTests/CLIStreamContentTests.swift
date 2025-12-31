import XCTest
@testable import CodingBridge

final class CLIStreamContentTests: XCTestCase {
    private func decodeJSON<T: Decodable>(_ json: String, as type: T.Type = T.self) throws -> T {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func decodeStreamContent(_ json: String) throws -> CLIStreamContent {
        try decodeJSON(json, as: CLIStreamContent.self)
    }

    private func decodeStreamMessage(_ json: String) throws -> CLIStreamMessage {
        try decodeJSON(json, as: CLIStreamMessage.self)
    }

    // MARK: - Stream Message Wrapper

    func test_streamMessage_decodesAssistantPayload() throws {
        // v0.3.5+ format: CLIStreamMessage includes id and timestamp at top level
        let json = """
        {
          "id": "msg-123",
          "timestamp": "2025-01-01T12:00:00.000Z",
          "message": {
            "type": "assistant",
            "content": "Hello",
            "delta": false
          }
        }
        """

        let message = try decodeStreamMessage(json)

        XCTAssertEqual(message.id, "msg-123")
        XCTAssertEqual(message.timestamp, "2025-01-01T12:00:00.000Z")

        guard case let .assistant(payload) = message.message else {
            XCTFail("Expected assistant content")
            return
        }

        XCTAssertEqual(payload.content, "Hello")
        XCTAssertEqual(payload.delta, false)
        XCTAssertTrue(payload.isFinal)
    }

    func test_streamMessage_decodesPermissionPayload() throws {
        // v0.3.5+ format: CLIStreamMessage includes id and timestamp at top level
        let json = """
        {
          "id": "msg-456",
          "timestamp": "2025-01-01T12:00:01.000Z",
          "message": {
            "type": "permission",
            "id": "perm-1",
            "tool": "Bash",
            "input": { "command": "ls -la" },
            "options": ["allow", "deny", "always"]
          }
        }
        """

        let message = try decodeStreamMessage(json)

        XCTAssertEqual(message.id, "msg-456")
        XCTAssertEqual(message.timestamp, "2025-01-01T12:00:01.000Z")

        guard case let .permission(payload) = message.message else {
            XCTFail("Expected permission content")
            return
        }

        XCTAssertEqual(payload.id, "perm-1")
        XCTAssertEqual(payload.tool, "Bash")
        XCTAssertEqual(payload.input["command"]?.stringValue, "ls -la")
        XCTAssertEqual(payload.options, ["allow", "deny", "always"])
    }

    // MARK: - Stream Content Types

    func test_streamContent_decodesAssistantCase() throws {
        let json = """
        {
          "type": "assistant",
          "content": "Chunk",
          "delta": true
        }
        """

        let content = try decodeStreamContent(json)

        guard case let .assistant(payload) = content else {
            XCTFail("Expected assistant content")
            return
        }

        XCTAssertEqual(payload.content, "Chunk")
        XCTAssertEqual(payload.delta, true)
        XCTAssertFalse(payload.isFinal)
    }

    func test_streamContent_decodesAssistantCaseWithMissingDelta() throws {
        let json = """
        {
          "type": "assistant",
          "content": "Final"
        }
        """

        let content = try decodeStreamContent(json)

        guard case let .assistant(payload) = content else {
            XCTFail("Expected assistant content")
            return
        }

        XCTAssertEqual(payload.content, "Final")
        XCTAssertNil(payload.delta)
        XCTAssertTrue(payload.isFinal)
    }

    func test_streamContent_decodesUserCase() throws {
        let json = """
        {
          "type": "user",
          "content": "Hi"
        }
        """

        let content = try decodeStreamContent(json)

        guard case let .user(payload) = content else {
            XCTFail("Expected user content")
            return
        }

        XCTAssertEqual(payload.content, "Hi")
    }

    func test_streamContent_decodesSystemCase() throws {
        let json = """
        {
          "type": "system",
          "content": "System message"
        }
        """

        let content = try decodeStreamContent(json)

        guard case let .system(payload) = content else {
            XCTFail("Expected system content")
            return
        }

        XCTAssertEqual(payload.content, "System message")
        XCTAssertNil(payload.subtype)
    }

    func test_streamContent_decodesSystemCaseWithSubtype() throws {
        let json = """
        {
          "type": "system",
          "content": "Init message",
          "subtype": "init"
        }
        """

        let content = try decodeStreamContent(json)

        guard case let .system(payload) = content else {
            XCTFail("Expected system content")
            return
        }

        XCTAssertEqual(payload.content, "Init message")
        XCTAssertEqual(payload.subtype, "init")
    }

    func test_streamContent_decodesThinkingCase() throws {
        let json = """
        {
          "type": "thinking",
          "content": "Reasoning"
        }
        """

        let content = try decodeStreamContent(json)

        guard case let .thinking(payload) = content else {
            XCTFail("Expected thinking content")
            return
        }

        XCTAssertEqual(payload.content, "Reasoning")
    }

    func test_streamContent_decodesToolUseCase() throws {
        let json = """
        {
          "type": "tool_use",
          "id": "tool-1",
          "name": "Bash",
          "input": {
            "command": "ls",
            "cwd": "/tmp",
            "interactive": true,
            "count": 2,
            "options": ["-l", "-a"]
          }
        }
        """

        let content = try decodeStreamContent(json)

        guard case let .toolUse(payload) = content else {
            XCTFail("Expected tool_use content")
            return
        }

        XCTAssertEqual(payload.id, "tool-1")
        XCTAssertEqual(payload.name, "Bash")
        XCTAssertEqual(payload.input["command"]?.stringValue, "ls")
        XCTAssertEqual(payload.input["cwd"]?.stringValue, "/tmp")
        XCTAssertEqual(payload.input["interactive"]?.boolValue, true)
        XCTAssertEqual(payload.input["count"]?.intValue, 2)
        XCTAssertEqual(payload.input["options"]?.arrayValue as? [String], ["-l", "-a"])
    }

    func test_streamContent_decodesToolResultCase() throws {
        let json = """
        {
          "type": "tool_result",
          "id": "tool-1",
          "tool": "Bash",
          "output": "Done",
          "success": true
        }
        """

        let content = try decodeStreamContent(json)

        guard case let .toolResult(payload) = content else {
            XCTFail("Expected tool_result content")
            return
        }

        XCTAssertEqual(payload.id, "tool-1")
        XCTAssertEqual(payload.tool, "Bash")
        XCTAssertEqual(payload.output, "Done")
        XCTAssertEqual(payload.success, true)
        XCTAssertNil(payload.isError)
    }

    func test_streamContent_decodesToolResultCaseWithIsError() throws {
        let json = """
        {
          "type": "tool_result",
          "id": "tool-2",
          "tool": "Read",
          "output": "Missing file",
          "success": false,
          "isError": true
        }
        """

        let content = try decodeStreamContent(json)

        guard case let .toolResult(payload) = content else {
            XCTFail("Expected tool_result content")
            return
        }

        XCTAssertEqual(payload.id, "tool-2")
        XCTAssertEqual(payload.tool, "Read")
        XCTAssertEqual(payload.output, "Missing file")
        XCTAssertEqual(payload.success, false)
        XCTAssertEqual(payload.isError, true)
    }

    func test_streamContent_decodesProgressCase() throws {
        let json = """
        {
          "type": "progress",
          "id": "tool-3",
          "tool": "Bash",
          "elapsed": 12.5,
          "progress": 42,
          "detail": "Working"
        }
        """

        let content = try decodeStreamContent(json)

        guard case let .progress(payload) = content else {
            XCTFail("Expected progress content")
            return
        }

        XCTAssertEqual(payload.id, "tool-3")
        XCTAssertEqual(payload.tool, "Bash")
        XCTAssertEqual(payload.elapsed, 12.5, accuracy: 0.001)
        XCTAssertEqual(payload.progress, 42)
        XCTAssertEqual(payload.detail, "Working")
        XCTAssertEqual(payload.elapsedSeconds, 12)
    }

    func test_streamContent_decodesUsageCase() throws {
        let json = """
        {
          "type": "usage",
          "inputTokens": 10,
          "outputTokens": 5,
          "cacheReadTokens": 2,
          "cacheCreateTokens": 1,
          "totalCost": 0.02,
          "contextUsed": 1500,
          "contextLimit": 3000
        }
        """

        let content = try decodeStreamContent(json)

        guard case let .usage(payload) = content else {
            XCTFail("Expected usage content")
            return
        }

        XCTAssertEqual(payload.inputTokens, 10)
        XCTAssertEqual(payload.outputTokens, 5)
        XCTAssertEqual(payload.cacheReadTokens, 2)
        XCTAssertEqual(payload.cacheCreateTokens, 1)
        guard let totalCost = payload.totalCost else {
            XCTFail("Expected totalCost")
            return
        }
        XCTAssertEqual(totalCost, 0.02, accuracy: 0.0001)
        XCTAssertEqual(payload.contextUsed, 1500)
        XCTAssertEqual(payload.contextLimit, 3000)
        XCTAssertEqual(payload.totalTokens, 15)
        XCTAssertEqual(payload.contextPercentage, 50.0, accuracy: 0.001)
    }

    func test_streamContent_decodesStateCase() throws {
        let json = """
        {
          "type": "state",
          "state": "executing",
          "tool": "Bash"
        }
        """

        let content = try decodeStreamContent(json)

        guard case let .state(payload) = content else {
            XCTFail("Expected state content")
            return
        }

        XCTAssertEqual(payload.state, .executing)
        XCTAssertEqual(payload.tool, "Bash")
    }

    func test_streamContent_decodesSubagentStartCase() throws {
        let json = """
        {
          "type": "subagent_start",
          "id": "agent-1",
          "description": "Review code",
          "agentType": "code-reviewer"
        }
        """

        let content = try decodeStreamContent(json)

        guard case let .subagentStart(payload) = content else {
            XCTFail("Expected subagent_start content")
            return
        }

        XCTAssertEqual(payload.id, "agent-1")
        XCTAssertEqual(payload.description, "Review code")
        XCTAssertEqual(payload.agentType, "code-reviewer")
        XCTAssertEqual(payload.displayAgentType, "code-reviewer")
    }

    func test_streamContent_decodesSubagentCompleteCase() throws {
        let json = """
        {
          "type": "subagent_complete",
          "id": "agent-1",
          "summary": "All done"
        }
        """

        let content = try decodeStreamContent(json)

        guard case let .subagentComplete(payload) = content else {
            XCTFail("Expected subagent_complete content")
            return
        }

        XCTAssertEqual(payload.id, "agent-1")
        XCTAssertEqual(payload.summary, "All done")
        XCTAssertEqual(payload.displaySummary, "All done")
    }

    func test_streamContent_decodesQuestionCase() throws {
        let json = """
        {
          "type": "question",
          "id": "question-1",
          "questions": [
            {
              "question": "Pick one",
              "header": "Header",
              "options": [
                { "label": "A", "description": "Option A" },
                { "label": "B" }
              ],
              "multiSelect": false
            }
          ]
        }
        """

        let content = try decodeStreamContent(json)

        guard case let .question(payload) = content else {
            XCTFail("Expected question content")
            return
        }

        XCTAssertEqual(payload.id, "question-1")
        XCTAssertEqual(payload.questions.count, 1)
        XCTAssertEqual(payload.questions.first?.question, "Pick one")
        XCTAssertEqual(payload.questions.first?.header, "Header")
        XCTAssertEqual(payload.questions.first?.options.count, 2)
        XCTAssertEqual(payload.questions.first?.options.first?.label, "A")
        XCTAssertEqual(payload.questions.first?.options.first?.description, "Option A")
        XCTAssertEqual(payload.questions.first?.options.last?.label, "B")
        XCTAssertNil(payload.questions.first?.options.last?.description)
        XCTAssertEqual(payload.questions.first?.multiSelect, false)
    }

    func test_streamContent_decodesPermissionCase() throws {
        let json = """
        {
          "type": "permission",
          "id": "perm-2",
          "tool": "Read",
          "input": {
            "file_path": "/tmp/readme.md"
          },
          "options": ["allow", "deny"]
        }
        """

        let content = try decodeStreamContent(json)

        guard case let .permission(payload) = content else {
            XCTFail("Expected permission content")
            return
        }

        XCTAssertEqual(payload.id, "perm-2")
        XCTAssertEqual(payload.tool, "Read")
        XCTAssertEqual(payload.input["file_path"]?.stringValue, "/tmp/readme.md")
        XCTAssertEqual(payload.options, ["allow", "deny"])
    }

    func test_streamContent_throwsForUnknownType() throws {
        let json = """
        {
          "type": "unknown"
        }
        """

        XCTAssertThrowsError(try decodeStreamContent(json)) { error in
            guard case DecodingError.dataCorrupted = error else {
                XCTFail("Expected dataCorrupted error")
                return
            }
        }
    }

    // MARK: - Assistant Content

    func test_assistantContent_decodesContentAndDelta() throws {
        let json = """
        {
          "content": "Hello",
          "delta": true
        }
        """

        let content = try decodeJSON(json, as: CLIAssistantContent.self)

        XCTAssertEqual(content.content, "Hello")
        XCTAssertEqual(content.delta, true)
    }

    func test_assistantContent_isFinal_trueWhenDeltaMissing() throws {
        let json = """
        {
          "content": "Hello"
        }
        """

        let content = try decodeJSON(json, as: CLIAssistantContent.self)

        XCTAssertNil(content.delta)
        XCTAssertTrue(content.isFinal)
    }

    func test_assistantContent_isFinal_trueWhenDeltaFalse() throws {
        let json = """
        {
          "content": "Hello",
          "delta": false
        }
        """

        let content = try decodeJSON(json, as: CLIAssistantContent.self)

        XCTAssertEqual(content.delta, false)
        XCTAssertTrue(content.isFinal)
    }

    func test_assistantContent_isFinal_falseWhenDeltaTrue() throws {
        let json = """
        {
          "content": "Hello",
          "delta": true
        }
        """

        let content = try decodeJSON(json, as: CLIAssistantContent.self)

        XCTAssertEqual(content.delta, true)
        XCTAssertFalse(content.isFinal)
    }

    // MARK: - User Content

    func test_userContent_decodesContent() throws {
        let json = """
        {
          "content": "User message"
        }
        """

        let content = try decodeJSON(json, as: CLIUserContent.self)

        XCTAssertEqual(content.content, "User message")
    }

    // MARK: - System Content

    func test_systemContent_decodesContent() throws {
        let json = """
        {
          "content": "System notice"
        }
        """

        let content = try decodeJSON(json, as: CLISystemContent.self)

        XCTAssertEqual(content.content, "System notice")
        XCTAssertNil(content.subtype)
    }

    func test_systemContent_decodesSubtypeWhenPresent() throws {
        let json = """
        {
          "content": "Progress update",
          "subtype": "progress"
        }
        """

        let content = try decodeJSON(json, as: CLISystemContent.self)

        XCTAssertEqual(content.content, "Progress update")
        XCTAssertEqual(content.subtype, "progress")
    }

    // MARK: - Thinking Content

    func test_thinkingContent_decodesContent() throws {
        let json = """
        {
          "content": "Reasoning block"
        }
        """

        let content = try decodeJSON(json, as: CLIThinkingContent.self)

        XCTAssertEqual(content.content, "Reasoning block")
    }

    // MARK: - Tool Use Content

    func test_toolUseContent_decodesFields() throws {
        let json = """
        {
          "id": "tool-9",
          "name": "Read",
          "input": {
            "file_path": "/tmp/file.txt"
          }
        }
        """

        let content = try decodeJSON(json, as: CLIToolUseContent.self)

        XCTAssertEqual(content.id, "tool-9")
        XCTAssertEqual(content.name, "Read")
        XCTAssertEqual(content.input["file_path"]?.stringValue, "/tmp/file.txt")
    }

    func test_toolUseContent_decodesInputValues() throws {
        let json = """
        {
          "id": "tool-10",
          "name": "Bash",
          "input": {
            "command": "pwd",
            "count": 3,
            "dry_run": true,
            "args": ["-L", "-P"]
          }
        }
        """

        let content = try decodeJSON(json, as: CLIToolUseContent.self)

        XCTAssertEqual(content.input["command"]?.stringValue, "pwd")
        XCTAssertEqual(content.input["count"]?.intValue, 3)
        XCTAssertEqual(content.input["dry_run"]?.boolValue, true)
        XCTAssertEqual(content.input["args"]?.arrayValue as? [String], ["-L", "-P"])
    }

    func test_toolUseContent_decodesNestedInputDictionary() throws {
        let json = """
        {
          "id": "tool-11",
          "name": "Edit",
          "input": {
            "metadata": {
              "path": "/tmp/file.txt",
              "mode": "safe"
            }
          }
        }
        """

        let content = try decodeJSON(json, as: CLIToolUseContent.self)
        let metadata = content.input["metadata"]?.dictValue

        XCTAssertEqual(metadata?["path"] as? String, "/tmp/file.txt")
        XCTAssertEqual(metadata?["mode"] as? String, "safe")
    }

    // MARK: - Tool Result Content

    func test_toolResultContent_decodesFields() throws {
        let json = """
        {
          "id": "tool-12",
          "tool": "Bash",
          "output": "Done",
          "success": true
        }
        """

        let content = try decodeJSON(json, as: CLIToolResultContent.self)

        XCTAssertEqual(content.id, "tool-12")
        XCTAssertEqual(content.tool, "Bash")
        XCTAssertEqual(content.output, "Done")
        XCTAssertEqual(content.success, true)
    }

    func test_toolResultContent_decodesIsErrorWhenPresent() throws {
        let json = """
        {
          "id": "tool-13",
          "tool": "Write",
          "output": "Failed",
          "success": false,
          "isError": true
        }
        """

        let content = try decodeJSON(json, as: CLIToolResultContent.self)

        XCTAssertEqual(content.isError, true)
    }

    func test_toolResultContent_isErrorDefaultsToNil() throws {
        let json = """
        {
          "id": "tool-14",
          "tool": "Write",
          "output": "OK",
          "success": true
        }
        """

        let content = try decodeJSON(json, as: CLIToolResultContent.self)

        XCTAssertNil(content.isError)
    }

    // MARK: - Progress Content

    func test_progressContent_decodesFields() throws {
        let json = """
        {
          "id": "tool-15",
          "tool": "Read",
          "elapsed": 4.25,
          "progress": 80,
          "detail": "Almost done"
        }
        """

        let content = try decodeJSON(json, as: CLIProgressContent.self)

        XCTAssertEqual(content.id, "tool-15")
        XCTAssertEqual(content.tool, "Read")
        XCTAssertEqual(content.elapsed, 4.25, accuracy: 0.001)
        XCTAssertEqual(content.progress, 80)
        XCTAssertEqual(content.detail, "Almost done")
    }

    func test_progressContent_elapsedSeconds_truncatesDouble() throws {
        let json = """
        {
          "id": "tool-16",
          "tool": "Read",
          "elapsed": 9.9
        }
        """

        let content = try decodeJSON(json, as: CLIProgressContent.self)

        XCTAssertEqual(content.elapsedSeconds, 9)
    }

    func test_progressContent_optionalFields_defaultNil() throws {
        let json = """
        {
          "id": "tool-17",
          "tool": "Read",
          "elapsed": 0.2
        }
        """

        let content = try decodeJSON(json, as: CLIProgressContent.self)

        XCTAssertNil(content.progress)
        XCTAssertNil(content.detail)
    }

    // MARK: - Usage Content

    func test_usageContent_decodesFields() throws {
        let json = """
        {
          "inputTokens": 4,
          "outputTokens": 6,
          "cacheReadTokens": 1,
          "cacheCreateTokens": 2,
          "totalCost": 0.01,
          "contextUsed": 100,
          "contextLimit": 200
        }
        """

        let content = try decodeJSON(json, as: CLIUsageContent.self)

        XCTAssertEqual(content.inputTokens, 4)
        XCTAssertEqual(content.outputTokens, 6)
        XCTAssertEqual(content.cacheReadTokens, 1)
        XCTAssertEqual(content.cacheCreateTokens, 2)
        guard let totalCost = content.totalCost else {
            XCTFail("Expected totalCost")
            return
        }
        XCTAssertEqual(totalCost, 0.01, accuracy: 0.0001)
        XCTAssertEqual(content.contextUsed, 100)
        XCTAssertEqual(content.contextLimit, 200)
    }

    func test_usageContent_totalTokens_sumsInputAndOutput() throws {
        let json = """
        {
          "inputTokens": 7,
          "outputTokens": 9
        }
        """

        let content = try decodeJSON(json, as: CLIUsageContent.self)

        XCTAssertEqual(content.totalTokens, 16)
    }

    func test_usageContent_contextPercentage_calculatesWhenValuesPresent() throws {
        let json = """
        {
          "inputTokens": 1,
          "outputTokens": 1,
          "contextUsed": 250,
          "contextLimit": 500
        }
        """

        let content = try decodeJSON(json, as: CLIUsageContent.self)

        XCTAssertEqual(content.contextPercentage, 50.0, accuracy: 0.001)
    }

    func test_usageContent_contextPercentage_returnsZeroWhenMissingValues() throws {
        let json = """
        {
          "inputTokens": 1,
          "outputTokens": 1,
          "contextLimit": 500
        }
        """

        let content = try decodeJSON(json, as: CLIUsageContent.self)

        XCTAssertEqual(content.contextPercentage, 0)
    }

    func test_usageContent_contextPercentage_returnsZeroWhenLimitZero() throws {
        let json = """
        {
          "inputTokens": 1,
          "outputTokens": 1,
          "contextUsed": 100,
          "contextLimit": 0
        }
        """

        let content = try decodeJSON(json, as: CLIUsageContent.self)

        XCTAssertEqual(content.contextPercentage, 0)
    }

    func test_usageContent_optionalFields_defaultNil() throws {
        let json = """
        {
          "inputTokens": 2,
          "outputTokens": 3
        }
        """

        let content = try decodeJSON(json, as: CLIUsageContent.self)

        XCTAssertNil(content.cacheReadTokens)
        XCTAssertNil(content.cacheCreateTokens)
        XCTAssertNil(content.totalCost)
        XCTAssertNil(content.contextUsed)
        XCTAssertNil(content.contextLimit)
    }

    // MARK: - State Content

    func test_stateContent_decodesState() throws {
        let json = """
        {
          "state": "waiting_input"
        }
        """

        let content = try decodeJSON(json, as: CLIStateContent.self)

        XCTAssertEqual(content.state, .waitingInput)
        XCTAssertNil(content.tool)
    }

    func test_stateContent_decodesToolWhenPresent() throws {
        let json = """
        {
          "state": "executing",
          "tool": "Bash"
        }
        """

        let content = try decodeJSON(json, as: CLIStateContent.self)

        XCTAssertEqual(content.state, .executing)
        XCTAssertEqual(content.tool, "Bash")
    }

    // MARK: - Subagent Start Content

    func test_subagentStartContent_decodesFields() throws {
        let json = """
        {
          "id": "agent-2",
          "description": "Summarize",
          "agentType": "summarizer"
        }
        """

        let content = try decodeJSON(json, as: CLISubagentStartContent.self)

        XCTAssertEqual(content.id, "agent-2")
        XCTAssertEqual(content.description, "Summarize")
        XCTAssertEqual(content.agentType, "summarizer")
    }

    func test_subagentStartContent_displayAgentType_defaultsToTask() {
        let content = CLISubagentStartContent(id: "agent-3", description: "Run tests")

        XCTAssertEqual(content.displayAgentType, "Task")
    }

    func test_subagentStartContent_displayAgentType_usesAgentType() {
        let content = CLISubagentStartContent(id: "agent-4", description: "Analyze", agentType: "analyzer")

        XCTAssertEqual(content.displayAgentType, "analyzer")
    }

    // MARK: - Subagent Complete Content

    func test_subagentCompleteContent_decodesFields() throws {
        let json = """
        {
          "id": "agent-5",
          "summary": "Done"
        }
        """

        let content = try decodeJSON(json, as: CLISubagentCompleteContent.self)

        XCTAssertEqual(content.id, "agent-5")
        XCTAssertEqual(content.summary, "Done")
    }

    func test_subagentCompleteContent_displaySummary_defaultsToTaskCompleted() {
        let content = CLISubagentCompleteContent(id: "agent-6")

        XCTAssertEqual(content.displaySummary, "Task completed")
    }

    func test_subagentCompleteContent_displaySummary_usesSummary() {
        let content = CLISubagentCompleteContent(id: "agent-7", summary: "Merged")

        XCTAssertEqual(content.displaySummary, "Merged")
    }

    // MARK: - StoredMessage to ChatMessage Conversion (History Display)

    func test_storedMessage_toolUse_convertsToCorrectChatMessage() throws {
        // Real API format from /messages endpoint
        let json = """
        {
          "id": "bf263a34-e1c8-4cf6-a4e6-a3bf6797077d",
          "timestamp": "2025-12-31T10:00:00.000Z",
          "message": {
            "type": "tool_use",
            "id": "toolu_01VFvN8D2cWVrGYe5VPnNk5n",
            "name": "Bash",
            "input": {
              "command": "git status",
              "description": "Show git status"
            }
          }
        }
        """

        let storedMessage = try decodeJSON(json, as: StoredMessage.self)
        let chatMessage = storedMessage.toChatMessage()

        XCTAssertNotNil(chatMessage)
        XCTAssertEqual(chatMessage?.role, .toolUse)
        // Content should be in format: ToolName({"input":"json"})
        XCTAssertTrue(chatMessage?.content.hasPrefix("Bash(") == true)
        XCTAssertTrue(chatMessage?.content.contains("git status") == true)
    }

    func test_storedMessage_toolResult_convertsToCorrectChatMessage() throws {
        // Real API format from /messages endpoint
        let json = """
        {
          "id": "82d1a5d1-1f75-4404-b87e-f3802b5c9127",
          "timestamp": "2025-12-31T10:00:01.000Z",
          "message": {
            "type": "tool_result",
            "id": "toolu_01VFvN8D2cWVrGYe5VPnNk5n",
            "tool": "Bash",
            "output": "On branch main\\nnothing to commit",
            "success": true
          }
        }
        """

        let storedMessage = try decodeJSON(json, as: StoredMessage.self)
        let chatMessage = storedMessage.toChatMessage()

        XCTAssertNotNil(chatMessage)
        XCTAssertEqual(chatMessage?.role, .toolResult)
        // JSON \\n decodes to actual newline character
        XCTAssertEqual(chatMessage?.content, "On branch main\nnothing to commit")
    }

    func test_storedMessage_toolResultWithError_convertsToErrorRole() throws {
        let json = """
        {
          "id": "error-123",
          "timestamp": "2025-12-31T10:00:02.000Z",
          "message": {
            "type": "tool_result",
            "id": "toolu_error",
            "tool": "Bash",
            "output": "Command failed",
            "success": false,
            "isError": true
          }
        }
        """

        let storedMessage = try decodeJSON(json, as: StoredMessage.self)
        let chatMessage = storedMessage.toChatMessage()

        XCTAssertNotNil(chatMessage)
        XCTAssertEqual(chatMessage?.role, .error)
        XCTAssertEqual(chatMessage?.content, "Command failed")
    }

    func test_storedMessage_editToolUse_convertsWithFullInput() throws {
        // Edit tool with old_string/new_string should preserve full content
        let json = """
        {
          "id": "edit-123",
          "timestamp": "2025-12-31T10:00:03.000Z",
          "message": {
            "type": "tool_use",
            "id": "toolu_edit",
            "name": "Edit",
            "input": {
              "file_path": "/path/to/file.swift",
              "old_string": "func oldCode() {}",
              "new_string": "func newCode() {}"
            }
          }
        }
        """

        let storedMessage = try decodeJSON(json, as: StoredMessage.self)
        let chatMessage = storedMessage.toChatMessage()

        XCTAssertNotNil(chatMessage)
        XCTAssertEqual(chatMessage?.role, .toolUse)
        XCTAssertTrue(chatMessage?.content.hasPrefix("Edit(") == true)
        XCTAssertTrue(chatMessage?.content.contains("old_string") == true)
        XCTAssertTrue(chatMessage?.content.contains("new_string") == true)
    }

    func test_storedMessage_todoWriteToolUse_convertsWithTodosArray() throws {
        let json = """
        {
          "id": "todo-123",
          "timestamp": "2025-12-31T10:00:04.000Z",
          "message": {
            "type": "tool_use",
            "id": "toolu_todo",
            "name": "TodoWrite",
            "input": {
              "todos": [
                {"content": "Task 1", "status": "completed", "activeForm": "Doing task 1"},
                {"content": "Task 2", "status": "in_progress", "activeForm": "Doing task 2"}
              ]
            }
          }
        }
        """

        let storedMessage = try decodeJSON(json, as: StoredMessage.self)
        let chatMessage = storedMessage.toChatMessage()

        XCTAssertNotNil(chatMessage)
        XCTAssertEqual(chatMessage?.role, .toolUse)
        XCTAssertTrue(chatMessage?.content.hasPrefix("TodoWrite(") == true)
        XCTAssertTrue(chatMessage?.content.contains("Task 1") == true)
        XCTAssertTrue(chatMessage?.content.contains("completed") == true)
    }

    func test_storedMessage_assistantDelta_returnsNil() throws {
        // Streaming deltas should not create chat messages
        let json = """
        {
          "id": "delta-123",
          "timestamp": "2025-12-31T10:00:05.000Z",
          "message": {
            "type": "assistant",
            "content": "Streaming...",
            "delta": true
          }
        }
        """

        let storedMessage = try decodeJSON(json, as: StoredMessage.self)
        let chatMessage = storedMessage.toChatMessage()

        XCTAssertNil(chatMessage, "Streaming deltas should not create chat messages")
    }

    func test_storedMessage_assistantFinal_convertsToAssistantRole() throws {
        let json = """
        {
          "id": "final-123",
          "timestamp": "2025-12-31T10:00:06.000Z",
          "message": {
            "type": "assistant",
            "content": "Final response",
            "delta": false
          }
        }
        """

        let storedMessage = try decodeJSON(json, as: StoredMessage.self)
        let chatMessage = storedMessage.toChatMessage()

        XCTAssertNotNil(chatMessage)
        XCTAssertEqual(chatMessage?.role, .assistant)
        XCTAssertEqual(chatMessage?.content, "Final response")
    }

    func test_storedMessage_thinking_convertsToThinkingRole() throws {
        let json = """
        {
          "id": "thinking-123",
          "timestamp": "2025-12-31T10:00:07.000Z",
          "message": {
            "type": "thinking",
            "content": "Let me think about this..."
          }
        }
        """

        let storedMessage = try decodeJSON(json, as: StoredMessage.self)
        let chatMessage = storedMessage.toChatMessage()

        XCTAssertNotNil(chatMessage)
        XCTAssertEqual(chatMessage?.role, .thinking)
        XCTAssertEqual(chatMessage?.content, "Let me think about this...")
    }

    func test_storedMessage_user_convertsToUserRole() throws {
        let json = """
        {
          "id": "user-123",
          "timestamp": "2025-12-31T10:00:08.000Z",
          "message": {
            "type": "user",
            "content": "Hello, Claude!"
          }
        }
        """

        let storedMessage = try decodeJSON(json, as: StoredMessage.self)
        let chatMessage = storedMessage.toChatMessage()

        XCTAssertNotNil(chatMessage)
        XCTAssertEqual(chatMessage?.role, .user)
        XCTAssertEqual(chatMessage?.content, "Hello, Claude!")
    }
}
