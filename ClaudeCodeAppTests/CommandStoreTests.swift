import XCTest
@testable import ClaudeCodeApp

@MainActor
final class CommandStoreTests: XCTestCase {
    private func makeTempFileURL(filename: String = "commands.json") throws -> (dir: URL, file: URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (dir, dir.appendingPathComponent(filename))
    }

    private func writeCommands(_ commands: [SavedCommand], to url: URL) throws {
        let data = try JSONEncoder().encode(commands)
        try data.write(to: url)
    }

    func testCategoriesSorted() throws {
        let (dir, fileURL) = try makeTempFileURL()
        defer { try? FileManager.default.removeItem(at: dir) }

        let commands = [
            SavedCommand(name: "Build app", content: "Build", category: "Build"),
            SavedCommand(name: "Run tests", content: "Test", category: "Testing"),
            SavedCommand(name: "Commit changes", content: "Commit", category: "Git")
        ]
        try writeCommands(commands, to: fileURL)

        let store = CommandStore(fileURL: fileURL)
        XCTAssertEqual(store.categories, ["Build", "Git", "Testing"])
    }

    func testCommandsSortedByLastUsedAndName() throws {
        let (dir, fileURL) = try makeTempFileURL()
        defer { try? FileManager.default.removeItem(at: dir) }

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let earlier = Date(timeIntervalSince1970: 1_600_000_000)
        let commands = [
            SavedCommand(name: "Alpha", content: "A", category: "Git"),
            SavedCommand(name: "Beta", content: "B", category: "Git", lastUsedAt: now),
            SavedCommand(name: "Gamma", content: "C", category: "Git", lastUsedAt: earlier),
            SavedCommand(name: "Delta", content: "D", category: "Git")
        ]
        try writeCommands(commands, to: fileURL)

        let store = CommandStore(fileURL: fileURL)
        let sorted = store.commands(in: "Git").map(\.name)
        XCTAssertEqual(sorted, ["Beta", "Gamma", "Alpha", "Delta"])
    }

    func testMarkUsedSetsLastUsedAt() throws {
        let (dir, fileURL) = try makeTempFileURL()
        defer { try? FileManager.default.removeItem(at: dir) }

        let command = SavedCommand(name: "Run tests", content: "Test", category: "Testing")
        try writeCommands([command], to: fileURL)

        let store = CommandStore(fileURL: fileURL)
        XCTAssertNil(store.commands.first?.lastUsedAt)

        store.markUsed(command)

        XCTAssertNotNil(store.commands.first?.lastUsedAt)
    }

    func testDeleteCommandsAtOffsets() throws {
        let (dir, fileURL) = try makeTempFileURL()
        defer { try? FileManager.default.removeItem(at: dir) }

        let alpha = SavedCommand(name: "Alpha", content: "A", category: "Testing")
        let beta = SavedCommand(name: "Beta", content: "B", category: "Testing")
        let git = SavedCommand(name: "Commit", content: "Commit", category: "Git")
        try writeCommands([alpha, beta, git], to: fileURL)

        let store = CommandStore(fileURL: fileURL)
        store.deleteCommands(at: IndexSet(integer: 0), in: "Testing")

        let remainingTesting = store.commands(in: "Testing").map(\.name)
        XCTAssertEqual(remainingTesting, ["Beta"])
        XCTAssertEqual(store.count(in: "Git"), 1)
    }

    func testUpdateCommandReplacesExistingEntry() throws {
        let (dir, fileURL) = try makeTempFileURL()
        defer { try? FileManager.default.removeItem(at: dir) }

        let original = SavedCommand(name: "Old", content: "Old content", category: "Docs")
        try writeCommands([original], to: fileURL)

        let store = CommandStore(fileURL: fileURL)
        let updated = SavedCommand(
            id: original.id,
            name: "New",
            content: "Updated content",
            category: "Docs",
            createdAt: original.createdAt,
            lastUsedAt: original.lastUsedAt
        )

        store.update(updated)

        XCTAssertEqual(store.commands.count, 1)
        XCTAssertEqual(store.commands.first?.name, "New")
        XCTAssertEqual(store.commands.first?.content, "Updated content")
    }

    func testInitWithoutFile_createsDefaultCommands() throws {
        let (dir, fileURL) = try makeTempFileURL()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = CommandStore(fileURL: fileURL)

        XCTAssertFalse(store.commands.isEmpty)
        XCTAssertTrue(store.commands.contains { $0.name == "Commit changes" })
        XCTAssertTrue(store.commands.contains { $0.name == "Run tests" })
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testInitWithInvalidFile_returnsEmptyCommands() throws {
        let (dir, fileURL) = try makeTempFileURL()
        defer { try? FileManager.default.removeItem(at: dir) }

        try Data("not-json".utf8).write(to: fileURL)

        let store = CommandStore(fileURL: fileURL)

        XCTAssertTrue(store.commands.isEmpty)
    }
}
