import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @StateObject private var apiClient: APIClient
    @State private var projects: [Project] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showSettings = false
    @State private var showTerminal = false

    init() {
        let settings = AppSettings()
        _apiClient = StateObject(wrappedValue: APIClient(settings: settings))
    }

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
            .background(CLITheme.background)
            .navigationTitle("Claude Code")
            .toolbarBackground(CLITheme.secondaryBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showTerminal = true
                        } label: {
                            Image(systemName: "terminal")
                                .foregroundColor(CLITheme.cyan)
                        }
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gear")
                                .foregroundColor(CLITheme.secondaryText)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await loadProjects() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(CLITheme.secondaryText)
                    }
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
                                    .foregroundColor(CLITheme.cyan)
                                }
                            }
                        }
                }
            }
        }
        .task {
            await loadProjects()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            Text("+ Loading projects...")
                .font(CLITheme.monoFont)
                .foregroundColor(CLITheme.yellow)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CLITheme.background)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Text("! Error")
                .font(CLITheme.monoFont)
                .foregroundColor(CLITheme.red)

            Text(error)
                .font(CLITheme.monoSmall)
                .foregroundColor(CLITheme.secondaryText)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button {
                    Task { await loadProjects() }
                } label: {
                    Text("[Retry]")
                        .font(CLITheme.monoFont)
                        .foregroundColor(CLITheme.cyan)
                }

                Button {
                    showSettings = true
                } label: {
                    Text("[Settings]")
                        .font(CLITheme.monoFont)
                        .foregroundColor(CLITheme.cyan)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CLITheme.background)
    }

    private var projectListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if projects.isEmpty {
                    VStack(spacing: 8) {
                        Text("No projects found")
                            .font(CLITheme.monoFont)
                            .foregroundColor(CLITheme.secondaryText)
                        Text("Open a project in Claude Code to see it here")
                            .font(CLITheme.monoSmall)
                            .foregroundColor(CLITheme.mutedText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    ForEach(projects) { project in
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
        .background(CLITheme.background)
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

    var body: some View {
        HStack(spacing: 8) {
            Text(">")
                .font(CLITheme.monoFont)
                .foregroundColor(CLITheme.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.title)
                    .font(CLITheme.monoFont)
                    .foregroundColor(CLITheme.primaryText)

                HStack(spacing: 8) {
                    Text(project.path)
                        .font(CLITheme.monoSmall)
                        .foregroundColor(CLITheme.mutedText)
                        .lineLimit(1)

                    if let sessions = project.sessions, !sessions.isEmpty {
                        Text("[\(sessions.count) sessions]")
                            .font(CLITheme.monoSmall)
                            .foregroundColor(CLITheme.cyan)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(CLITheme.monoSmall)
                .foregroundColor(CLITheme.mutedText)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Server Configuration
                    VStack(alignment: .leading, spacing: 12) {
                        Text("* Server Configuration")
                            .font(CLITheme.monoFont)
                            .foregroundColor(CLITheme.cyan)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("URL:")
                                .font(CLITheme.monoSmall)
                                .foregroundColor(CLITheme.secondaryText)

                            TextField("", text: $settings.serverURL)
                                .font(CLITheme.monoFont)
                                .foregroundColor(CLITheme.primaryText)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .padding(12)
                                .background(CLITheme.secondaryBackground)
                                .cornerRadius(8)
                        }

                        Text("Default: http://10.0.3.2:8080")
                            .font(CLITheme.monoSmall)
                            .foregroundColor(CLITheme.mutedText)
                    }

                    // Font Size
                    VStack(alignment: .leading, spacing: 12) {
                        Text("* Font Size")
                            .font(CLITheme.monoFont)
                            .foregroundColor(CLITheme.cyan)

                        HStack(spacing: 8) {
                            ForEach(FontSizePreset.allCases, id: \.rawValue) { preset in
                                Button {
                                    settings.fontSize = preset.rawValue
                                } label: {
                                    Text(preset.displayName)
                                        .font(CLITheme.monoSmall)
                                        .foregroundColor(settings.fontSize == preset.rawValue ? CLITheme.background : CLITheme.primaryText)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(settings.fontSize == preset.rawValue ? CLITheme.cyan : CLITheme.secondaryBackground)
                                        .cornerRadius(6)
                                }
                            }
                        }

                        Text("Preview: The quick brown fox")
                            .font(settings.scaledFont(.body))
                            .foregroundColor(CLITheme.primaryText)
                            .padding(.top, 4)
                    }

                    // SSH Configuration
                    VStack(alignment: .leading, spacing: 12) {
                        Text("* SSH Configuration")
                            .font(CLITheme.monoFont)
                            .foregroundColor(CLITheme.cyan)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Host:")
                                .font(CLITheme.monoSmall)
                                .foregroundColor(CLITheme.secondaryText)
                            TextField("", text: $settings.sshHost)
                                .font(CLITheme.monoFont)
                                .foregroundColor(CLITheme.primaryText)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .padding(12)
                                .background(CLITheme.secondaryBackground)
                                .cornerRadius(8)
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Port:")
                                    .font(CLITheme.monoSmall)
                                    .foregroundColor(CLITheme.secondaryText)
                                TextField("", value: $settings.sshPort, format: .number)
                                    .font(CLITheme.monoFont)
                                    .foregroundColor(CLITheme.primaryText)
                                    .keyboardType(.numberPad)
                                    .padding(12)
                                    .background(CLITheme.secondaryBackground)
                                    .cornerRadius(8)
                            }
                            .frame(width: 100)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Username:")
                                    .font(CLITheme.monoSmall)
                                    .foregroundColor(CLITheme.secondaryText)
                                TextField("", text: $settings.sshUsername)
                                    .font(CLITheme.monoFont)
                                    .foregroundColor(CLITheme.primaryText)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .padding(12)
                                    .background(CLITheme.secondaryBackground)
                                    .cornerRadius(8)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password:")
                                .font(CLITheme.monoSmall)
                                .foregroundColor(CLITheme.secondaryText)
                            SecureField("", text: $settings.sshPassword)
                                .font(CLITheme.monoFont)
                                .foregroundColor(CLITheme.primaryText)
                                .padding(12)
                                .background(CLITheme.secondaryBackground)
                                .cornerRadius(8)
                        }

                        Text("Credentials are saved locally")
                            .font(CLITheme.monoSmall)
                            .foregroundColor(CLITheme.mutedText)
                    }

                    Spacer()
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CLITheme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CLITheme.secondaryBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .foregroundColor(CLITheme.cyan)
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
