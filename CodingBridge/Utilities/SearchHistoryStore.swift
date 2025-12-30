import Foundation

/// Stores recent search queries for quick access
@MainActor
final class SearchHistoryStore: ObservableObject {
    static let shared = SearchHistoryStore()

    /// Maximum number of searches to keep
    private let maxHistory = 10

    /// Key for UserDefaults storage
    private let storageKey = "search_history_v1"

    /// Recent search queries (most recent first)
    @Published private(set) var recentSearches: [String] = []

    // MARK: - Initialization

    private init() {
        load()
    }

    // MARK: - Public Methods

    /// Add a search query to history
    /// - Parameter query: The search query to add
    func addSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Remove if already exists (will re-add at front)
        recentSearches.removeAll { $0.lowercased() == trimmed.lowercased() }

        // Add to front
        recentSearches.insert(trimmed, at: 0)

        // Trim to max size
        if recentSearches.count > maxHistory {
            recentSearches = Array(recentSearches.prefix(maxHistory))
        }

        save()
    }

    /// Remove a specific search from history
    /// - Parameter query: The query to remove
    func removeSearch(_ query: String) {
        recentSearches.removeAll { $0 == query }
        save()
    }

    /// Clear all search history
    func clearHistory() {
        recentSearches = []
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let searches = try? JSONDecoder().decode([String].self, from: data) else {
            recentSearches = []
            return
        }
        recentSearches = searches
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(recentSearches) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
