import XCTest
@testable import CodingBridge

final class ProjectSessionFilterTests: XCTestCase {
    private func makeSession(
        id: String,
        summary: String? = nil,
        messageCount: Int? = nil,
        lastActivity: String? = nil,
        lastUserMessage: String? = nil
    ) -> ProjectSession {
        ProjectSession(
            id: id,
            summary: summary,
            messageCount: messageCount,
            lastActivity: lastActivity,
            lastUserMessage: lastUserMessage,
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
        let project = Project(name: "demo", path: projectPath, displayName: nil, fullPath: nil, sessions: sessions, sessionMeta: nil)

        XCTAssertEqual(project.displaySessions.map { $0.id }, ["kept"])
    }

    func testProjectSortedDisplaySessionsSortsByLastActivity() {
        let projectPath = "/tmp/project-sorted"
        let sessions = [
            makeSession(id: "older", messageCount: 1, lastActivity: "2025-01-01T00:00:00Z"),
            makeSession(id: "newest", messageCount: 1, lastActivity: "2025-02-01T00:00:00Z")
        ]
        let project = Project(name: "demo", path: projectPath, displayName: nil, fullPath: nil, sessions: sessions, sessionMeta: nil)

        XCTAssertEqual(project.sortedDisplaySessions.map { $0.id }, ["newest", "older"])
    }

    // MARK: - Content-Based Helper Filtering Tests
    // Note: Content-based filtering is NO LONGER used because ClaudeHelper correctly
    // reuses the existing session - so a real session may have a helper prompt as lastUserMessage.

    func testFilterForDisplayDoesNotFilterByContent() {
        let projectPath = "/tmp/filter-helper-content"
        let sessions = [
            makeSession(
                id: "helper-suggestions",
                messageCount: 5,
                lastUserMessage: "Based on this conversation context, suggest 3 short next actions the user might want to take."
            ),
            makeSession(
                id: "helper-files",
                messageCount: 3,
                lastUserMessage: "Based on this conversation, which files would be most relevant to reference next?"
            ),
            makeSession(
                id: "helper-ideas",
                messageCount: 10,
                lastUserMessage: "You are helping a developer expand a quick idea into an actionable prompt for Claude Code."
            ),
            makeSession(
                id: "helper-analyze",
                messageCount: 2,
                lastUserMessage: "Analyze this Claude Code response and suggest 3 helpful follow-up actions."
            ),
            makeSession(
                id: "user-session",
                messageCount: 5,
                lastUserMessage: "Help me fix this bug in the auth module"
            )
        ]

        let filtered = sessions.filterForDisplay(projectPath: projectPath)

        // All sessions should remain - content is not filtered
        XCTAssertEqual(filtered.count, 5)
    }

    func testFilterForDisplayKeepsSessionsWithRegularUserMessages() {
        let projectPath = "/tmp/filter-regular"
        let sessions = [
            makeSession(
                id: "session1",
                messageCount: 3,
                lastUserMessage: "Implement a new login feature"
            ),
            makeSession(
                id: "session2",
                messageCount: 5,
                lastUserMessage: "Run the test suite"
            )
        ]

        let filtered = sessions.filterForDisplay(projectPath: projectPath)

        XCTAssertEqual(filtered.count, 2)
    }

    func testFilterForDisplayAlwaysIncludesActiveSessionEvenIfHelperContent() {
        let projectPath = "/tmp/filter-active-helper"
        let activeId = "active-helper"
        let sessions = [
            makeSession(
                id: activeId,
                messageCount: 10,
                lastUserMessage: "Based on this conversation context, suggest 3 short next actions"
            ),
            makeSession(
                id: "regular",
                messageCount: 5,
                lastUserMessage: "Fix the bug"
            )
        ]

        let filtered = sessions.filterForDisplay(projectPath: projectPath, activeSessionId: activeId)

        // Active session should be included even though it has helper content
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.contains { $0.id == activeId })
    }
}
