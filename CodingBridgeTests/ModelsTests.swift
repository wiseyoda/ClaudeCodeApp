import XCTest
@testable import CodingBridge

final class ModelsTests: XCTestCase {

    // MARK: - Project Tests

    func testProjectTitleWithDisplayName() {
        let project = Project(
            name: "-home-dev-workspace-MyProject",
            path: "/home/dev/workspace/MyProject",
            displayName: "My Project",
            fullPath: nil,
            sessions: nil,
            sessionMeta: nil
        )

        XCTAssertEqual(project.title, "My Project")
    }

    func testProjectTitleWithoutDisplayName() {
        let project = Project(
            name: "-home-dev-workspace-MyProject",
            path: "/home/dev/workspace/MyProject",
            displayName: nil,
            fullPath: nil,
            sessions: nil,
            sessionMeta: nil
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
            sessions: nil,
            sessionMeta: nil
        )

        XCTAssertEqual(project.title, "TestApp")
    }

    func testProjectTitleWithoutWorkspacePrefix() {
        let project = Project(
            name: "StandaloneProject",
            path: "/tmp/StandaloneProject",
            displayName: nil,
            fullPath: nil,
            sessions: nil,
            sessionMeta: nil
        )

        XCTAssertEqual(project.title, "StandaloneProject")
    }

    func testProjectId() {
        let project = Project(
            name: "Test",
            path: "/unique/path",
            displayName: nil,
            fullPath: nil,
            sessions: nil,
            sessionMeta: nil
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

        let data = AskUserQuestionData.from(input, requestId: "test-req-1")

        XCTAssertNotNil(data)
        XCTAssertEqual(data?.questions.count, 1)
        XCTAssertEqual(data?.requestId, "test-req-1")
    }

    func testAskUserQuestionDataFromInputEmpty() {
        let input: [String: Any] = [
            "questions": []
        ]

        let data = AskUserQuestionData.from(input, requestId: "test-req-2")

        // Empty questions array should return nil
        XCTAssertNil(data)
    }

    func testAskUserQuestionDataFromInputMissingQuestions() {
        let input: [String: Any] = [
            "other": "data"
        ]

        let data = AskUserQuestionData.from(input, requestId: "test-req-3")

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

        let data = AskUserQuestionData(requestId: "test-request-1", questions: [question])
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

        let data = AskUserQuestionData(requestId: "test-request-2", questions: [question])
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

        let data = AskUserQuestionData(requestId: "test-request-3", questions: [question])
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
