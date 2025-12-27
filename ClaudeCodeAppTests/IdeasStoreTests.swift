import XCTest
@testable import ClaudeCodeApp

@MainActor
final class IdeasStoreTests: XCTestCase {
    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func testQuickAddTrimsAndOrdersMostRecentFirst() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = IdeasStore(projectPath: "/tmp/project", baseDirectory: dir)
        store.quickAdd("  First \n")
        store.quickAdd("Second")

        XCTAssertEqual(store.ideas.count, 2)
        XCTAssertEqual(store.ideas[0].text, "Second")
        XCTAssertEqual(store.ideas[1].text, "First")
    }

    func testArchiveAndCounts() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = IdeasStore(projectPath: "/tmp/project", baseDirectory: dir)
        let first = Idea(text: "First idea")
        let second = Idea(text: "Second idea")
        store.add(first)
        store.add(second)

        store.archive(first)

        XCTAssertEqual(store.activeCount, 1)
        XCTAssertEqual(store.archivedCount, 1)

        store.unarchive(first)

        XCTAssertEqual(store.activeCount, 2)
        XCTAssertEqual(store.archivedCount, 0)
    }

    func testAllTagsSortedUnique() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = IdeasStore(projectPath: "/tmp/project", baseDirectory: dir)
        store.ideas = [
            Idea(text: "One", tags: ["beta", "alpha"]),
            Idea(text: "Two", tags: ["alpha", "gamma"])
        ]

        XCTAssertEqual(store.allTags, ["alpha", "beta", "gamma"])
    }

    func testFilterByTagSearchAndArchive() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = IdeasStore(projectPath: "/tmp/project", baseDirectory: dir)
        let date1 = Date(timeIntervalSince1970: 1_600_000_000)
        let date2 = Date(timeIntervalSince1970: 1_700_000_000)
        let date3 = Date(timeIntervalSince1970: 1_800_000_000)

        let idea1 = Idea(
            id: UUID(),
            text: "Login flow",
            title: "Auth",
            tags: ["ios"],
            createdAt: date1,
            updatedAt: date1,
            isArchived: false
        )
        let idea2 = Idea(
            id: UUID(),
            text: "SSH key handling",
            title: "Keys",
            tags: ["ssh", "ios"],
            createdAt: date2,
            updatedAt: date2,
            isArchived: true
        )
        let idea3 = Idea(
            id: UUID(),
            text: "Button layout tweaks",
            title: nil,
            tags: ["ui"],
            createdAt: date3,
            updatedAt: date3,
            isArchived: false
        )

        store.ideas = [idea1, idea2, idea3]

        let iosActive = store.filter(byTag: "ios", showArchived: false)
        XCTAssertEqual(iosActive.map(\.id), [idea1.id])

        let iosArchived = store.filter(byTag: "ios", showArchived: true)
        XCTAssertEqual(iosArchived.map(\.id), [idea2.id])

        let searchResults = store.filter(byTag: nil, searchText: "button", showArchived: false)
        XCTAssertEqual(searchResults.map(\.id), [idea3.id])
    }

    func testUpdateAndClearEnhancement() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = IdeasStore(projectPath: "/tmp/project", baseDirectory: dir)
        let idea = Idea(text: "Sketch the flow")
        store.add(idea)

        store.updateWithEnhancement(
            ideaId: idea.id,
            expandedPrompt: "Expanded prompt",
            suggestedFollowups: ["Follow up 1", "Follow up 2"]
        )

        let updated = store.ideas.first(where: { $0.id == idea.id })
        XCTAssertEqual(updated?.expandedPrompt, "Expanded prompt")
        XCTAssertEqual(updated?.suggestedFollowups ?? [], ["Follow up 1", "Follow up 2"])

        store.clearEnhancement(ideaId: idea.id)

        let cleared = store.ideas.first(where: { $0.id == idea.id })
        XCTAssertNil(cleared?.expandedPrompt)
        XCTAssertNil(cleared?.suggestedFollowups)
    }
}
