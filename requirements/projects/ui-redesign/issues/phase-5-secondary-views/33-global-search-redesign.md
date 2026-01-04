---
number: 33
title: Global Search Redesign
phase: phase-5-secondary-views
status: pending
completed_by: null
completed_at: null
verified_by: null
verified_at: null
commit: null
spot_checked: false
blocked_reason: null
---

# Issue 33: Global Search Redesign

**Phase:** 5 (Secondary Views)
**Priority:** Medium
**Status:** Not Started
**Depends On:** Issue #17 (Liquid Glass), Issue #23 (Navigation)

## Goal

Redesign global search as a full-screen view with cross-project searching, recent searches, and rich result previews.

## Decision

Preserve SearchHistoryStore (keep last 10 searches) as part of the redesign.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue #17 (Liquid Glass), Issue #23 (Navigation).
- Add runtime or tooling dependencies here.

## Touch Set
- Files to create: TBD.
- Files to modify: TBD.

## Interface Definitions
- List new or changed models, protocols, and API payloads.

## Edge Cases
- TBD.

## Tests
- [ ] Unit tests updated or added.
- [ ] UI tests updated or added (if user flows change).
## Design

```
┌─────────────────────────────────────────────────────────┐
│ ←  Search                                               │
├─────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 🔍 Search all sessions...                     [×]   │ │
│ └─────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────┤
│ RECENT SEARCHES                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 🕐 authentication bug                               │ │
│ │ 🕐 database migration                               │ │
│ │ 🕐 api refactor                                     │ │
│ └─────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────┤
│ RESULTS (12)                                            │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 📁 my-project                                       │ │
│ │ ┌─────────────────────────────────────────────────┐ │ │
│ │ │ 💬 "Help me fix the authentication bug..."      │ │ │
│ │ │    Session: Fix login issues • 2h ago           │ │ │
│ │ └─────────────────────────────────────────────────┘ │ │
│ │ ┌─────────────────────────────────────────────────┐ │ │
│ │ │ 🤖 "I found the authentication issue in..."     │ │ │
│ │ │    Session: Fix login issues • 2h ago           │ │ │
│ │ └─────────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 📁 cli-bridge                                       │ │
│ │ ┌─────────────────────────────────────────────────┐ │ │
│ │ │ 👤 "Add authentication to the API..."           │ │ │
│ │ │    Session: API development • 1d ago            │ │ │
│ │ └─────────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Implementation

### Search Algorithm and Indexing

- Use backend `/search` endpoint with ranked results.
- Tokenize by word boundaries; normalize case and punctuation.
- Highlight snippets using `AttributedString` with match ranges.
- Cache recent results per project for quick back/forward navigation.

### GlobalSearchView

```swift
struct GlobalSearchView: View {
    @State private var viewModel = GlobalSearchViewModel()
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            GlobalSearchBar(
                text: $viewModel.searchText,
                isSearching: viewModel.isSearching,
                onClear: { viewModel.clearSearch() }
            )
            .focused($isSearchFocused)

            // Content
            if viewModel.searchText.isEmpty {
                RecentSearchesView(
                    searches: viewModel.recentSearches,
                    onSelect: { viewModel.searchText = $0 },
                    onClear: { viewModel.clearRecentSearches() }
                )
            } else if viewModel.isSearching {
                SearchingView()
            } else if viewModel.results.isEmpty {
                NoResultsView(query: viewModel.searchText)
            } else {
                SearchResultsView(
                    results: viewModel.results,
                    onSelect: viewModel.selectResult
                )
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isSearchFocused = true
        }
    }
}
```

### GlobalSearchViewModel

```swift
@MainActor @Observable
final class GlobalSearchViewModel {
    private(set) var results: [SearchResultGroup] = []
    private(set) var recentSearches: [String] = []
    private(set) var isSearching = false

    var searchText = "" {
        didSet {
            debounceSearch()
        }
    }

    private var searchTask: Task<Void, Never>?
    private let searchHistoryStore = SearchHistoryStore.shared

    init() {
        loadRecentSearches()
    }

    private func debounceSearch() {
        searchTask?.cancel()

        guard !searchText.isEmpty else {
            results = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))

            guard !Task.isCancelled else { return }

            await performSearch()
        }
    }

    private func performSearch() async {
        isSearching = true
        defer { isSearching = false }

        do {
            let store = SessionStore.shared
            let searchResults = try await store.globalSearch(query: searchText)

            results = groupResults(searchResults)

            // Save to history
            searchHistoryStore.addSearch(searchText)
            loadRecentSearches()
        } catch {
            Logger.error("Search failed: \(error)")
            results = []
        }
    }

    func clearSearch() {
        searchText = ""
        results = []
    }

    func clearRecentSearches() {
        searchHistoryStore.clearHistory()
        recentSearches = []
    }

    func selectResult(_ result: SearchResult) {
        // Navigate to session with highlighted message
    }

    private func loadRecentSearches() {
        recentSearches = searchHistoryStore.recentSearches
    }

    private func groupResults(_ results: [SearchResult]) -> [SearchResultGroup] {
        Dictionary(grouping: results) { $0.projectPath }
            .map { path, results in
                SearchResultGroup(
                    projectPath: path,
                    projectName: path.projectDisplayName,
                    results: results
                )
            }
            .sorted { $0.results.count > $1.results.count }
    }
}
```

### GlobalSearchBar

```swift
struct GlobalSearchBar: View {
    @Binding var text: String
    let isSearching: Bool
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search all sessions...", text: $text)
                .textFieldStyle(.plain)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if isSearching {
                ProgressView()
                    .scaleEffect(0.8)
            } else if !text.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .glassEffect()
    }
}
```

### RecentSearchesView

```swift
struct RecentSearchesView: View {
    let searches: [String]
    let onSelect: (String) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if searches.isEmpty {
                ContentUnavailableView(
                    "No Recent Searches",
                    systemImage: "magnifyingglass",
                    description: Text("Your search history will appear here")
                )
            } else {
                HStack {
                    Text("Recent Searches")
                        .font(.headline)

                    Spacer()

                    Button("Clear", action: onClear)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()

                List {
                    ForEach(searches, id: \.self) { search in
                        Button {
                            onSelect(search)
                        } label: {
                            Label(search, systemImage: "clock")
                        }
                        .foregroundStyle(.primary)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}
```

### SearchResultsView

```swift
struct SearchResultsView: View {
    let results: [SearchResultGroup]
    let onSelect: (SearchResult) -> Void

    var totalCount: Int {
        results.reduce(0) { $0 + $1.results.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Results (\(totalCount))")
                .font(.headline)
                .padding()

            List {
                ForEach(results) { group in
                    Section {
                        ForEach(group.results) { result in
                            SearchResultRowView(result: result)
                                .contentShape(Rectangle())
                                .onTapGesture { onSelect(result) }
                        }
                    } header: {
                        HStack {
                            Image(systemName: "folder.fill")
                            Text(group.projectName)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

struct SearchResultGroup: Identifiable {
    let id = UUID()
    let projectPath: String
    let projectName: String
    let results: [SearchResult]
}
```

### SearchResultRowView

```swift
struct SearchResultRowView: View {
    let result: SearchResult

    var roleIcon: String {
        switch result.role {
        case .user: return "person.fill"
        case .assistant: return "sparkles"
        default: return "bubble.left"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: roleIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(result.snippet)
                    .lineLimit(2)
            }

            HStack {
                Text("Session: \(result.sessionTitle)")
                Text("•")
                if let timestamp = result.timestamp {
                    Text(timestamp, style: .relative)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
```

### SearchResult Model

```swift
struct SearchResult: Identifiable {
    let id: String
    let projectPath: String
    let sessionId: String
    let sessionTitle: String
    let messageId: String
    let role: ChatMessage.Role
    let snippet: String
    let timestamp: Date?
    let score: Double

    var highlightedSnippet: AttributedString {
        // Return snippet with search terms highlighted
        var attributed = AttributedString(snippet)
        // Highlight logic here
        return attributed
    }
}
```

### SearchingView & NoResultsView

```swift
struct SearchingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Searching...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NoResultsView: View {
    let query: String

    var body: some View {
        ContentUnavailableView(
            "No Results",
            systemImage: "magnifyingglass",
            description: Text("No results found for \"\(query)\"")
        )
    }
}
```

### SearchHistoryStore

```swift
@MainActor @Observable
final class SearchHistoryStore {
    static let shared = SearchHistoryStore()

    private(set) var recentSearches: [String] = []
    private let maxHistory = 10
    private let defaults = UserDefaults.standard
    private let key = "recentSearches"

    init() {
        load()
    }

    func addSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Remove if exists, add to front
        recentSearches.removeAll { $0 == trimmed }
        recentSearches.insert(trimmed, at: 0)

        // Limit history size
        if recentSearches.count > maxHistory {
            recentSearches = Array(recentSearches.prefix(maxHistory))
        }

        save()
    }

    func clearHistory() {
        recentSearches = []
        save()
    }

    private func load() {
        recentSearches = defaults.stringArray(forKey: key) ?? []
    }

    private func save() {
        defaults.set(recentSearches, forKey: key)
    }
}
```

## Files to Create

```
CodingBridge/Features/Search/
├── GlobalSearchView.swift         # ~80 lines
├── GlobalSearchViewModel.swift    # ~100 lines
├── GlobalSearchBar.swift          # ~40 lines
├── RecentSearchesView.swift       # ~50 lines
├── SearchResultsView.swift        # ~60 lines
├── SearchResultRowView.swift      # ~40 lines
├── SearchResult.swift             # ~30 lines
└── SearchHistoryStore.swift       # ~50 lines
```

## Files to Modify

| File | Changes |
|------|---------|
| Current `GlobalSearchView.swift` | Replace with new implementation |
| `SessionStore.swift` | Add globalSearch method |

## Acceptance Criteria

- [ ] Full-screen search view
- [ ] Debounced search (300ms)
- [ ] Recent searches with persistence
- [ ] Results grouped by project
- [ ] Result snippets with context
- [ ] Role indicators on results
- [ ] Tap to navigate to message
- [ ] Clear search button
- [ ] Loading and empty states
- [ ] Glass effect styling
- [ ] Build passes

## Testing

```swift
struct GlobalSearchTests: XCTestCase {
    func testSearchHistory() {
        let store = SearchHistoryStore.shared
        store.clearHistory()

        store.addSearch("test query")
        XCTAssertEqual(store.recentSearches.first, "test query")

        store.addSearch("another query")
        XCTAssertEqual(store.recentSearches.first, "another query")
    }

    func testHistoryLimit() {
        let store = SearchHistoryStore.shared
        store.clearHistory()

        for i in 0..<15 {
            store.addSearch("query \(i)")
        }

        XCTAssertEqual(store.recentSearches.count, 10)
    }

    func testResultGrouping() {
        let viewModel = GlobalSearchViewModel()

        // Test grouping logic
    }
}
```
