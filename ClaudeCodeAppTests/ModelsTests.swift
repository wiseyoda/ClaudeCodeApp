import XCTest
@testable import ClaudeCodeApp

final class ModelsTests: XCTestCase {

    // MARK: - Project Tests

    func testProjectTitleWithDisplayName() {
        let project = Project(
            name: "-home-dev-workspace-MyProject",
            path: "/home/dev/workspace/MyProject",
            displayName: "My Project",
            fullPath: nil,
            sessions: nil
        )

        XCTAssertEqual(project.title, "My Project")
    }

    func testProjectTitleWithoutDisplayName() {
        let project = Project(
            name: "-home-dev-workspace-MyProject",
            path: "/home/dev/workspace/MyProject",
            displayName: nil,
            fullPath: nil,
            sessions: nil
        )

        // Should strip the prefix
        XCTAssertEqual(project.title, "MyProject")
    }

    func testProjectTitleWithEmptyDisplayName() {
        let project = Project(
            name: "-home-dev-workspace-TestApp",
            path: "/home/dev/workspace/TestApp",
            displayName: "",
            fullPath: nil,
            sessions: nil
        )

        XCTAssertEqual(project.title, "TestApp")
    }

    func testProjectTitleWithoutWorkspacePrefix() {
        let project = Project(
            name: "StandaloneProject",
            path: "/tmp/StandaloneProject",
            displayName: nil,
            fullPath: nil,
            sessions: nil
        )

        XCTAssertEqual(project.title, "StandaloneProject")
    }

    func testProjectId() {
        let project = Project(
            name: "Test",
            path: "/unique/path",
            displayName: nil,
            fullPath: nil,
            sessions: nil
        )

        XCTAssertEqual(project.id, "/unique/path")
    }

    // MARK: - ChatMessage Tests

    func testChatMessageInitialization() {
        let message = ChatMessage(role: .user, content: "Hello")

        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Hello")
        XCTAssertFalse(message.isStreaming)
        XCTAssertNil(message.imageData)
    }

    func testChatMessageWithImageData() {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        let message = ChatMessage(role: .user, content: "Image", imageData: imageData)

        XCTAssertNotNil(message.imageData)
        XCTAssertEqual(message.imageData, imageData)
    }

    func testChatMessageEquality() {
        let message1 = ChatMessage(role: .user, content: "Hello")
        let message2 = ChatMessage(role: .user, content: "Hello")

        // Different IDs = not equal
        XCTAssertNotEqual(message1, message2)
        // Same message = equal
        XCTAssertEqual(message1, message1)
    }

    func testChatMessageRoles() {
        let roles: [ChatMessage.Role] = [.user, .assistant, .system, .error, .toolUse, .toolResult, .resultSuccess, .thinking]

        for role in roles {
            let message = ChatMessage(role: role, content: "Test")
            XCTAssertEqual(message.role, role)
            XCTAssertEqual(message.role.rawValue, role.rawValue)
        }
    }

    func testChatMessageStreamingFlag() {
        let message = ChatMessage(role: .assistant, content: "Streaming", isStreaming: true)

        XCTAssertTrue(message.isStreaming)
    }

    func testChatMessageCodable() throws {
        let original = ChatMessage(
            role: .assistant,
            content: "Test response",
            timestamp: Date(timeIntervalSince1970: 1000)
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ChatMessage.self, from: data)

        XCTAssertEqual(decoded.role, original.role)
        XCTAssertEqual(decoded.content, original.content)
        XCTAssertEqual(decoded.timestamp, original.timestamp)
    }

    // MARK: - SessionHistoryLoader Tests

    func testParseEmptySessionHistory() {
        let result = SessionHistoryLoader.parseSessionHistory("")
        XCTAssertEqual(result.count, 0)
    }

    func testParseUserMessage() {
        let jsonl = """
        {"type":"user","message":{"content":[{"type":"text","text":"Hello Claude"}]},"timestamp":"2024-01-15T10:30:00.000Z"}
        """

        let result = SessionHistoryLoader.parseSessionHistory(jsonl)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].role, .user)
        XCTAssertEqual(result[0].content, "Hello Claude")
    }

    func testParseAssistantTextMessage() {
        let jsonl = """
        {"type":"assistant","message":{"content":[{"type":"text","text":"Hello! How can I help?"}]},"timestamp":"2024-01-15T10:30:01.000Z"}
        """

        let result = SessionHistoryLoader.parseSessionHistory(jsonl)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].role, .assistant)
        XCTAssertEqual(result[0].content, "Hello! How can I help?")
    }

    func testParseAssistantThinkingMessage() {
        let jsonl = """
        {"type":"assistant","message":{"content":[{"type":"thinking","thinking":"Let me think about this..."}]},"timestamp":"2024-01-15T10:30:01.000Z"}
        """

        let result = SessionHistoryLoader.parseSessionHistory(jsonl)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].role, .thinking)
        XCTAssertEqual(result[0].content, "Let me think about this...")
    }

    func testParseToolUseMessage() {
        let jsonl = """
        {"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"ls -la"}}]},"timestamp":"2024-01-15T10:30:02.000Z"}
        """

        let result = SessionHistoryLoader.parseSessionHistory(jsonl)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].role, .toolUse)
        XCTAssertTrue(result[0].content.contains("Bash"))
        XCTAssertTrue(result[0].content.contains("command"))
    }

    func testParseToolResultMessage() {
        let jsonl = """
        {"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"123"}]},"toolUseResult":"file1.txt\\nfile2.txt","timestamp":"2024-01-15T10:30:03.000Z"}
        """

        let result = SessionHistoryLoader.parseSessionHistory(jsonl)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].role, .toolResult)
        // JSON parsing converts \n to actual newline
        XCTAssertEqual(result[0].content, "file1.txt\nfile2.txt")
    }

    func testParseToolResultMessageWithStdoutDict() {
        let jsonl = """
        {"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"123"}]},"toolUseResult":{"stdout":"ok"},"timestamp":"2024-01-15T10:30:03.000Z"}
        """

        let result = SessionHistoryLoader.parseSessionHistory(jsonl)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].role, .toolResult)
        XCTAssertEqual(result[0].content, "ok")
    }

    func testParseMultipleMessages() {
        let jsonl = """
        {"type":"user","message":{"content":[{"type":"text","text":"First"}]},"timestamp":"2024-01-15T10:30:00.000Z"}
        {"type":"assistant","message":{"content":[{"type":"text","text":"Second"}]},"timestamp":"2024-01-15T10:30:01.000Z"}
        {"type":"user","message":{"content":[{"type":"text","text":"Third"}]},"timestamp":"2024-01-15T10:30:02.000Z"}
        """

        let result = SessionHistoryLoader.parseSessionHistory(jsonl)

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].content, "First")
        XCTAssertEqual(result[1].content, "Second")
        XCTAssertEqual(result[2].content, "Third")
    }

    func testParseSkipsUnknownTypes() {
        let jsonl = """
        {"type":"queue-operation","data":{"action":"start"}}
        {"type":"user","message":{"content":[{"type":"text","text":"Hello"}]},"timestamp":"2024-01-15T10:30:00.000Z"}
        {"type":"system","message":"some system message"}
        """

        let result = SessionHistoryLoader.parseSessionHistory(jsonl)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].content, "Hello")
    }

    func testParseHandlesInvalidJSON() {
        let jsonl = """
        {"type":"user","message":{"content":[{"type":"text","text":"Valid"}]},"timestamp":"2024-01-15T10:30:00.000Z"}
        not valid json at all
        {"type":"assistant","message":{"content":[{"type":"text","text":"Also valid"}]},"timestamp":"2024-01-15T10:30:01.000Z"}
        """

        let result = SessionHistoryLoader.parseSessionHistory(jsonl)

        // Should parse valid lines and skip invalid
        XCTAssertEqual(result.count, 2)
    }

    func testParseSkipsMissingTimestamp() {
        let jsonl = """
        {"type":"user","message":{"content":[{"type":"text","text":"Missing timestamp"}]}}
        {"type":"assistant","message":{"content":[{"type":"text","text":"Valid"}]},"timestamp":"2024-01-15T10:30:01.000Z"}
        """

        let result = SessionHistoryLoader.parseSessionHistory(jsonl)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].content, "Valid")
    }

    func testParseTimestampWithoutFractionalSeconds() {
        let jsonl = """
        {"type":"user","message":{"content":[{"type":"text","text":"Test"}]},"timestamp":"2024-01-15T10:30:00Z"}
        """

        let result = SessionHistoryLoader.parseSessionHistory(jsonl)

        XCTAssertEqual(result.count, 1)
        XCTAssertNotNil(result[0].timestamp)
    }

    func testSessionFilePath() {
        let path = SessionHistoryLoader.sessionFilePath(
            projectPath: "/home/dev/workspace/MyProject",
            sessionId: "abc123"
        )

        XCTAssertEqual(path, "~/.claude/projects/-home-dev-workspace-MyProject/abc123.jsonl")
    }

    func testSessionFilePathWithTrailingSlash() {
        let path = SessionHistoryLoader.sessionFilePath(
            projectPath: "/home/dev/workspace/MyProject/",
            sessionId: "abc123"
        )

        // Trailing slash becomes trailing dash, which should be trimmed
        XCTAssertEqual(path, "~/.claude/projects/-home-dev-workspace-MyProject/abc123.jsonl")
    }

    // MARK: - WSImage Tests

    func testWSImageCreation() {
        let image = WSImage(mediaType: "image/png", base64Data: "abc123")

        XCTAssertEqual(image.data, "data:image/png;base64,abc123")
    }

    func testWSImageWithJPEG() {
        let image = WSImage(mediaType: "image/jpeg", base64Data: "xyz789")

        XCTAssertEqual(image.data, "data:image/jpeg;base64,xyz789")
    }

    // MARK: - AnyCodable Tests

    func testAnyCodableString() throws {
        let json = """
        {"value": "hello"}
        """
        let data = json.data(using: .utf8)!

        struct Wrapper: Decodable {
            let value: AnyCodable
        }

        let decoded = try JSONDecoder().decode(Wrapper.self, from: data)
        XCTAssertEqual(decoded.value.stringValue, "hello")
    }

    func testAnyCodableInt() throws {
        let json = """
        {"value": 42}
        """
        let data = json.data(using: .utf8)!

        struct Wrapper: Decodable {
            let value: AnyCodable
        }

        let decoded = try JSONDecoder().decode(Wrapper.self, from: data)
        XCTAssertEqual(decoded.value.value as? Int, 42)
    }

    func testAnyCodableBool() throws {
        let json = """
        {"value": true}
        """
        let data = json.data(using: .utf8)!

        struct Wrapper: Decodable {
            let value: AnyCodable
        }

        let decoded = try JSONDecoder().decode(Wrapper.self, from: data)
        XCTAssertEqual(decoded.value.value as? Bool, true)
    }

    func testAnyCodableDict() throws {
        let json = """
        {"value": {"nested": "data"}}
        """
        let data = json.data(using: .utf8)!

        struct Wrapper: Decodable {
            let value: AnyCodable
        }

        let decoded = try JSONDecoder().decode(Wrapper.self, from: data)
        let dict = decoded.value.dictValue
        XCTAssertNotNil(dict)
        XCTAssertEqual(dict?["nested"] as? String, "data")
    }

    func testAnyCodableStringValueFromDict() throws {
        let json = """
        {"value": {"key": "val"}}
        """
        let data = json.data(using: .utf8)!

        struct Wrapper: Decodable {
            let value: AnyCodable
        }

        let decoded = try JSONDecoder().decode(Wrapper.self, from: data)
        let stringValue = decoded.value.stringValue

        // Should be JSON string representation
        XCTAssertTrue(stringValue.contains("key"))
        XCTAssertTrue(stringValue.contains("val"))
    }

    // MARK: - QuestionOption Tests

    func testQuestionOptionFromDict() {
        let dict: [String: Any] = [
            "label": "Option A",
            "description": "First option"
        ]

        let option = QuestionOption.from(dict)

        XCTAssertNotNil(option)
        XCTAssertEqual(option?.label, "Option A")
        XCTAssertEqual(option?.description, "First option")
    }

    func testQuestionOptionFromDictWithoutDescription() {
        let dict: [String: Any] = [
            "label": "Option B"
        ]

        let option = QuestionOption.from(dict)

        XCTAssertNotNil(option)
        XCTAssertEqual(option?.label, "Option B")
        XCTAssertNil(option?.description)
    }

    func testQuestionOptionFromDictMissingLabel() {
        let dict: [String: Any] = [
            "description": "No label here"
        ]

        let option = QuestionOption.from(dict)

        XCTAssertNil(option)
    }

    // MARK: - UserQuestion Tests

    func testUserQuestionFromDict() {
        let dict: [String: Any] = [
            "question": "Which option?",
            "header": "Choice",
            "multiSelect": false,
            "options": [
                ["label": "A", "description": "First"],
                ["label": "B", "description": "Second"]
            ]
        ]

        let question = UserQuestion.from(dict)

        XCTAssertNotNil(question)
        XCTAssertEqual(question?.question, "Which option?")
        XCTAssertEqual(question?.header, "Choice")
        XCTAssertEqual(question?.multiSelect, false)
        XCTAssertEqual(question?.options.count, 2)
    }

    func testUserQuestionFromDictWithMultiSelect() {
        let dict: [String: Any] = [
            "question": "Select all that apply",
            "multiSelect": true,
            "options": [
                ["label": "One"],
                ["label": "Two"]
            ]
        ]

        let question = UserQuestion.from(dict)

        XCTAssertNotNil(question)
        XCTAssertEqual(question?.multiSelect, true)
    }

    func testUserQuestionFromDictMissingQuestion() {
        let dict: [String: Any] = [
            "header": "Test",
            "options": []
        ]

        let question = UserQuestion.from(dict)

        XCTAssertNil(question)
    }

    // MARK: - AskUserQuestionData Tests

    func testAskUserQuestionDataFromInput() {
        let input: [String: Any] = [
            "questions": [
                [
                    "question": "Pick one",
                    "header": "Selection",
                    "multiSelect": false,
                    "options": [
                        ["label": "Yes"],
                        ["label": "No"]
                    ]
                ]
            ]
        ]

        let data = AskUserQuestionData.from(input)

        XCTAssertNotNil(data)
        XCTAssertEqual(data?.questions.count, 1)
    }

    func testAskUserQuestionDataFromInputEmpty() {
        let input: [String: Any] = [
            "questions": []
        ]

        let data = AskUserQuestionData.from(input)

        // Empty questions array should return nil
        XCTAssertNil(data)
    }

    func testAskUserQuestionDataFromInputMissingQuestions() {
        let input: [String: Any] = [
            "other": "data"
        ]

        let data = AskUserQuestionData.from(input)

        XCTAssertNil(data)
    }

    func testFormatAnswersWithSelectedOptions() {
        var question = UserQuestion(
            question: "Which framework?",
            header: "Framework",
            options: [
                QuestionOption(label: "SwiftUI"),
                QuestionOption(label: "UIKit")
            ],
            multiSelect: false
        )
        question.selectedOptions = ["SwiftUI"]

        let data = AskUserQuestionData(questions: [question])
        let formatted = data.formatAnswers()

        XCTAssertTrue(formatted.contains("**Framework**"))
        XCTAssertTrue(formatted.contains("SwiftUI"))
    }

    func testFormatAnswersWithCustomAnswer() {
        var question = UserQuestion(
            question: "What's your preference?",
            header: "Preference",
            options: [],
            multiSelect: false
        )
        question.customAnswer = "Custom response here"

        let data = AskUserQuestionData(questions: [question])
        let formatted = data.formatAnswers()

        XCTAssertTrue(formatted.contains("Custom response here"))
    }

    func testFormatAnswersWithMultipleSelections() {
        var question = UserQuestion(
            question: "Select features",
            header: "Features",
            options: [
                QuestionOption(label: "Dark Mode"),
                QuestionOption(label: "Notifications"),
                QuestionOption(label: "Sync")
            ],
            multiSelect: true
        )
        question.selectedOptions = ["Dark Mode", "Sync"]

        let data = AskUserQuestionData(questions: [question])
        let formatted = data.formatAnswers()

        XCTAssertTrue(formatted.contains("Dark Mode"))
        XCTAssertTrue(formatted.contains("Sync"))
    }

    // MARK: - ProjectSession Tests

    func testProjectSessionDecoding() throws {
        let json = """
        {
            "id": "session-123",
            "summary": "Working on feature X",
            "messageCount": 42,
            "lastActivity": "2024-01-15T10:30:00Z",
            "lastUserMessage": "How do I fix this?",
            "lastAssistantMessage": "Here's the solution..."
        }
        """

        let data = json.data(using: .utf8)!
        let session = try JSONDecoder().decode(ProjectSession.self, from: data)

        XCTAssertEqual(session.id, "session-123")
        XCTAssertEqual(session.summary, "Working on feature X")
        XCTAssertEqual(session.messageCount, 42)
        XCTAssertEqual(session.lastUserMessage, "How do I fix this?")
    }

    func testProjectSessionWithNilFields() throws {
        let json = """
        {
            "id": "session-456"
        }
        """

        let data = json.data(using: .utf8)!
        let session = try JSONDecoder().decode(ProjectSession.self, from: data)

        XCTAssertEqual(session.id, "session-456")
        XCTAssertNil(session.summary)
        XCTAssertNil(session.messageCount)
        XCTAssertNil(session.lastActivity)
    }
}
