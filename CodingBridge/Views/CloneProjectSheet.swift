import SwiftUI

// MARK: - Clone Project Sheet

struct CloneProjectSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

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

    /// Convert SSH-style git URLs to HTTPS format for server compatibility.
    /// The CLI Bridge server uses gh auth git-credential for HTTPS authentication
    /// but has no SSH keys configured.
    ///
    /// Examples:
    /// - git@github.com:user/repo.git → https://github.com/user/repo.git
    /// - git@gitlab.com:user/repo.git → https://gitlab.com/user/repo.git
    /// - https://github.com/user/repo.git → unchanged
    private func normalizeToHTTPS(_ url: String) -> String {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for SSH format: git@host:path
        guard trimmed.hasPrefix("git@") else {
            return trimmed
        }

        // git@github.com:user/repo.git → https://github.com/user/repo.git
        var converted = trimmed
        converted = converted.replacingOccurrences(of: "git@", with: "https://")
        converted = converted.replacingOccurrences(of: ":", with: "/", options: [], range: converted.range(of: ":"))

        return converted
    }

    private func cloneRepository() async {
        isCloning = true
        error = nil
        progress = "Cloning repository..."

        // Convert SSH URLs to HTTPS for server compatibility
        let normalizedURL = normalizeToHTTPS(gitURL)

        do {
            let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)

            let response = try await apiClient.cloneProject(
                url: normalizedURL,
                initializeClaude: true
            )

            await MainActor.run {
                progress = "Cloned to \(response.path)"
            }

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
