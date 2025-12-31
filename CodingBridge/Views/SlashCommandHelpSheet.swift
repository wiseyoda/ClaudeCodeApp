import SwiftUI

// MARK: - Slash Command Help Sheet

struct SlashCommandHelpSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Keyboard Shortcuts section
                    Text("Keyboard Shortcuts")
                        .font(.headline)
                        .foregroundColor(CLITheme.primaryText(for: colorScheme))

                    VStack(alignment: .leading, spacing: 12) {
                        KeyboardShortcutRow(shortcut: "⌘ Return", description: "Send message")
                        KeyboardShortcutRow(shortcut: "⌘ K", description: "Clear conversation")
                        KeyboardShortcutRow(shortcut: "⌘ N", description: "New session")
                        KeyboardShortcutRow(shortcut: "⌘ .", description: "Abort current request")
                        KeyboardShortcutRow(shortcut: "⌘ /", description: "Show this help")
                        KeyboardShortcutRow(shortcut: "⌘ R", description: "Resume session picker")
                    }

                    Divider()
                        .padding(.vertical, 8)

                    // Slash Commands section
                    Text("Slash Commands")
                        .font(.headline)
                        .foregroundColor(CLITheme.primaryText(for: colorScheme))

                    VStack(alignment: .leading, spacing: 12) {
                        SlashCommandRow(command: "/clear", description: "Clear conversation and start fresh")
                        SlashCommandRow(command: "/new", description: "Start a new session")
                        SlashCommandRow(command: "/init", description: "Create/modify CLAUDE.md (via Claude)")
                        SlashCommandRow(command: "/resume [id]", description: "Resume session (picker or by ID)")
                        SlashCommandRow(command: "/model [name]", description: "Switch model (opus/sonnet/haiku)")
                        SlashCommandRow(command: "/compact", description: "Compact conversation to save context")
                        SlashCommandRow(command: "/status", description: "Show connection and session info")
                        SlashCommandRow(command: "/exit", description: "Close chat and return to projects")
                        SlashCommandRow(command: "/help", description: "Show this help")
                    }

                    Divider()
                        .padding(.vertical, 8)

                    Text("Claude Commands")
                        .font(.headline)
                        .foregroundColor(CLITheme.primaryText(for: colorScheme))

                    Text("Other slash commands (like /review, /commit) are passed directly to Claude for handling.")
                        .font(.subheadline)
                        .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                }
                .padding()
            }
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .keyboardShortcut(.escape)
                }
            }
        }
    }
}

// MARK: - Keyboard Shortcut Row

struct KeyboardShortcutRow: View {
    let shortcut: String
    let description: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(CLITheme.yellow(for: colorScheme))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(CLITheme.secondaryBackground(for: colorScheme))
                .cornerRadius(6)

            Text(description)
                .font(.subheadline)
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Slash Command Row

private struct SlashCommandRow: View {
    let command: String
    let description: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(command)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(CLITheme.cyan(for: colorScheme))
                .frame(width: 100, alignment: .leading)

            Text(description)
                .font(.subheadline)
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
