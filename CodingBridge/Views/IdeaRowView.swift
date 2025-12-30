import SwiftUI

/// Individual idea display with swipe actions
struct IdeaRowView: View {
    let idea: Idea
    let onSend: () -> Void
    let onEdit: () -> Void
    let onArchiveToggle: () -> Void
    let onDelete: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private let tagColors: [Color] = [
        .blue, .purple, .pink, .orange, .green, .cyan, .indigo, .mint, .teal
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tappable content area (tap to edit)
            VStack(alignment: .leading, spacing: 8) {
                // Title or first line of text
                HStack {
                    Text(idea.title ?? firstLine)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()
                }

                // Text preview (if has title, show the text)
                if idea.title != nil {
                    Text(idea.text)
                        .font(.subheadline)
                        .foregroundStyle(CLITheme.secondaryText(for: colorScheme))
                        .lineLimit(2)
                } else if idea.text.contains("\n") {
                    // If no title but multiline, show remaining lines
                    Text(remainingLines)
                        .font(.subheadline)
                        .foregroundStyle(CLITheme.secondaryText(for: colorScheme))
                        .lineLimit(2)
                }

                // Tags
                if !idea.tags.isEmpty {
                    TagsFlowView(tags: idea.tags)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onEdit()
            }

            // Action buttons row (separate from tap gesture)
            HStack(spacing: 12) {
                // Timestamp
                Text(idea.updatedAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(CLITheme.mutedText(for: colorScheme))

                Spacer()

                // Send button
                Button {
                    onSend()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("Send")
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(CLITheme.blue(for: colorScheme).opacity(0.15))
                    .foregroundStyle(CLITheme.blue(for: colorScheme))
                    .cornerRadius(12)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                onArchiveToggle()
            } label: {
                if idea.isArchived {
                    Label("Restore", systemImage: "arrow.uturn.backward")
                } else {
                    Label("Archive", systemImage: "archivebox")
                }
            }
            .tint(.orange)

            Button {
                onSend()
            } label: {
                Label("Send", systemImage: "arrow.up.circle")
            }
            .tint(.blue)
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                onSend()
            } label: {
                Label("Send to Chat", systemImage: "arrow.up.circle")
            }

            Divider()

            Button {
                onArchiveToggle()
            } label: {
                if idea.isArchived {
                    Label("Restore", systemImage: "arrow.uturn.backward")
                } else {
                    Label("Archive", systemImage: "archivebox")
                }
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Helpers

    private var firstLine: String {
        let lines = idea.text.components(separatedBy: .newlines)
        return String(lines.first?.prefix(50) ?? "")
    }

    private var remainingLines: String {
        let lines = idea.text.components(separatedBy: .newlines)
        guard lines.count > 1 else { return "" }
        return lines.dropFirst().joined(separator: "\n")
    }
}

// MARK: - Preview

#Preview("Idea Rows") {
    List {
        IdeaRowView(
            idea: Idea(
                text: "Add a scratch pad feature for capturing ideas during long-running commands",
                title: "Ideas Drawer",
                tags: ["feature", "ux"]
            ),
            onSend: {},
            onEdit: {},
            onArchiveToggle: {},
            onDelete: {}
        )

        IdeaRowView(
            idea: Idea(
                text: "This is a longer idea that spans multiple lines.\nIt has some additional context here.\nAnd even more details.",
                tags: ["refactoring"]
            ),
            onSend: {},
            onEdit: {},
            onArchiveToggle: {},
            onDelete: {}
        )

        IdeaRowView(
            idea: Idea(
                text: "Simple idea without title or tags"
            ),
            onSend: {},
            onEdit: {},
            onArchiveToggle: {},
            onDelete: {}
        )
    }
}
