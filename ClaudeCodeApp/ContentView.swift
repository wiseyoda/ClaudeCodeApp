import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var apiClient = APIClient()
    @State private var projects: [Project] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showSettings = false
    @State private var showTerminal = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    projectListView
                }
            }
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Claude Code")
            .toolbarBackground(CLITheme.secondaryBackground(for: colorScheme), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showTerminal = true
                        } label: {
                            Image(systemName: "terminal")
                                .foregroundColor(CLITheme.cyan(for: colorScheme))
                        }
                        .accessibilityLabel("SSH Terminal")
                        .accessibilityHint("Open SSH terminal to connect to server")

                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gear")
                                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                        }
                        .accessibilityLabel("Settings")
                        .accessibilityHint("Open app settings")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await loadProjects() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                    }
                    .accessibilityLabel("Refresh projects")
                    .accessibilityHint("Reload project list from server")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .fullScreenCover(isPresented: $showTerminal) {
                NavigationStack {
                    TerminalView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button {
                                    showTerminal = false
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "chevron.left")
                                        Text("Projects")
                                    }
                                    .foregroundColor(CLITheme.cyan(for: colorScheme))
                                }
                                .accessibilityLabel("Close terminal")
                                .accessibilityHint("Return to project list")
                            }
                        }
                }
            }
        }
        .onAppear {
            // Configure APIClient with the EnvironmentObject settings
            apiClient.configure(with: settings)
        }
        .task {
            await loadProjects()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            Text("+ Loading projects...")
                .font(CLITheme.monoFont)
                .foregroundColor(CLITheme.yellow(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CLITheme.background(for: colorScheme))
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Text("! Error")
                .font(CLITheme.monoFont)
                .foregroundColor(CLITheme.red(for: colorScheme))

            Text(error)
                .font(CLITheme.monoSmall)
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button {
                    Task { await loadProjects() }
                } label: {
                    Text("[Retry]")
                        .font(CLITheme.monoFont)
                        .foregroundColor(CLITheme.cyan(for: colorScheme))
                }
                .accessibilityLabel("Retry")
                .accessibilityHint("Try loading projects again")

                Button {
                    showSettings = true
                } label: {
                    Text("[Settings]")
                        .font(CLITheme.monoFont)
                        .foregroundColor(CLITheme.cyan(for: colorScheme))
                }
                .accessibilityLabel("Settings")
                .accessibilityHint("Open settings to configure server connection")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CLITheme.background(for: colorScheme))
    }

    /// Projects sorted according to user preference
    private var sortedProjects: [Project] {
        switch settings.projectSortOrder {
        case .date:
            // Sort by most recent activity (most recent first)
            return projects.sorted { p1, p2 in
                let date1 = p1.sessions?.compactMap { $0.lastActivity }.max() ?? ""
                let date2 = p2.sessions?.compactMap { $0.lastActivity }.max() ?? ""
                return date1 > date2
            }
        case .name:
            // Sort alphabetically by title
            return projects.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    private var projectListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if projects.isEmpty {
                    VStack(spacing: 8) {
                        Text("No projects found")
                            .font(CLITheme.monoFont)
                            .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                        Text("Open a project in Claude Code to see it here")
                            .font(CLITheme.monoSmall)
                            .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    ForEach(sortedProjects) { project in
                        NavigationLink {
                            ChatView(project: project, apiClient: apiClient)
                        } label: {
                            ProjectRow(project: project)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(CLITheme.background(for: colorScheme))
    }

    private func loadProjects() async {
        isLoading = true
        errorMessage = nil

        do {
            projects = try await apiClient.fetchProjects()
            isLoading = false
        } catch {
            errorMessage = "Failed to connect to server.\n\nCheck Tailscale and server at:\n\(settings.serverURL)"
            isLoading = false
        }
    }
}

// MARK: - Project Row

struct ProjectRow: View {
    let project: Project
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Text(">")
                .font(CLITheme.monoFont)
                .foregroundColor(CLITheme.green(for: colorScheme))

            VStack(alignment: .leading, spacing: 2) {
                Text(project.title)
                    .font(CLITheme.monoFont)
                    .foregroundColor(CLITheme.primaryText(for: colorScheme))

                HStack(spacing: 8) {
                    Text(project.path)
                        .font(CLITheme.monoSmall)
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                        .lineLimit(1)

                    if let sessions = project.sessions, !sessions.isEmpty {
                        Text("[\(sessions.count) sessions]")
                            .font(CLITheme.monoSmall)
                            .foregroundColor(CLITheme.cyan(for: colorScheme))
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(CLITheme.monoSmall)
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss

    // Binding for font size picker
    private var fontSizeBinding: Binding<FontSizePreset> {
        Binding(
            get: { FontSizePreset(rawValue: settings.fontSize) ?? .medium },
            set: { settings.fontSize = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Appearance
                Section("Appearance") {
                    Picker("Theme", selection: Binding(
                        get: { settings.appTheme },
                        set: { settings.appTheme = $0 }
                    )) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }

                    Picker("Font Size", selection: fontSizeBinding) {
                        ForEach(FontSizePreset.allCases, id: \.rawValue) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }

                    // Font preview
                    HStack {
                        Text("Preview:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("The quick brown fox")
                            .font(settings.scaledFont(.body))
                    }
                }

                // Section 2: Claude Behavior
                Section {
                    Picker("Default Mode", selection: Binding(
                        get: { settings.claudeMode },
                        set: { settings.claudeMode = $0 }
                    )) {
                        ForEach(ClaudeMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }

                    Toggle("Skip Permission Prompts", isOn: $settings.skipPermissions)
                } header: {
                    Text("Claude")
                } footer: {
                    if settings.skipPermissions {
                        Label("All tool executions will be auto-approved without confirmation.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                // Section 3: Chat Display
                Section("Chat Display") {
                    Toggle("Show Thinking Blocks", isOn: $settings.showThinkingBlocks)
                    Toggle("Auto-scroll to Bottom", isOn: $settings.autoScrollEnabled)
                }

                // Section 4: Project List
                Section("Projects") {
                    Picker("Sort Order", selection: Binding(
                        get: { settings.projectSortOrder },
                        set: { settings.projectSortOrder = $0 }
                    )) {
                        ForEach(ProjectSortOrder.allCases, id: \.self) { order in
                            Text(order.displayName).tag(order)
                        }
                    }
                }

                // Section 5: Server Configuration
                Section {
                    TextField("URL", text: $settings.serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("API Key", text: $settings.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Server")
                } footer: {
                    Text("API Key from Settings > API Keys in web UI")
                }

                // Section 6: SSH Configuration
                Section {
                    TextField("Host", text: $settings.sshHost)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    HStack {
                        Text("Port")
                        Spacer()
                        TextField("22", value: $settings.sshPort, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    TextField("Username", text: $settings.sshUsername)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $settings.sshPassword)
                } header: {
                    Text("SSH")
                } footer: {
                    Text("Credentials are saved locally on device")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettings())
        .preferredColorScheme(.dark)
}
