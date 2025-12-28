import XCTest
@testable import CodingBridge

@MainActor
final class BookmarkStoreTests: XCTestCase {
    private func makeTempFileURL(filename: String = "bookmarks.json") throws -> (dir: URL, file: URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (dir, dir.appendingPathComponent(filename))
    }

    func testToggleBookmarkAddsAndRemoves() throws {
        let (dir, fileURL) = try makeTempFileURL()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = BookmarkStore(bookmarksFile: fileURL)
        let message = ChatMessage(role: .assistant, content: "Hello")

        store.toggleBookmark(message: message, projectPath: "/tmp", projectTitle: "App")
        XCTAssertTrue(store.isBookmarked(messageId: message.id))
        XCTAssertEqual(store.bookmarks.count, 1)

        store.toggleBookmark(message: message, projectPath: "/tmp", projectTitle: "App")
        XCTAssertFalse(store.isBookmarked(messageId: message.id))
        XCTAssertEqual(store.bookmarks.count, 0)
    }

    func testSearchBookmarksMatchesContentAndProjectTitle() throws {
        let (dir, fileURL) = try makeTempFileURL()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = BookmarkStore(bookmarksFile: fileURL)
        let message1 = ChatMessage(role: .assistant, content: "Fix login flow")
        let message2 = ChatMessage(role: .assistant, content: "Add SSH key support")

        store.toggleBookmark(message: message1, projectPath: "/tmp/app", projectTitle: "Mobile App")
        store.toggleBookmark(message: message2, projectPath: "/tmp/infra", projectTitle: "Infra")

        XCTAssertEqual(store.searchBookmarks("ssh").count, 1)
        XCTAssertEqual(store.searchBookmarks("mobile").count, 1)
    }

    func testRemoveBookmark() throws {
        let (dir, fileURL) = try makeTempFileURL()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = BookmarkStore(bookmarksFile: fileURL)
        let message1 = ChatMessage(role: .assistant, content: "First")
        let message2 = ChatMessage(role: .assistant, content: "Second")

        store.toggleBookmark(message: message1, projectPath: "/tmp", projectTitle: "App")
        store.toggleBookmark(message: message2, projectPath: "/tmp", projectTitle: "App")

        store.removeBookmark(messageId: message1.id)

        XCTAssertFalse(store.isBookmarked(messageId: message1.id))
        XCTAssertTrue(store.isBookmarked(messageId: message2.id))
        XCTAssertEqual(store.bookmarks.count, 1)
    }

    func testLoadInvalidFile_returnsEmptyBookmarks() throws {
        let (dir, fileURL) = try makeTempFileURL()
        defer { try? FileManager.default.removeItem(at: dir) }

        try Data("not-json".utf8).write(to: fileURL)

        let store = BookmarkStore(bookmarksFile: fileURL)

        XCTAssertTrue(store.bookmarks.isEmpty)
    }
}
