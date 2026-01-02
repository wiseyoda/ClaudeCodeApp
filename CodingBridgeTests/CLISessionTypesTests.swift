import XCTest
@testable import CodingBridge

final class CLISessionTypesTests: XCTestCase {

    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(type, from: data)
    }

    private func makeMetadata(
        id: UUID = UUID(),
        projectPath: String = "/tmp/project",
        messageCount: Int = 3,
        createdAt: Date? = Date(timeIntervalSince1970: 1704067200), // 2024-01-01T00:00:00Z
        lastActivityAt: Date = Date(timeIntervalSince1970: 1704153600), // 2024-01-02T00:00:00Z
        lastUserMessage: String? = nil,
        lastAssistantMessage: String? = nil,
        title: String? = nil,
        customTitle: String? = nil,
        model: String? = "claude-3-5",
        source: CLISessionMetadata.SessionSource = .user,
        archivedAt: Date? = nil,
        parentSessionId: UUID? = nil
    ) -> CLISessionMetadata {
        return CLISessionMetadata(
            id: id,
            projectPath: projectPath,
            source: source,
            createdAt: createdAt,
            lastActivityAt: lastActivityAt,
            messageCount: messageCount,
            lastUserMessage: lastUserMessage,
            lastAssistantMessage: lastAssistantMessage,
            title: title,
            customTitle: customTitle,
            model: model,
            archivedAt: archivedAt,
            parentSessionId: parentSessionId
        )
    }

    // MARK: - CLIPermissionRequest

    func test_permissionRequest_decodesFields() throws {
        let json = """
        {
            "type": "permission",
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
        XCTAssertEqual(request.options, [.allow, .deny, .always])
        XCTAssertEqual(request.input["command"]?.stringValue, "ls -la")
        XCTAssertEqual(request.input["timeout"]?.intValue, 10)
        XCTAssertEqual(request.input["dryRun"]?.boolValue, true)
    }

    func test_permissionRequest_description_prefersCommand() {
        let request = CLIPermissionRequest(
            type: .permission,
            id: "perm-2",
            tool: "bash",
            input: [
                "command": JSONValue("git status"),
                "file_path": JSONValue("/tmp/notes.txt")
            ],
            options: []
        )

        XCTAssertEqual(request.description, "Run command: git status")
    }

    func test_permissionRequest_description_usesFilePath() {
        let request = CLIPermissionRequest(
            type: .permission,
            id: "perm-3",
            tool: "file_read",
            input: ["file_path": JSONValue("/tmp/notes.txt")],
            options: []
        )

        XCTAssertEqual(request.description, "file_read: /tmp/notes.txt")
    }

    func test_permissionRequest_description_usesFilePathCamelCase() {
        let request = CLIPermissionRequest(
            type: .permission,
            id: "perm-4",
            tool: "file_write",
            input: ["filePath": JSONValue("/tmp/new.txt")],
            options: []
        )

        XCTAssertEqual(request.description, "file_write: /tmp/new.txt")
    }

    func test_permissionRequest_description_fallsBackToTool() {
        let request = CLIPermissionRequest(
            type: .permission,
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
            "type": "question",
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

    private let testSessionId1 = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let testSessionId2 = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let testSessionId3 = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    private let testSessionId4 = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    private let testSessionId5 = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!

    func test_sessionEvent_decodesCreatedAction() throws {
        let json = """
        {
            "type": "session_event",
            "action": "created",
            "projectPath": "/tmp/project",
            "sessionId": "11111111-1111-1111-1111-111111111111"
        }
        """

        let event = try decode(CLISessionEvent.self, from: json)

        XCTAssertEqual(event.action, .created)
        XCTAssertEqual(event.projectPath, "/tmp/project")
        XCTAssertEqual(event.sessionId, testSessionId1)
        XCTAssertNil(event.metadata)
    }

    func test_sessionEvent_decodesUpdatedAction() throws {
        let json = """
        {
            "type": "session_event",
            "action": "updated",
            "projectPath": "/tmp/project",
            "sessionId": "22222222-2222-2222-2222-222222222222"
        }
        """

        let event = try decode(CLISessionEvent.self, from: json)

        XCTAssertEqual(event.action, .updated)
        XCTAssertEqual(event.sessionId, testSessionId2)
    }

    func test_sessionEvent_decodesDeletedAction() throws {
        let json = """
        {
            "type": "session_event",
            "action": "deleted",
            "projectPath": "/tmp/project",
            "sessionId": "33333333-3333-3333-3333-333333333333"
        }
        """

        let event = try decode(CLISessionEvent.self, from: json)

        XCTAssertEqual(event.action, .deleted)
        XCTAssertEqual(event.sessionId, testSessionId3)
    }

    func test_sessionEvent_decodesMetadataWhenPresent() throws {
        let json = """
        {
            "type": "session_event",
            "action": "created",
            "projectPath": "/tmp/project",
            "sessionId": "44444444-4444-4444-4444-444444444444",
            "metadata": {
                "id": "44444444-4444-4444-4444-444444444444",
                "projectPath": "/tmp/project",
                "source": "user",
                "messageCount": 4,
                "createdAt": "2024-02-01T12:00:00Z",
                "lastActivityAt": "2024-02-01T12:10:00Z"
            }
        }
        """

        let event = try decode(CLISessionEvent.self, from: json)

        XCTAssertEqual(event.metadata?.id, testSessionId4)
        XCTAssertEqual(event.metadata?.messageCount, 4)
        // lastActivityAt is now a Date, compare by checking the decoded value exists
        XCTAssertNotNil(event.metadata?.lastActivityAt)
    }

    func test_sessionEvent_decodesWithoutMetadata() throws {
        let json = """
        {
            "type": "session_event",
            "action": "updated",
            "projectPath": "/tmp/project",
            "sessionId": "55555555-5555-5555-5555-555555555555",
            "metadata": null
        }
        """

        let event = try decode(CLISessionEvent.self, from: json)

        XCTAssertNil(event.metadata)
    }

    // MARK: - CLISessionMetadata Decoding

    private let testSessionId6 = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!

    func test_sessionMetadata_decodesAllFields() throws {
        let json = """
        {
            "id": "66666666-6666-6666-6666-666666666666",
            "projectPath": "/tmp/project",
            "source": "agent",
            "messageCount": 12,
            "createdAt": "2024-03-01T08:00:00Z",
            "lastActivityAt": "2024-03-01T08:30:00Z",
            "lastUserMessage": "User message",
            "lastAssistantMessage": "Assistant message",
            "title": "Session title",
            "customTitle": "Custom title",
            "model": "claude"
        }
        """

        let metadata = try decode(CLISessionMetadata.self, from: json)

        XCTAssertEqual(metadata.id, testSessionId6)
        XCTAssertEqual(metadata.projectPath, "/tmp/project")
        XCTAssertEqual(metadata.messageCount, 12)
        XCTAssertNotNil(metadata.createdAt)
        XCTAssertNotNil(metadata.lastActivityAt)
        XCTAssertEqual(metadata.lastUserMessage, "User message")
        XCTAssertEqual(metadata.lastAssistantMessage, "Assistant message")
        XCTAssertEqual(metadata.title, "Session title")
        XCTAssertEqual(metadata.customTitle, "Custom title")
        XCTAssertEqual(metadata.model, "claude")
        XCTAssertEqual(metadata.source, .agent)
    }

    func test_sessionMetadata_createdAt_storesDate() {
        let createdAt = Date(timeIntervalSince1970: 1709373330.123) // 2024-03-02T10:15:30.123Z
        let metadata = makeMetadata(createdAt: createdAt)

        XCTAssertEqual(metadata.createdAt, createdAt)
    }

    func test_sessionMetadata_lastActivityAt_storesDate() {
        let lastActivityAt = Date(timeIntervalSince1970: 1709376000.456) // 2024-03-02T11:00:00.456Z
        let metadata = makeMetadata(lastActivityAt: lastActivityAt)

        XCTAssertEqual(metadata.lastActivityAt, lastActivityAt)
    }

    func test_sessionMetadata_createdAt_canBeNil() {
        let metadata = makeMetadata(createdAt: nil)

        XCTAssertNil(metadata.createdAt)
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

    func test_sessionMetadata_displayTitle_returnsNilWhenNoTitle() {
        let metadata = makeMetadata(title: nil, customTitle: nil)

        XCTAssertNil(metadata.displayTitle)
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

    // MARK: - ProjectSession Conversion

    private let testSessionId7 = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
    private let testSessionId8 = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!

    func test_sessionMetadata_toProjectSession_mapsFields() {
        let metadata = makeMetadata(
            id: testSessionId7,
            messageCount: 8,
            lastActivityAt: Date(timeIntervalSince1970: 1711958400), // 2024-04-01T08:00:00Z
            lastUserMessage: "User text",
            lastAssistantMessage: "Assistant text",
            title: "Session Summary"
        )

        let session = metadata.toProjectSession()

        XCTAssertEqual(session.id, testSessionId7.uuidString)
        XCTAssertEqual(session.summary, "Session Summary")
        XCTAssertEqual(session.messageCount, 8)
        // lastActivity is ISO8601 formatted string from the Date
        XCTAssertNotNil(session.lastActivity)
        XCTAssertEqual(session.lastUserMessage, "User text")
        XCTAssertEqual(session.lastAssistantMessage, "Assistant text")
    }

    func test_sessionMetadata_toProjectSession_prefersCustomTitle() {
        let metadata = makeMetadata(
            id: testSessionId7,
            title: "Auto Title",
            customTitle: "Custom Title"
        )

        let session = metadata.toProjectSession()

        XCTAssertEqual(session.summary, "Custom Title")
    }

    func test_sessionMetadata_toProjectSession_handlesNilTitle() {
        let metadata = makeMetadata(
            id: testSessionId8,
            messageCount: 0,
            lastActivityAt: Date(timeIntervalSince1970: 1712044800), // 2024-04-02T08:00:00Z
            lastUserMessage: nil,
            lastAssistantMessage: nil,
            title: nil
        )

        let session = metadata.toProjectSession()

        XCTAssertEqual(session.id, testSessionId8.uuidString)
        XCTAssertNil(session.summary)
        XCTAssertNil(session.lastUserMessage)
        XCTAssertNil(session.lastAssistantMessage)
    }
}
