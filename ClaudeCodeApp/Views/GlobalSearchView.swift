import SwiftUI

// MARK: - Global Search Result

struct GlobalSearchResult: Identifiable {
    let id = UUID()
    let projectPath: String
    let projectTitle: String
    let sessionId: String
    let message: ChatMessage
    let matchPreview: String
}

// MARK: - Global Search View

struct GlobalSearchView: View {
    let projects: [Project]
    @EnvironmentObject var settings: AppSettings
    @ObservedObject private var sshManager = SSHManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @State private var searchText = ""
    @State private var isSearching = false
    @State private var results: [GlobalSearchResult] = []
    @State private var searchError: String?
    @State private var hasSearched = false
    @State private var searchTask: Task<Void, Never>?
    @State private var connectTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search input
                searchInputView

                // Results or placeholder
                if isSearching {
                    loadingView
                } else if let error = searchError {
                    errorView(error)
                } else if results.isEmpty && hasSearched {
                    emptyResultsView
                } else if results.isEmpty {
                    placeholderView
                } else {
                    resultsList
                }
            }
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Search All Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CLITheme.secondaryBackground(for: colorScheme), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(CLITheme.blue(for: colorScheme))
                }
            }
        }
        .onAppear {
            connectSSH()
        }
        .onDisappear {
            // Cancel any pending tasks to prevent hangs
            searchTask?.cancel()
            connectTask?.cancel()
        }
    }

    private var searchInputView: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    .font(.system(size: 14))

                TextField("Search across all sessions...", text: $searchText)
                    .font(settings.scaledFont(.body))
                    .foregroundColor(CLITheme.primaryText(for: colorScheme))
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit {
                        performSearch()
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        results = []
                        hasSearched = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(CLITheme.mutedText(for: colorScheme))
                            .font(.system(size: 14))
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(CLITheme.background(for: colorScheme))
            .cornerRadius(8)

            Button("Search") {
                performSearch()
            }
            .font(settings.scaledFont(.body))
            .foregroundColor(searchText.isEmpty ? CLITheme.mutedText(for: colorScheme) : CLITheme.blue(for: colorScheme))
            .disabled(searchText.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(CLITheme.secondaryBackground(for: colorScheme))
    }

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
                connectSSH()
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

            Text("No messages found matching \"\(searchText)\"")
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))

            Text("Search All Sessions")
                .font(settings.scaledFont(.large))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            Text("Find messages across all your projects and sessions")
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsList: some View {
        VStack(spacing: 0) {
            // Result count
            HStack {
                Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(CLITheme.secondaryBackground(for: colorScheme))

            List {
                ForEach(results) { result in
                    GlobalSearchResultRow(result: result, searchText: searchText)
                        .listRowBackground(CLITheme.background(for: colorScheme))
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }
            }
            .listStyle(.plain)
            .background(CLITheme.background(for: colorScheme))
        }
    }

    // MARK: - SSH Connection

    private func connectSSH() {
        searchError = nil
        connectTask?.cancel()
        connectTask = Task {
            do {
                try await sshManager.autoConnect(settings: settings)
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    searchError = "Failed to connect: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Search

    private func performSearch() {
        guard !searchText.isEmpty else { return }
        guard sshManager.isConnected else {
            searchError = "SSH not connected. Please check settings."
            return
        }

        // Cancel any previous search
        searchTask?.cancel()

        isSearching = true
        searchError = nil
        results = []

        searchTask = Task {
            var allResults: [GlobalSearchResult] = []

            for project in projects {
                // Check for cancellation between projects
                guard !Task.isCancelled else { return }

                // Encode project path for Claude session directory
                let encodedPath = project.path
                    .replacingOccurrences(of: "/", with: "-")

                // List session files (use $HOME for consistent shell expansion)
                let sessionsPath = "$HOME/.claude/projects/\(encodedPath)"
                if let output = try? await sshManager.executeCommand("ls \(sessionsPath)/*.jsonl 2>/dev/null") {
                    let files = output.components(separatedBy: .newlines).filter { !$0.isEmpty }

                    for file in files.prefix(20) { // Limit to 20 sessions per project
                        // Check for cancellation between files
                        guard !Task.isCancelled else { return }

                        // Extract session ID from filename
                        let sessionId = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent

                        // Read and search the file
                        if let content = try? await sshManager.executeCommand("cat '\(file)'") {
                            let messages = SessionHistoryLoader.parseSessionHistory(content)
                            let matches = messages.filter {
                                $0.content.localizedCaseInsensitiveContains(searchText)
                            }

                            for message in matches.prefix(5) { // Limit matches per session
                                let preview = createPreview(content: message.content, searchText: searchText)
                                allResults.append(GlobalSearchResult(
                                    projectPath: project.path,
                                    projectTitle: project.title,
                                    sessionId: sessionId,
                                    message: message,
                                    matchPreview: preview
                                ))
                            }
                        }
                    }
                }
            }

            // Only update UI if not cancelled
            guard !Task.isCancelled else { return }

            await MainActor.run {
                // Sort by timestamp, newest first
                results = allResults.sorted { $0.message.timestamp > $1.message.timestamp }
                isSearching = false
                hasSearched = true
            }
        }
    }

    private func createPreview(content: String, searchText: String) -> String {
        guard let range = content.range(of: searchText, options: .caseInsensitive) else {
            return String(content.prefix(100))
        }

        // Get context around the match
        let startDistance = content.distance(from: content.startIndex, to: range.lowerBound)
        let contextStart = max(0, startDistance - 30)
        let contextEnd = min(content.count, startDistance + searchText.count + 70)

        let startIndex = content.index(content.startIndex, offsetBy: contextStart)
        let endIndex = content.index(content.startIndex, offsetBy: contextEnd)

        var preview = String(content[startIndex..<endIndex])
        if contextStart > 0 { preview = "..." + preview }
        if contextEnd < content.count { preview = preview + "..." }

        return preview
    }
}

// MARK: - Global Search Result Row

struct GlobalSearchResultRow: View {
    let result: GlobalSearchResult
    let searchText: String
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    private var roleIcon: String {
        switch result.message.role {
        case .user: return "person.fill"
        case .assistant: return "sparkle"
        case .toolUse, .toolResult, .resultSuccess: return "wrench.fill"
        case .thinking: return "brain"
        case .system, .error: return "exclamationmark.circle"
        }
    }

    private var roleColor: Color {
        switch result.message.role {
        case .user: return CLITheme.green(for: colorScheme)
        case .assistant: return CLITheme.blue(for: colorScheme)
        case .toolUse, .toolResult, .resultSuccess: return CLITheme.cyan(for: colorScheme)
        case .thinking: return CLITheme.purple(for: colorScheme)
        case .system, .error: return CLITheme.yellow(for: colorScheme)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Project and role header
            HStack {
                Image(systemName: roleIcon)
                    .font(.system(size: 10))
                    .foregroundColor(roleColor)

                Text(result.projectTitle)
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.blue(for: colorScheme))
                    .lineLimit(1)

                Spacer()

                Text(result.message.timestamp, style: .relative)
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }

            // Match preview
            Text(result.matchPreview)
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))
                .lineLimit(3)

            // Session info
            Text("Session: \(result.sessionId.prefix(8))...")
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button {
                UIPasteboard.general.string = result.message.content
            } label: {
                Label("Copy Message", systemImage: "doc.on.doc")
            }
        }
    }
}
