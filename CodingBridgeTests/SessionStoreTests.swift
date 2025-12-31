import XCTest
@testable import CodingBridge

@MainActor
final class SessionStoreTests: XCTestCase {
    private var store: SessionStore!
    private var mockRepo: MockSessionRepository!

    override func setUp() {
        super.setUp()
        store = SessionStore.shared
        store.resetForTesting()  // Clear previous state so we can reconfigure
        mockRepo = MockSessionRepository()
        store.configure(with: mockRepo)
    }

    override func tearDown() {
        store.resetForTesting()
        super.tearDown()
    }

    private func makeProjectPath() -> String {
        "/tmp/session-store-tests-\(UUID().uuidString)"
    }

    private func makeSession(
        id: String = UUID().uuidString,
        summary: String? = nil,
        messageCount: Int? = 1,
        lastActivity: String? = nil
    ) -> ProjectSession {
        ProjectSession(
            id: id,
            summary: summary,
            lastActivity: lastActivity,
            messageCount: messageCount,
            lastUserMessage: nil,
            lastAssistantMessage: nil
        )
    }

    // MARK: - Loading Tests

    func testLoadSessionsStoresSessions() async {
        let path = makeProjectPath()
        let session1 = makeSession(id: "s1", summary: "First session")
        let session2 = makeSession(id: "s2", summary: "Second session")

        mockRepo.mockSessions = [session1, session2]
        mockRepo.mockTotal = 2
        mockRepo.mockHasMore = false

        await store.loadSessions(for: path, forceRefresh: true)

        XCTAssertTrue(mockRepo.fetchSessionsCalled)
        XCTAssertEqual(store.sessions(for: path).count, 2)
        XCTAssertEqual(store.sessionCount(for: path), 2)
        XCTAssertFalse(store.hasMore(for: path))
    }

    func testLoadSessionsHandlesError() async {
        let path = makeProjectPath()
        mockRepo.shouldThrowError = true

        await store.loadSessions(for: path, forceRefresh: true)

        XCTAssertNotNil(store.errorByProject[path])
        XCTAssertTrue(store.sessions(for: path).isEmpty)
    }

    func testHasLoadedReturnsTrueAfterLoad() async {
        let path = makeProjectPath()
        mockRepo.mockSessions = []
        mockRepo.mockTotal = 0

        XCTAssertFalse(store.hasLoaded(for: path))

        await store.loadSessions(for: path)

        XCTAssertTrue(store.hasLoaded(for: path))
    }

    // MARK: - Pagination Tests

    func testLoadMoreAppendsSessions() async {
        let path = makeProjectPath()
        let session1 = makeSession(id: "s1")
        let session2 = makeSession(id: "s2")
        let session3 = makeSession(id: "s3")

        // Initial load
        mockRepo.mockSessions = [session1, session2]
        mockRepo.mockTotal = 3
        mockRepo.mockHasMore = true

        await store.loadSessions(for: path, forceRefresh: true)
        XCTAssertEqual(store.sessions(for: path).count, 2)
        XCTAssertTrue(store.hasMore(for: path))

        // Load more
        mockRepo.mockSessions = [session1, session2, session3]
        mockRepo.mockTotal = 3
        mockRepo.mockHasMore = false

        await store.loadMore(for: path)
        XCTAssertEqual(store.sessions(for: path).count, 3)
        XCTAssertFalse(store.hasMore(for: path))
    }

    func testLoadMoreDoesNothingWhenNoMoreAvailable() async {
        let path = makeProjectPath()
        mockRepo.mockSessions = [makeSession(id: "s1")]
        mockRepo.mockTotal = 1
        mockRepo.mockHasMore = false

        await store.loadSessions(for: path)
        mockRepo.fetchSessionsCalled = false

        await store.loadMore(for: path)
        // Should not have called fetch again
        XCTAssertFalse(mockRepo.fetchSessionsCalled)
    }

    // MARK: - Session Addition Tests

    func testAddSessionInsertsAtFront() {
        let path = makeProjectPath()
        let first = makeSession(id: "first")
        let second = makeSession(id: "second")

        XCTAssertTrue(store.addSession(first, for: path))
        XCTAssertTrue(store.addSession(second, for: path))

        let sessions = store.sessions(for: path)
        XCTAssertEqual(sessions.map { $0.id }, ["second", "first"])
    }

    func testAddSessionRejectsDuplicate() {
        let path = makeProjectPath()
        let session = makeSession(id: "dup")

        XCTAssertTrue(store.addSession(session, for: path))
        XCTAssertFalse(store.addSession(session, for: path))
        XCTAssertEqual(store.sessions(for: path).count, 1)
    }

    // MARK: - Active Session Tests

    func testSetActiveSessionTracksId() {
        let path = makeProjectPath()

        store.setActiveSession("active-123", for: path)
        XCTAssertEqual(store.activeSessionId(for: path), "active-123")

        store.setActiveSession(nil, for: path)
        XCTAssertNil(store.activeSessionId(for: path))
    }

    func testDisplaySessionCountExcludesAgentSessions() {
        let path = makeProjectPath()
        let agent = makeSession(id: "agent-test-123", messageCount: 5)
        let regular = makeSession(id: "regular", messageCount: 1)

        store.addSession(agent, for: path)
        store.addSession(regular, for: path)

        XCTAssertEqual(store.displaySessionCount(for: path), 1)
    }

    // MARK: - WebSocket Event Tests

    func testHandleSessionsUpdatedDeletedRemovesSession() async {
        let path = makeProjectPath()
        let encodedPath = path.replacingOccurrences(of: "/", with: "-")
        let session = makeSession(id: "to-delete")

        store.addSession(session, for: path)
        XCTAssertEqual(store.sessions(for: path).count, 1)

        await store.handleSessionsUpdated(
            projectName: encodedPath,
            sessionId: "to-delete",
            action: "deleted"
        )

        XCTAssertTrue(store.sessions(for: path).isEmpty)
    }

    func testHandleSessionsUpdatedDeletedClearsActiveSession() async {
        let path = makeProjectPath()
        let encodedPath = path.replacingOccurrences(of: "/", with: "-")
        let session = makeSession(id: "active-session")

        store.addSession(session, for: path)
        store.setActiveSession("active-session", for: path)

        await store.handleSessionsUpdated(
            projectName: encodedPath,
            sessionId: "active-session",
            action: "deleted"
        )

        XCTAssertNil(store.activeSessionId(for: path))
    }

    func testHandleSessionsUpdatedCreatedReloadsSessions() async {
        let path = makeProjectPath()
        let encodedPath = path.replacingOccurrences(of: "/", with: "-")

        store.addSession(makeSession(id: "existing"), for: path)
        mockRepo.mockSessions = [makeSession(id: "new")]
        mockRepo.mockTotal = 1
        mockRepo.mockHasMore = false
        mockRepo.fetchSessionsCalled = false

        await store.handleSessionsUpdated(
            projectName: encodedPath,
            sessionId: "new",
            action: "created"
        )

        XCTAssertTrue(mockRepo.fetchSessionsCalled)
        XCTAssertEqual(store.sessions(for: path).first?.id, "new")
    }

    func testHandleSessionsUpdatedUpdatedReloadsSessions() async {
        let path = makeProjectPath()
        let encodedPath = path.replacingOccurrences(of: "/", with: "-")

        store.addSession(makeSession(id: "existing"), for: path)
        mockRepo.mockSessions = [makeSession(id: "updated")]
        mockRepo.mockTotal = 1
        mockRepo.mockHasMore = false
        mockRepo.fetchSessionsCalled = false

        await store.handleSessionsUpdated(
            projectName: encodedPath,
            sessionId: "updated",
            action: "updated"
        )

        XCTAssertTrue(mockRepo.fetchSessionsCalled)
        XCTAssertEqual(store.sessions(for: path).first?.id, "updated")
    }

    // MARK: - Bulk Operations Tests

    func testCountSessionsToDelete() {
        let path = makeProjectPath()
        let active = makeSession(id: "active")
        let other = makeSession(id: "other")

        store.addSession(active, for: path)
        store.addSession(other, for: path)
        store.setActiveSession("active", for: path)

        let (all, activeProtected) = store.countSessionsToDelete(for: path)
        XCTAssertEqual(all, 2)
        XCTAssertTrue(activeProtected)
    }
}
