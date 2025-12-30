import SwiftUI
import Combine

// MARK: - Date Filter Enum

/// Date range filter options for search results
enum SearchDateFilter: String, CaseIterable, Identifiable {
    case anyTime = "Any time"
    case today = "Today"
    case pastWeek = "Past week"
    case pastMonth = "Past month"
    case pastYear = "Past year"

    var id: String { rawValue }

    /// Check if a date matches this filter
    func matches(_ date: Date) -> Bool {
        let now = Date()
        let calendar = Calendar.current

        switch self {
        case .anyTime:
            return true
        case .today:
            return calendar.isDateInToday(date)
        case .pastWeek:
            guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return true }
            return date >= weekAgo
        case .pastMonth:
            guard let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) else { return true }
            return date >= monthAgo
        case .pastYear:
            guard let yearAgo = calendar.date(byAdding: .year, value: -1, to: now) else { return true }
            return date >= yearAgo
        }
    }
}

// MARK: - Search Service

/// Manages search state with debouncing and pagination
@MainActor
class SearchService: ObservableObject {
    private let serverURL: String

    @Published var query: String = ""
    @Published private(set) var results: [CLISearchResult] = []
    @Published private(set) var isSearching = false
    @Published private(set) var error: String?
    @Published private(set) var hasMore = false
    @Published private(set) var totalResults = 0

    private var searchTask: Task<Void, Never>?
    private var currentOffset = 0
    private let pageSize = 20
    private var currentProjectPath: String?

    // Debounce search
    private var searchDebouncer: AnyCancellable?

    init(serverURL: String) {
        self.serverURL = serverURL
        setupDebouncer()
    }

    private func setupDebouncer() {
        searchDebouncer = $query
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self = self else { return }
                if query.isEmpty {
                    self.clearResults()
                } else {
                    Task { await self.performSearch(query: query, projectPath: self.currentProjectPath, reset: true) }
                }
            }
    }

    // MARK: - Search Operations

    func search(query: String, projectPath: String? = nil, limit: Int = 20, offset: Int = 0) async throws -> CLISearchResponse {
        let apiClient = CLIBridgeAPIClient(serverURL: serverURL)
        return try await apiClient.search(query: query, projectPath: projectPath, limit: limit, offset: offset)
    }

    /// Update the project filter and re-search if needed
    func setProjectFilter(_ projectPath: String?) {
        currentProjectPath = projectPath
        if !query.isEmpty {
            Task { await performSearch(query: query, projectPath: projectPath, reset: true) }
        }
    }

    // MARK: - UI Operations

    func performSearch(query: String, projectPath: String? = nil, reset: Bool) async {
        searchTask?.cancel()

        searchTask = Task {
            if reset {
                currentOffset = 0
                results = []
            }

            isSearching = true
            error = nil

            do {
                let response = try await search(
                    query: query,
                    projectPath: projectPath,
                    limit: pageSize,
                    offset: currentOffset
                )

                guard !Task.isCancelled else { return }

                if reset {
                    results = response.results
                } else {
                    results.append(contentsOf: response.results)
                }

                totalResults = response.total
                hasMore = response.hasMore
                currentOffset += response.results.count

                // Save to search history
                if reset && !response.results.isEmpty {
                    SearchHistoryStore.shared.addSearch(query)
                }

            } catch is CancellationError {
                // Ignore cancellation
            } catch {
                self.error = error.localizedDescription
            }

            isSearching = false
        }
    }

    func loadMore() async {
        guard hasMore, !isSearching else { return }
        await performSearch(query: query, projectPath: currentProjectPath, reset: false)
    }

    func clearResults() {
        searchTask?.cancel()
        results = []
        totalResults = 0
        hasMore = false
        currentOffset = 0
        error = nil
    }

    func refresh() async {
        guard !query.isEmpty else { return }
        await performSearch(query: query, projectPath: currentProjectPath, reset: true)
    }
}

// MARK: - Global Search View

struct GlobalSearchView: View {
    let projects: [Project]
    let onSelect: ((CLISearchResult) -> Void)?
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @StateObject private var searchService: SearchService
    @ObservedObject private var historyStore = SearchHistoryStore.shared
    @State private var hasSearched = false
    @State private var selectedProject: Project?
    @State private var dateFilter: SearchDateFilter = .anyTime
    @FocusState private var isSearchFocused: Bool

    init(projects: [Project], serverURL: String = "", onSelect: ((CLISearchResult) -> Void)? = nil) {
        self.projects = projects
        self.onSelect = onSelect
        _searchService = StateObject(wrappedValue: SearchService(serverURL: serverURL))
    }

    /// Filtered results based on date filter
    private var filteredResults: [CLISearchResult] {
        guard dateFilter != .anyTime else { return searchService.results }
        return searchService.results.filter { result in
            guard let date = result.date else { return true }
            return dateFilter.matches(date)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                if !searchService.results.isEmpty || hasSearched {
                    filterBar
                }

                searchContent
            }
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Search All Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(CLITheme.blue(for: colorScheme))
                }
            }
            .searchable(
                text: $searchService.query,
                prompt: "Search across all sessions..."
            )
        }
        .onChange(of: searchService.query) { oldValue, newValue in
            if newValue.isEmpty {
                hasSearched = false
            }
        }
        .onChange(of: selectedProject) { _, newValue in
            searchService.setProjectFilter(newValue?.path)
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Project filter
                Menu {
                    Button {
                        selectedProject = nil
                    } label: {
                        HStack {
                            Text("All Projects")
                            if selectedProject == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    Divider()

                    ForEach(projects) { project in
                        Button {
                            selectedProject = project
                        } label: {
                            HStack {
                                Text(project.title)
                                if selectedProject?.id == project.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    SearchFilterChip(
                        icon: "folder",
                        text: selectedProject?.title ?? "All Projects",
                        isActive: selectedProject != nil
                    )
                }

                // Date filter
                Menu {
                    ForEach(SearchDateFilter.allCases) { filter in
                        Button {
                            dateFilter = filter
                        } label: {
                            HStack {
                                Text(filter.rawValue)
                                if dateFilter == filter {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    SearchFilterChip(
                        icon: "calendar",
                        text: dateFilter.rawValue,
                        isActive: dateFilter != .anyTime
                    )
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(CLITheme.secondaryBackground(for: colorScheme))
    }

    // MARK: - Search Content

    @ViewBuilder
    private var searchContent: some View {
        if searchService.isSearching && searchService.results.isEmpty {
            loadingView
        } else if let error = searchService.error {
            errorView(error)
        } else if searchService.results.isEmpty && hasSearched {
            emptyResultsView
        } else if searchService.results.isEmpty && searchService.query.isEmpty {
            suggestionsView
        } else {
            resultsList
        }
    }

    // MARK: - Suggestions View (Recent Searches + Tips)

    private var suggestionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Recent searches
                if !historyStore.recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recent Searches")
                                .font(settings.scaledFont(.body))
                                .fontWeight(.medium)
                                .foregroundColor(CLITheme.secondaryText(for: colorScheme))

                            Spacer()

                            Button("Clear") {
                                historyStore.clearHistory()
                            }
                            .font(settings.scaledFont(.small))
                            .foregroundColor(CLITheme.blue(for: colorScheme))
                        }

                        ForEach(historyStore.recentSearches, id: \.self) { query in
                            Button {
                                searchService.query = query
                                hasSearched = true
                            } label: {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 14))
                                        .foregroundColor(CLITheme.mutedText(for: colorScheme))

                                    Text(query)
                                        .font(settings.scaledFont(.body))
                                        .foregroundColor(CLITheme.primaryText(for: colorScheme))

                                    Spacer()

                                    Image(systemName: "arrow.up.left")
                                        .font(.system(size: 12))
                                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding()
                    .background(CLITheme.secondaryBackground(for: colorScheme))
                    .cornerRadius(12)
                }

                // Search tips
                VStack(alignment: .leading, spacing: 12) {
                    Text("Search Tips")
                        .font(settings.scaledFont(.body))
                        .fontWeight(.medium)
                        .foregroundColor(CLITheme.secondaryText(for: colorScheme))

                    SearchTipRow(
                        icon: "text.bubble",
                        text: "Search messages, code, and tool outputs"
                    )

                    SearchTipRow(
                        icon: "folder",
                        text: "Filter by project for faster results"
                    )

                    SearchTipRow(
                        icon: "hand.tap",
                        text: "Tap a result to jump to that session"
                    )
                }
                .padding()
                .background(CLITheme.secondaryBackground(for: colorScheme))
                .cornerRadius(12)
            }
            .padding()
        }
    }

    private var resultsList: some View {
        VStack(spacing: 0) {
            // Result count with filter info
            HStack {
                if dateFilter != .anyTime && filteredResults.count != searchService.totalResults {
                    Text("\(filteredResults.count) of \(searchService.totalResults) result\(searchService.totalResults == 1 ? "" : "s")")
                } else {
                    Text("\(searchService.totalResults) result\(searchService.totalResults == 1 ? "" : "s")")
                }
                Spacer()
            }
            .font(settings.scaledFont(.small))
            .foregroundColor(CLITheme.mutedText(for: colorScheme))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(CLITheme.secondaryBackground(for: colorScheme))

            List {
                ForEach(filteredResults) { result in
                    Button {
                        onSelect?(result)
                    } label: {
                        SearchResultRow(result: result, projects: projects)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(CLITheme.background(for: colorScheme))
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .onAppear {
                        // Load more when approaching end
                        if result.id == searchService.results.last?.id && searchService.hasMore {
                            Task { await searchService.loadMore() }
                        }
                    }
                }

                // Loading indicator for infinite scroll
                if searchService.isSearching && searchService.hasMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: CLITheme.blue(for: colorScheme)))
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .background(CLITheme.background(for: colorScheme))
        }
        .onAppear {
            hasSearched = !searchService.query.isEmpty
        }
        .onChange(of: searchService.results) { _, _ in
            hasSearched = true
        }
    }

    // MARK: - Shared Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: CLITheme.blue(for: colorScheme)))

            Text("Searching sessions...")
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(CLITheme.yellow(for: colorScheme))

            Text("Search Error")
                .font(settings.scaledFont(.large))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            Text(error)
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task { await searchService.refresh() }
            }
            .foregroundColor(CLITheme.blue(for: colorScheme))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))

            Text("No Results")
                .font(settings.scaledFont(.large))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            Text("No messages found matching \"\(searchService.query)\"")
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Search Filter Chip

private struct SearchFilterChip: View {
    let icon: String
    let text: String
    let isActive: Bool
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))

            Text(text)
                .font(settings.scaledFont(.small))
                .lineLimit(1)

            Image(systemName: "chevron.down")
                .font(.system(size: 10))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .foregroundColor(isActive ? .white : CLITheme.primaryText(for: colorScheme))
        .background(isActive ? CLITheme.blue(for: colorScheme) : CLITheme.background(for: colorScheme))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(CLITheme.mutedText(for: colorScheme).opacity(0.3), lineWidth: isActive ? 0 : 1)
        )
    }
}

// MARK: - Search Tip Row

private struct SearchTipRow: View {
    let icon: String
    let text: String
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(CLITheme.blue(for: colorScheme))
                .frame(width: 24)

            Text(text)
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: CLISearchResult
    let projects: [Project]
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    private var projectTitle: String {
        projects.first { $0.path == result.projectPath }?.title ?? result.projectName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(CLITheme.blue(for: colorScheme))
                    .font(.system(size: 12))

                Text(projectTitle)
                    .font(settings.scaledFont(.body).bold())
                    .foregroundColor(CLITheme.primaryText(for: colorScheme))
                    .lineLimit(1)

                Spacer()

                Text(result.formattedDate)
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }

            // Snippets with highlighting
            ForEach(result.snippets) { snippet in
                SnippetView(snippet: snippet)
            }

            // Score badge
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundColor(CLITheme.yellow(for: colorScheme))

                Text("Relevance: \(Int(result.score))")
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))

                Spacer()

                Text("Session: \(result.sessionId.prefix(8))...")
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button {
                UIPasteboard.general.string = result.snippet
            } label: {
                Label("Copy Preview", systemImage: "doc.on.doc")
            }
        }
    }
}

// MARK: - Snippet View with Highlighting

struct SnippetView: View {
    let snippet: CLISearchSnippet
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: snippet.messageTypeIcon)
                .font(.system(size: 10))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                .frame(width: 16)

            // Highlighted text
            Text(highlightedText)
                .font(settings.scaledFont(.body))
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }

    private var highlightedText: AttributedString {
        var text = AttributedString(snippet.text)

        // Set default foreground color for the entire text
        text.foregroundColor = CLITheme.primaryText(for: colorScheme)

        // Find the range to highlight using string indices
        let sourceString = snippet.text
        let startOffset = min(snippet.matchStart, sourceString.count)
        let endOffset = min(snippet.matchStart + snippet.matchLength, sourceString.count)

        guard startOffset < endOffset,
              startOffset >= 0 else {
            return text
        }

        // Convert String indices to AttributedString indices
        let sourceStartIndex = sourceString.index(sourceString.startIndex, offsetBy: startOffset)
        let sourceEndIndex = sourceString.index(sourceString.startIndex, offsetBy: endOffset)
        let sourceRange = sourceStartIndex..<sourceEndIndex

        // Find the equivalent range in the AttributedString
        if let attributedRange = Range(sourceRange, in: text) {
            text[attributedRange].backgroundColor = CLITheme.yellow(for: colorScheme).opacity(0.3)
            text[attributedRange].font = settings.scaledFont(.body).bold()
        }

        return text
    }
}
