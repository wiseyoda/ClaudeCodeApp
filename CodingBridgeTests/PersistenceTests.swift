import XCTest
@testable import CodingBridge

@MainActor
final class PersistenceTests: XCTestCase {
    private let draftPersistence = DraftInputPersistence.shared
    private let queuePersistence = MessageQueuePersistence.shared

    private var queueFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pending-messages.json")
    }

    override func setUp() {
        super.setUp()
        draftPersistence.clear()
        queuePersistence.clear()
        try? FileManager.default.removeItem(at: queueFileURL)
    }

    override func tearDown() {
        draftPersistence.clear()
        queuePersistence.clear()
        try? FileManager.default.removeItem(at: queueFileURL)
        super.tearDown()
    }

    // MARK: - DraftInputPersistence

    func test_draftSaveStoresFieldsAndTimestamp() {
        draftPersistence.save(draft: "Hello", sessionId: "session-1", projectPath: "/tmp/project")

        XCTAssertEqual(draftPersistence.currentDraft, "Hello")
        XCTAssertEqual(draftPersistence.draftSessionId, "session-1")
        XCTAssertEqual(draftPersistence.draftProjectPath, "/tmp/project")
        XCTAssertNotNil(draftPersistence.draftTimestamp)
        XCTAssertFalse(draftPersistence.isDraftStale)
    }

    func test_draftSaveDoesNotOverrideMissingFields() {
        draftPersistence.save(draft: "Hello", sessionId: "session-1", projectPath: "/tmp/project")

        draftPersistence.save(sessionId: "session-2")

        XCTAssertEqual(draftPersistence.currentDraft, "Hello")
        XCTAssertEqual(draftPersistence.draftSessionId, "session-2")
        XCTAssertEqual(draftPersistence.draftProjectPath, "/tmp/project")
    }

    func test_loadForSessionReturnsDraftWhenMatch() {
        draftPersistence.save(draft: "Draft", sessionId: "session-1", projectPath: "/tmp/project")

        XCTAssertEqual(draftPersistence.loadForSession("session-1"), "Draft")
    }

    func test_loadForSessionReturnsNilWhenMismatch() {
        draftPersistence.save(draft: "Draft", sessionId: "session-1", projectPath: "/tmp/project")

        XCTAssertNil(draftPersistence.loadForSession("session-2"))
    }

    func test_loadForSessionReturnsNilWhenDraftEmpty() {
        draftPersistence.save(draft: "", sessionId: "session-1", projectPath: "/tmp/project")

        XCTAssertNil(draftPersistence.loadForSession("session-1"))
    }

    func test_loadForProjectReturnsDraftWhenMatch() {
        draftPersistence.save(draft: "Draft", sessionId: "session-1", projectPath: "/tmp/project")

        XCTAssertEqual(draftPersistence.loadForProject("/tmp/project"), "Draft")
    }

    func test_loadForProjectReturnsNilWhenMismatch() {
        draftPersistence.save(draft: "Draft", sessionId: "session-1", projectPath: "/tmp/project")

        XCTAssertNil(draftPersistence.loadForProject("/other"))
    }

    func test_draftStaleTrueWhenTimestampMissing() {
        XCTAssertTrue(draftPersistence.isDraftStale)
    }

    func test_draftStaleTrueWhenOlderThanDay() {
        let oldDate = Date(timeIntervalSinceNow: -25 * 60 * 60)
        draftPersistence.draftTimestamp = oldDate

        XCTAssertTrue(draftPersistence.isDraftStale)
    }

    func test_draftStaleFalseWhenRecent() {
        draftPersistence.draftTimestamp = Date()

        XCTAssertFalse(draftPersistence.isDraftStale)
    }

    func test_clearResetsDraft() {
        draftPersistence.save(draft: "Draft", sessionId: "session-1", projectPath: "/tmp/project")

        draftPersistence.clear()

        XCTAssertEqual(draftPersistence.currentDraft, "")
        XCTAssertNil(draftPersistence.draftSessionId)
        XCTAssertNil(draftPersistence.draftProjectPath)
        XCTAssertNil(draftPersistence.draftTimestamp)
    }

    func test_clearIfSessionOnlyClearsMatchingSession() {
        draftPersistence.save(draft: "Draft", sessionId: "session-1", projectPath: "/tmp/project")

        draftPersistence.clearIfSession("session-2")
        XCTAssertEqual(draftPersistence.currentDraft, "Draft")

        draftPersistence.clearIfSession("session-1")
        XCTAssertEqual(draftPersistence.currentDraft, "")
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
