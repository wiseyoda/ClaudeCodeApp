import SwiftUI

/// Action bar shown below assistant messages with copy, time, tokens, and analyze options
struct MessageActionBar: View {
    let message: ChatMessage
    let projectPath: String
    let onCopy: () -> Void
    let onAnalyze: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var settings: AppSettings
    @State private var showCopied = false
    @State private var copyResetTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 12) {
            // Execution time
            if let time = message.executionTime {
                StatLabel(
                    icon: "clock",
                    text: formatTime(time),
                    color: CLITheme.mutedText(for: colorScheme)
                )
            }

            // Token count
            if let tokens = message.tokenCount {
                StatLabel(
                    icon: "number",
                    text: formatTokens(tokens),
                    color: CLITheme.mutedText(for: colorScheme)
                )
            }

            Spacer()

            // Analyze button - sends to Haiku for follow-up suggestions
            Button {
                onAnalyze()
            } label: {
                Label("Analyze", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundColor(CLITheme.purple(for: colorScheme))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Analyze response")
            .accessibilityHint("Get AI-powered follow-up suggestions")

            // Copy button
            Button {
                onCopy()
                showCopied = true
                // Cancel any existing reset task and start a new one
                copyResetTask?.cancel()
                copyResetTask = Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    guard !Task.isCancelled else { return }
                    showCopied = false
                }
            } label: {
                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 14))
                    .foregroundColor(showCopied ? CLITheme.green(for: colorScheme) : CLITheme.mutedText(for: colorScheme))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showCopied ? "Copied" : "Copy message")
            .accessibilityHint("Copy response to clipboard")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .onDisappear {
            copyResetTask?.cancel()
        }
    }

    /// Format execution time for display
    private func formatTime(_ seconds: TimeInterval) -> String {
        if seconds < 1 {
            return String(format: "%.0fms", seconds * 1000)
        } else if seconds < 60 {
            return String(format: "%.1fs", seconds)
        } else {
            let minutes = Int(seconds) / 60
            let secs = Int(seconds) % 60
            return "\(minutes)m \(secs)s"
        }
    }

    /// Format token count for display
    private func formatTokens(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000)
        }
        return "\(count)"
    }
}

/// Small label with icon and text for stats display
private struct StatLabel: View {
    let icon: String
    let text: String
    let color: Color

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(settings.scaledFont(.small))
        }
        .foregroundColor(color)
    }
}

#Preview {
    VStack {
        MessageActionBar(
            message: ChatMessage(
                role: .assistant,
                content: "This is a test response",
                executionTime: 2.5,
                tokenCount: 1234
            ),
            projectPath: "/test/project",
            onCopy: { print("Copy") },
            onAnalyze: { print("Analyze") }
        )
        .environmentObject(AppSettings())

        MessageActionBar(
            message: ChatMessage(
                role: .assistant,
                content: "Short response",
                executionTime: 0.5,
                tokenCount: 89
            ),
            projectPath: "/test/project",
            onCopy: { print("Copy") },
            onAnalyze: { print("Analyze") }
        )
        .environmentObject(AppSettings())

        MessageActionBar(
            message: ChatMessage(
                role: .assistant,
                content: "Long running response",
                executionTime: 125.3,
                tokenCount: 15432
            ),
            projectPath: "/test/project",
            onCopy: { print("Copy") },
            onAnalyze: { print("Analyze") }
        )
        .environmentObject(AppSettings())
    }
    .padding()
    .background(Color.black)
}
