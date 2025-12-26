import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @StateObject private var apiClient: APIClient
    @State private var projects: [Project] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showSettings = false

    init() {
        let settings = AppSettings()
        _apiClient = StateObject(wrappedValue: APIClient(settings: settings))
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading projects...")
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await loadProjects() }
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Settings") {
                            showSettings = true
                        }
                    }
                    .padding()
                } else {
                    ProjectsListView(projects: projects, apiClient: apiClient)
                }
            }
            .navigationTitle("Claude Code")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await loadProjects() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
        .task {
            await loadProjects()
        }
    }

    private func loadProjects() async {
        isLoading = true
        errorMessage = nil

        do {
            projects = try await apiClient.fetchProjects()
            isLoading = false
        } catch {
            errorMessage = "Failed to connect to server.\n\nMake sure you're on Tailscale and the server is running at:\n\(settings.serverURL)"
            isLoading = false
        }
    }
}

// MARK: - Projects List

struct ProjectsListView: View {
    let projects: [Project]
    let apiClient: APIClient

    var body: some View {
        List(projects) { project in
            NavigationLink {
                ChatView(project: project, apiClient: apiClient)
            } label: {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text(project.name)
                            .font(.headline)
                        Text(project.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if projects.isEmpty {
                ContentUnavailableView(
                    "No Projects",
                    systemImage: "folder.badge.questionmark",
                    description: Text("Open a project in Claude Code to see it here")
                )
            }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("Server URL", text: $settings.serverURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }

                Section {
                    Text("Default: http://10.0.3.2:8080")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettings())
}
