import XCTest
@testable import CodingBridge

final class CLISessionTypesTests: XCTestCase {

    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(type, from: data)
    }

    private func makeMetadata(
        id: String = "session-1",
        projectPath: String = "/tmp/project",
        messageCount: Int = 3,
        createdAt: String = "2024-01-01T00:00:00Z",
        lastActivityAt: String = "2024-01-02T00:00:00Z",
        lastUserMessage: String? = nil,
        lastAssistantMessage: String? = nil,
        title: String? = nil,
        customTitle: String? = nil,
        model: String? = "claude-3-5",
        source: CLISessionMetadata.SessionSource? = nil,
        archivedAt: String? = nil,
        parentSessionId: String? = nil
    ) -> CLISessionMetadata {
        return CLISessionMetadata(
            id: id,
            projectPath: projectPath,
            messageCount: messageCount,
            createdAt: createdAt,
            lastActivityAt: lastActivityAt,
            lastUserMessage: lastUserMessage,
            lastAssistantMessage: lastAssistantMessage,
            title: title,
            customTitle: customTitle,
            model: model,
            source: source,
            archivedAt: archivedAt,
            parentSessionId: parentSessionId
        )
    }

    private func parseISODate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    // MARK: - CLIPermissionRequest

    func test_permissionRequest_decodesFields() throws {
        let json = """
        {
            "id": "perm-1",
            "tool": "bash",
            "input": {
                "command": "ls -la",
                "timeout": 10,
                "dryRun": true
            },
            "options": ["allow", "deny", "always"]
        }
        """

        let request = try decode(CLIPermissionRequest.self, from: json)

        XCTAssertEqual(request.id, "perm-1")
        XCTAssertEqual(request.tool, "bash")
        XCTAssertEqual(request.options, ["allow", "deny", "always"])
        XCTAssertEqual(request.input["command"]?.stringValue, "ls -la")
        XCTAssertEqual(request.input["timeout"]?.intValue, 10)
        XCTAssertEqual(request.input["dryRun"]?.boolValue, true)
    }

    func test_permissionRequest_description_prefersCommand() {
        let request = CLIPermissionRequest(
            id: "perm-2",
            tool: "bash",
            input: [
                "command": AnyCodableValue("git status"),
                "file_path": AnyCodableValue("/tmp/notes.txt")
            ],
            options: []
        )

        XCTAssertEqual(request.description, "Run command: git status")
    }

    func test_permissionRequest_description_usesFilePath() {
        let request = CLIPermissionRequest(
            id: "perm-3",
            tool: "file_read",
            input: ["file_path": AnyCodableValue("/tmp/notes.txt")],
            options: []
        )

        XCTAssertEqual(request.description, "file_read: /tmp/notes.txt")
    }

    func test_permissionRequest_description_usesFilePathCamelCase() {
        let request = CLIPermissionRequest(
            id: "perm-4",
            tool: "file_write",
            input: ["filePath": AnyCodableValue("/tmp/new.txt")],
            options: []
        )

        XCTAssertEqual(request.description, "file_write: /tmp/new.txt")
    }

    func test_permissionRequest_description_fallsBackToTool() {
        let request = CLIPermissionRequest(
            id: "perm-5",
            tool: "custom_tool",
            input: [:],
            options: []
        )

        XCTAssertEqual(request.description, "custom_tool")
    }

    // MARK: - CLIQuestionRequest

    func test_questionRequest_decodesNestedQuestions() throws {
        let json = """
        {
            "id": "question-1",
            "questions": [
                {
                    "question": "Choose language",
                    "header": "Setup",
                    "options": [
                        {"label": "Swift", "description": "Apple"},
                        {"label": "Kotlin", "description": "Android"}
                    ],
                    "multiSelect": false
                },
                {
                    "question": "Select features",
                    "header": "Options",
                    "options": [
                        {"label": "Tests", "description": null}
                    ],
                    "multiSelect": true
                }
            ]
        }
        """

        let request = try decode(CLIQuestionRequest.self, from: json)

        XCTAssertEqual(request.id, "question-1")
        XCTAssertEqual(request.questions.count, 2)
        XCTAssertEqual(request.questions[0].question, "Choose language")
        XCTAssertEqual(request.questions[0].header, "Setup")
        XCTAssertEqual(request.questions[0].options.count, 2)
        XCTAssertEqual(request.questions[0].options[0].label, "Swift")
        XCTAssertEqual(request.questions[0].options[0].description, "Apple")
        XCTAssertTrue(request.questions[1].multiSelect)
        XCTAssertNil(request.questions[1].options[0].description)
    }

    func test_questionItem_decodesMultiSelectFalse() throws {
        let json = """
        {
            "question": "Proceed?",
            "header": "Confirm",
            "options": [
                {"label": "Yes", "description": "Continue"}
            ],
            "multiSelect": false
        }
        """

        let item = try decode(CLIQuestionItem.self, from: json)

        XCTAssertEqual(item.question, "Proceed?")
        XCTAssertEqual(item.header, "Confirm")
        XCTAssertFalse(item.multiSelect)
        XCTAssertEqual(item.options.count, 1)
    }

    func test_questionOption_decodesWithDescription() throws {
        let json = """
        {"label": "Yes", "description": "Preferred"}
        """

        let option = try decode(CLIQuestionOption.self, from: json)

        XCTAssertEqual(option.label, "Yes")
        XCTAssertEqual(option.description, "Preferred")
    }

    func test_questionOption_decodesWithNilDescription() throws {
        let json = """
        {"label": "No", "description": null}
        """

        let option = try decode(CLIQuestionOption.self, from: json)

        XCTAssertEqual(option.label, "No")
        XCTAssertNil(option.description)
    }

    func test_questionOption_decodesWhenDescriptionMissing() throws {
        let json = """
        {"label": "Maybe"}
        """

        let option = try decode(CLIQuestionOption.self, from: json)

        XCTAssertEqual(option.label, "Maybe")
        XCTAssertNil(option.description)
    }

    // MARK: - CLISessionEvent

    func test_sessionEvent_decodesCreatedAction() throws {
        let json = """
        {
            "action": "created",
            "projectPath": "/tmp/project",
            "sessionId": "session-1"
        }
        """

        let event = try decode(CLISessionEvent.self, from: json)

        XCTAssertEqual(event.action, .created)
        XCTAssertEqual(event.projectPath, "/tmp/project")
        XCTAssertEqual(event.sessionId, "session-1")
        XCTAssertNil(event.metadata)
    }

    func test_sessionEvent_decodesUpdatedAction() throws {
        let json = """
        {
            "action": "updated",
            "projectPath": "/tmp/project",
            "sessionId": "session-2"
        }
        """

        let event = try decode(CLISessionEvent.self, from: json)

        XCTAssertEqual(event.action, .updated)
        XCTAssertEqual(event.sessionId, "session-2")
    }

    func test_sessionEvent_decodesDeletedAction() throws {
        let json = """
        {
            "action": "deleted",
            "projectPath": "/tmp/project",
            "sessionId": "session-3"
        }
        """

        let event = try decode(CLISessionEvent.self, from: json)

        XCTAssertEqual(event.action, .deleted)
        XCTAssertEqual(event.sessionId, "session-3")
    }

    func test_sessionEvent_decodesMetadataWhenPresent() throws {
        let json = """
        {
            "action": "created",
            "projectPath": "/tmp/project",
            "sessionId": "session-4",
            "metadata": {
                "id": "session-4",
                "projectPath": "/tmp/project",
                "messageCount": 4,
                "createdAt": "2024-02-01T12:00:00Z",
                "lastActivityAt": "2024-02-01T12:10:00Z"
            }
        }
        """

        let event = try decode(CLISessionEvent.self, from: json)

        XCTAssertEqual(event.metadata?.id, "session-4")
        XCTAssertEqual(event.metadata?.messageCount, 4)
        XCTAssertEqual(event.metadata?.lastActivityAt, "2024-02-01T12:10:00Z")
    }

    func test_sessionEvent_decodesWithoutMetadata() throws {
        let json = """
        {
            "action": "updated",
            "projectPath": "/tmp/project",
            "sessionId": "session-5",
            "metadata": null
        }
        """

        let event = try decode(CLISessionEvent.self, from: json)

        XCTAssertNil(event.metadata)
    }

    // MARK: - CLISessionMetadata Decoding

    func test_sessionMetadata_decodesAllFields() throws {
        let json = """
        {
            "id": "session-6",
            "projectPath": "/tmp/project",
            "messageCount": 12,
            "createdAt": "2024-03-01T08:00:00Z",
            "lastActivityAt": "2024-03-01T08:30:00Z",
            "lastUserMessage": "User message",
            "lastAssistantMessage": "Assistant message",
            "title": "Session title",
            "customTitle": "Custom title",
            "model": "claude",
            "source": "agent"
        }
        """

        let metadata = try decode(CLISessionMetadata.self, from: json)

        XCTAssertEqual(metadata.id, "session-6")
        XCTAssertEqual(metadata.projectPath, "/tmp/project")
        XCTAssertEqual(metadata.messageCount, 12)
        XCTAssertEqual(metadata.createdAt, "2024-03-01T08:00:00Z")
        XCTAssertEqual(metadata.lastActivityAt, "2024-03-01T08:30:00Z")
        XCTAssertEqual(metadata.lastUserMessage, "User message")
        XCTAssertEqual(metadata.lastAssistantMessage, "Assistant message")
        XCTAssertEqual(metadata.title, "Session title")
        XCTAssertEqual(metadata.customTitle, "Custom title")
        XCTAssertEqual(metadata.model, "claude")
        XCTAssertEqual(metadata.source, .agent)
    }

    func test_sessionMetadata_createdDate_parsesFractionalSeconds() {
        let createdAt = "2024-03-02T10:15:30.123Z"
        let metadata = makeMetadata(createdAt: createdAt)

        XCTAssertEqual(metadata.createdDate, parseISODate(createdAt))
    }

    func test_sessionMetadata_createdDate_parsesWithoutFractionalSeconds() {
        let createdAt = "2024-03-02T10:15:30Z"
        let metadata = makeMetadata(createdAt: createdAt)

        XCTAssertEqual(metadata.createdDate, parseISODate(createdAt))
    }

    func test_sessionMetadata_lastActivityDate_parsesFractionalSeconds() {
        let lastActivityAt = "2024-03-02T11:00:00.456Z"
        let metadata = makeMetadata(lastActivityAt: lastActivityAt)

        XCTAssertEqual(metadata.lastActivityDate, parseISODate(lastActivityAt))
    }

    func test_sessionMetadata_lastActivityDate_parsesWithoutFractionalSeconds() {
        let lastActivityAt = "2024-03-02T11:00:00Z"
        let metadata = makeMetadata(lastActivityAt: lastActivityAt)

        XCTAssertEqual(metadata.lastActivityDate, parseISODate(lastActivityAt))
    }

    func test_sessionMetadata_dateParsing_returnsNilForInvalidValues() {
        let metadata = makeMetadata(
            createdAt: "not-a-date",
            lastActivityAt: "still-not-a-date"
        )

        XCTAssertNil(metadata.createdDate)
        XCTAssertNil(metadata.lastActivityDate)
    }

    // MARK: - CLISessionMetadata Display Title

    func test_sessionMetadata_displayTitle_prefersCustomTitle() {
        let metadata = makeMetadata(
            lastUserMessage: "User message",
            title: "Auto title",
            customTitle: "Custom title"
        )

        XCTAssertEqual(metadata.displayTitle, "Custom title")
    }

    func test_sessionMetadata_displayTitle_ignoresEmptyCustomTitle() {
        let metadata = makeMetadata(
            title: "Fallback title",
            customTitle: ""
        )

        XCTAssertEqual(metadata.displayTitle, "Fallback title")
    }

    func test_sessionMetadata_displayTitle_returnsPlainTitle() {
        let metadata = makeMetadata(title: "Plain title")

        XCTAssertEqual(metadata.displayTitle, "Plain title")
    }

    func test_sessionMetadata_displayTitle_parsesJsonTitleTextBlocks() {
        let title = #"[{"type":"text","text":"Hello"}]"#
        let metadata = makeMetadata(title: title)

        XCTAssertEqual(metadata.displayTitle, "Hello")
    }

    func test_sessionMetadata_displayTitle_parsesJsonTitleToolResultContent() {
        let title = #"[{"type":"tool_result","content":"Tool output"}]"#
        let metadata = makeMetadata(title: title)

        XCTAssertEqual(metadata.displayTitle, "Tool output")
    }

    func test_sessionMetadata_displayTitle_fallsBackToLastUserMessageWhenTitleUnparseable() {
        let title = #"["oops"]"#
        let lastUser = #"[{"type":"text","text":"Last message"}]"#
        let metadata = makeMetadata(lastUserMessage: lastUser, title: title)

        XCTAssertEqual(metadata.displayTitle, "Last message")
    }

    func test_sessionMetadata_displayTitle_usesLastUserMessageWhenTitleMissing() {
        let lastUser = #"[{"type":"text","text":"Only message"}]"#
        let metadata = makeMetadata(lastUserMessage: lastUser, title: nil)

        XCTAssertEqual(metadata.displayTitle, "Only message")
    }

    func test_sessionMetadata_displayTitle_returnsRawTitleWhenLastUserMessageUnavailable() {
        let title = #"["raw"]"#
        let metadata = makeMetadata(lastUserMessage: nil, title: title)

        XCTAssertEqual(metadata.displayTitle, title)
    }

    func test_sessionMetadata_displayTitle_handlesTruncatedJsonPrefix() {
        let title = "[{\"type\":\"text\",\"text\":\""
        let metadata = makeMetadata(lastUserMessage: nil, title: title)

        XCTAssertEqual(metadata.displayTitle, "")
    }

    func test_sessionMetadata_displayTitle_returnsNilWhenNoTitleOrLastUserMessage() {
        let metadata = makeMetadata(lastUserMessage: nil, title: nil)

        XCTAssertNil(metadata.displayTitle)
    }

    // MARK: - Parsed Last User Message

    func test_sessionMetadata_parsedLastUserMessage_returnsNilWhenMissing() {
        let metadata = makeMetadata(lastUserMessage: nil)

        XCTAssertNil(metadata.parsedLastUserMessage)
    }

    func test_sessionMetadata_parsedLastUserMessage_returnsPlainText() {
        let metadata = makeMetadata(lastUserMessage: "Plain message")

        XCTAssertEqual(metadata.parsedLastUserMessage, "Plain message")
    }

    func test_sessionMetadata_parsedLastUserMessage_parsesTextBlocks() {
        let message = #"[{"type":"text","text":"One"},{"type":"text","text":"Two"}]"#
        let metadata = makeMetadata(lastUserMessage: message)

        XCTAssertEqual(metadata.parsedLastUserMessage, "One Two")
    }

    func test_sessionMetadata_parsedLastUserMessage_parsesToolResultContent() {
        let message = #"[{"type":"tool_result","content":"Tool output"}]"#
        let metadata = makeMetadata(lastUserMessage: message)

        XCTAssertEqual(metadata.parsedLastUserMessage, "Tool output")
    }

    func test_sessionMetadata_parsedLastUserMessage_parsesMixedArray() {
        let message = #"["ignore", {"type":"text","text":"Mixed"}]"#
        let metadata = makeMetadata(lastUserMessage: message)

        XCTAssertEqual(metadata.parsedLastUserMessage, "Mixed")
    }

    func test_sessionMetadata_parsedLastUserMessage_fallsBackToRegexForInvalidJson() {
        let message = #"[{"type":"text","text":"Line 1\nLine 2""#
        let metadata = makeMetadata(lastUserMessage: message)

        XCTAssertEqual(metadata.parsedLastUserMessage, "Line 1\nLine 2")
    }

    func test_sessionMetadata_parsedLastUserMessage_fallsBackToTruncatedText() {
        let message = #"[{"type":"text","text":"Truncated..."#
        let metadata = makeMetadata(lastUserMessage: message)

        XCTAssertEqual(metadata.parsedLastUserMessage, "Truncated")
    }

    // MARK: - Source Flags

    func test_sessionMetadata_sourceHelper_flags() {
        let metadata = makeMetadata(source: .helper)

        XCTAssertTrue(metadata.isHelper)
        XCTAssertFalse(metadata.isAgent)
        XCTAssertFalse(metadata.isUserVisible)
    }

    func test_sessionMetadata_sourceAgent_flags() {
        let metadata = makeMetadata(source: .agent)

        XCTAssertFalse(metadata.isHelper)
        XCTAssertTrue(metadata.isAgent)
        XCTAssertFalse(metadata.isUserVisible)
    }

    func test_sessionMetadata_sourceUser_flags() {
        let metadata = makeMetadata(source: .user)

        XCTAssertFalse(metadata.isHelper)
        XCTAssertFalse(metadata.isAgent)
        XCTAssertTrue(metadata.isUserVisible)
    }

    func test_sessionMetadata_sourceNil_isUserVisible() {
        let metadata = makeMetadata(source: nil)

        XCTAssertTrue(metadata.isUserVisible)
        XCTAssertFalse(metadata.isHelper)
        XCTAssertFalse(metadata.isAgent)
    }

    // MARK: - ProjectSession Conversion

    func test_sessionMetadata_toProjectSession_usesParsedFields() {
        let title = #"[{"type":"text","text":"Summary"}]"#
        let lastUser = #"[{"type":"text","text":"User text"}]"#
        let metadata = makeMetadata(
            id: "session-7",
            messageCount: 8,
            lastActivityAt: "2024-04-01T09:00:00Z",
            lastUserMessage: lastUser,
            lastAssistantMessage: "Assistant text",
            title: title
        )

        let session = metadata.toProjectSession()

        XCTAssertEqual(session.id, "session-7")
        XCTAssertEqual(session.summary, "Summary")
        XCTAssertEqual(session.messageCount, 8)
        XCTAssertEqual(session.lastActivity, "2024-04-01T09:00:00Z")
        XCTAssertEqual(session.lastUserMessage, "User text")
        XCTAssertEqual(session.lastAssistantMessage, "Assistant text")
    }

    func test_sessionMetadata_toProjectSession_handlesNilTitle() {
        let metadata = makeMetadata(
            id: "session-8",
            messageCount: 0,
            lastActivityAt: "2024-04-02T09:00:00Z",
            lastUserMessage: nil,
            lastAssistantMessage: nil,
            title: nil
        )

        let session = metadata.toProjectSession()

        XCTAssertEqual(session.id, "session-8")
        XCTAssertNil(session.summary)
        XCTAssertNil(session.lastUserMessage)
        XCTAssertNil(session.lastAssistantMessage)
    }
}
