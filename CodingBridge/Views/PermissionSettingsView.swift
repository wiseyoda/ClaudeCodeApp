import SwiftUI

/// Settings view for managing permission modes at session and project level
struct PermissionSettingsView: View {
    let projectPath: String
    let onSessionModeChanged: ((PermissionMode) -> Void)?

    @EnvironmentObject var settings: AppSettings
    @ObservedObject var permissionManager = PermissionManager.shared
    @ObservedObject var projectSettings = ProjectSettingsStore.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @State private var sessionMode: PermissionMode?
    @State private var projectMode: PermissionMode?
    @State private var alwaysAllowList: [String] = []
    @State private var alwaysDenyList: [String] = []
    @State private var isLoading = false
    @State private var error: String?

    init(projectPath: String, onSessionModeChanged: ((PermissionMode) -> Void)? = nil) {
        self.projectPath = projectPath
        self.onSessionModeChanged = onSessionModeChanged
    }

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: This Session (temporary)
                Section {
                    ForEach(PermissionMode.allCases, id: \.self) { mode in
                        sessionModeRow(mode)
                    }
                } header: {
                    Text("This Session")
                } footer: {
                    Text("Session settings are temporary and reset when you disconnect.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Section 2: Project Default (persisted locally)
                Section {
                    // Use global option
                    Button {
                        projectSettings.setPermissionModeOverride(for: projectPath, mode: nil)
                        projectMode = nil
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Use Global Default")
                                    .foregroundColor(CLITheme.primaryText(for: colorScheme))
                                Text("Currently: \(settings.globalPermissionMode.displayName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if projectMode == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(CLITheme.cyan(for: colorScheme))
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    ForEach(PermissionMode.allCases, id: \.self) { mode in
                        projectModeRow(mode)
                    }
                } header: {
                    Text("Project Default")
                } footer: {
                    Text("Project settings persist across sessions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Section 3: Always Allowed Tools (from server)
                Section {
                    if alwaysAllowList.isEmpty {
                        Text("No tools are always allowed")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(alwaysAllowList, id: \.self) { tool in
                            HStack {
                                Image(systemName: toolIcon(for: tool))
                                    .foregroundColor(CLITheme.green(for: colorScheme))
                                    .frame(width: 24)
                                Text(tool)
                                Spacer()
                            }
                        }
                        .onDelete(perform: deleteAlwaysAllowTool)
                    }
                } header: {
                    Text("Always Allowed Tools")
                } footer: {
                    Text("Tools here are automatically approved. Tap \"Always\" when prompted to add tools.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Section 4: Always Denied Tools (from server)
                Section {
                    if alwaysDenyList.isEmpty {
                        Text("No tools are always denied")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(alwaysDenyList, id: \.self) { tool in
                            HStack {
                                Image(systemName: toolIcon(for: tool))
                                    .foregroundColor(CLITheme.red(for: colorScheme))
                                    .frame(width: 24)
                                Text(tool)
                                Spacer()
                            }
                        }
                        .onDelete(perform: deleteAlwaysDenyTool)
                    }
                } header: {
                    Text("Always Denied Tools")
                } footer: {
                    Text("Tools here are always blocked.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Error display
                if let error = error {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(error)
                                .foregroundColor(.orange)
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("Permissions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .task {
                await loadPermissions()
            }
        }
    }

    // MARK: - Row Views

    @ViewBuilder
    private func sessionModeRow(_ mode: PermissionMode) -> some View {
        Button {
            sessionMode = mode
            onSessionModeChanged?(mode)
        } label: {
            HStack {
                Image(systemName: mode.icon)
                    .foregroundColor(mode.color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .foregroundColor(CLITheme.primaryText(for: colorScheme))
                    Text(mode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if sessionMode == mode {
                    Image(systemName: "checkmark")
                        .foregroundColor(CLITheme.cyan(for: colorScheme))
                }
            }
        }
        .buttonStyle(.plain)

        // Warning for dangerous mode
        if mode.isDangerous && sessionMode == mode {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("All tools will run without asking")
            }
            .font(.caption)
            .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private func projectModeRow(_ mode: PermissionMode) -> some View {
        Button {
            projectSettings.setPermissionModeOverride(for: projectPath, mode: mode)
            projectMode = mode
        } label: {
            HStack {
                Image(systemName: mode.icon)
                    .foregroundColor(mode.color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .foregroundColor(CLITheme.primaryText(for: colorScheme))
                    Text(mode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if projectMode == mode {
                    Image(systemName: "checkmark")
                        .foregroundColor(CLITheme.cyan(for: colorScheme))
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func loadPermissions() async {
        isLoading = true
        error = nil

        // Load local project override
        projectMode = projectSettings.permissionModeOverride(for: projectPath)

        // Try to load server config (may fail if server doesn't support it)
        if permissionManager.isConfigured {
            do {
                let config = try await permissionManager.loadConfig()
                alwaysAllowList = config.projects[projectPath]?.alwaysAllow ?? []
                alwaysDenyList = config.projects[projectPath]?.alwaysDeny ?? []
            } catch {
                // Server may not support permissions endpoint - that's OK
                log.debug("Failed to load server permission config: \(error)")
            }
        }

        isLoading = false
    }

    private func deleteAlwaysAllowTool(at offsets: IndexSet) {
        let toolsToRemove = offsets.map { alwaysAllowList[$0] }
        alwaysAllowList.remove(atOffsets: offsets)

        Task {
            for tool in toolsToRemove {
                do {
                    try await permissionManager.removeAlwaysAllow(tool, for: projectPath)
                } catch {
                    self.error = "Failed to remove tool: \(error.localizedDescription)"
                    await loadPermissions()  // Reload to sync state
                }
            }
        }
    }

    private func deleteAlwaysDenyTool(at offsets: IndexSet) {
        let toolsToRemove = offsets.map { alwaysDenyList[$0] }
        alwaysDenyList.remove(atOffsets: offsets)

        Task {
            for tool in toolsToRemove {
                do {
                    try await permissionManager.removeAlwaysDeny(tool, for: projectPath)
                } catch {
                    self.error = "Failed to remove tool: \(error.localizedDescription)"
                    await loadPermissions()  // Reload to sync state
                }
            }
        }
    }

    // MARK: - Helpers

    private func toolIcon(for tool: String) -> String {
        switch tool {
        case "Bash":
            return "terminal"
        case "Read":
            return "doc.text"
        case "Write":
            return "doc.badge.plus"
        case "Edit":
            return "pencil"
        case "Glob":
            return "magnifyingglass"
        case "Grep":
            return "text.magnifyingglass"
        case "LS":
            return "folder"
        case "WebFetch":
            return "globe"
        case "Task":
            return "gearshape.2"
        default:
            return "wrench"
        }
    }
}

// MARK: - Preview

#Preview {
    PermissionSettingsView(projectPath: "/Users/dev/project")
        .environmentObject(AppSettings())
}
