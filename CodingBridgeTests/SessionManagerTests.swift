import XCTest
@testable import CodingBridge

@MainActor
final class SessionManagerTests: XCTestCase {
    private let sessionManager = SessionManager.shared

    private func makeProjectPath() -> String {
        "/tmp/session-tests-\(UUID().uuidString)"
    }

    private func makeSession(
        id: String = UUID().uuidString,
        summary: String? = nil,
        messageCount: Int? = nil,
        lastActivity: String? = nil
    ) -> ProjectSession {
        ProjectSession(
            id: id,
            summary: summary,
            messageCount: messageCount,
            lastActivity: lastActivity,
            lastUserMessage: nil,
            lastAssistantMessage: nil
        )
    }

    private func isoString(_ date: Date, fractional: Bool) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = fractional
            ? [.withInternetDateTime, .withFractionalSeconds]
            : [.withInternetDateTime]
        return formatter.string(from: date)
    }

    func testAddSessionInsertsAtFrontAndUpdatesCount() {
        let path = makeProjectPath()
        let first = makeSession(id: "first")
        let second = makeSession(id: "second")

        XCTAssertTrue(sessionManager.addSession(first, for: path))
        XCTAssertTrue(sessionManager.addSession(second, for: path))

        let sessions = sessionManager.sessions(for: path)
        XCTAssertEqual(sessions.map { $0.id }, ["second", "first"])
        XCTAssertEqual(sessionManager.sessionCount(for: path), 2)
    }

    func testAddSessionRejectsDuplicate() {
        let path = makeProjectPath()
        let session = makeSession(id: "dup")

        XCTAssertTrue(sessionManager.addSession(session, for: path))
        XCTAssertFalse(sessionManager.addSession(session, for: path))
        XCTAssertEqual(sessionManager.sessionCount(for: path), 1)
    }

    func testSessionsForUnknownProjectReturnsEmpty() {
        let path = makeProjectPath()

        XCTAssertTrue(sessionManager.sessions(for: path).isEmpty)
    }

    func testSessionCountDefaultsToZero() {
        let path = makeProjectPath()

        XCTAssertEqual(sessionManager.sessionCount(for: path), 0)
    }

    func testDisplaySessionsFiltersHelperAndEmptyButKeepsActive() {
        let path = makeProjectPath()
        let helperId = ClaudeHelper.createHelperSessionId(for: path)
        let helper = makeSession(id: helperId, messageCount: 5, lastActivity: "2025-01-01T00:00:00Z")
        let empty = makeSession(id: "empty", messageCount: 0, lastActivity: "2025-01-02T00:00:00Z")
        let active = makeSession(id: "active", messageCount: 0, lastActivity: "2025-01-03T00:00:00Z")
        let nilCount = makeSession(id: "nil", messageCount: nil, lastActivity: "2025-01-04T00:00:00Z")

        sessionManager.addSession(helper, for: path)
        sessionManager.addSession(empty, for: path)
        sessionManager.addSession(active, for: path)
        sessionManager.addSession(nilCount, for: path)
        sessionManager.setActiveSession(active.id, for: path)

        let ids = sessionManager.displaySessions(for: path).map { $0.id }
        XCTAssertEqual(ids, ["nil", "active"])
    }

    func testDisplaySessionsSortsByLastActivityDescending() {
        let path = makeProjectPath()
        let older = makeSession(id: "older", messageCount: 1, lastActivity: "2025-01-01T00:00:00Z")
        let newest = makeSession(id: "newest", messageCount: 1, lastActivity: "2025-02-01T00:00:00Z")
        let middle = makeSession(id: "middle", messageCount: 1, lastActivity: "2025-01-15T00:00:00Z")

        sessionManager.addSession(older, for: path)
        sessionManager.addSession(newest, for: path)
        sessionManager.addSession(middle, for: path)

        let ids = sessionManager.displaySessions(for: path).map { $0.id }
        XCTAssertEqual(ids, ["newest", "middle", "older"])
    }

    func testSetActiveSessionStoresAndClearsId() {
        let path = makeProjectPath()

        sessionManager.setActiveSession("active", for: path)
        XCTAssertEqual(sessionManager.activeSessionId(for: path), "active")

        sessionManager.setActiveSession(nil, for: path)
        XCTAssertNil(sessionManager.activeSessionId(for: path))
    }

    func testSaveLoadAndClearActiveSessionIdRoundTrip() {
        let path = makeProjectPath()
        let sessionId = UUID().uuidString

        sessionManager.setActiveSession(sessionId, for: path)
        sessionManager.saveActiveSessionId(for: path)

        sessionManager.setActiveSession(nil, for: path)
        XCTAssertNil(sessionManager.activeSessionId(for: path))

        XCTAssertEqual(sessionManager.loadActiveSessionId(for: path), sessionId)
        XCTAssertEqual(sessionManager.activeSessionId(for: path), sessionId)

        sessionManager.clearActiveSessionId(for: path)
        XCTAssertNil(sessionManager.activeSessionId(for: path))
        XCTAssertNil(sessionManager.loadActiveSessionId(for: path))
    }

    func testCountSessionsToDeleteMarksActiveProtectedWhenPresent() {
        let path = makeProjectPath()
        let active = makeSession(id: "active")
        let other = makeSession(id: "other")

        sessionManager.addSession(active, for: path)
        sessionManager.addSession(other, for: path)
        sessionManager.setActiveSession(active.id, for: path)

        let result = sessionManager.countSessionsToDelete(for: path)
        XCTAssertEqual(result.all, 2)
        XCTAssertTrue(result.activeProtected)

        sessionManager.setActiveSession("missing", for: path)
        let resultWithoutActive = sessionManager.countSessionsToDelete(for: path)
        XCTAssertEqual(resultWithoutActive.all, 2)
        XCTAssertFalse(resultWithoutActive.activeProtected)
    }

    func testCountSessionsOlderThanHandlesFractionalAndInvalidDates() {
        let path = makeProjectPath()
        let now = Date()
        let oldDate = now.addingTimeInterval(-86400 * 2)
        let newDate = now.addingTimeInterval(86400 * 2)

        let activeOld = makeSession(id: "active-old", messageCount: 1, lastActivity: isoString(oldDate, fractional: true))
        let oldFractional = makeSession(id: "old-fractional", messageCount: 1, lastActivity: isoString(oldDate, fractional: true))
        let newNoFractional = makeSession(id: "new-nofrac", messageCount: 1, lastActivity: isoString(newDate, fractional: false))
        let invalid = makeSession(id: "invalid", messageCount: 1, lastActivity: "not-a-date")
        let noDate = makeSession(id: "no-date", messageCount: 1, lastActivity: nil)

        sessionManager.addSession(activeOld, for: path)
        sessionManager.addSession(oldFractional, for: path)
        sessionManager.addSession(newNoFractional, for: path)
        sessionManager.addSession(invalid, for: path)
        sessionManager.addSession(noDate, for: path)
        sessionManager.setActiveSession(activeOld.id, for: path)

        let count = sessionManager.countSessionsOlderThan(now, for: path)
        XCTAssertEqual(count, 3)
    }

    func testCountSessionsToDeleteKeepingNRespectsActive() {
        let path = makeProjectPath()
        let oldest = makeSession(id: "oldest", messageCount: 1, lastActivity: "2025-01-01T00:00:00Z")
        let middle = makeSession(id: "middle", messageCount: 1, lastActivity: "2025-02-01T00:00:00Z")
        let newest = makeSession(id: "newest", messageCount: 1, lastActivity: "2025-03-01T00:00:00Z")

        sessionManager.addSession(oldest, for: path)
        sessionManager.addSession(middle, for: path)
        sessionManager.addSession(newest, for: path)
        sessionManager.setActiveSession(oldest.id, for: path)

        let deleteCount = sessionManager.countSessionsToDeleteKeepingN(1, for: path)
        XCTAssertEqual(deleteCount, 1)
    }
}
