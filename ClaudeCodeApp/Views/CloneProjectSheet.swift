import SwiftUI

// MARK: - Clone Project Sheet

struct CloneProjectSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var sshManager = SSHManager.shared

    @State private var gitURL = ""
    @State private var isCloning = false
    @State private var error: String?
    @State private var progress: String = ""

    let onComplete: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 48))
                    .foregroundColor(CLITheme.cyan(for: colorScheme))
                    .padding(.top, 24)

                // Instructions
                Text("Clone a Git Repository")
                    .font(settings.scaledFont(.body))
                    .foregroundColor(CLITheme.primaryText(for: colorScheme))

                // URL Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Repository URL")
                        .font(settings.scaledFont(.small))
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))

                    TextField("https://github.com/user/repo.git", text: $gitURL)
                        .font(settings.scaledFont(.body))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .padding(12)
                        .background(CLITheme.secondaryBackground(for: colorScheme))
                        .cornerRadius(8)
                        .disabled(isCloning)
                }
                .padding(.horizontal, 24)

                // Clone button
                Button {
                    Task { await cloneRepository() }
                } label: {
                    HStack {
                        if isCloning {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.down.circle")
                        }
                        Text(isCloning ? "Cloning..." : "Clone Repository")
                    }
                    .font(settings.scaledFont(.body))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isValidURL ? CLITheme.cyan(for: colorScheme) : CLITheme.mutedText(for: colorScheme))
                    .cornerRadius(10)
                }
                .disabled(!isValidURL || isCloning)
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
                VStack(spacing: 4) {
                    Text("Repository will be cloned to the server's workspace")
                        .font(settings.scaledFont(.small))
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))

                    Text("Supports GitHub, GitLab, Bitbucket URLs")
                        .font(settings.scaledFont(.small))
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                }
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)
            }
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Clone Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isCloning)
                }
            }
        }
    }

    private var isValidURL: Bool {
        guard !gitURL.isEmpty else { return false }
        // Simple validation for git URLs
        return gitURL.contains("github.com") ||
               gitURL.contains("gitlab.com") ||
               gitURL.contains("bitbucket.org") ||
               gitURL.hasSuffix(".git") ||
               gitURL.hasPrefix("git@")
    }

    private var repoName: String {
        // Extract repo name from URL
        // https://github.com/user/repo.git -> repo
        // git@github.com:user/repo.git -> repo
        var name = gitURL

        // Remove .git suffix
        if name.hasSuffix(".git") {
            name = String(name.dropLast(4))
        }

        // Get last path component
        if let lastSlash = name.lastIndex(of: "/") {
            name = String(name[name.index(after: lastSlash)...])
        } else if let lastColon = name.lastIndex(of: ":") {
            name = String(name[name.index(after: lastColon)...])
        }

        return name.isEmpty ? "project" : name
    }

    private func cloneRepository() async {
        isCloning = true
        error = nil
        progress = "Connecting to server..."

        do {
            progress = "Cloning repository..."

            // Clone to workspace directory
            let workspaceDir = "~/workspace"
            let cloneCmd = "mkdir -p \(workspaceDir) && cd \(workspaceDir) && git clone \(gitURL) 2>&1"

            // Execute clone command
            let output = try await sshManager.executeCommandWithAutoConnect(cloneCmd, settings: settings)

            // Check for errors - but ignore "already exists" which is fine
            if output.contains("fatal:") || output.contains("error:") {
                // Allow "already exists" - user might want to re-clone
                if !output.contains("already exists") {
                    throw SSHError.connectionFailed(output.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }

            // Verify the clone succeeded by checking if directory exists
            let verifyCmd = "test -d \(workspaceDir)/\(repoName) && echo 'EXISTS' || echo 'NOT_FOUND'"
            let verifyOutput = try await sshManager.executeCommand(verifyCmd)
            if verifyOutput.contains("NOT_FOUND") {
                throw SSHError.connectionFailed("Clone failed - repository directory not created")
            }

            progress = "Registering project..."

            // Get the absolute path of the cloned repo
            let realpathCmd = "realpath \(workspaceDir)/\(repoName)"
            let absolutePath = try await sshManager.executeCommand(realpathCmd)
            let cleanPath = absolutePath.trimmingCharacters(in: .whitespacesAndNewlines)

            // Create Claude project directory structure
            // Path encoding: /home/user/workspace/repo -> -home-user-workspace-repo
            let encodedPath = cleanPath.replacingOccurrences(of: "/", with: "-")
            let claudeProjectDir = "~/.claude/projects/\(encodedPath)"

            // Create the project directory and a session file with cwd so it appears in the project list
            // The backend reads 'cwd' from session files to determine project paths
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let sessionContent = "{\"type\":\"init\",\"cwd\":\"\(cleanPath)\",\"timestamp\":\"\(timestamp)\"}"
            let setupCmd = "mkdir -p '\(claudeProjectDir)' && echo '\(sessionContent)' > '\(claudeProjectDir)/init.jsonl'"
            _ = try? await sshManager.executeCommand(setupCmd)

            progress = "Initializing Claude..."

            // Try to initialize Claude in the cloned repo with timeout
            // Use --yes flag if available, and timeout after 10 seconds
            let initCmd = "cd '\(cleanPath)' && claude init --yes 2>&1 || claude init 2>&1 || true"
            let initResult = await sshManager.executeCommandWithTimeout(initCmd, timeoutSeconds: 10)

            if initResult == nil {
                // Claude init timed out - that's OK, project dir is created
                progress = "Clone complete!"
            } else {
                progress = "Clone complete!"
            }

            // Small delay to show success
            try await Task.sleep(nanoseconds: 500_000_000)

            await MainActor.run {
                onComplete()
                dismiss()
            }

        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isCloning = false
            }
        }
    }
}
