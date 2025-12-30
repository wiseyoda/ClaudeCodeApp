import SwiftUI

// MARK: - File Browser View

struct FileBrowserView: View {
    let projectPath: String
    let projectName: String
    var onAskClaude: ((String, Bool) -> Void)?  // (content, isNewSession)

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var settings: AppSettings

    @State private var currentPath: String = "/"
    @State private var entries: [CLIFileEntry] = []
    @State private var parentPath: String?
    @State private var isLoading = false
    @State private var error: String?
    @State private var selectedFile: CLIFileContentResponse?
    @State private var showFileViewer = false

    // Navigation history for back/forward buttons
    @State private var history: [String] = ["/"]
    @State private var historyIndex: Int = 0

    private var canGoBack: Bool { historyIndex > 0 }
    private var canGoForward: Bool { historyIndex < history.count - 1 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Breadcrumb navigation
                breadcrumbBar

                Divider()

                // File list
                if isLoading {
                    loadingView
                } else if let error = error {
                    errorView(error)
                } else if entries.isEmpty {
                    emptyView
                } else {
                    fileList
                }
            }
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle(projectName)
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

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Back button
                    Button {
                        navigateBack()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!canGoBack)
                    .foregroundColor(canGoBack ? CLITheme.blue(for: colorScheme) : CLITheme.mutedText(for: colorScheme))

                    // Forward button
                    Button {
                        navigateForward()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!canGoForward)
                    .foregroundColor(canGoForward ? CLITheme.blue(for: colorScheme) : CLITheme.mutedText(for: colorScheme))

                    // Refresh button
                    Button {
                        Task { await loadDirectory(currentPath, addToHistory: false) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .foregroundColor(CLITheme.blue(for: colorScheme))
                }
            }
            .sheet(isPresented: $showFileViewer) {
                if let file = selectedFile {
                    FileContentViewer(
                        fileContent: file,
                        projectPath: projectPath,
                        onAskClaude: onAskClaude
                    )
                }
            }
        }
        .task {
            // Initial load - don't add to history since we initialize with "/"
            await loadDirectory("/", addToHistory: false)
        }
    }

    // MARK: - Breadcrumb Navigation

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                // Project root
                Button {
                    Task { await loadDirectory("/", addToHistory: true) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 12))
                        Text(projectName)
                            .font(settings.scaledFont(.small))
                    }
                    .foregroundColor(currentPath == "/" ? CLITheme.primaryText(for: colorScheme) : CLITheme.blue(for: colorScheme))
                }

                // Path components
                ForEach(pathComponents, id: \.path) { component in
                    HStack(spacing: 4) {
                        Text("/")
                            .font(settings.scaledFont(.small))
                            .foregroundColor(CLITheme.mutedText(for: colorScheme))

                        Button {
                            Task { await loadDirectory(component.path, addToHistory: true) }
                        } label: {
                            Text(component.name)
                                .font(settings.scaledFont(.small))
                                .foregroundColor(component.path == currentPath ? CLITheme.primaryText(for: colorScheme) : CLITheme.blue(for: colorScheme))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(CLITheme.secondaryBackground(for: colorScheme))
    }

    private var pathComponents: [(name: String, path: String)] {
        guard currentPath != "/" else { return [] }

        var components: [(name: String, path: String)] = []
        let parts = currentPath.trimmingCharacters(in: CharacterSet(charactersIn: "/")).split(separator: "/")
        var buildPath = ""

        for part in parts {
            buildPath += "/\(part)"
            components.append((name: String(part), path: buildPath))
        }

        return components
    }

    // MARK: - Content Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading files...")
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(CLITheme.yellow(for: colorScheme))

            Text("Failed to load files")
                .font(settings.scaledFont(.large))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            Text(message)
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task { await loadDirectory(currentPath) }
            }
            .foregroundColor(CLITheme.blue(for: colorScheme))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))

            Text("Empty Directory")
                .font(settings.scaledFont(.large))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            Text("This directory contains no files")
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fileList: some View {
        List {
            ForEach(sortedEntries) { entry in
                FileEntryRow(entry: entry) {
                    Task { await handleEntryTap(entry) }
                }
                .listRowBackground(CLITheme.background(for: colorScheme))
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(CLITheme.background(for: colorScheme))
    }

    private var sortedEntries: [CLIFileEntry] {
        entries.sorted { e1, e2 in
            // Directories first, then alphabetically
            if e1.isDir != e2.isDir {
                return e1.isDir
            }
            return e1.name.lowercased() < e2.name.lowercased()
        }
    }

    // MARK: - Navigation

    private func navigateBack() {
        guard canGoBack else { return }
        historyIndex -= 1
        let path = history[historyIndex]
        Task { await loadDirectory(path, addToHistory: false) }
    }

    private func navigateForward() {
        guard canGoForward else { return }
        historyIndex += 1
        let path = history[historyIndex]
        Task { await loadDirectory(path, addToHistory: false) }
    }

    private func handleEntryTap(_ entry: CLIFileEntry) async {
        if entry.isDir {
            await loadDirectory(entry.path, addToHistory: true)
        } else {
            await loadFile(entry)
        }
    }

    private func loadDirectory(_ path: String, addToHistory: Bool = true) async {
        await MainActor.run {
            isLoading = true
            error = nil
        }

        do {
            let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)
            let response = try await apiClient.listFiles(projectPath: projectPath, directory: path)

            await MainActor.run {
                currentPath = response.path
                entries = response.entries
                parentPath = response.parent
                isLoading = false

                // Update history if this is a new navigation (not back/forward)
                if addToHistory {
                    // Truncate any forward history when navigating to a new path
                    if historyIndex < history.count - 1 {
                        history = Array(history.prefix(historyIndex + 1))
                    }
                    // Add new path to history (unless it's the same as current)
                    if history.last != response.path {
                        history.append(response.path)
                        historyIndex = history.count - 1
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func loadFile(_ entry: CLIFileEntry) async {
        await MainActor.run {
            isLoading = true
            error = nil
        }

        do {
            let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)
            let content = try await apiClient.readFile(projectPath: projectPath, filePath: entry.path)

            await MainActor.run {
                selectedFile = content
                showFileViewer = true
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - File Entry Row

struct FileEntryRow: View {
    let entry: CLIFileEntry
    let onTap: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: entry.icon)
                    .font(.system(size: 20))
                    .foregroundColor(entry.isDir ? CLITheme.yellow(for: colorScheme) : CLITheme.blue(for: colorScheme))
                    .frame(width: 24)

                // Name and metadata
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(CLITheme.monoFont)
                        .foregroundColor(CLITheme.primaryText(for: colorScheme))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        // Size or child count
                        if entry.isDir {
                            if let count = entry.childCount {
                                Text("\(count) items")
                                    .font(settings.scaledFont(.small))
                                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
                            }
                        } else if let size = entry.formattedSize {
                            Text(size)
                                .font(settings.scaledFont(.small))
                                .foregroundColor(CLITheme.mutedText(for: colorScheme))
                        }

                        // Modified date
                        if let date = entry.modifiedDate {
                            Text(date, style: .relative)
                                .font(settings.scaledFont(.small))
                                .foregroundColor(CLITheme.mutedText(for: colorScheme))
                        }
                    }
                }

                Spacer()

                // Chevron for directories
                if entry.isDir {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    FileBrowserView(
        projectPath: "/Users/dev/myapp",
        projectName: "myapp"
    )
    .environmentObject(AppSettings())
}
