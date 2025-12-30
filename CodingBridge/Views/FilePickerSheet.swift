import SwiftUI

// MARK: - File Picker Sheet

struct FilePickerSheet: View {
    let projectPath: String
    let onSelect: (String) -> Void
    var recentMessages: [ChatMessage]

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    @State private var currentPath: String = ""
    @State private var files: [FileEntry] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var searchText = ""
    @State private var pathHistory: [String] = []

    // AI file suggestions
    var claudeHelper: ClaudeHelper?
    var sessionId: String?  // Current session ID to avoid creating orphan sessions
    @State private var suggestedFiles: [String] = []
    @State private var isLoadingSuggestions = false

    init(projectPath: String, recentMessages: [ChatMessage] = [], claudeHelper: ClaudeHelper? = nil, sessionId: String? = nil, onSelect: @escaping (String) -> Void) {
        self.projectPath = projectPath
        self.recentMessages = recentMessages
        self.claudeHelper = claudeHelper
        self.sessionId = sessionId
        self.onSelect = onSelect
    }

    var filteredFiles: [FileEntry] {
        if searchText.isEmpty {
            return files
        }
        return files.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Breadcrumb path
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(pathComponents, id: \.path) { component in
                            Button {
                                navigateTo(component.path)
                            } label: {
                                Text(component.name)
                                    .font(settings.scaledFont(.small))
                                    .foregroundColor(CLITheme.blue(for: colorScheme))
                            }
                            if component.path != currentPath {
                                Text("/")
                                    .font(settings.scaledFont(.small))
                                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(CLITheme.secondaryBackground(for: colorScheme))

                Divider()

                // File list
                if isLoading {
                    Spacer()
                    ProgressView("Loading files...")
                        .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                    Spacer()
                } else if let error = error {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(CLITheme.yellow(for: colorScheme))
                        Text(error)
                            .font(settings.scaledFont(.body))
                            .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await loadFiles() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    Spacer()
                } else if filteredFiles.isEmpty && suggestedFiles.isEmpty {
                    Spacer()
                    Text(searchText.isEmpty ? "No files found" : "No matching files")
                        .font(settings.scaledFont(.body))
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    Spacer()
                } else {
                    List {
                        // AI-suggested files section (at root only)
                        if currentPath == projectPath && searchText.isEmpty && (!suggestedFiles.isEmpty || isLoadingSuggestions) {
                            Section {
                                if isLoadingSuggestions {
                                    HStack {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Finding relevant files...")
                                            .font(settings.scaledFont(.small))
                                            .foregroundColor(CLITheme.mutedText(for: colorScheme))
                                    }
                                    .listRowBackground(CLITheme.background(for: colorScheme))
                                }
                                ForEach(suggestedFiles, id: \.self) { file in
                                    Button {
                                        onSelect(file)
                                        dismiss()
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "sparkles")
                                                .foregroundColor(CLITheme.yellow(for: colorScheme))
                                                .frame(width: 24)

                                            Text(file)
                                                .font(settings.scaledFont(.body))
                                                .foregroundColor(CLITheme.primaryText(for: colorScheme))

                                            Spacer()

                                            Image(systemName: "plus.circle")
                                                .foregroundColor(CLITheme.cyan(for: colorScheme))
                                                .font(.system(size: 14))
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .listRowBackground(CLITheme.cyan(for: colorScheme).opacity(0.05))
                                }
                            } header: {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .font(.caption2)
                                    Text("Suggested")
                                        .font(.caption)
                                }
                                .foregroundColor(CLITheme.yellow(for: colorScheme))
                            }
                        }

                        // Regular files section
                        Section(header: suggestedFiles.isEmpty || currentPath != projectPath ? nil : Text("All Files").font(.caption).foregroundColor(CLITheme.mutedText(for: colorScheme))) {
                            ForEach(filteredFiles) { file in
                                Button {
                                    if file.isDirectory {
                                        navigateTo(file.path)
                                    } else {
                                        // Select this file
                                        let relativePath = makeRelativePath(file.path)
                                        onSelect(relativePath)
                                        dismiss()
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: file.icon)
                                            .foregroundColor(file.isDirectory ?
                                                CLITheme.yellow(for: colorScheme) :
                                                CLITheme.cyan(for: colorScheme))
                                            .frame(width: 24)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(file.name)
                                                .font(settings.scaledFont(.body))
                                                .foregroundColor(CLITheme.primaryText(for: colorScheme))

                                            if !file.isDirectory {
                                                Text(file.formattedSize)
                                                    .font(settings.scaledFont(.small))
                                                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
                                            }
                                        }

                                        Spacer()

                                        if file.isDirectory {
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(CLITheme.mutedText(for: colorScheme))
                                                .font(.system(size: 12))
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(CLITheme.background(for: colorScheme))
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(CLITheme.background(for: colorScheme))
                }
            }
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Select File")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search files...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    if !pathHistory.isEmpty {
                        Button {
                            navigateBack()
                        } label: {
                            Image(systemName: "arrow.up")
                        }
                    }
                }
            }
        }
        .task {
            currentPath = projectPath
            let loadedFiles = await loadFilesAndReturn()

            // Generate AI file suggestions if we have context
            if let helper = claudeHelper, !recentMessages.isEmpty, !loadedFiles.isEmpty {
                isLoadingSuggestions = true
                let availableFilePaths = loadedFiles
                    .filter { !$0.isDirectory }
                    .map { makeRelativePath($0.path) }

                await helper.suggestRelevantFiles(
                    recentMessages: recentMessages,
                    availableFiles: availableFilePaths,
                    projectPath: projectPath,
                    sessionId: sessionId
                )
                suggestedFiles = helper.suggestedFiles
                isLoadingSuggestions = false
            }
        }
    }

    private var pathComponents: [(name: String, path: String)] {
        var components: [(name: String, path: String)] = []
        let path = currentPath

        // Start with project root
        if path.hasPrefix(projectPath) {
            components.append((name: "project", path: projectPath))
            let remainder = String(path.dropFirst(projectPath.count))
            if !remainder.isEmpty {
                let parts = remainder.split(separator: "/").map(String.init)
                var buildPath = projectPath
                for part in parts {
                    buildPath += "/\(part)"
                    components.append((name: part, path: buildPath))
                }
            }
        } else {
            // Fallback for paths outside project
            components.append((name: path, path: path))
        }

        return components
    }

    private func navigateTo(_ path: String) {
        pathHistory.append(currentPath)
        currentPath = path
        Task { await loadFiles() }
    }

    private func navigateBack() {
        guard let previousPath = pathHistory.popLast() else { return }
        currentPath = previousPath
        Task { await loadFiles() }
    }

    private func loadFiles() async {
        _ = await loadFilesAndReturn()
    }

    /// Load files and return them directly (avoids state timing issues)
    /// Uses REST API when cli-bridge is enabled, otherwise uses SSH
    private func loadFilesAndReturn() async -> [FileEntry] {
        isLoading = true
        error = nil

        do {
            // Use CLI Bridge REST API
            let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)
            // Calculate relative directory path from project root
            let relativeDir = currentPath.hasPrefix(projectPath)
                ? String(currentPath.dropFirst(projectPath.count))
                : "/"
            let directory = relativeDir.isEmpty ? "/" : relativeDir
            let response = try await apiClient.listFiles(projectPath: projectPath, directory: directory)
            let loadedFiles = response.entries.toFileEntries()

            files = loadedFiles
            isLoading = false
            return loadedFiles
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return []
        }
    }

    private func makeRelativePath(_ absolutePath: String) -> String {
        if absolutePath.hasPrefix(projectPath) {
            let relative = String(absolutePath.dropFirst(projectPath.count))
            if relative.hasPrefix("/") {
                return String(relative.dropFirst())
            }
            return relative.isEmpty ? "." : relative
        }
        return absolutePath
    }
}
