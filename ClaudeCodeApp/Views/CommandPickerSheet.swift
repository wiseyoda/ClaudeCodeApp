import SwiftUI

// MARK: - Command Picker Sheet

/// A sheet for selecting saved commands to insert into chat
struct CommandPickerSheet: View {
    @ObservedObject var commandStore: CommandStore
    let onSelect: (SavedCommand) -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var settings: AppSettings
    @State private var searchText = ""

    private var filteredGroups: [(category: String, commands: [SavedCommand])] {
        if searchText.isEmpty {
            return commandStore.allCommandsGrouped
        }

        return commandStore.allCommandsGrouped.compactMap { group in
            let filtered = group.commands.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
            return filtered.isEmpty ? nil : (category: group.category, commands: filtered)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if commandStore.commands.isEmpty {
                    emptyStateView
                } else if filteredGroups.isEmpty {
                    noResultsView
                } else {
                    commandListView
                }
            }
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Saved Commands")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search commands...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 48))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))

            Text("No Saved Commands")
                .font(settings.scaledFont(.body))
                .fontWeight(.medium)
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            Text("Create commands from the home screen to quickly reuse prompts.")
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))

            Text("No commands match \"\(searchText)\"")
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var commandListView: some View {
        List {
            ForEach(filteredGroups, id: \.category) { group in
                Section {
                    ForEach(group.commands) { command in
                        CommandPickerRow(command: command) {
                            commandStore.markUsed(command)
                            onSelect(command)
                            dismiss()
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: categoryIcon(for: group.category))
                            .font(.caption)
                        Text(group.category)
                    }
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case "git": return "arrow.triangle.branch"
        case "code review": return "eye"
        case "testing": return "testtube.2"
        case "docs", "documentation": return "doc.text"
        case "refactor", "refactoring": return "arrow.triangle.2.circlepath"
        case "debug", "debugging": return "ladybug"
        default: return "folder"
        }
    }
}

// MARK: - Command Picker Row

private struct CommandPickerRow: View {
    let command: SavedCommand
    let onTap: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(command.name)
                    .font(settings.scaledFont(.body))
                    .fontWeight(.medium)
                    .foregroundColor(CLITheme.primaryText(for: colorScheme))

                Text(command.content)
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                    .lineLimit(2)

                if let lastUsed = command.lastUsedAt {
                    Text("Last used \(lastUsed.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(CLITheme.secondaryBackground(for: colorScheme))
    }
}

// MARK: - Preview

#Preview {
    CommandPickerSheet(
        commandStore: CommandStore.shared,
        onSelect: { command in
            print("Selected: \(command.name)")
        }
    )
    .environmentObject(AppSettings())
}
