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
        progress = "Creating project..."

        do {
            let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)

            // TODO: Replace with cli-bridge API endpoint when available
            // POST /projects/create { name: string, initializeClaude: bool }
            // For now, show error that this feature requires cli-bridge support
            throw CLIBridgeAPIError.endpointNotAvailable(
                "Create project requires cli-bridge API support. " +
                "See CLI-BRIDGE-FEATURE-REQUEST.md for details."
            )

            // When API is available:
            // let response = try await apiClient.createProject(
            //     name: sanitizedName,
            //     initializeClaude: initializeClaude
            // )
            //
            // progress = "Project created!"
            // try await Task.sleep(nanoseconds: 500_000_000)
            //
            // await MainActor.run {
            //     onComplete()
            //     dismiss()
            // }

        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isCreating = false
            }
        }
    }
}
