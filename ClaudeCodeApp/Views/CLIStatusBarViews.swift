import SwiftUI

// MARK: - CLI Status Bar

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
