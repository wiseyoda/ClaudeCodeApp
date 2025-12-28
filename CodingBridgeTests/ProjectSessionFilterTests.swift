import XCTest
@testable import CodingBridge

final class ProjectSessionFilterTests: XCTestCase {
    private func makeSession(
        id: String,
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

    func testFilterForDisplayExcludesHelperSession() {
        let projectPath = "/tmp/filter-helper"
        let helperId = ClaudeHelper.createHelperSessionId(for: projectPath)
        let sessions = [
            makeSession(id: helperId, messageCount: 2),
            makeSession(id: "user", messageCount: 2)
        ]

        let filtered = sessions.filterForDisplay(projectPath: projectPath)

        XCTAssertEqual(filtered.map { $0.id }, ["user"])
    }

    func testFilterForDisplayExcludesEmptySessionsButKeepsNilCount() {
        let projectPath = "/tmp/filter-empty"
        let sessions = [
            makeSession(id: "empty", messageCount: 0),
            makeSession(id: "nil", messageCount: nil),
            makeSession(id: "ok", messageCount: 1)
        ]

        let filtered = sessions.filterForDisplay(projectPath: projectPath)

        XCTAssertEqual(filtered.map { $0.id }, ["nil", "ok"])
    }

    func testFilterForDisplayAlwaysIncludesActiveSessionEvenIfEmpty() {
        let projectPath = "/tmp/filter-active"
        let activeId = "active"
        let sessions = [
            makeSession(id: activeId, messageCount: 0),
            makeSession(id: "other", messageCount: 1)
        ]

        let filtered = sessions.filterForDisplay(projectPath: projectPath, activeSessionId: activeId)

        XCTAssertEqual(filtered.map { $0.id }, [activeId, "other"])
    }

    func testFilterAndSortForDisplaySortsByLastActivityDescending() {
        let projectPath = "/tmp/filter-sort"
        let sessions = [
            makeSession(id: "older", messageCount: 1, lastActivity: "2025-01-01T00:00:00Z"),
            makeSession(id: "newest", messageCount: 1, lastActivity: "2025-03-01T00:00:00Z"),
            makeSession(id: "middle", messageCount: 1, lastActivity: "2025-02-01T00:00:00Z")
        ]

        let sorted = sessions.filterAndSortForDisplay(projectPath: projectPath)

        XCTAssertEqual(sorted.map { $0.id }, ["newest", "middle", "older"])
    }

    func testProjectDisplaySessionsUsesFilter() {
        let projectPath = "/tmp/project-display"
        let helperId = ClaudeHelper.createHelperSessionId(for: projectPath)
        let sessions = [
            makeSession(id: helperId, messageCount: 1),
            makeSession(id: "empty", messageCount: 0),
            makeSession(id: "kept", messageCount: 2)
        ]
        let project = Project(name: "demo", path: projectPath, displayName: nil, fullPath: nil, sessions: sessions)

        XCTAssertEqual(project.displaySessions.map { $0.id }, ["kept"])
    }

    func testProjectSortedDisplaySessionsSortsByLastActivity() {
        let projectPath = "/tmp/project-sorted"
        let sessions = [
            makeSession(id: "older", messageCount: 1, lastActivity: "2025-01-01T00:00:00Z"),
            makeSession(id: "newest", messageCount: 1, lastActivity: "2025-02-01T00:00:00Z")
        ]
        let project = Project(name: "demo", path: projectPath, displayName: nil, fullPath: nil, sessions: sessions)

        XCTAssertEqual(project.sortedDisplaySessions.map { $0.id }, ["newest", "older"])
    }
}
