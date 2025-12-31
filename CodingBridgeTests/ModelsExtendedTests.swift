import SwiftUI
import UIKit
import XCTest
@testable import CodingBridge

final class ModelsExtendedTests: XCTestCase {

    private struct DescribedValue: CustomStringConvertible {
        let description: String
    }

    private struct ChatMessageDTOStub: Codable {
        let id: UUID
        let role: String
        let content: String
        let timestamp: Date
        let imageFilename: String?
        let executionTime: TimeInterval?
        let tokenCount: Int?
    }

    private var testProjectPath: String!
    private var documentsDir: URL!

    override func setUp() {
        super.setUp()
        testProjectPath = "/test/project/\(UUID().uuidString)"
        documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    override func tearDown() {
        MessageStore.clearMessages(for: testProjectPath)
        MessageStore.clearDraft(for: testProjectPath)
        MessageStore.clearSessionId(for: testProjectPath)
        MessageStore.clearProcessingState(for: testProjectPath)
        UserDefaults.standard.removeObject(forKey: oldUserDefaultsKey(for: testProjectPath))
        waitForFileOperations(delay: 0.1)
        super.tearDown()
    }

    private func waitForFileOperations(delay: TimeInterval = 0.2) {
        let expectation = XCTestExpectation(description: "File operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    private func safeKey(for projectPath: String) -> String {
        projectPath
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private func projectDirectory(for projectPath: String) -> URL {
        documentsDir
            .appendingPathComponent("Messages", isDirectory: true)
            .appendingPathComponent(safeKey(for: projectPath), isDirectory: true)
    }

    private func messagesFile(for projectPath: String) -> URL {
        projectDirectory(for: projectPath).appendingPathComponent("messages.json")
    }

    private func imagesDirectory(for projectPath: String) -> URL {
        projectDirectory(for: projectPath).appendingPathComponent("images", isDirectory: true)
    }

    private func oldUserDefaultsKey(for projectPath: String) -> String {
        "chat_messages_" + safeKey(for: projectPath)
    }

    private func writeMessagesJSON(_ dtos: [ChatMessageDTOStub], for projectPath: String) throws {
        let directory = projectDirectory(for: projectPath)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(dtos)
        try data.write(to: messagesFile(for: projectPath), options: .atomic)
    }

    private func rgbaComponents(for color: Color) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return (red, green, blue, alpha)
        }
        var white: CGFloat = 0
        if uiColor.getWhite(&white, alpha: &alpha) {
            return (white, white, white, alpha)
        }
        return (0, 0, 0, 0)
    }

    private func assertColorEqual(
        _ actual: Color,
        _ expected: Color,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actualComponents = rgbaComponents(for: actual)
        let expectedComponents = rgbaComponents(for: expected)
        XCTAssertEqual(actualComponents.0, expectedComponents.0, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(actualComponents.1, expectedComponents.1, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(actualComponents.2, expectedComponents.2, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(actualComponents.3, expectedComponents.3, accuracy: 0.01, file: file, line: line)
    }

    private func makeSession(
        id: String,
        summary: String? = nil,
        messageCount: Int? = nil,
        lastActivity: String? = nil,
        lastUserMessage: String? = nil
    ) -> ProjectSession {
        ProjectSession(
            id: id,
            projectPath: nil,
            summary: summary,
            lastActivity: lastActivity,
            messageCount: messageCount,
            lastUserMessage: lastUserMessage,
            lastAssistantMessage: nil
        )
    }

    // MARK: - stringifyAnyValue

    func test_stringifyAnyValue_returnsString() {
        XCTAssertEqual(stringifyAnyValue("hello"), "hello")
    }

    func test_stringifyAnyValue_nsNumberReturnsString() {
        XCTAssertEqual(stringifyAnyValue(NSNumber(value: 42)), "42")
    }

    func test_stringifyAnyValue_anyCodableValueUsesStringValue() {
        let wrapped = AnyCodableValue("wrapped")

        XCTAssertEqual(stringifyAnyValue(wrapped), "wrapped")
    }

    func test_stringifyAnyValue_dictWithStdoutReturnsStdout() {
        let dict: [String: Any] = ["stdout": "ok", "code": 0]

        XCTAssertEqual(stringifyAnyValue(dict), "ok")
    }

    func test_stringifyAnyValue_dictWithoutStdoutReturnsJson() throws {
        let dict: [String: Any] = ["error": "nope", "code": 2]
        let output = stringifyAnyValue(dict)

        let data = try XCTUnwrap(output.data(using: .utf8))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["error"] as? String, "nope")
        XCTAssertEqual(json["code"] as? Int, 2)
    }

    func test_stringifyAnyValue_arrayReturnsJson() throws {
        let output = stringifyAnyValue([1, "two"])

        let data = try XCTUnwrap(output.data(using: .utf8))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [Any])
        XCTAssertEqual(json.count, 2)
        XCTAssertEqual(json[0] as? Int, 1)
        XCTAssertEqual(json[1] as? String, "two")
    }

    func test_stringifyAnyValue_stripsAnyCodableWrapper() {
        let value = DescribedValue(description: "AnyCodable(value: 123)")

        XCTAssertEqual(stringifyAnyValue(value), "123")
    }

    func test_stringifyAnyValue_stripsAnyCodableValueWrapper() {
        let value = DescribedValue(description: "AnyCodableValue(value: hello)")

        XCTAssertEqual(stringifyAnyValue(value), "hello")
    }

    func test_stringifyAnyValue_fallbackUsesDescription() {
        let value = DescribedValue(description: "CustomType(value: 7)")

        XCTAssertEqual(stringifyAnyValue(value), "CustomType(value: 7)")
    }

    // MARK: - ClaudeModel

    func test_claudeModel_displayProperties() {
        let cases: [(ClaudeModel, String, String, String, String)] = [
            (.opus, "Opus 4.5", "Opus", "Most capable for complex work", "brain.head.profile"),
            (.sonnet, "Sonnet 4.5", "Sonnet", "Best for everyday tasks", "sparkles"),
            (.haiku, "Haiku 4.5", "Haiku", "Fastest for quick answers", "bolt.fill"),
            (.custom, "Custom", "Custom", "Custom model ID", "gearshape")
        ]

        for (model, displayName, shortName, description, icon) in cases {
            XCTAssertEqual(model.displayName, displayName)
            XCTAssertEqual(model.shortName, shortName)
            XCTAssertEqual(model.description, description)
            XCTAssertEqual(model.icon, icon)
        }
    }

    func test_claudeModel_modelIdMapping() {
        XCTAssertEqual(ClaudeModel.opus.modelId, "opus")
        XCTAssertEqual(ClaudeModel.sonnet.modelId, "sonnet")
        XCTAssertEqual(ClaudeModel.haiku.modelId, "haiku")
        XCTAssertNil(ClaudeModel.custom.modelId)
    }

    func test_claudeModel_color_lightScheme() {
        assertColorEqual(ClaudeModel.opus.color(for: .light), Color(red: 0.5, green: 0.3, blue: 0.7))
        assertColorEqual(ClaudeModel.sonnet.color(for: .light), Color(red: 0.0, green: 0.55, blue: 0.7))
        assertColorEqual(ClaudeModel.haiku.color(for: .light), Color(red: 0.7, green: 0.55, blue: 0.0))
        assertColorEqual(ClaudeModel.custom.color(for: .light), Color(white: 0.4))
    }

    func test_claudeModel_color_darkScheme() {
        assertColorEqual(ClaudeModel.opus.color(for: .dark), Color(red: 0.7, green: 0.5, blue: 0.9))
        assertColorEqual(ClaudeModel.sonnet.color(for: .dark), Color(red: 0.4, green: 0.8, blue: 0.9))
        assertColorEqual(ClaudeModel.haiku.color(for: .dark), Color(red: 0.9, green: 0.8, blue: 0.4))
        assertColorEqual(ClaudeModel.custom.color(for: .dark), Color(white: 0.6))
    }

    // MARK: - Project

    func test_project_totalSessionCount_prefersSessionMeta() {
        let meta = ProjectSessionMeta(hasMore: true, total: 5)
        let project = Project(
            name: "demo",
            path: "/tmp/project",
            displayName: nil,
            fullPath: nil,
            sessions: [makeSession(id: "one", messageCount: 1)],
            sessionMeta: meta
        )

        XCTAssertEqual(project.totalSessionCount, 5)
    }

    func test_project_totalSessionCount_usesSessionsCountWhenMetaNil() {
        let project = Project(
            name: "demo",
            path: "/tmp/project",
            displayName: nil,
            fullPath: nil,
            sessions: [makeSession(id: "one", messageCount: 1), makeSession(id: "two", messageCount: 1)],
            sessionMeta: nil
        )

        XCTAssertEqual(project.totalSessionCount, 2)
    }

    func test_project_totalSessionCount_defaultsToZero() {
        let project = Project(
            name: "demo",
            path: "/tmp/project",
            displayName: nil,
            fullPath: nil,
            sessions: nil,
            sessionMeta: nil
        )

        XCTAssertEqual(project.totalSessionCount, 0)
    }

    func test_project_hasMoreSessions_trueWhenMetaTrue() {
        let meta = ProjectSessionMeta(hasMore: true, total: 1)
        let project = Project(
            name: "demo",
            path: "/tmp/project",
            displayName: nil,
            fullPath: nil,
            sessions: nil,
            sessionMeta: meta
        )

        XCTAssertTrue(project.hasMoreSessions)
    }

    func test_project_hasMoreSessions_falseWhenMetaNil() {
        let project = Project(
            name: "demo",
            path: "/tmp/project",
            displayName: nil,
            fullPath: nil,
            sessions: nil,
            sessionMeta: nil
        )

        XCTAssertFalse(project.hasMoreSessions)
    }

    func test_project_displaySessions_filtersAgentAndEmpty() {
        let projectPath = "/tmp/project"
        let sessions = [
            makeSession(id: "agent-test-123", messageCount: 1),
            makeSession(id: "empty", messageCount: 0),
            makeSession(id: "kept", messageCount: 2)
        ]
        let project = Project(
            name: "demo",
            path: projectPath,
            displayName: nil,
            fullPath: nil,
            sessions: sessions,
            sessionMeta: nil
        )

        XCTAssertEqual(project.displaySessions.map { $0.id }, ["kept"])
    }

    func test_project_sortedDisplaySessions_sortsByLastActivityAndFilters() {
        let projectPath = "/tmp/project"
        let sessions = [
            makeSession(id: "agent-test-123", messageCount: 1, lastActivity: "2025-01-01T00:00:00Z"),
            makeSession(id: "older", messageCount: 1, lastActivity: "2025-01-01T00:00:00Z"),
            makeSession(id: "newer", messageCount: 1, lastActivity: "2025-03-01T00:00:00Z"),
            makeSession(id: "empty", messageCount: 0, lastActivity: "2025-04-01T00:00:00Z")
        ]
        let project = Project(
            name: "demo",
            path: projectPath,
            displayName: nil,
            fullPath: nil,
            sessions: sessions,
            sessionMeta: nil
        )

        XCTAssertEqual(project.sortedDisplaySessions.map { $0.id }, ["newer", "older"])
    }

    // MARK: - ProjectSession filtering

    func test_filterForDisplay_excludesAgentSession() {
        let projectPath = "/tmp/filter-agent"
        let sessions = [
            makeSession(id: "agent-test-123", messageCount: 2),
            makeSession(id: "user", messageCount: 2)
        ]

        let filtered = sessions.filterForDisplay(projectPath: projectPath)

        XCTAssertEqual(filtered.map { $0.id }, ["user"])
    }

    func test_filterForDisplay_excludesEmptySessions() {
        let projectPath = "/tmp/filter-empty"
        let sessions = [
            makeSession(id: "empty", messageCount: 0),
            makeSession(id: "ok", messageCount: 1)
        ]

        let filtered = sessions.filterForDisplay(projectPath: projectPath)

        XCTAssertEqual(filtered.map { $0.id }, ["ok"])
    }

    func test_filterForDisplay_keepsNilMessageCount() {
        let projectPath = "/tmp/filter-nil"
        let sessions = [
            makeSession(id: "nil", messageCount: nil),
            makeSession(id: "ok", messageCount: 1)
        ]

        let filtered = sessions.filterForDisplay(projectPath: projectPath)

        XCTAssertEqual(filtered.map { $0.id }, ["nil", "ok"])
    }

    func test_filterForDisplay_includesActiveSessionEvenIfAgent() {
        let projectPath = "/tmp/filter-active"
        let agentId = "agent-active-123"
        let sessions = [
            makeSession(id: agentId, messageCount: 0),
            makeSession(id: "ok", messageCount: 1)
        ]

        let filtered = sessions.filterForDisplay(projectPath: projectPath, activeSessionId: agentId)

        XCTAssertEqual(filtered.map { $0.id }, [agentId, "ok"])
    }

    func test_filterAndSortForDisplay_sortsByLastActivityDescending() {
        let projectPath = "/tmp/filter-sort"
        let sessions = [
            makeSession(id: "older", messageCount: 1, lastActivity: "2025-01-01T00:00:00Z"),
            makeSession(id: "newer", messageCount: 1, lastActivity: "2025-03-01T00:00:00Z"),
            makeSession(id: "middle", messageCount: 1, lastActivity: "2025-02-01T00:00:00Z")
        ]

        let sorted = sessions.filterAndSortForDisplay(projectPath: projectPath)

        XCTAssertEqual(sorted.map { $0.id }, ["newer", "middle", "older"])
    }

    func test_filterAndSortForDisplay_placesNilLastActivityLast() {
        let projectPath = "/tmp/filter-nil-activity"
        let sessions = [
            makeSession(id: "nil", messageCount: 1, lastActivity: nil),
            makeSession(id: "dated", messageCount: 1, lastActivity: "2025-02-01T00:00:00Z")
        ]

        let sorted = sessions.filterAndSortForDisplay(projectPath: projectPath)

        XCTAssertEqual(sorted.map { $0.id }, ["dated", "nil"])
    }

    // MARK: - ChatMessage

    func test_chatMessage_explicitIdInitializer_preservesId() {
        let id = UUID()
        let message = ChatMessage(id: id, role: .user, content: "Hello")

        XCTAssertEqual(message.id, id)
    }

    func test_chatMessage_explicitIdInitializer_equalityUsesId() {
        let id = UUID()
        let first = ChatMessage(id: id, role: .user, content: "One")
        let second = ChatMessage(id: id, role: .assistant, content: "Two")

        XCTAssertEqual(first, second)
    }

    func test_chatMessage_codableRoundTrip_preservesFields() throws {
        let id = UUID()
        let timestamp = Date(timeIntervalSince1970: 12345)
        let imageData = Data([0x01, 0x02, 0x03])
        let original = ChatMessage(
            id: id,
            role: .assistant,
            content: "Content",
            timestamp: timestamp,
            isStreaming: true,
            imageData: imageData,
            executionTime: 1.25,
            tokenCount: 55
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.role, .assistant)
        XCTAssertEqual(decoded.content, "Content")
        XCTAssertEqual(decoded.timestamp, timestamp)
        XCTAssertTrue(decoded.isStreaming)
        XCTAssertEqual(decoded.imageData, imageData)
        XCTAssertEqual(decoded.executionTime, 1.25)
        XCTAssertEqual(decoded.tokenCount, 55)
    }

    // MARK: - ChatMessageDTO cleaning (via MessageStore)

    func test_chatMessageDTO_cleanAnyCodableWrappers_stripsQuotedValue() async throws {
        let content = "AnyCodableValue(value: \"Hello\")"
        let dto = ChatMessageDTOStub(
            id: UUID(),
            role: "user",
            content: content,
            timestamp: Date(timeIntervalSince1970: 1000),
            imageFilename: nil,
            executionTime: nil,
            tokenCount: nil
        )

        try writeMessagesJSON([dto], for: testProjectPath)

        let loaded = await MessageStore.loadMessages(for: testProjectPath)
        XCTAssertEqual(loaded.first?.content, "Hello")
    }

    func test_chatMessageDTO_cleanAnyCodableWrappers_stripsUnquotedValue() async throws {
        let content = "AnyCodableValue(value: 123)"
        let dto = ChatMessageDTOStub(
            id: UUID(),
            role: "user",
            content: content,
            timestamp: Date(timeIntervalSince1970: 1000),
            imageFilename: nil,
            executionTime: nil,
            tokenCount: nil
        )

        try writeMessagesJSON([dto], for: testProjectPath)

        let loaded = await MessageStore.loadMessages(for: testProjectPath)
        XCTAssertEqual(loaded.first?.content, "123")
    }

    func test_chatMessageDTO_cleanAnyCodableWrappers_handlesMultipleWrappers() async throws {
        let content = "AnyCodableValue(value: \"One\") and AnyCodableValue(value: 2)"
        let dto = ChatMessageDTOStub(
            id: UUID(),
            role: "user",
            content: content,
            timestamp: Date(timeIntervalSince1970: 1000),
            imageFilename: nil,
            executionTime: nil,
            tokenCount: nil
        )

        try writeMessagesJSON([dto], for: testProjectPath)

        let loaded = await MessageStore.loadMessages(for: testProjectPath)
        XCTAssertEqual(loaded.first?.content, "One and 2")
    }

    // MARK: - MessageStore

    func test_messageStore_loadMessages_asyncLoadsSavedMessages() async {
        let message = ChatMessage(role: .user, content: "Hello")

        MessageStore.saveMessages([message], for: testProjectPath)
        waitForFileOperations(delay: 0.2)

        let loaded = await MessageStore.loadMessages(for: testProjectPath)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.content, "Hello")
    }

    func test_messageStore_saveMessages_withImage_writesImageFile() {
        let imageData = Data([0x10, 0x11])
        let message = ChatMessage(role: .user, content: "Image", imageData: imageData)

        MessageStore.saveMessages([message], for: testProjectPath)
        waitForFileOperations(delay: 0.3)

        let imagePath = imagesDirectory(for: testProjectPath).appendingPathComponent("\(message.id.uuidString).jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: imagePath.path))
    }

    func test_messageStore_saveMessages_withImage_loadsImageData() async {
        let imageData = Data([0x01, 0x02, 0x03])
        let message = ChatMessage(role: .user, content: "Image", imageData: imageData)

        MessageStore.saveMessages([message], for: testProjectPath)
        waitForFileOperations(delay: 0.3)

        let loaded = await MessageStore.loadMessages(for: testProjectPath)
        // MessageStore uses lazy loading - imagePath is set instead of imageData
        XCTAssertNotNil(loaded.first?.imagePath, "Image path should be set for lazy loading")
        // Verify the file exists and contains the correct data
        guard let path = loaded.first?.imagePath else {
            XCTFail("Image path should not be nil")
            return
        }
        let loadedImageData = try? Data(contentsOf: URL(fileURLWithPath: path))
        XCTAssertEqual(loadedImageData, imageData)
    }

    func test_messageStore_clearMessages_removesProjectDirectory() async {
        let message = ChatMessage(role: .user, content: "Delete")

        MessageStore.saveMessages([message], for: testProjectPath)
        waitForFileOperations(delay: 0.2)

        MessageStore.clearMessages(for: testProjectPath)
        waitForFileOperations(delay: 0.2)

        XCTAssertFalse(FileManager.default.fileExists(atPath: projectDirectory(for: testProjectPath).path))
        let loaded = await MessageStore.loadMessages(for: testProjectPath)
        XCTAssertEqual(loaded.count, 0)
    }

    func test_messageStore_migrateFromUserDefaults_movesDataAndRemovesKey() async throws {
        let message = ChatMessage(role: .user, content: "Legacy")
        let data = try JSONEncoder().encode([message])
        UserDefaults.standard.set(data, forKey: oldUserDefaultsKey(for: testProjectPath))

        let loaded = await MessageStore.loadMessages(for: testProjectPath)

        XCTAssertEqual(loaded.count, 1)
        XCTAssertNil(UserDefaults.standard.data(forKey: oldUserDefaultsKey(for: testProjectPath)))

        waitForFileOperations(delay: 0.2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: messagesFile(for: testProjectPath).path))
    }

    func test_messageStore_loadMessages_invalidJsonReturnsEmpty() async throws {
        let directory = projectDirectory(for: testProjectPath)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: messagesFile(for: testProjectPath), options: .atomic)

        let loaded = await MessageStore.loadMessages(for: testProjectPath)
        XCTAssertEqual(loaded.count, 0)
    }

    func test_messageStore_cleanupOrphanedImages_removesStaleUuidFile() {
        let imagesDir = imagesDirectory(for: testProjectPath)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        let staleId = UUID()
        let stalePath = imagesDir.appendingPathComponent("\(staleId.uuidString).jpg")
        try? Data([0x01]).write(to: stalePath)

        MessageStore.saveMessages([], for: testProjectPath)
        waitForFileOperations(delay: 0.3)

        XCTAssertFalse(FileManager.default.fileExists(atPath: stalePath.path))
    }

    func test_messageStore_cleanupOrphanedImages_preservesNonUuidFile() {
        let imagesDir = imagesDirectory(for: testProjectPath)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        let extraPath = imagesDir.appendingPathComponent("not-a-uuid.jpg")
        try? Data([0x02]).write(to: extraPath)

        MessageStore.saveMessages([], for: testProjectPath)
        waitForFileOperations(delay: 0.3)

        XCTAssertTrue(FileManager.default.fileExists(atPath: extraPath.path))
    }

    func test_messageStore_saveDraft_andLoad() {
        MessageStore.saveDraft("Draft", for: testProjectPath)

        XCTAssertEqual(MessageStore.loadDraft(for: testProjectPath), "Draft")
    }

    func test_messageStore_saveDraft_emptyRemoves() {
        MessageStore.saveDraft("Draft", for: testProjectPath)
        MessageStore.saveDraft("", for: testProjectPath)

        XCTAssertEqual(MessageStore.loadDraft(for: testProjectPath), "")
    }

    func test_messageStore_clearDraft_removes() {
        MessageStore.saveDraft("Draft", for: testProjectPath)
        MessageStore.clearDraft(for: testProjectPath)

        XCTAssertEqual(MessageStore.loadDraft(for: testProjectPath), "")
    }

    func test_messageStore_saveSessionId_andLoad() {
        MessageStore.saveSessionId("session-1", for: testProjectPath)

        XCTAssertEqual(MessageStore.loadSessionId(for: testProjectPath), "session-1")
    }

    func test_messageStore_saveSessionId_emptyRemoves() {
        MessageStore.saveSessionId("session-1", for: testProjectPath)
        MessageStore.saveSessionId("", for: testProjectPath)

        XCTAssertNil(MessageStore.loadSessionId(for: testProjectPath))
    }

    func test_messageStore_clearSessionId_removes() {
        MessageStore.saveSessionId("session-1", for: testProjectPath)
        MessageStore.clearSessionId(for: testProjectPath)

        XCTAssertNil(MessageStore.loadSessionId(for: testProjectPath))
    }

    func test_messageStore_loadProcessingState_defaultsFalse() {
        MessageStore.clearProcessingState(for: testProjectPath)

        XCTAssertFalse(MessageStore.loadProcessingState(for: testProjectPath))
    }

    func test_messageStore_saveProcessingState_truePersists() {
        MessageStore.saveProcessingState(true, for: testProjectPath)

        XCTAssertTrue(MessageStore.loadProcessingState(for: testProjectPath))
    }

    func test_messageStore_saveProcessingState_falseClears() {
        MessageStore.saveProcessingState(true, for: testProjectPath)
        MessageStore.saveProcessingState(false, for: testProjectPath)

        XCTAssertFalse(MessageStore.loadProcessingState(for: testProjectPath))
    }

    func test_messageStore_clearProcessingState_removes() {
        MessageStore.saveProcessingState(true, for: testProjectPath)
        MessageStore.clearProcessingState(for: testProjectPath)

        XCTAssertFalse(MessageStore.loadProcessingState(for: testProjectPath))
    }
}
