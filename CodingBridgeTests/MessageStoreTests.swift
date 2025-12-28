import XCTest
@testable import CodingBridge

final class MessageStoreTests: XCTestCase {

    private var testProjectPath: String!
    private var documentsDir: URL!

    private func waitForFileOperations(delay: TimeInterval = 0.3) {
        let expectation = XCTestExpectation(description: "File operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    private func imagesDirectory(for projectPath: String) -> URL {
        let safeKey = projectPath
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        return documentsDir
            .appendingPathComponent("Messages", isDirectory: true)
            .appendingPathComponent(safeKey, isDirectory: true)
            .appendingPathComponent("images", isDirectory: true)
    }

    override func setUp() {
        super.setUp()
        // Use a unique test project path to avoid collisions
        testProjectPath = "/test/project/\(UUID().uuidString)"
        documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    override func tearDown() {
        // Clean up test data
        MessageStore.clearMessages(for: testProjectPath)
        MessageStore.clearDraft(for: testProjectPath)
        MessageStore.clearSessionId(for: testProjectPath)

        // Give async operations time to complete
        waitForFileOperations(delay: 0.1)

        super.tearDown()
    }

    // MARK: - Load/Save Messages Tests

    func test_loadMessages_emptyProject_returnsEmptyArray() async {
        let messages = await MessageStore.loadMessages(for: testProjectPath)

        XCTAssertEqual(messages.count, 0)
    }

    func test_saveMessages_thenLoad_returnsSavedMessages() async {
        // Given
        let message1 = ChatMessage(role: .user, content: "Hello")
        let message2 = ChatMessage(role: .assistant, content: "Hi there!")

        // When
        MessageStore.saveMessages([message1, message2], for: testProjectPath)

        // Wait for async save
        waitForFileOperations(delay: 0.2)

        // Then
        let loaded = await MessageStore.loadMessages(for: testProjectPath)

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].content, "Hello")
        XCTAssertEqual(loaded[0].role, .user)
        XCTAssertEqual(loaded[1].content, "Hi there!")
        XCTAssertEqual(loaded[1].role, .assistant)
    }

    func test_saveMessages_excludesStreamingMessages() async {
        // Given
        let regularMessage = ChatMessage(role: .user, content: "Regular")
        let streamingMessage = ChatMessage(role: .assistant, content: "Streaming...", isStreaming: true)

        // When
        MessageStore.saveMessages([regularMessage, streamingMessage], for: testProjectPath)

        // Wait for async save
        waitForFileOperations(delay: 0.2)

        // Then
        let loaded = await MessageStore.loadMessages(for: testProjectPath)

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].content, "Regular")
    }

    func test_saveMessages_limitsToMaxMessages() async {
        // Given - create more than 50 messages
        var messages: [ChatMessage] = []
        for i in 1...60 {
            messages.append(ChatMessage(role: .user, content: "Message \(i)"))
        }

        // When
        MessageStore.saveMessages(messages, for: testProjectPath)

        // Wait for async save
        waitForFileOperations(delay: 0.3)

        // Then - should only keep last 50
        let loaded = await MessageStore.loadMessages(for: testProjectPath)

        XCTAssertEqual(loaded.count, 50)
        // First saved message should be "Message 11" (60-50+1=11)
        XCTAssertEqual(loaded[0].content, "Message 11")
        // Last saved message should be "Message 60"
        XCTAssertEqual(loaded[49].content, "Message 60")
    }

    func test_clearMessages_removesAllMessages() async {
        // Given
        let message = ChatMessage(role: .user, content: "To be deleted")
        MessageStore.saveMessages([message], for: testProjectPath)

        // Wait for save
        waitForFileOperations(delay: 0.2)

        // When
        MessageStore.clearMessages(for: testProjectPath)

        // Wait for clear
        waitForFileOperations(delay: 0.2)

        // Then
        let loaded = await MessageStore.loadMessages(for: testProjectPath)
        XCTAssertEqual(loaded.count, 0)
    }

    func test_saveMessages_preservesMessageRoles() async {
        // Given - messages with different roles
        let roles: [ChatMessage.Role] = [.user, .assistant, .system, .error, .toolUse, .toolResult, .resultSuccess, .thinking]
        let messages = roles.map { ChatMessage(role: $0, content: "Role: \($0.rawValue)") }

        // When
        MessageStore.saveMessages(messages, for: testProjectPath)

        // Wait for save
        waitForFileOperations(delay: 0.2)

        // Then
        let loaded = await MessageStore.loadMessages(for: testProjectPath)

        XCTAssertEqual(loaded.count, roles.count)
        for (index, role) in roles.enumerated() {
            XCTAssertEqual(loaded[index].role, role)
        }
    }

    func test_saveMessages_preservesTimestamps() async {
        // Given
        let timestamp = Date(timeIntervalSince1970: 1704067200) // 2024-01-01 00:00:00 UTC
        let message = ChatMessage(role: .user, content: "Timestamped", timestamp: timestamp)

        // When
        MessageStore.saveMessages([message], for: testProjectPath)

        // Wait for save
        waitForFileOperations(delay: 0.2)

        // Then
        let loaded = await MessageStore.loadMessages(for: testProjectPath)

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].timestamp, timestamp)
    }

    // MARK: - Image Persistence Tests

    func test_saveMessages_withImageData_persistsAndLoadsImage() async {
        // Given
        let imageData = Data([0x00, 0x01, 0x02])
        let message = ChatMessage(role: .user, content: "With image", imageData: imageData)

        // When
        MessageStore.saveMessages([message], for: testProjectPath)

        // Wait for save
        waitForFileOperations(delay: 0.3)

        // Then
        let loaded = await MessageStore.loadMessages(for: testProjectPath)

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].imageData, imageData)
    }

    func test_saveMessages_cleansUpOrphanedImages() {
        // Given
        let imageData1 = Data([0x10, 0x11])
        let imageData2 = Data([0x20, 0x21])
        let message1 = ChatMessage(role: .user, content: "Image one", imageData: imageData1)
        let message2 = ChatMessage(role: .user, content: "Image two", imageData: imageData2)

        // When
        MessageStore.saveMessages([message1, message2], for: testProjectPath)
        waitForFileOperations(delay: 0.3)

        MessageStore.saveMessages([message2], for: testProjectPath)
        waitForFileOperations(delay: 0.3)

        // Then
        let files = (try? FileManager.default.contentsOfDirectory(
            at: imagesDirectory(for: testProjectPath),
            includingPropertiesForKeys: nil
        )) ?? []

        let filenames = files.map { $0.lastPathComponent }
        XCTAssertEqual(filenames.count, 1)
        XCTAssertTrue(filenames.contains("\(message2.id.uuidString).jpg"))
    }

    // MARK: - UserDefaults Migration Tests

    func test_loadMessages_migratesFromUserDefaults() async throws {
        // Given
        let safeKey = testProjectPath
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        let oldKey = "chat_messages_" + safeKey

        let message1 = ChatMessage(role: .user, content: "Legacy one")
        let message2 = ChatMessage(role: .assistant, content: "Legacy two")
        let data = try JSONEncoder().encode([message1, message2])
        UserDefaults.standard.set(data, forKey: oldKey)

        // When
        let loaded = await MessageStore.loadMessages(for: testProjectPath)

        // Then
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].content, "Legacy one")
        XCTAssertNil(UserDefaults.standard.data(forKey: oldKey))

        waitForFileOperations(delay: 0.3)
        let reloaded = await MessageStore.loadMessages(for: testProjectPath)
        XCTAssertEqual(reloaded.count, 2)
    }

    func test_loadMessages_invalidUserDefaultsData_returnsEmpty() async {
        // Given
        let safeKey = testProjectPath
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        let oldKey = "chat_messages_" + safeKey
        let invalidData = Data("not-json".utf8)
        UserDefaults.standard.set(invalidData, forKey: oldKey)

        // When
        let loaded = await MessageStore.loadMessages(for: testProjectPath)

        // Then
        XCTAssertTrue(loaded.isEmpty)
        XCTAssertNotNil(UserDefaults.standard.data(forKey: oldKey))

        UserDefaults.standard.removeObject(forKey: oldKey)
    }

    // MARK: - Project Path Encoding Tests

    func test_saveMessages_handlesPathWithSlashes() async {
        // Given
        let pathWithSlashes = "/home/user/deep/nested/path"
        let message = ChatMessage(role: .user, content: "Deep nested")

        // When
        MessageStore.saveMessages([message], for: pathWithSlashes)

        // Wait for save
        waitForFileOperations(delay: 0.2)

        // Then
        let loaded = await MessageStore.loadMessages(for: pathWithSlashes)

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].content, "Deep nested")

        // Cleanup
        MessageStore.clearMessages(for: pathWithSlashes)
    }

    func test_saveMessages_handlesPathWithSpaces() async {
        // Given
        let pathWithSpaces = "/home/user/my project/code"
        let message = ChatMessage(role: .user, content: "Spaced path")

        // When
        MessageStore.saveMessages([message], for: pathWithSpaces)

        // Wait for save
        waitForFileOperations(delay: 0.2)

        // Then
        let loaded = await MessageStore.loadMessages(for: pathWithSpaces)

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].content, "Spaced path")

        // Cleanup
        MessageStore.clearMessages(for: pathWithSpaces)
    }

    // MARK: - Draft Persistence Tests

    func test_loadDraft_nonExistent_returnsEmptyString() {
        let draft = MessageStore.loadDraft(for: testProjectPath)

        XCTAssertEqual(draft, "")
    }

    func test_saveDraft_thenLoad_returnsSavedDraft() {
        // Given
        let draftText = "This is my draft message"

        // When
        MessageStore.saveDraft(draftText, for: testProjectPath)

        // Then
        let loaded = MessageStore.loadDraft(for: testProjectPath)

        XCTAssertEqual(loaded, draftText)
    }

    func test_saveDraft_emptyString_removesDraft() {
        // Given
        MessageStore.saveDraft("Initial draft", for: testProjectPath)
        XCTAssertEqual(MessageStore.loadDraft(for: testProjectPath), "Initial draft")

        // When
        MessageStore.saveDraft("", for: testProjectPath)

        // Then
        let loaded = MessageStore.loadDraft(for: testProjectPath)
        XCTAssertEqual(loaded, "")
    }

    func test_clearDraft_removesDraft() {
        // Given
        MessageStore.saveDraft("Draft to clear", for: testProjectPath)
        XCTAssertEqual(MessageStore.loadDraft(for: testProjectPath), "Draft to clear")

        // When
        MessageStore.clearDraft(for: testProjectPath)

        // Then
        let loaded = MessageStore.loadDraft(for: testProjectPath)
        XCTAssertEqual(loaded, "")
    }

    func test_saveDraft_preservesUnicodeContent() {
        // Given
        let unicodeDraft = "Hello World! Emoji test and Japanese: 日本語"

        // When
        MessageStore.saveDraft(unicodeDraft, for: testProjectPath)

        // Then
        let loaded = MessageStore.loadDraft(for: testProjectPath)
        XCTAssertEqual(loaded, unicodeDraft)
    }

    // MARK: - Session ID Persistence Tests

    func test_loadSessionId_nonExistent_returnsNil() {
        let sessionId = MessageStore.loadSessionId(for: testProjectPath)

        XCTAssertNil(sessionId)
    }

    func test_saveSessionId_thenLoad_returnsSavedSessionId() {
        // Given
        let sessionId = "session-abc-123"

        // When
        MessageStore.saveSessionId(sessionId, for: testProjectPath)

        // Then
        let loaded = MessageStore.loadSessionId(for: testProjectPath)

        XCTAssertEqual(loaded, sessionId)
    }

    func test_saveSessionId_nil_removesSessionId() {
        // Given
        MessageStore.saveSessionId("initial-session", for: testProjectPath)
        XCTAssertEqual(MessageStore.loadSessionId(for: testProjectPath), "initial-session")

        // When
        MessageStore.saveSessionId(nil, for: testProjectPath)

        // Then
        let loaded = MessageStore.loadSessionId(for: testProjectPath)
        XCTAssertNil(loaded)
    }

    func test_saveSessionId_emptyString_removesSessionId() {
        // Given
        MessageStore.saveSessionId("existing-session", for: testProjectPath)
        XCTAssertEqual(MessageStore.loadSessionId(for: testProjectPath), "existing-session")

        // When
        MessageStore.saveSessionId("", for: testProjectPath)

        // Then
        let loaded = MessageStore.loadSessionId(for: testProjectPath)
        XCTAssertNil(loaded)
    }

    func test_clearSessionId_removesSessionId() {
        // Given
        MessageStore.saveSessionId("session-to-clear", for: testProjectPath)
        XCTAssertEqual(MessageStore.loadSessionId(for: testProjectPath), "session-to-clear")

        // When
        MessageStore.clearSessionId(for: testProjectPath)

        // Then
        let loaded = MessageStore.loadSessionId(for: testProjectPath)
        XCTAssertNil(loaded)
    }

    // MARK: - Multi-Project Isolation Tests

    func test_messages_isolatedBetweenProjects() async {
        // Given
        let project1 = "/project/one/\(UUID().uuidString)"
        let project2 = "/project/two/\(UUID().uuidString)"

        let message1 = ChatMessage(role: .user, content: "Project 1 message")
        let message2 = ChatMessage(role: .user, content: "Project 2 message")

        // When
        MessageStore.saveMessages([message1], for: project1)
        MessageStore.saveMessages([message2], for: project2)

        // Wait for saves
        waitForFileOperations(delay: 0.3)

        // Then
        let loaded1 = await MessageStore.loadMessages(for: project1)
        let loaded2 = await MessageStore.loadMessages(for: project2)

        XCTAssertEqual(loaded1.count, 1)
        XCTAssertEqual(loaded1[0].content, "Project 1 message")

        XCTAssertEqual(loaded2.count, 1)
        XCTAssertEqual(loaded2[0].content, "Project 2 message")

        // Cleanup
        MessageStore.clearMessages(for: project1)
        MessageStore.clearMessages(for: project2)
    }

    func test_drafts_isolatedBetweenProjects() {
        // Given
        let project1 = "/draft/project/one"
        let project2 = "/draft/project/two"

        // When
        MessageStore.saveDraft("Draft for project 1", for: project1)
        MessageStore.saveDraft("Draft for project 2", for: project2)

        // Then
        XCTAssertEqual(MessageStore.loadDraft(for: project1), "Draft for project 1")
        XCTAssertEqual(MessageStore.loadDraft(for: project2), "Draft for project 2")

        // Cleanup
        MessageStore.clearDraft(for: project1)
        MessageStore.clearDraft(for: project2)
    }

    func test_sessionIds_isolatedBetweenProjects() {
        // Given
        let project1 = "/session/project/one"
        let project2 = "/session/project/two"

        // When
        MessageStore.saveSessionId("session-1", for: project1)
        MessageStore.saveSessionId("session-2", for: project2)

        // Then
        XCTAssertEqual(MessageStore.loadSessionId(for: project1), "session-1")
        XCTAssertEqual(MessageStore.loadSessionId(for: project2), "session-2")

        // Cleanup
        MessageStore.clearSessionId(for: project1)
        MessageStore.clearSessionId(for: project2)
    }
}
