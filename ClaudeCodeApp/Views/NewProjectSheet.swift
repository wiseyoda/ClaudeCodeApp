import SwiftUI

// MARK: - New Project Sheet

struct NewProjectSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var sshManager = SSHManager.shared

    @State private var projectName = ""
    @State private var initializeClaude = true
    @State private var isCreating = false
    @State private var error: String?
    @State private var progress: String = ""

    let onComplete: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(CLITheme.green(for: colorScheme))
                    .padding(.top, 24)

                // Instructions
                Text("Create a New Project")
                    .font(settings.scaledFont(.body))
                    .foregroundColor(CLITheme.primaryText(for: colorScheme))

                // Project Name Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Project Name")
                        .font(settings.scaledFont(.small))
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))

                    TextField("my-awesome-project", text: $projectName)
                        .font(settings.scaledFont(.body))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(CLITheme.secondaryBackground(for: colorScheme))
                        .cornerRadius(8)
                        .disabled(isCreating)
                }
                .padding(.horizontal, 24)

                // Initialize Claude toggle
                Toggle(isOn: $initializeClaude) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Initialize with Claude")
                            .font(settings.scaledFont(.body))
                            .foregroundColor(CLITheme.primaryText(for: colorScheme))
                        Text("Creates CLAUDE.md project file")
                            .font(settings.scaledFont(.small))
                            .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    }
                }
                .tint(CLITheme.green(for: colorScheme))
                .padding(.horizontal, 24)
                .disabled(isCreating)

                // Create button
                Button {
                    Task { await createProject() }
                } label: {
                    HStack {
                        if isCreating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "plus.circle")
                        }
                        Text(isCreating ? "Creating..." : "Create Project")
                    }
                    .font(settings.scaledFont(.body))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isValidName ? CLITheme.green(for: colorScheme) : CLITheme.mutedText(for: colorScheme))
                    .cornerRadius(10)
                }
                .disabled(!isValidName || isCreating)
                .padding(.horizontal, 24)

                // Progress/Error
                if !progress.isEmpty || error != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        if let error = error {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(CLITheme.red(for: colorScheme))
                                Text(error)
                                    .font(settings.scaledFont(.small))
                                    .foregroundColor(CLITheme.red(for: colorScheme))
                            }
                        }

                        if !progress.isEmpty {
                            Text(progress)
                                .font(settings.scaledFont(.small))
                                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                        }
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()

                // Hint
                Text("Project will be created in ~/workspace/")
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    .padding(.bottom, 24)
            }
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isCreating)
                }
            }
        }
    }

    private var isValidName: Bool {
        guard !projectName.isEmpty else { return false }
        // Basic validation - no spaces or special chars that would cause issues
        let validChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return projectName.unicodeScalars.allSatisfy { validChars.contains($0) }
    }

    private var sanitizedName: String {
        // Replace spaces with hyphens, remove other problematic chars
        projectName
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
    }

    private func createProject() async {
        isCreating = true
        error = nil
        progress = "Connecting to server..."

        do {
            let workspaceDir = "$HOME/workspace"
            // sanitizedName is already validated to contain only alphanumerics and -_
            let escapedSanitizedName = shellEscape(sanitizedName)

            // Check if directory already exists
            progress = "Checking if project exists..."
            let checkCmd = "test -d \"\(workspaceDir)\"/\(escapedSanitizedName) && echo 'EXISTS' || echo 'NOT_FOUND'"
            let checkOutput = try await sshManager.executeCommandWithAutoConnect(checkCmd, settings: settings)

            if checkOutput.contains("EXISTS") {
                throw SSHError.connectionFailed("Project '\(sanitizedName)' already exists")
            }

            // Create the project directory
            progress = "Creating project directory..."
            let mkdirCmd = "mkdir -p \"\(workspaceDir)\"/\(escapedSanitizedName)"
            _ = try await sshManager.executeCommand(mkdirCmd)

            // Get the absolute path
            let realpathCmd = "realpath \"\(workspaceDir)\"/\(escapedSanitizedName)"
            let absolutePath = try await sshManager.executeCommand(realpathCmd)
            let cleanPath = absolutePath.trimmingCharacters(in: .whitespacesAndNewlines)

            // Register with Claude
            progress = "Registering project..."
            let encodedPath = cleanPath.replacingOccurrences(of: "/", with: "-")
            // Shell-escape the encoded path for safe use in shell commands
            let escapedEncodedPath = shellEscape(encodedPath)
            // Use $HOME with double quotes for proper shell expansion, then append escaped path
            let claudeProjectDir = "\"$HOME/.claude/projects/\"\(escapedEncodedPath)"
            let timestamp = ISO8601DateFormatter().string(from: Date())
            // Escape cleanPath for JSON embedding (escape backslashes and quotes)
            let jsonEscapedPath = cleanPath
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            let sessionContent = "{\"type\":\"init\",\"cwd\":\"\(jsonEscapedPath)\",\"timestamp\":\"\(timestamp)\"}"
            // Shell-escape the JSON content for safe use in echo command
            let setupCmd = "mkdir -p \(claudeProjectDir) && echo \(shellEscape(sessionContent)) > \(claudeProjectDir)/init.jsonl"
            _ = try? await sshManager.executeCommand(setupCmd)

            // Optionally initialize Claude
            if initializeClaude {
                progress = "Initializing Claude..."
                let initCmd = "cd \(shellEscape(cleanPath)) && claude init --yes 2>&1 || claude init 2>&1 || true"
                _ = await sshManager.executeCommandWithTimeout(initCmd, timeoutSeconds: 10)
            }

            progress = "Project created!"

            // Small delay to show success
            try await Task.sleep(nanoseconds: 500_000_000)

            await MainActor.run {
                onComplete()
                dismiss()
            }

        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isCreating = false
            }
        }
    }
}
