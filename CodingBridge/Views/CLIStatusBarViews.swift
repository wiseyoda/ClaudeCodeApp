import SwiftUI
import Combine

// MARK: - Unified Status Bar (New Design)

/// A clean, unified status bar combining connection, model, modes, and settings
struct UnifiedStatusBar: View {
    let isProcessing: Bool
    let tokenUsage: TokenUsage?
    let effectivePermissionMode: PermissionMode
    let projectPath: String?
    @Binding var showQuickSettings: Bool
    @EnvironmentObject var settings: AppSettings
    @ObservedObject private var projectSettingsStore = ProjectSettingsStore.shared
    @Environment(\.colorScheme) var colorScheme

    /// Initializer with basic parameters
    init(isProcessing: Bool, tokenUsage: TokenUsage?, showQuickSettings: Binding<Bool>) {
        self.isProcessing = isProcessing
        self.tokenUsage = tokenUsage
        self.effectivePermissionMode = .default
        self.projectPath = nil
        self._showQuickSettings = showQuickSettings
    }

    /// Full initializer with per-project permission support
    init(isProcessing: Bool, tokenUsage: TokenUsage?, effectivePermissionMode: PermissionMode, projectPath: String, showQuickSettings: Binding<Bool>) {
        self.isProcessing = isProcessing
        self.tokenUsage = tokenUsage
        self.effectivePermissionMode = effectivePermissionMode
        self.projectPath = projectPath
        self._showQuickSettings = showQuickSettings
    }

    var body: some View {
        HStack(spacing: 12) {
            // Connection status dot + Model name
            HStack(spacing: 6) {
                // Isolated status indicator - observes HealthMonitorService independently
                // This prevents health check updates from re-rendering the entire status bar
                StatusIndicatorDot(isProcessing: isProcessing)

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

            // Permission mode indicator (icon-only, tappable to cycle modes)
            if effectivePermissionMode != .default || hasProjectOverride {
                Button {
                    togglePermissionMode()
                } label: {
                    ModePill(
                        icon: hasProjectOverride ? effectivePermissionMode.icon + ".fill" : effectivePermissionMode.icon,
                        text: hasProjectOverride ? effectivePermissionMode.shortDisplayName + "*" : effectivePermissionMode.shortDisplayName,
                        color: effectivePermissionMode.color,
                        isActive: effectivePermissionMode != .default,
                        iconOnly: true
                    )
                }
                .accessibilityLabel("Permission mode: \(effectivePermissionMode.displayName)" + (hasProjectOverride ? " for this project" : " globally"))
                .accessibilityHint("Tap to change permission mode")
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

    /// Whether this project has a specific override (vs using global setting)
    private var hasProjectOverride: Bool {
        guard let path = projectPath else { return false }
        return projectSettingsStore.permissionModeOverride(for: path) != nil
    }

    /// Toggle the per-project permission mode
    /// Cycles through: use global -> default -> acceptEdits -> bypassPermissions -> use global
    private func togglePermissionMode() {
        guard let path = projectPath else { return }

        let currentOverride = projectSettingsStore.permissionModeOverride(for: path)

        switch currentOverride {
        case nil:
            // Using global, start cycling through modes (start with default)
            projectSettingsStore.setPermissionModeOverride(for: path, mode: .default)
        case .default:
            // Switch to acceptEdits
            projectSettingsStore.setPermissionModeOverride(for: path, mode: .acceptEdits)
        case .acceptEdits:
            // Switch to bypassPermissions
            projectSettingsStore.setPermissionModeOverride(for: path, mode: .bypassPermissions)
        case .bypassPermissions:
            // Clear override to use global
            projectSettingsStore.setPermissionModeOverride(for: path, mode: nil)
        }
    }
}

// MARK: - Status Indicator Dot (Isolated)

/// Isolated view that observes HealthMonitorService independently.
/// This prevents health check updates (every 30s) from re-rendering the parent status bar,
/// which would cause unnecessary work during keyboard input.
private struct StatusIndicatorDot: View {
    let isProcessing: Bool
    @ObservedObject private var healthService = HealthMonitorService.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
            .modifier(ConditionalPulse(isActive: shouldPulse))
    }

    /// Status color based on server health and processing state
    private var statusColor: Color {
        switch healthService.serverStatus {
        case .disconnected:
            return CLITheme.red(for: colorScheme)
        case .checking:
            return CLITheme.red(for: colorScheme)
        case .connected:
            return isProcessing ? CLITheme.yellow(for: colorScheme) : CLITheme.green(for: colorScheme)
        }
    }

    /// Whether the status indicator should pulse
    private var shouldPulse: Bool {
        isProcessing || healthService.serverStatus == .checking
    }
}

// MARK: - Conditional Pulse Animation

/// A modifier that pulses opacity when active, but keeps the view stable (no layout shifts)
private struct ConditionalPulse: ViewModifier {
    let isActive: Bool
    @State private var animationPhase: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? animationPhase : 1.0)
            .animation(
                isActive
                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .default,
                value: animationPhase
            )
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    // Start pulsing
                    animationPhase = 0.3
                } else {
                    // Stop pulsing, return to full opacity
                    animationPhase = 1.0
                }
            }
            .onAppear {
                if isActive {
                    animationPhase = 0.3
                }
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

    /// Cached percentage (computed once per init, not on every body call)
    private let percentage: Double

    init(used: Int, total: Int) {
        self.used = used
        self.total = total
        self.percentage = total > 0 ? Double(used) / Double(total) : 0
    }

    private var color: Color {
        // Use cached percentage to avoid recalculating
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
