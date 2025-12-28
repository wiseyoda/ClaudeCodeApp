import SwiftUI
import Combine

// MARK: - Unified Status Bar (New Design)

/// A clean, unified status bar combining connection, model, modes, and settings
struct UnifiedStatusBar: View {
    let isProcessing: Bool
    let connectionState: ConnectionState
    let tokenUsage: WebSocketManager.TokenUsage?
    let effectiveSkipPermissions: Bool
    let projectPath: String?
    @Binding var showQuickSettings: Bool
    @EnvironmentObject var settings: AppSettings
    @ObservedObject private var projectSettingsStore = ProjectSettingsStore.shared
    @Environment(\.colorScheme) var colorScheme

    /// Legacy initializer for backward compatibility
    init(isProcessing: Bool, isConnected: Bool, tokenUsage: WebSocketManager.TokenUsage?, showQuickSettings: Binding<Bool>) {
        self.isProcessing = isProcessing
        self.connectionState = isConnected ? .connected : .disconnected
        self.tokenUsage = tokenUsage
        self.effectiveSkipPermissions = false
        self.projectPath = nil
        self._showQuickSettings = showQuickSettings
    }

    /// New initializer with full connection state
    init(isProcessing: Bool, connectionState: ConnectionState, tokenUsage: WebSocketManager.TokenUsage?, showQuickSettings: Binding<Bool>) {
        self.isProcessing = isProcessing
        self.connectionState = connectionState
        self.tokenUsage = tokenUsage
        self.effectiveSkipPermissions = false
        self.projectPath = nil
        self._showQuickSettings = showQuickSettings
    }

    /// Full initializer with per-project permission support
    init(isProcessing: Bool, connectionState: ConnectionState, tokenUsage: WebSocketManager.TokenUsage?, effectiveSkipPermissions: Bool, projectPath: String, showQuickSettings: Binding<Bool>) {
        self.isProcessing = isProcessing
        self.connectionState = connectionState
        self.tokenUsage = tokenUsage
        self.effectiveSkipPermissions = effectiveSkipPermissions
        self.projectPath = projectPath
        self._showQuickSettings = showQuickSettings
    }

    var body: some View {
        HStack(spacing: 12) {
            // Connection status dot + Model name
            HStack(spacing: 6) {
                ZStack {
                    // Static base circle (always present for stable layout)
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    // Pulsing overlay when processing/connecting
                    if connectionState.isConnecting || isProcessing {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                            .modifier(PulsingOpacity())
                    }
                }
                .frame(width: 8, height: 8)  // Fixed frame prevents layout shifts

                // Show model name (tappable) - always visible for consistent layout
                Button {
                    showQuickSettings = true
                } label: {
                    Text(settings.defaultModel.shortName)
                        .font(settings.scaledFont(.body))
                        .fontWeight(.medium)
                        .foregroundColor(CLITheme.primaryText(for: colorScheme))
                }
            }

            // Mode toggles (icon-only to prevent word wrap when tokens visible)
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    settings.claudeMode = settings.claudeMode.next()
                }
            } label: {
                ModePill(
                    icon: settings.claudeMode.icon,
                    text: settings.claudeMode.displayName,
                    color: settings.claudeMode.color,
                    isActive: settings.claudeMode != .normal,
                    iconOnly: true
                )
            }
            .accessibilityLabel("Mode: \(settings.claudeMode.displayName)")
            .accessibilityHint("Tap to switch to \(settings.claudeMode.next().displayName)")

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    settings.thinkingMode = settings.thinkingMode.next()
                }
            } label: {
                ModePill(
                    icon: settings.thinkingMode.icon,
                    text: settings.thinkingMode.shortDisplayName,
                    color: settings.thinkingMode.color,
                    isActive: settings.thinkingMode != .normal,
                    iconOnly: true
                )
            }
            .accessibilityLabel("Thinking: \(settings.thinkingMode.displayName)")
            .accessibilityHint("Tap to switch to \(settings.thinkingMode.next().displayName)")

            // Skip permissions indicator (icon-only, tappable to toggle per-project)
            if effectiveSkipPermissions {
                Button {
                    toggleProjectBypass()
                } label: {
                    ModePill(
                        icon: hasProjectOverride ? "exclamationmark.shield.fill" : "exclamationmark.shield",
                        text: hasProjectOverride ? "Bypass*" : "Bypass",
                        color: CLITheme.red(for: colorScheme),
                        isActive: true,
                        iconOnly: true
                    )
                }
                .accessibilityLabel("Permissions bypass enabled" + (hasProjectOverride ? " for this project" : " globally"))
                .accessibilityHint("Tap to toggle for this project")
            } else if let path = projectPath, projectSettingsStore.skipPermissionsOverride(for: path) == false {
                // Show when project explicitly disables bypass (overriding global)
                Button {
                    toggleProjectBypass()
                } label: {
                    ModePill(
                        icon: "shield.checkered",
                        text: "Safe*",
                        color: CLITheme.green(for: colorScheme),
                        isActive: true,
                        iconOnly: true
                    )
                }
                .accessibilityLabel("Permissions required for this project")
                .accessibilityHint("Tap to toggle for this project")
            }

            Spacer()

            // Token count (compact)
            if let usage = tokenUsage {
                Button {
                    showQuickSettings = true
                } label: {
                    CompactTokenView(used: usage.used, total: usage.total)
                }
            }

            // Settings gear
            Button {
                showQuickSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }
            .accessibilityLabel("Quick settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(CLITheme.secondaryBackground(for: colorScheme))
    }

    private var statusColor: Color {
        switch connectionState {
        case .disconnected:
            return CLITheme.red(for: colorScheme)
        case .connecting, .reconnecting:
            // Yellow for connecting/reconnecting - pulsing animation shows activity
            return CLITheme.yellow(for: colorScheme)
        case .connected:
            if isProcessing {
                return CLITheme.yellow(for: colorScheme)
            } else {
                return CLITheme.green(for: colorScheme)
            }
        }
    }

    /// Whether this project has a specific override (vs using global setting)
    private var hasProjectOverride: Bool {
        guard let path = projectPath else { return false }
        return projectSettingsStore.skipPermissionsOverride(for: path) != nil
    }

    /// Toggle the per-project bypass setting
    /// Cycles through: use global -> force on -> force off -> use global
    private func toggleProjectBypass() {
        guard let path = projectPath else { return }

        let currentOverride = projectSettingsStore.skipPermissionsOverride(for: path)

        switch currentOverride {
        case nil:
            // Using global, switch to opposite of global
            projectSettingsStore.setSkipPermissionsOverride(for: path, override: !settings.skipPermissions)
        case true:
            // Was forced on, switch to forced off
            projectSettingsStore.setSkipPermissionsOverride(for: path, override: false)
        case false:
            // Was forced off, clear override to use global
            projectSettingsStore.setSkipPermissionsOverride(for: path, override: nil)
        }
    }
}

// MARK: - Pulsing Opacity Animation

private struct PulsingOpacity: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.3 : 1.0)
            .animation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Mode Pill

private struct ModePill: View {
    let icon: String
    let text: String
    let color: Color
    var isActive: Bool = true
    var iconOnly: Bool = false
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: iconOnly ? 0 : 3) {
            Image(systemName: icon)
                .font(.system(size: iconOnly ? 12 : 10))
            if !iconOnly {
                Text(text)
                    .font(settings.scaledFont(.small))
            }
        }
        .foregroundColor(isActive ? color : CLITheme.mutedText(for: colorScheme))
        .padding(.horizontal, iconOnly ? 6 : 8)
        .padding(.vertical, iconOnly ? 5 : 3)
        .background(isActive ? color.opacity(0.15) : CLITheme.mutedText(for: colorScheme).opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Processing Indicator

private struct ProcessingIndicator: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    @State private var wordIndex = 0
    @State private var timerCancellable: AnyCancellable?
    private let words = ["thinking", "working", "analyzing"]

    var body: some View {
        Text(words[wordIndex])
            .font(settings.scaledFont(.body))
            .foregroundColor(CLITheme.yellow(for: colorScheme))
            .onAppear {
                timerCancellable = Timer.publish(every: 2, on: .main, in: .common)
                    .autoconnect()
                    .sink { _ in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            wordIndex = (wordIndex + 1) % words.count
                        }
                    }
            }
            .onDisappear {
                timerCancellable?.cancel()
                timerCancellable = nil
            }
    }
}

// MARK: - Compact Token View

private struct CompactTokenView: View {
    let used: Int
    let total: Int
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }

    private var color: Color {
        if percentage > 0.8 {
            return CLITheme.red(for: colorScheme)
        } else if percentage > 0.6 {
            return CLITheme.yellow(for: colorScheme)
        } else {
            return CLITheme.secondaryText(for: colorScheme)
        }
    }

    var body: some View {
        Text(formatTokens(used))
            .font(settings.scaledFont(.small))
            .fontDesign(.monospaced)
            .foregroundColor(color)
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        }
        return "\(count)"
    }
}

// MARK: - CLI Status Bar (Legacy - kept for compatibility)

struct CLIStatusBar: View {
    let isProcessing: Bool
    let isUploadingImage: Bool
    let startTime: Date?
    let tokenUsage: WebSocketManager.TokenUsage?
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    @State private var elapsedTime: String = "0s"
    @State private var statusWordIndex: Int = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Cycling status words for processing state
    private let statusWords = ["thinking", "processing", "analyzing", "working", "reasoning"]

    private var statusAccessibilityLabel: String {
        var label: String
        if isUploadingImage {
            label = "Uploading image"
        } else if isProcessing {
            label = "Claude is \(statusWords[statusWordIndex]), elapsed time \(elapsedTime)"
        } else {
            label = "Claude is ready"
        }
        if let usage = tokenUsage {
            let percentage = Int((Double(usage.used) / Double(usage.total)) * 100)
            label += ", \(percentage)% of context used"
        }
        return label
    }

    var body: some View {
        HStack(spacing: 12) {
            if isUploadingImage {
                HStack(spacing: 4) {
                    Circle()
                        .fill(CLITheme.cyan(for: colorScheme))
                        .frame(width: 6, height: 6)
                    Text("uploading image")
                        .foregroundColor(CLITheme.cyan(for: colorScheme))
                }
            } else if isProcessing {
                HStack(spacing: 4) {
                    Circle()
                        .fill(CLITheme.yellow(for: colorScheme))
                        .frame(width: 6, height: 6)
                    Text(statusWords[statusWordIndex])
                        .foregroundColor(CLITheme.yellow(for: colorScheme))
                        .animation(.easeInOut(duration: 0.3), value: statusWordIndex)
                }
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(CLITheme.green(for: colorScheme))
                        .frame(width: 6, height: 6)
                    Text("ready")
                        .foregroundColor(CLITheme.green(for: colorScheme))
                }
            }

            Spacer()

            // Context usage from WebSocket (only show if actually received from server)
            if let usage = tokenUsage {
                TokenUsageView(used: usage.used, total: usage.total)
            }

            if isProcessing {
                Text(elapsedTime)
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }
        }
        .font(settings.scaledFont(.small))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(CLITheme.secondaryBackground(for: colorScheme))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusAccessibilityLabel)
        .accessibilityAddTraits(isProcessing ? .updatesFrequently : [])
        .onReceive(timer) { _ in
            if let start = startTime {
                let elapsed = Int(Date().timeIntervalSince(start))
                if elapsed < 60 {
                    elapsedTime = "\(elapsed)s"
                } else {
                    elapsedTime = "\(elapsed / 60)m \(elapsed % 60)s"
                }
                // Cycle status word every 3 seconds
                if isProcessing && elapsed > 0 && elapsed % 3 == 0 {
                    statusWordIndex = (statusWordIndex + 1) % statusWords.count
                }
            }
        }
        .onChange(of: isProcessing) { _, processing in
            // Reset to first word when processing starts
            if processing {
                statusWordIndex = 0
            }
        }
    }

}

// MARK: - Token Usage View

struct TokenUsageView: View {
    let used: Int
    let total: Int
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    private var percentage: Double {
        Double(used) / Double(total)
    }

    private var displayPercentage: Double {
        min(percentage, 1.0)
    }

    private var color: Color {
        if percentage > 0.8 {
            return CLITheme.red(for: colorScheme)
        } else if percentage > 0.6 {
            return CLITheme.yellow(for: colorScheme)
        } else {
            return CLITheme.green(for: colorScheme)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            // Circular progress indicator
            ZStack {
                // Background circle
                Circle()
                    .stroke(CLITheme.mutedText(for: colorScheme).opacity(0.3), lineWidth: 2)

                // Progress arc
                Circle()
                    .trim(from: 0, to: displayPercentage)
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 14, height: 14)

            // Text display
            Text("\(formatTokens(used))/\(formatTokens(total))")
                .font(settings.scaledFont(.small))
                .foregroundColor(color)
        }
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        }
        return "\(count)"
    }
}

// MARK: - CLI Mode Selector

struct CLIModeSelector: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            // Claude mode toggle (left side)
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    settings.claudeMode = settings.claudeMode.next()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: settings.claudeMode.icon)
                        .font(.system(size: 12))
                    Text(settings.claudeMode.displayName)
                        .font(settings.scaledFont(.small))
                }
                .foregroundColor(settings.claudeMode.color)
            }
            .accessibilityLabel("Claude mode: \(settings.claudeMode.displayName)")
            .accessibilityHint("Switch to \(settings.claudeMode.next().displayName) mode")

            Spacer()

            // Thinking mode toggle (right side)
            ThinkingModeIndicator()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(CLITheme.secondaryBackground(for: colorScheme))
    }
}

// MARK: - Thinking Mode Indicator

struct ThinkingModeIndicator: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.thinkingMode = settings.thinkingMode.next()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: settings.thinkingMode.icon)
                    .font(.system(size: 10))
                Text(settings.thinkingMode.displayName)
                    .font(settings.scaledFont(.small))
            }
            .foregroundColor(settings.thinkingMode.color)
        }
        .accessibilityLabel("Thinking mode: \(settings.thinkingMode.displayName)")
        .accessibilityHint("Switch to \(settings.thinkingMode.next().displayName) mode")
    }
}
