import SwiftUI

// MARK: - Quick Settings Sheet

/// A compact settings sheet for frequently-changed session settings
struct QuickSettingsSheet: View {
    @EnvironmentObject var settings: AppSettings
    @ObservedObject var debugStore = DebugLogStore.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    let tokenUsage: (current: Int, max: Int)?
    @State private var showDebugLog = false
    @State private var showErrorInsights = false
    @ObservedObject private var errorAnalytics = ErrorAnalyticsStore.shared

    var body: some View {
        NavigationStack {
            List {
                // Model & Mode Selection (compact)
                Section {
                    Picker(selection: $settings.defaultModel) {
                        ForEach(ClaudeModel.allCases, id: \.self) { model in
                            Label(model.shortName, systemImage: model.icon)
                                .tag(model)
                        }
                    } label: {
                        Label("Model", systemImage: "cpu")
                    }

                    Picker(selection: $settings.claudeMode) {
                        ForEach(ClaudeMode.allCases, id: \.self) { mode in
                            Label(mode.displayName, systemImage: mode.icon)
                                .tag(mode)
                        }
                    } label: {
                        Label("Permission Mode", systemImage: "lock.shield")
                    }

                    Picker(selection: $settings.thinkingMode) {
                        ForEach(ThinkingMode.allCases, id: \.self) { mode in
                            Label(mode.displayName, systemImage: mode.icon)
                                .tag(mode)
                        }
                    } label: {
                        Label("Thinking Mode", systemImage: "brain")
                    }
                } header: {
                    Text("Claude")
                }

                // Token Usage
                if let usage = tokenUsage {
                    Section {
                        QuickSettingsTokenView(current: usage.current, max: usage.max)
                    } header: {
                        Text("Token Usage")
                    }
                }

                // Quick Toggles
                Section {
                    Toggle(isOn: $settings.lockToPortrait) {
                        Label("Lock to Portrait", systemImage: "rectangle.portrait")
                    }

                    Toggle(isOn: $settings.showThinkingBlocks) {
                        Label("Show Thinking Blocks", systemImage: "brain")
                    }

                    Toggle(isOn: $settings.autoScrollEnabled) {
                        Label("Auto-scroll", systemImage: "arrow.down.to.line")
                    }

                    Toggle(isOn: $settings.autoSuggestionsEnabled) {
                        Label("Auto Suggestions", systemImage: "sparkles")
                    }

                    Picker(selection: Binding(
                        get: { settings.historyLimit },
                        set: { settings.historyLimit = $0 }
                    )) {
                        ForEach(HistoryLimit.allCases, id: \.self) { limit in
                            Text("\(limit.displayName) messages").tag(limit)
                        }
                    } label: {
                        Label("History Limit", systemImage: "clock.arrow.circlepath")
                    }
                } header: {
                    Text("Display")
                } footer: {
                    Text("Auto suggestions uses AI to suggest next actions after each response.")
                }

                // Advanced Section
                Section {
                    Picker(selection: $settings.processingTimeout) {
                        Text("30 seconds").tag(30)
                        Text("1 minute").tag(60)
                        Text("5 minutes").tag(300)
                        Text("15 minutes").tag(900)
                        Text("30 minutes").tag(1800)
                        Text("1 hour").tag(3600)
                    } label: {
                        Label("Response Timeout", systemImage: "clock")
                    }
                } header: {
                    Text("Advanced")
                } footer: {
                    Text("How long to wait for Claude to respond. Increase for long operations like code reviews.")
                }

                // Debug Section
                Section {
                    Toggle(isOn: Binding(
                        get: { debugStore.isEnabled },
                        set: { newValue in
                            debugStore.isEnabled = newValue
                            settings.debugLoggingEnabled = newValue
                        }
                    )) {
                        Label("Debug Logging", systemImage: "ladybug")
                    }

                    Button {
                        showDebugLog = true
                    } label: {
                        HStack {
                            Label("View Debug Log", systemImage: "doc.text.magnifyingglass")
                            Spacer()
                            if debugStore.entries.count > 0 {
                                Text("\(debugStore.entries.count)")
                                    .font(.caption)
                                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(CLITheme.mutedText(for: colorScheme).opacity(0.2))
                                    .cornerRadius(8)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(CLITheme.mutedText(for: colorScheme))
                        }
                    }

                    Button {
                        showErrorInsights = true
                    } label: {
                        HStack {
                            Label("Error Insights", systemImage: "exclamationmark.triangle")
                            Spacer()
                            if errorAnalytics.totalErrors > 0 {
                                Text("\(errorAnalytics.totalErrors)")
                                    .font(.caption)
                                    .foregroundColor(CLITheme.red(for: colorScheme))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(CLITheme.red(for: colorScheme).opacity(0.15))
                                    .cornerRadius(8)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(CLITheme.mutedText(for: colorScheme))
                        }
                    }
                } header: {
                    Text("Developer")
                } footer: {
                    Text("Debug logging captures raw WebSocket messages for troubleshooting.")
                }
            }
            .listStyle(.insetGrouped)
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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showDebugLog) {
            DebugLogView()
        }
        .sheet(isPresented: $showErrorInsights) {
            ErrorInsightsView()
        }
    }

}

// MARK: - Quick Settings Token View

private struct QuickSettingsTokenView: View {
    let current: Int
    let max: Int
    @Environment(\.colorScheme) var colorScheme

    private var percentage: Double {
        guard max > 0 else { return 0 }
        return Double(current) / Double(max)
    }

    private var progressColor: Color {
        if percentage > 0.9 {
            return CLITheme.red(for: colorScheme)
        } else if percentage > 0.7 {
            return CLITheme.yellow(for: colorScheme)
        } else {
            return CLITheme.green(for: colorScheme)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formatTokens(current))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(CLITheme.primaryText(for: colorScheme))

                Text("/")
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))

                Text(formatTokens(max))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))

                Spacer()

                Text("\(Int(percentage * 100))%")
                    .font(.caption)
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(CLITheme.mutedText(for: colorScheme).opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * percentage, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 4)
        .listRowBackground(CLITheme.secondaryBackground(for: colorScheme))
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000)
        }
        return "\(count)"
    }
}

// MARK: - Preview

#Preview {
    QuickSettingsSheet(tokenUsage: (current: 32900, max: 160000))
        .environmentObject(AppSettings())
}
