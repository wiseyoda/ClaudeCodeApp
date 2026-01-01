import SwiftUI
import UniformTypeIdentifiers

// MARK: - Session Names Storage

/// Stores custom names for sessions (persisted locally)
class SessionNamesStore {
    static let shared = SessionNamesStore()
    private let key = "session_custom_names"

    func getName(for sessionId: String) -> String? {
        let names = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
        return names[sessionId]
    }

    func setName(_ name: String?, for sessionId: String) {
        var names = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
        if let name = name, !name.isEmpty {
            names[sessionId] = name
        } else {
            names.removeValue(forKey: sessionId)
        }
        UserDefaults.standard.set(names, forKey: key)
    }
}

// MARK: - Session Bar (Compact UI)

/// Compact session bar showing current session name with action buttons.
/// Layout: `| <session name> [+] [≡] |`
struct SessionBar: View {
    let project: Project
    @Binding var sessions: [ProjectSession]
    @Binding var selected: ProjectSession?
    var isLoading: Bool = false
    var isProcessing: Bool = false
    var activeSessionId: String?
    let onSelect: (ProjectSession) -> Void
    let onNew: () -> Void
    let onDelete: ((ProjectSession) -> Void)?

    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    @State private var showSessionSheet = false

    /// Get display name for current session
    private var currentSessionName: String {
        // Priority: selected session -> active session -> "No Session"
        if let session = selected ?? currentSession {
            if let customName = SessionNamesStore.shared.getName(for: session.id) {
                return customName
            }
            if let summary = session.summary, !summary.isEmpty {
                return String(summary.prefix(40))
            }
            // Fallback to last user message if no summary
            if let lastUser = session.lastUserMessage, !lastUser.isEmpty {
                return String(lastUser.prefix(40))
            }
            return "Session \(session.id.prefix(6))..."
        }
        return "No Session"
    }

    /// Get the current active session
    private var currentSession: ProjectSession? {
        guard let activeId = activeSessionId else { return nil }
        return sessions.first { $0.id == activeId }
    }

    /// Check if we have an active session
    private var hasActiveSession: Bool {
        selected != nil || activeSessionId != nil
    }

    var body: some View {
        HStack(spacing: 8) {
            // Session name (tappable to open session manager)
            Button {
                showSessionSheet = true
            } label: {
                HStack(spacing: 6) {
                    // Processing indicator
                    if isProcessing {
                        Circle()
                            .fill(CLITheme.yellow(for: colorScheme))
                            .frame(width: 6, height: 6)
                    } else if isLoading {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 10, height: 10)
                    }

                    Text(currentSessionName)
                        .font(settings.scaledFont(.small))
                        .foregroundColor(hasActiveSession ? CLITheme.primaryText(for: colorScheme) : CLITheme.mutedText(for: colorScheme))
                        .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(CLITheme.secondaryBackground(for: colorScheme))
                .cornerRadius(4)
            }
            .accessibilityLabel("Current session: \(currentSessionName)")
            .accessibilityHint("Tap to open session manager")

            Spacer()

            // New session button
            Button {
                onNew()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(CLITheme.cyan(for: colorScheme))
                    .frame(width: 32, height: 28)
                    .background(CLITheme.secondaryBackground(for: colorScheme))
                    .cornerRadius(4)
            }
            .accessibilityLabel("New session")

            // Session manager button
            Button {
                showSessionSheet = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                    .frame(width: 32, height: 28)
                    .background(CLITheme.secondaryBackground(for: colorScheme))
                    .cornerRadius(4)
            }
            .accessibilityLabel("Session manager")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(CLITheme.background(for: colorScheme))
        .sheet(isPresented: $showSessionSheet) {
            SessionPickerSheet(
                project: project,
                sessions: $sessions,
                activeSessionId: activeSessionId ?? selected?.id,
                onSelect: { session in
                    showSessionSheet = false
                    selected = session
                    onSelect(session)
                },
                onCancel: {
                    showSessionSheet = false
                },
                onDelete: onDelete
            )
        }
    }
}

// MARK: - Session Picker Sheet

struct SessionPickerSheet: View {
    let project: Project
    @Binding var sessions: [ProjectSession]  // Fallback for API sessions (before SessionStore loads)
    var activeSessionId: String?  // Currently active session (may be new with few messages)
    let onSelect: (ProjectSession) -> Void
    let onCancel: () -> Void
    var onDelete: ((ProjectSession) -> Void)?
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var settings: AppSettings

    @State private var sessionToDelete: ProjectSession?
    @State private var sessionToRename: ProjectSession?
    @State private var renameText = ""
    @State private var sessionToExport: ProjectSession?
    @State private var exportedMarkdown: String?
    @State private var showExportSheet = false

    // Search state
    @State private var searchQuery = ""
    @State private var searchTask: Task<Void, Never>?

    // Archive toggle state
    @State private var showArchived = false

    // Bulk delete state
    @State private var showBulkActions = false
    @State private var showDeleteAgeOptions = false
    @State private var showKeepNOptions = false
    @State private var bulkDeleteConfirmation: BulkDeleteType? = nil
    @State private var isDeletingBulk = false

    @ObservedObject private var sessionStore = SessionStore.shared

    /// Types of bulk delete operations for confirmation dialogs
    enum BulkDeleteType: Identifiable {
        case all(count: Int, protectActive: Bool)
        case olderThan(days: Int, count: Int)
        case keepLastN(keeping: Int, deleting: Int)

        var id: String {
            switch self {
            case .all: return "all"
            case .olderThan: return "olderThan"
            case .keepLastN: return "keepLastN"
            }
        }
    }

    /// Whether we're currently searching
    private var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Search results from SessionStore
    private var searchResults: [CLISessionSearchResult] {
        sessionStore.searchResults[project.path]?.results ?? []
    }

    /// Whether search is in progress
    private var isSearchingActive: Bool {
        sessionStore.isSearchingSessions(for: project.path)
    }

    /// Sessions to display - use SessionStore as single source of truth
    /// Only fall back to binding if API hasn't loaded yet
    private var displaySessions: [ProjectSession] {
        let storeSessions = sessionStore.sessions(for: project.path)

        // If we've loaded from API, always use SessionStore (even if empty = all deleted)
        if sessionStore.hasLoaded(for: project.path) {
            return storeSessions.filterAndSortForDisplay(projectPath: project.path, activeSessionId: activeSessionId)
        }

        // Before API loads, use binding as fallback
        let baseSessions = storeSessions.isEmpty ? Array(sessions) : storeSessions
        return baseSessions.filterAndSortForDisplay(projectPath: project.path, activeSessionId: activeSessionId)
    }

    /// Whether sessions are currently loading
    private var isLoadingAllSessions: Bool {
        sessionStore.isLoadingSessions(for: project.path)
    }

    /// Whether more sessions are available to load (pagination)
    private var hasMoreSessions: Bool {
        SessionStore.shared.hasMore(for: project.path)
    }

    /// Load more sessions (pagination)
    private func loadMoreSessions() {
        Task {
            await SessionStore.shared.loadMore(for: project.path)
        }
    }

    /// Load all sessions via API (SessionStore handles API-based loading)
    /// Always force refresh to ensure we have the latest sessions from the server
    private func loadAllSessions() {
        Task {
            sessionStore.configure(with: settings)
            // Always force refresh to get all sessions from API
            // Don't skip based on hasLoaded - that would miss sessions
            // when ChatView has only added the current session locally
            await sessionStore.loadSessions(for: project.path, forceRefresh: true)
        }
    }

    private func parseDate(_ isoString: String?) -> Date {
        guard let isoString = isoString else { return .distantPast }
        return CLIDateFormatter.parseDate(isoString) ?? .distantPast
    }

    // MARK: - Search Bar View
    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
            TextField("Search sessions...", text: $searchQuery)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: searchQuery) { _, newValue in
                    handleSearchQueryChange(newValue)
                }
            if isSearching {
                searchClearButton
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(CLITheme.secondaryBackground(for: colorScheme))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var searchClearButton: some View {
        if isSearchingActive {
            ProgressView()
                .scaleEffect(0.7)
        } else {
            Button {
                searchQuery = ""
                sessionStore.clearSearch(for: project.path)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }
        }
    }

    private func handleSearchQueryChange(_ newValue: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if !Task.isCancelled && !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await sessionStore.searchSessions(for: project.path, query: newValue)
            } else if newValue.isEmpty {
                sessionStore.clearSearch(for: project.path)
            }
        }
    }

    // MARK: - Archive Toggle View
    @ViewBuilder
    private var archiveToggle: some View {
        HStack {
            Button {
                showArchived.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showArchived ? "archivebox.fill" : "archivebox")
                    Text(showArchived ? "Showing Archived" : "Show Archived")
                }
                .font(.caption)
                .foregroundColor(showArchived ? CLITheme.orange(for: colorScheme) : CLITheme.mutedText(for: colorScheme))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    // MARK: - Search Results View
    @ViewBuilder
    private var searchResultsView: some View {
        if isSearchingActive {
            searchingPlaceholder
        } else if searchResults.isEmpty {
            noSearchResultsView
        } else {
            searchResultsList
        }
    }

    @ViewBuilder
    private var searchingPlaceholder: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Searching...")
                .font(.subheadline)
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
        }
        .padding()
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var noSearchResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))

            Text("No Results")
                .font(.headline)
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            Text("No sessions match \"\(searchQuery)\"")
                .font(.subheadline)
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var searchResultsList: some View {
        List {
            ForEach(searchResults) { result in
                Button {
                    selectSearchResult(result)
                } label: {
                    SessionSearchResultRow(result: result)
                }
                .listRowBackground(CLITheme.secondaryBackground(for: colorScheme))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func selectSearchResult(_ result: CLISessionSearchResult) {
        if let session = displaySessions.first(where: { $0.id == result.sessionId }) {
            onSelect(session)
        } else {
            let session = ProjectSession(
                id: result.sessionId,
                projectPath: result.projectPath,
                summary: nil,
                lastActivity: nil,
                messageCount: nil,
                lastUserMessage: nil,
                lastAssistantMessage: nil
            )
            onSelect(session)
        }
    }

    // MARK: - Sessions List View
    @ViewBuilder
    private var sessionsListView: some View {
        if isLoadingAllSessions && displaySessions.isEmpty {
            loadingPlaceholder
        } else if displaySessions.isEmpty {
            emptySessionsView
        } else {
            sessionsList
        }
    }

    @ViewBuilder
    private var loadingPlaceholder: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading all sessions...")
                .font(.subheadline)
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
        }
        .padding()
    }

    @ViewBuilder
    private var emptySessionsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))

            Text("No Previous Sessions")
                .font(.headline)
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            Text("Start a conversation to create your first session.")
                .font(.subheadline)
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    @ViewBuilder
    private var sessionsList: some View {
        List {
            ForEach(displaySessions) { session in
                sessionRowButton(for: session)
            }

            if hasMoreSessions {
                loadMoreButton
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func sessionRowButton(for session: ProjectSession) -> some View {
        Button {
            onSelect(session)
        } label: {
            SessionRow(session: session, isArchived: session.isArchived)
        }
        .listRowBackground(CLITheme.secondaryBackground(for: colorScheme))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                sessionToDelete = session
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            archiveSwipeButton(for: session)
            exportSwipeButton(for: session)
        }
        .contextMenu {
            sessionContextMenu(for: session)
        }
    }

    @ViewBuilder
    private func archiveSwipeButton(for session: ProjectSession) -> some View {
        Button {
            Task {
                if session.isArchived {
                    await sessionStore.unarchiveSession(session, for: project.path)
                } else {
                    await sessionStore.archiveSession(session, for: project.path)
                }
            }
        } label: {
            Label(
                session.isArchived ? "Unarchive" : "Archive",
                systemImage: session.isArchived ? "tray.and.arrow.up" : "archivebox"
            )
        }
        .tint(CLITheme.orange(for: colorScheme))
    }

    @ViewBuilder
    private func exportSwipeButton(for session: ProjectSession) -> some View {
        Button {
            sessionToExport = session
            exportSession(session)
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .tint(CLITheme.cyan(for: colorScheme))
    }

    @ViewBuilder
    private func sessionContextMenu(for session: ProjectSession) -> some View {
        Button {
            sessionToRename = session
            renameText = SessionNamesStore.shared.getName(for: session.id) ?? session.summary ?? ""
        } label: {
            Label("Rename", systemImage: "pencil")
        }

        Button {
            sessionToExport = session
            exportSession(session)
        } label: {
            Label("Export as Markdown", systemImage: "doc.text")
        }

        Button {
            Task {
                if session.isArchived {
                    await sessionStore.unarchiveSession(session, for: project.path)
                } else {
                    await sessionStore.archiveSession(session, for: project.path)
                }
            }
        } label: {
            Label(
                session.isArchived ? "Unarchive" : "Archive",
                systemImage: session.isArchived ? "tray.and.arrow.up" : "archivebox"
            )
        }

        Divider()

        Button(role: .destructive) {
            sessionToDelete = session
        } label: {
            Label("Delete Session", systemImage: "trash")
        }
    }

    @ViewBuilder
    private var loadMoreButton: some View {
        Button {
            loadMoreSessions()
        } label: {
            HStack {
                Spacer()
                if isLoadingAllSessions {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                } else {
                    Image(systemName: "arrow.down.circle")
                    Text("Load More Sessions")
                }
                Spacer()
            }
            .padding(.vertical, 12)
        }
        .foregroundColor(CLITheme.cyan(for: colorScheme))
        .listRowBackground(CLITheme.secondaryBackground(for: colorScheme))
    }

    // MARK: - Main Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                if !isSearching {
                    archiveToggle
                }

                if isSearching {
                    searchResultsView
                } else {
                    sessionsListView
                }
            }
            .background(CLITheme.background(for: colorScheme))
            .onAppear {
                loadAllSessions()
            }
            .navigationTitle(isLoadingAllSessions ? "Sessions (loading...)" : "Sessions (\(displaySessions.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isDeletingBulk {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button("Manage") {
                            showBulkActions = true
                        }
                        .foregroundColor(CLITheme.cyan(for: colorScheme))
                        .disabled(displaySessions.isEmpty)
                    }
                }
            }
            .alert("Delete Session?", isPresented: .init(
                get: { sessionToDelete != nil },
                set: { if !$0 { sessionToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    sessionToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let session = sessionToDelete {
                        // Call parent's delete handler - SessionStore handles state updates
                        onDelete?(session)
                        sessionToDelete = nil
                    }
                }
            } message: {
                Text("This will permanently delete this session's history.")
            }
            .alert("Rename Session", isPresented: .init(
                get: { sessionToRename != nil },
                set: { if !$0 { sessionToRename = nil } }
            )) {
                TextField("Session name", text: $renameText)
                Button("Cancel", role: .cancel) {
                    sessionToRename = nil
                    renameText = ""
                }
                Button("Save") {
                    if let session = sessionToRename {
                        SessionNamesStore.shared.setName(renameText.isEmpty ? nil : renameText, for: session.id)
                    }
                    sessionToRename = nil
                    renameText = ""
                }
            } message: {
                Text("Enter a custom name for this session")
            }
            .sheet(isPresented: $showExportSheet) {
                if let markdown = exportedMarkdown {
                    SessionExportSheet(markdown: markdown, sessionId: sessionToExport?.id ?? "session")
                }
            }
            // MARK: - Bulk Actions
            .confirmationDialog("Manage Sessions", isPresented: $showBulkActions, titleVisibility: .visible) {
                Button("Delete All Sessions", role: .destructive) {
                    let (count, hasActive) = sessionStore.countSessionsToDelete(for: project.path)
                    let deleteCount = hasActive ? count - 1 : count
                    if deleteCount > 0 {
                        bulkDeleteConfirmation = .all(count: deleteCount, protectActive: hasActive)
                    }
                }
                Button("Delete Old Sessions...") {
                    showDeleteAgeOptions = true
                }
                Button("Keep Last N Sessions...") {
                    showKeepNOptions = true
                }
                Button("Cancel", role: .cancel) { }
            }
            // Age options picker
            .confirmationDialog("Delete Sessions Older Than", isPresented: $showDeleteAgeOptions, titleVisibility: .visible) {
                Button("7 Days") {
                    let date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                    let count = sessionStore.countSessionsOlderThan(date, for: project.path)
                    if count > 0 {
                        bulkDeleteConfirmation = .olderThan(days: 7, count: count)
                    }
                }
                Button("30 Days") {
                    let date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
                    let count = sessionStore.countSessionsOlderThan(date, for: project.path)
                    if count > 0 {
                        bulkDeleteConfirmation = .olderThan(days: 30, count: count)
                    }
                }
                Button("90 Days") {
                    let date = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
                    let count = sessionStore.countSessionsOlderThan(date, for: project.path)
                    if count > 0 {
                        bulkDeleteConfirmation = .olderThan(days: 90, count: count)
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            // Keep N options picker
            .confirmationDialog("Keep How Many Sessions?", isPresented: $showKeepNOptions, titleVisibility: .visible) {
                Button("Keep Last 5") {
                    let count = sessionStore.countSessionsToDeleteKeepingN(5, for: project.path)
                    if count > 0 {
                        bulkDeleteConfirmation = .keepLastN(keeping: 5, deleting: count)
                    }
                }
                Button("Keep Last 10") {
                    let count = sessionStore.countSessionsToDeleteKeepingN(10, for: project.path)
                    if count > 0 {
                        bulkDeleteConfirmation = .keepLastN(keeping: 10, deleting: count)
                    }
                }
                Button("Keep Last 20") {
                    let count = sessionStore.countSessionsToDeleteKeepingN(20, for: project.path)
                    if count > 0 {
                        bulkDeleteConfirmation = .keepLastN(keeping: 20, deleting: count)
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            // Bulk delete confirmation
            .alert(bulkDeleteTitle, isPresented: .init(
                get: { bulkDeleteConfirmation != nil },
                set: { if !$0 { bulkDeleteConfirmation = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    bulkDeleteConfirmation = nil
                }
                Button("Delete", role: .destructive) {
                    executeBulkDelete()
                }
            } message: {
                Text(bulkDeleteMessage)
            }
        }
    }

    // MARK: - Bulk Delete Helpers

    private var bulkDeleteTitle: String {
        guard let confirmation = bulkDeleteConfirmation else { return "Delete Sessions?" }
        switch confirmation {
        case .all(let count, _):
            return "Delete \(count) Session\(count == 1 ? "" : "s")?"
        case .olderThan(let days, let count):
            return "Delete \(count) Session\(count == 1 ? "" : "s") Older Than \(days) Days?"
        case .keepLastN(_, let deleting):
            return "Delete \(deleting) Session\(deleting == 1 ? "" : "s")?"
        }
    }

    private var bulkDeleteMessage: String {
        guard let confirmation = bulkDeleteConfirmation else { return "" }
        switch confirmation {
        case .all(_, let protectActive):
            if protectActive {
                return "This will permanently delete all sessions except the currently active one."
            }
            return "This will permanently delete all sessions for this project."
        case .olderThan(let days, _):
            return "This will permanently delete all sessions that haven't been used in over \(days) days."
        case .keepLastN(let keeping, _):
            return "This will keep only the \(keeping) most recent sessions and delete the rest."
        }
    }

    private func executeBulkDelete() {
        guard let confirmation = bulkDeleteConfirmation else { return }
        isDeletingBulk = true

        Task {
            switch confirmation {
            case .all(_, _):
                _ = await sessionStore.deleteAllSessions(for: project.path, keepActiveSession: true)
            case .olderThan(let days, _):
                let date = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
                _ = await sessionStore.deleteSessionsOlderThan(date, for: project.path)
            case .keepLastN(let keeping, _):
                _ = await sessionStore.keepOnlyLastN(keeping, for: project.path)
            }
            isDeletingBulk = false
            bulkDeleteConfirmation = nil
        }
    }

    private func exportSession(_ session: ProjectSession) {
        // Build markdown from session info
        var markdown = "# Session: \(SessionNamesStore.shared.getName(for: session.id) ?? session.summary ?? session.id.prefix(8).description)\n\n"
        markdown += "**Project:** \(project.title)\n"
        markdown += "**Path:** \(project.path)\n"
        if let activity = session.lastActivity {
            markdown += "**Last Activity:** \(activity)\n"
        }
        if let count = session.messageCount {
            markdown += "**Messages:** \(count)\n"
        }
        markdown += "\n---\n\n"

        if let lastUser = session.lastUserMessage {
            markdown += "## Last User Message\n\n\(lastUser)\n\n"
        }
        if let lastAssistant = session.lastAssistantMessage {
            markdown += "## Last Assistant Response\n\n\(lastAssistant)\n\n"
        }

        markdown += "\n---\n\n*Exported from Coding Bridge*\n"

        exportedMarkdown = markdown
        showExportSheet = true
    }
}

// MARK: - Session Export Sheet

struct SessionExportSheet: View {
    let markdown: String
    let sessionId: String
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(markdown)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(CLITheme.primaryText(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)  // Force word wrap
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Export Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button {
                            UIPasteboard.general.string = markdown
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }

                        Button {
                            shareMarkdown()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    private func shareMarkdown() {
        let activityVC = UIActivityViewController(
            activityItems: [markdown],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Session Search Result Row

struct SessionSearchResultRow: View {
    let result: CLISessionSearchResult
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Session ID
            Text("Session \(result.sessionId.prefix(8))...")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(CLITheme.cyan(for: colorScheme))

            // Matches with highlighted snippets
            ForEach(result.matches.prefix(2), id: \.messageId) { match in
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: match.role == "user" ? "person.fill" : "cpu")
                        .font(.caption)
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))

                    Text(match.snippet)
                        .font(.subheadline)
                        .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                        .lineLimit(2)
                }
            }

            // Match count and score
            HStack {
                Text("\(result.matches.count) match\(result.matches.count == 1 ? "" : "es")")
                    .font(.caption)
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))

                Text("•")
                    .font(.caption)
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))

                Text("Score: \(String(format: "%.1f", result.score))")
                    .font(.caption)
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: ProjectSession
    var isArchived: Bool = false
    @Environment(\.colorScheme) var colorScheme

    // MARK: - Shared Formatters (expensive to create, so share across all instances)
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private var displayName: String {
        if let customName = SessionNamesStore.shared.getName(for: session.id) {
            return customName
        }
        if let summary = session.summary, !summary.isEmpty {
            return summary
        }
        // Fallback to last user message if no summary
        if let lastUser = session.lastUserMessage, !lastUser.isEmpty {
            return lastUser
        }
        return "Session \(session.id.prefix(8))..."
    }

    private var hasCustomName: Bool {
        SessionNamesStore.shared.getName(for: session.id) != nil
    }

    /// Preview text to show below the session name
    /// Shows assistant's last response (more informative), or user's message if different from title
    private var previewText: String? {
        // Prefer showing what Claude was working on (more informative)
        if let assistantMsg = session.lastAssistantMessage, !assistantMsg.isEmpty {
            // Truncate long responses to first meaningful line
            let firstLine = assistantMsg.components(separatedBy: .newlines).first ?? assistantMsg
            return String(firstLine.prefix(100))
        }

        // Fall back to user message only if different from display name
        if let userMsg = session.lastUserMessage, !userMsg.isEmpty {
            // Don't show if it's the same as the title (avoids "Test" / "Test" duplication)
            let normalizedUser = userMsg.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let normalizedDisplay = displayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalizedUser != normalizedDisplay {
                return userMsg
            }
        }

        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Archive indicator
                if isArchived {
                    Image(systemName: "archivebox.fill")
                        .font(.caption)
                        .foregroundColor(CLITheme.orange(for: colorScheme))
                }

                Text(displayName)
                    .font(.system(.body, design: hasCustomName ? .default : .monospaced))
                    .foregroundColor(isArchived ? CLITheme.mutedText(for: colorScheme) : CLITheme.cyan(for: colorScheme))
                    .lineLimit(1)

                Spacer()

                if let activity = session.lastActivity {
                    Text(formatRelativeTime(activity))
                        .font(.caption)
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                }
            }

            // Show preview text (assistant response or different user message)
            if let preview = previewText {
                Text(preview)
                    .font(.subheadline)
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                    .lineLimit(2)
                    .opacity(isArchived ? 0.7 : 1.0)
            }

            HStack {
                if let count = session.messageCount {
                    Text("\(count) messages")
                        .font(.caption)
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                }

                // Show archived label
                if isArchived {
                    Text("•")
                        .font(.caption)
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    Text("Archived")
                        .font(.caption)
                        .foregroundColor(CLITheme.orange(for: colorScheme))
                }

                // Show session ID if we have a custom name
                if hasCustomName {
                    Text("•")
                        .font(.caption)
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    Text(session.id.prefix(8) + "...")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(isArchived ? 0.8 : 1.0)
    }

    private func formatRelativeTime(_ isoString: String) -> String {
        guard let date = CLIDateFormatter.parseDate(isoString) else {
            return isoString
        }
        return Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}
