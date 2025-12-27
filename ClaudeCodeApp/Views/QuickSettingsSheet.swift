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

    var body: some View {
        NavigationStack {
            List {
                // Model Selection
                Section {
                    ForEach(ClaudeModel.allCases, id: \.self) { model in
                        ModelRow(model: model, isSelected: settings.defaultModel == model) {
                            settings.defaultModel = model
                        }
                    }
                } header: {
                    Text("Model")
                }

                // Claude Mode
                Section {
                    ForEach(ClaudeMode.allCases, id: \.self) { mode in
                        ModeRow(
                            title: mode.displayName,
                            subtitle: mode.description,
                            icon: mode.icon,
                            isSelected: settings.claudeMode == mode
                        ) {
                            settings.claudeMode = mode
                        }
                    }
                } header: {
                    Text("Permission Mode")
                }

                // Thinking Mode
                Section {
                    ForEach(ThinkingMode.allCases, id: \.self) { mode in
                        ModeRow(
                            title: mode.displayName,
                            subtitle: thinkingModeDescription(mode),
                            icon: mode.icon,
                            isSelected: settings.thinkingMode == mode,
                            tintColor: mode.color
                        ) {
                            settings.thinkingMode = mode
                        }
                    }
                } header: {
                    Text("Thinking Mode")
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
                    Toggle(isOn: $settings.showThinkingBlocks) {
                        Label("Show Thinking Blocks", systemImage: "brain")
                    }

                    Toggle(isOn: $settings.autoScrollEnabled) {
                        Label("Auto-scroll", systemImage: "arrow.down.to.line")
                    }
                } header: {
                    Text("Display")
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
    }

    private func thinkingModeDescription(_ mode: ThinkingMode) -> String {
        switch mode {
        case .normal: return "Standard responses"
        case .think: return "Light reasoning"
        case .thinkHard: return "Deeper analysis"
        case .thinkHarder: return "Extended reasoning"
        case .ultrathink: return "Maximum depth"
        }
    }
}

// MARK: - Model Row

private struct ModelRow: View {
    let model: ClaudeModel
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: model.icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .white : CLITheme.blue(for: colorScheme))
                    .frame(width: 32, height: 32)
                    .background(isSelected ? CLITheme.blue(for: colorScheme) : CLITheme.blue(for: colorScheme).opacity(0.15))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.shortName)
                        .font(.body)
                        .foregroundColor(CLITheme.primaryText(for: colorScheme))

                    Text(model.description)
                        .font(.caption)
                        .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(CLITheme.blue(for: colorScheme))
                }
            }
        }
        .listRowBackground(CLITheme.secondaryBackground(for: colorScheme))
    }
}

// MARK: - Mode Row

private struct ModeRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    var tintColor: Color? = nil
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var effectiveTint: Color {
        tintColor ?? CLITheme.blue(for: colorScheme)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .white : effectiveTint)
                    .frame(width: 28, height: 28)
                    .background(isSelected ? effectiveTint : effectiveTint.opacity(0.15))
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(CLITheme.primaryText(for: colorScheme))

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(effectiveTint)
                }
            }
        }
        .listRowBackground(CLITheme.secondaryBackground(for: colorScheme))
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
