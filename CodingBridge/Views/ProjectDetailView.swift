import SwiftUI

// MARK: - Project Detail View

struct ProjectDetailView: View {
    let project: Project
    var onSelectSession: ((String) -> Void)?  // sessionId
    var onAskClaude: ((String, Bool) -> Void)?  // (content, isNewSession)

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var settings: AppSettings
    @ObservedObject private var projectSettingsStore = ProjectSettingsStore.shared

    @State private var projectDetail: CLIProjectDetail?
    @State private var isLoading = true
    @State private var error: String?
    @State private var showFileBrowser = false
    @State private var showSessionPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isLoading {
                        loadingView
                    } else if let error = error {
                        errorView(error)
                    } else {
                        contentView
                    }
                }
                .padding()
            }
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle(project.title)
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
            .sheet(isPresented: $showFileBrowser) {
                FileBrowserView(
                    projectPath: project.path,
                    projectName: project.title,
                    onAskClaude: onAskClaude
                )
            }
        }
        .task {
            await loadProjectDetail()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading project details...")
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(CLITheme.yellow(for: colorScheme))

            Text("Failed to load project")
                .font(settings.scaledFont(.large))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            Text(message)
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task { await loadProjectDetail() }
            }
            .foregroundColor(CLITheme.blue(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Content View

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Path info
            pathSection

            // Git status section
            if let git = projectDetail?.git {
                gitSection(git)
            }

            // Project structure badges
            if let structure = projectDetail?.structure {
                structureSection(structure)
            }

            // Quick actions
            actionsSection

            // Project settings
            projectSettingsSection

            // README preview
            if let readme = projectDetail?.readme, !readme.isEmpty {
                readmeSection(readme)
            }
        }
    }

    // MARK: - Sections

    private var pathSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Path")
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
                .textCase(.uppercase)

            Text(project.path)
                .font(CLITheme.monoSmall)
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                .textSelection(.enabled)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CLITheme.secondaryBackground(for: colorScheme))
        .cornerRadius(8)
    }

    private func gitSection(_ git: CLIGitStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Git Status")
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
                .textCase(.uppercase)

            HStack(spacing: 16) {
                // Branch
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundColor(CLITheme.blue(for: colorScheme))
                    Text(git.branch.isEmpty ? "unknown" : git.branch)
                        .font(CLITheme.monoFont)
                        .foregroundColor(CLITheme.primaryText(for: colorScheme))
                }

                Spacer()

                // Status badge
                GitStatusIndicator(status: git.toGitStatus)
            }

            // Ahead/behind info
            if let ahead = git.ahead, ahead > 0, let behind = git.behind, behind > 0 {
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 12))
                        Text("\(ahead) ahead")
                            .font(settings.scaledFont(.small))
                    }
                    .foregroundColor(CLITheme.blue(for: colorScheme))

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 12))
                        Text("\(behind) behind")
                            .font(settings.scaledFont(.small))
                    }
                    .foregroundColor(CLITheme.cyan(for: colorScheme))
                }
            } else if let ahead = git.ahead, ahead > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12))
                    Text("\(ahead) commit\(ahead == 1 ? "" : "s") ahead")
                        .font(settings.scaledFont(.small))
                }
                .foregroundColor(CLITheme.blue(for: colorScheme))
            } else if let behind = git.behind, behind > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 12))
                    Text("\(behind) commit\(behind == 1 ? "" : "s") behind")
                        .font(settings.scaledFont(.small))
                }
                .foregroundColor(CLITheme.cyan(for: colorScheme))
            }

            // Remote info
            if let remote = git.remote, let url = git.remoteUrl {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(remote): \(url)")
                        .font(settings.scaledFont(.small))
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CLITheme.secondaryBackground(for: colorScheme))
        .cornerRadius(8)
    }

    private func structureSection(_ structure: CLIProjectStructure) -> some View {
        let badges = structure.projectTypeBadges

        if badges.isEmpty && structure.primaryLanguage == nil {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Project Type")
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    .textCase(.uppercase)

                HStack(spacing: 8) {
                    // Type badges
                    ForEach(badges, id: \.label) { badge in
                        HStack(spacing: 4) {
                            Image(systemName: badge.icon)
                                .font(.system(size: 12))
                            Text(badge.label)
                                .font(settings.scaledFont(.small))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(badgeColor(badge.color).opacity(0.2))
                        .foregroundColor(badgeColor(badge.color))
                        .cornerRadius(6)
                    }

                    // Primary language if different
                    if let lang = structure.primaryLanguage, !badges.contains(where: { $0.label.lowercased() == lang.lowercased() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.system(size: 12))
                            Text(lang.capitalized)
                                .font(settings.scaledFont(.small))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(CLITheme.blue(for: colorScheme).opacity(0.2))
                        .foregroundColor(CLITheme.blue(for: colorScheme))
                        .cornerRadius(6)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CLITheme.secondaryBackground(for: colorScheme))
            .cornerRadius(8)
        )
    }

    private func badgeColor(_ name: String) -> Color {
        switch name {
        case "green": return CLITheme.green(for: colorScheme)
        case "orange": return CLITheme.orange(for: colorScheme)
        case "cyan": return CLITheme.cyan(for: colorScheme)
        case "yellow": return CLITheme.yellow(for: colorScheme)
        case "purple": return CLITheme.purple(for: colorScheme)
        default: return CLITheme.blue(for: colorScheme)
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Browse Files
            Button {
                showFileBrowser = true
            } label: {
                HStack {
                    Image(systemName: "folder")
                    Text("Browse Files")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                }
                .padding()
                .background(CLITheme.secondaryBackground(for: colorScheme))
                .cornerRadius(8)
            }
            .foregroundColor(CLITheme.primaryText(for: colorScheme))

            // View Sessions
            if let sessionCount = projectDetail?.sessionCount ?? project.sessionCount, sessionCount > 0 {
                Button {
                    showSessionPicker = true
                } label: {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right")
                        Text("View Sessions")
                        Spacer()
                        Text("\(sessionCount)")
                            .font(settings.scaledFont(.small))
                            .foregroundColor(CLITheme.cyan(for: colorScheme))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    }
                    .padding()
                    .background(CLITheme.secondaryBackground(for: colorScheme))
                    .cornerRadius(8)
                }
                .foregroundColor(CLITheme.primaryText(for: colorScheme))
            }
        }
    }

    private var projectSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Project Settings")
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
                .textCase(.uppercase)

            // Subrepo discovery toggle
            Toggle(isOn: Binding(
                get: { projectSettingsStore.isSubrepoDiscoveryEnabled(for: project.path) },
                set: { projectSettingsStore.setSubrepoDiscoveryEnabled(for: project.path, enabled: $0) }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundColor(CLITheme.cyan(for: colorScheme))
                        Text("Sub-repo Discovery")
                            .font(settings.scaledFont(.body))
                            .foregroundColor(CLITheme.primaryText(for: colorScheme))
                    }
                    Text("Scan for nested git repositories (monorepo support)")
                        .font(settings.scaledFont(.small))
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                }
            }
            .tint(CLITheme.cyan(for: colorScheme))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CLITheme.secondaryBackground(for: colorScheme))
        .cornerRadius(8)
    }

    private func readmeSection(_ readme: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("README")
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    .textCase(.uppercase)

                Spacer()

                Text("Preview")
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }

            // Truncated README preview
            Text(readme.prefix(1000) + (readme.count > 1000 ? "..." : ""))
                .font(CLITheme.monoSmall)
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                .lineLimit(20)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CLITheme.secondaryBackground(for: colorScheme))
        .cornerRadius(8)
    }

    // MARK: - Data Loading

    private func loadProjectDetail() async {
        await MainActor.run {
            isLoading = true
            error = nil
        }

        do {
            let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)
            let detail = try await apiClient.getProjectDetail(projectPath: project.path)

            await MainActor.run {
                projectDetail = detail
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

// MARK: - Computed Properties

extension Project {
    var sessionCount: Int? {
        sessionMeta?.total ?? sessions?.count
    }
}

// MARK: - Preview

#Preview {
    ProjectDetailView(
        project: Project(
            name: "myapp",
            path: "/Users/dev/myapp",
            displayName: nil,
            fullPath: nil,
            sessions: nil,
            sessionMeta: nil
        )
    )
    .environmentObject(AppSettings())
}
