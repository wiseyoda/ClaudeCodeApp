import XCTest
@testable import CodingBridge

@MainActor
final class PersistenceTests: XCTestCase {
    private let queuePersistence = MessageQueuePersistence.shared

    private var queueFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pending-messages.json")
    }

    override func setUp() {
        super.setUp()
        queuePersistence.clear()
        try? FileManager.default.removeItem(at: queueFileURL)
        MessageStore.clearGlobalRecoveryState()
    }

    override func tearDown() {
        queuePersistence.clear()
        try? FileManager.default.removeItem(at: queueFileURL)
        MessageStore.clearGlobalRecoveryState()
        super.tearDown()
    }

    // MARK: - MessageStore Global Recovery State

    func test_saveGlobalRecoveryStatePersistsAllFields() {
        MessageStore.saveGlobalRecoveryState(
            wasProcessing: true,
            sessionId: "session-1",
            projectPath: "/tmp/project"
        )

        XCTAssertTrue(MessageStore.wasProcessingOnBackground)
        XCTAssertEqual(MessageStore.lastBackgroundSessionId, "session-1")
        XCTAssertEqual(MessageStore.lastBackgroundProjectPath, "/tmp/project")
    }

    func test_saveGlobalRecoveryStateHandlesNilValues() {
        // First set all values
        MessageStore.saveGlobalRecoveryState(
            wasProcessing: true,
            sessionId: "session-1",
            projectPath: "/tmp/project"
        )

        // Then save with nil values
        MessageStore.saveGlobalRecoveryState(
            wasProcessing: false,
            sessionId: nil,
            projectPath: nil
        )

        XCTAssertFalse(MessageStore.wasProcessingOnBackground)
        XCTAssertNil(MessageStore.lastBackgroundSessionId)
        XCTAssertNil(MessageStore.lastBackgroundProjectPath)
    }

    func test_clearGlobalRecoveryStateResetsAllFields() {
        MessageStore.saveGlobalRecoveryState(
            wasProcessing: true,
            sessionId: "session-1",
            projectPath: "/tmp/project"
        )

        MessageStore.clearGlobalRecoveryState()

        XCTAssertFalse(MessageStore.wasProcessingOnBackground)
        XCTAssertNil(MessageStore.lastBackgroundSessionId)
        XCTAssertNil(MessageStore.lastBackgroundProjectPath)
    }

    func test_wasProcessingOnBackgroundDefaultsToFalse() {
        MessageStore.clearGlobalRecoveryState()

        XCTAssertFalse(MessageStore.wasProcessingOnBackground)
    }

    // MARK: - MessageStore Draft Persistence

    func test_saveDraftPersistsText() {
        MessageStore.saveDraft("Hello world", for: "/tmp/project")

        XCTAssertEqual(MessageStore.loadDraft(for: "/tmp/project"), "Hello world")
    }

    func test_saveDraftEmptyStringClearsDraft() {
        MessageStore.saveDraft("Hello", for: "/tmp/project")
        MessageStore.saveDraft("", for: "/tmp/project")

        XCTAssertEqual(MessageStore.loadDraft(for: "/tmp/project"), "")
    }

    func test_clearDraftRemovesDraft() {
        MessageStore.saveDraft("Hello", for: "/tmp/project")
        MessageStore.clearDraft(for: "/tmp/project")

        XCTAssertEqual(MessageStore.loadDraft(for: "/tmp/project"), "")
    }

    func test_draftIsolatedPerProject() {
        MessageStore.saveDraft("Project 1 draft", for: "/tmp/project1")
        MessageStore.saveDraft("Project 2 draft", for: "/tmp/project2")

        XCTAssertEqual(MessageStore.loadDraft(for: "/tmp/project1"), "Project 1 draft")
        XCTAssertEqual(MessageStore.loadDraft(for: "/tmp/project2"), "Project 2 draft")
    }

    // MARK: - MessageQueuePersistence

    func test_enqueueAndDequeueUpdatesCount() {
        let message1 = PersistablePendingMessage(
            id: UUID(),
            message: "Hello",
            projectPath: "/tmp/project",
            sessionId: "session-1",
            permissionMode: nil,
            hasImage: false,
            model: "sonnet",
            attempts: 0,
            createdAt: Date()
        )
        let message2 = PersistablePendingMessage(
            id: UUID(),
            message: "Next",
            projectPath: "/tmp/project",
            sessionId: "session-2",
            permissionMode: "default",
            hasImage: true,
            model: nil,
            attempts: 1,
            createdAt: Date()
        )

        queuePersistence.enqueue(message1)
        queuePersistence.enqueue(message2)

        XCTAssertEqual(queuePersistence.pendingCount, 2)

        queuePersistence.dequeue(message1.id)

        XCTAssertEqual(queuePersistence.pendingCount, 1)
    }

    func test_saveRemovesFileWhenEmpty() async {
        await queuePersistence.save()

        XCTAssertFalse(FileManager.default.fileExists(atPath: queueFileURL.path))
    }

    func test_saveAndLoadRoundTrip() async {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let message = PersistablePendingMessage(
            id: UUID(),
            message: "Persist",
            projectPath: "/tmp/project",
            sessionId: "session-1",
            permissionMode: "default",
            hasImage: false,
            model: "haiku",
            attempts: 2,
            createdAt: createdAt
        )

        queuePersistence.enqueue(message)
        await queuePersistence.save()

        let loaded = await queuePersistence.load()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, message.id)
        XCTAssertEqual(loaded.first?.message, "Persist")
        XCTAssertEqual(loaded.first?.projectPath, "/tmp/project")
        XCTAssertEqual(loaded.first?.sessionId, "session-1")
        XCTAssertEqual(loaded.first?.permissionMode, "default")
        XCTAssertEqual(loaded.first?.hasImage, false)
        XCTAssertEqual(loaded.first?.model, "haiku")
        XCTAssertEqual(loaded.first?.attempts, 2)
        XCTAssertEqual(loaded.first?.createdAt, createdAt)
    }

    func test_loadReturnsEmptyWhenFileMissing() async {
        try? FileManager.default.removeItem(at: queueFileURL)

        let loaded = await queuePersistence.load()

        XCTAssertTrue(loaded.isEmpty)
    }

    func test_loadReturnsEmptyWhenCorrupted() async {
        let data = Data("not-json".utf8)
        try? data.write(to: queueFileURL)

        let loaded = await queuePersistence.load()

        XCTAssertTrue(loaded.isEmpty)
    }

    func test_clearRemovesFileAndResetsCount() async {
        let message = PersistablePendingMessage(
            message: "Persist",
            projectPath: "/tmp/project",
            sessionId: nil,
            permissionMode: nil,
            hasImage: false,
            model: nil
        )
        queuePersistence.enqueue(message)
        await queuePersistence.save()

        queuePersistence.clear()

        XCTAssertEqual(queuePersistence.pendingCount, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: queueFileURL.path))
    }
}
