import SwiftUI

// MARK: - File Picker Sheet

struct FilePickerSheet: View {
    let projectPath: String
    let onSelect: (String) -> Void

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    @State private var currentPath: String = ""
    @State private var files: [FileEntry] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var searchText = ""
    @State private var pathHistory: [String] = []

    init(projectPath: String, onSelect: @escaping (String) -> Void) {
        self.projectPath = projectPath
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
                } else if filteredFiles.isEmpty {
                    Spacer()
                    Text(searchText.isEmpty ? "No files found" : "No matching files")
                        .font(settings.scaledFont(.body))
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    Spacer()
                } else {
                    List {
                        ForEach(filteredFiles) { file in
                            Button {
                                if file.isDirectory {
                                    navigateTo(file.path)
                                } else {
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
            await loadFiles()
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
        isLoading = true
        error = nil

        do {
            let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)
            let relativeDir = currentPath.hasPrefix(projectPath)
                ? String(currentPath.dropFirst(projectPath.count))
                : "/"
            let directory = relativeDir.isEmpty ? "/" : relativeDir
            let response = try await apiClient.listFiles(projectPath: projectPath, directory: directory)
            files = response.entries.toFileEntries()
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
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
