import Foundation

// MARK: - Bookmark Store

/// Stores bookmarked messages across all projects
@MainActor
class BookmarkStore: ObservableObject {
    static let shared = BookmarkStore()

    @Published private(set) var bookmarks: [BookmarkedMessage] = []

    private static var defaultBookmarksFile: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("bookmarks.json")
    }

    /// Background queue for file I/O to avoid blocking main thread
    private static let fileQueue = DispatchQueue(label: "com.codingbridge.bookmarkstore", qos: .userInitiated)

    private let bookmarksFile: URL

    init(bookmarksFile: URL? = nil) {
        self.bookmarksFile = bookmarksFile ?? Self.defaultBookmarksFile
        loadBookmarks()
    }

    /// Check if a message is bookmarked
    func isBookmarked(messageId: UUID) -> Bool {
        bookmarks.contains { $0.messageId == messageId }
    }

    /// Toggle bookmark status for a message
    func toggleBookmark(message: ChatMessage, projectPath: String, projectTitle: String) {
        if let index = bookmarks.firstIndex(where: { $0.messageId == message.id }) {
            bookmarks.remove(at: index)
        } else {
            let bookmark = BookmarkedMessage(
                messageId: message.id,
                role: message.role,
                content: message.content,
                timestamp: message.timestamp,
                projectPath: projectPath,
                projectTitle: projectTitle,
                bookmarkedAt: Date()
            )
            bookmarks.insert(bookmark, at: 0)
        }
        saveBookmarks()
    }

    /// Remove a bookmark
    func removeBookmark(messageId: UUID) {
        bookmarks.removeAll { $0.messageId == messageId }
        saveBookmarks()
    }

    /// Search bookmarks
    func searchBookmarks(_ query: String) -> [BookmarkedMessage] {
        guard !query.isEmpty else { return bookmarks }
        return bookmarks.filter {
            $0.content.localizedCaseInsensitiveContains(query) ||
            $0.projectTitle.localizedCaseInsensitiveContains(query)
        }
    }

    private func loadBookmarks() {
        let url = bookmarksFile

        BookmarkStore.fileQueue.async { [weak self] in
            guard let data = try? Data(contentsOf: url) else { return }
            do {
                let loadedBookmarks = try JSONDecoder().decode([BookmarkedMessage].self, from: data)
                Task { @MainActor [weak self] in
                    self?.bookmarks = loadedBookmarks
                }
            } catch {
                log.error("Failed to load bookmarks: \(error)")
            }
        }
    }

    private func saveBookmarks() {
        let bookmarksToSave = bookmarks
        let url = bookmarksFile

        BookmarkStore.fileQueue.async {
            do {
                let data = try JSONEncoder().encode(bookmarksToSave)
                try data.write(to: url, options: .atomic)
            } catch {
                log.error("Failed to save bookmarks: \(error)")
            }
        }
    }
}

/// A bookmarked message with project context
struct BookmarkedMessage: Identifiable, Codable {
    let id: UUID
    let messageId: UUID
    let role: ChatMessage.Role
    let content: String
    let timestamp: Date
    let projectPath: String
    let projectTitle: String
    let bookmarkedAt: Date

    init(
        messageId: UUID,
        role: ChatMessage.Role,
        content: String,
        timestamp: Date,
        projectPath: String,
        projectTitle: String,
        bookmarkedAt: Date
    ) {
        self.id = UUID()
        self.messageId = messageId
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.projectPath = projectPath
        self.projectTitle = projectTitle
        self.bookmarkedAt = bookmarkedAt
    }
}
