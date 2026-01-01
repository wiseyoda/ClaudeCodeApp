import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var showSSHKeyImport = false
    @State private var hasSSHKey = KeychainHelper.shared.hasSSHKey

    /// When false, hides the Done button (for tab embedding vs sheet presentation)
    var showDismissButton: Bool = true

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
                    Picker("Default Model", selection: Binding(
                        get: { settings.defaultModel },
                        set: { settings.defaultModel = $0 }
                    )) {
                        ForEach(ClaudeModel.allCases.filter { $0 != .custom }, id: \.self) { model in
                            HStack {
                                Image(systemName: model.icon)
                                Text(model.displayName)
                            }
                            .tag(model)
                        }
                    }

                    Picker("Default Mode", selection: Binding(
                        get: { settings.claudeMode },
                        set: { settings.claudeMode = $0 }
                    )) {
                        ForEach(ClaudeMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }

                    Picker("Permission Mode", selection: Binding(
                        get: { settings.globalPermissionMode },
                        set: { settings.globalPermissionMode = $0 }
                    )) {
                        ForEach(PermissionMode.allCases, id: \.self) { mode in
                            HStack {
                                Image(systemName: mode.icon)
                                Text(mode.displayName)
                            }
                            .tag(mode)
                        }
                    }
                } header: {
                    Text("Claude")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(settings.globalPermissionMode.description)
                            .foregroundStyle(.secondary)
                        if settings.globalPermissionMode.isDangerous {
                            Label("All tool executions will be auto-approved without confirmation.", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                        Text("Model: \(settings.defaultModel.description)")
                            .foregroundStyle(.secondary)
                    }
                }

                // Section 3: Chat Display
                Section("Chat Display") {
                    Toggle("Show Thinking Blocks", isOn: $settings.showThinkingBlocks)
                    Toggle("Auto-scroll to Bottom", isOn: $settings.autoScrollEnabled)
                }

                // Section 4: Message Collection
                Section {
                    MessageCollectionView()
                } header: {
                    Text("Message Collection")
                } footer: {
                    Text("Collect fun status messages as Claude works. Rarer messages appear less often!")
                }

                // Section 5: Push Notifications (Experimental)
                Section {
                    Toggle("Enable Push Notifications", isOn: $settings.enablePushNotifications)

                    if settings.enablePushNotifications {
                        Toggle("Background Notifications", isOn: $settings.enableBackgroundNotifications)
                        Toggle("Live Activities", isOn: $settings.enableLiveActivities)
                        Toggle("Time-Sensitive Alerts", isOn: $settings.enableTimeSensitiveNotifications)
                        Toggle("Show Details on Lock Screen", isOn: $settings.showNotificationDetails)
                    }
                } header: {
                    Text("Push Notifications")
                } footer: {
                    if settings.enablePushNotifications {
                        Text("Receive alerts when Claude completes tasks, needs approval, or has questions. Requires Firebase configuration.")
                    } else {
                        Text("Experimental feature. Enable to receive push notifications when app is in background.")
                    }
                }

                // Section 5: Projects
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

                // Section 6: Server Configuration
                Section {
                    TextField("URL", text: $settings.serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    NavigationLink {
                        DiagnosticsView()
                    } label: {
                        Label("Diagnostics", systemImage: "stethoscope")
                    }
                } header: {
                    Text("Server")
                } footer: {
                    Text("cli-bridge server URL (e.g., http://localhost:3100). Auth is handled by Tailscale.")
                }

                // Section 7: SSH Key (optional - for direct terminal access)
                Section {
                    HStack {
                        Text("SSH Key")
                        Spacer()
                        if hasSSHKey {
                            Label("Configured", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.subheadline)
                        } else {
                            Text("Not configured")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                    }

                    Button {
                        showSSHKeyImport = true
                    } label: {
                        Label(hasSSHKey ? "Replace SSH Key..." : "Import SSH Key...", systemImage: "key")
                    }

                    if hasSSHKey {
                        Button(role: .destructive) {
                            KeychainHelper.shared.clearAll()
                            hasSSHKey = false
                        } label: {
                            Label("Remove SSH Key", systemImage: "trash")
                        }
                    }
                } header: {
                    Text("SSH Key")
                } footer: {
                    Text("Optional. Import a private key for direct SSH terminal access to remote servers.")
                }

                // Section 8: SSH Connection (optional - only if SSH key is configured)
                if hasSSHKey {
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
                    } header: {
                        Text("SSH Connection")
                    } footer: {
                        Text("Configure SSH host for direct terminal access. Leave blank to use cli-bridge APIs only.")
                    }
                }

                // Section 9: About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(AppVersion.version)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text(AppVersion.build)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                if showDismissButton {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $showSSHKeyImport) {
                SSHKeyImportSheet(onKeyImported: {
                    hasSSHKey = KeychainHelper.shared.hasSSHKey
                })
            }
        }
    }
}
