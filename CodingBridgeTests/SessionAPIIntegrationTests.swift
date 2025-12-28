import XCTest
@testable import CodingBridge

final class SessionAPIIntegrationTests: XCTestCase {
    func testSessionsAPIReturnsMoreThanFiveWhenAvailable() async throws {
        let config = try IntegrationTestConfig.require()
        let client = SessionAPIClient(config: config)

        let firstPage = try await client.fetchSessions(limit: 5, offset: 0)
        let total = firstPage.total
        try XCTSkipIf(total < config.minTotal, "Need at least \(config.minTotal) sessions in the test project.")

        XCTAssertGreaterThan(total, 5)
        XCTAssertTrue(firstPage.hasMore)

        let expandedLimit = min(100, total)
        let expanded = try await client.fetchSessions(limit: expandedLimit, offset: 0)
        XCTAssertGreaterThan(expanded.sessions.count, 5)
    }

    func testSessionsPaginationReturnsNextPage() async throws {
        let config = try IntegrationTestConfig.require()
        let client = SessionAPIClient(config: config)

        let firstPage = try await client.fetchSessions(limit: 5, offset: 0)
        try XCTSkipIf(firstPage.total <= 5, "Not enough sessions to validate pagination.")

        let secondPage = try await client.fetchSessions(limit: 5, offset: 5)
        let firstIds = Set(firstPage.sessions.map { $0.id })
        let secondIds = Set(secondPage.sessions.map { $0.id })

        XCTAssertFalse(secondIds.isEmpty)
        XCTAssertTrue(firstIds.isDisjoint(with: secondIds))
    }

    func testSessionsSummariesPopulated() async throws {
        let config = try IntegrationTestConfig.require()
        let client = SessionAPIClient(config: config)

        let response = try await client.fetchSessions(limit: 50, offset: 0)
        let summaries = response.sessions
            .compactMap { $0.summary?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if config.requireSummaries {
            XCTAssertFalse(summaries.isEmpty)
        } else {
            try XCTSkipIf(summaries.isEmpty, "No summaries found; set CODINGBRIDGE_TEST_REQUIRE_SUMMARIES=1 to enforce.")
        }
    }

    func testSessionDeletionUpdatesList() async throws {
        let config = try IntegrationTestConfig.require()
        try XCTSkipIf(!config.allowMutations, "Set CODINGBRIDGE_TEST_ALLOW_MUTATIONS=1 to enable deletion tests.")

        guard let deleteSessionId = config.deleteSessionId, !deleteSessionId.isEmpty else {
            throw XCTSkip("Set CODINGBRIDGE_TEST_DELETE_SESSION_ID to enable deletion tests.")
        }

        let client = SessionAPIClient(config: config)
        let before = try await client.fetchSessions(limit: 100, offset: 0)
        try XCTSkipIf(!before.sessions.contains(where: { $0.id == deleteSessionId }), "Session ID not found in test project.")

        try await client.deleteSession(sessionId: deleteSessionId)

        let after = try await client.fetchSessions(limit: 100, offset: 0)
        XCTAssertFalse(after.sessions.contains(where: { $0.id == deleteSessionId }))
    }
}
