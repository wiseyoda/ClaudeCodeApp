import SwiftUI

/// Displays AI-generated suggestion chips that users can tap to quickly send prompts
struct SuggestionChipsView: View {
    let suggestions: [ClaudeHelper.SuggestedAction]
    let isLoading: Bool
    let onSelect: (ClaudeHelper.SuggestedAction) -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if isLoading {
            loadingView
        } else if !suggestions.isEmpty {
            chipsView
        }
    }

    private var loadingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
            Text("Thinking...")
                .font(.caption)
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var chipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions) { suggestion in
                    SuggestionChip(
                        suggestion: suggestion,
                        onTap: { onSelect(suggestion) }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}

/// Individual suggestion chip button
struct SuggestionChip: View {
    let suggestion: ClaudeHelper.SuggestedAction
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: suggestion.icon)
                    .font(.caption)
                Text(suggestion.label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(chipBackground)
            .foregroundColor(CLITheme.cyan(for: colorScheme))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(CLITheme.cyan(for: colorScheme).opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(ChipButtonStyle())
        .accessibilityLabel(suggestion.label)
        .accessibilityHint("Tap to send: \(suggestion.prompt)")
    }

    private var chipBackground: Color {
        isPressed
            ? CLITheme.cyan(for: colorScheme).opacity(0.2)
            : CLITheme.secondaryBackground(for: colorScheme)
    }
}

/// Custom button style for chips
struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Suggested Files Section

/// Shows AI-suggested files at the top of the file picker
struct SuggestedFilesSection: View {
    let files: [String]
    let isLoading: Bool
    let onSelect: (String) -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if isLoading || !files.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(CLITheme.yellow(for: colorScheme))
                    Text("Suggested")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(CLITheme.yellow(for: colorScheme))

                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                }

                if !files.isEmpty {
                    ForEach(files, id: \.self) { file in
                        SuggestedFileRow(
                            file: file,
                            onSelect: { onSelect(file) }
                        )
                    }
                }

                Divider()
                    .padding(.top, 4)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
    }
}

struct SuggestedFileRow: View {
    let file: String
    let onSelect: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: fileIcon)
                    .font(.caption)
                    .foregroundColor(CLITheme.blue(for: colorScheme))
                    .frame(width: 16)

                Text(file)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(CLITheme.primaryText(for: colorScheme))
                    .lineLimit(1)

                Spacer()

                Image(systemName: "plus.circle")
                    .font(.caption)
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(CLITheme.cyan(for: colorScheme).opacity(0.05))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private var fileIcon: String {
        let ext = (file as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "ts", "tsx", "js", "jsx": return "doc.text"
        case "json": return "curlybraces"
        case "md": return "doc.richtext"
        case "yml", "yaml": return "list.bullet"
        default: return "doc"
        }
    }
}

#Preview {
    VStack {
        SuggestionChipsView(
            suggestions: [
                ClaudeHelper.SuggestedAction(label: "Run tests", prompt: "Run the test suite", icon: "play.circle"),
                ClaudeHelper.SuggestedAction(label: "Commit", prompt: "Commit the changes", icon: "checkmark.circle"),
                ClaudeHelper.SuggestedAction(label: "Explain", prompt: "Explain more", icon: "questionmark.circle")
            ],
            isLoading: false,
            onSelect: { _ in }
        )

        SuggestedFilesSection(
            files: ["src/App.tsx", "package.json", "tests/app.test.ts"],
            isLoading: false,
            onSelect: { _ in }
        )
    }
    .background(Color.black)
}
