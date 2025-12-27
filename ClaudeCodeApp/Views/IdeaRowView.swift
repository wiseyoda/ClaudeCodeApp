import SwiftUI

/// Individual idea display with inline AI expansion and swipe actions
struct IdeaRowView: View {
    let idea: Idea
    let isEnhancing: Bool
    let onSend: () -> Void
    let onEdit: () -> Void
    let onEnhance: () -> Void
    let onArchiveToggle: () -> Void
    let onDelete: () -> Void

    @State private var isExpansionExpanded = false

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

                    if isEnhancing {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if idea.expandedPrompt != nil {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(CLITheme.purple(for: colorScheme))
                    }
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

                // AI expansion (inline, collapsible)
                if let expanded = idea.expandedPrompt {
                    DisclosureGroup(
                        isExpanded: $isExpansionExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(expanded)
                                .font(.callout)
                                .foregroundStyle(CLITheme.primaryText(for: colorScheme))
                                .padding(12)
                                .background(CLITheme.purple(for: colorScheme).opacity(0.1))
                                .cornerRadius(8)

                            // Suggested follow-ups
                            if let followups = idea.suggestedFollowups, !followups.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Related ideas:")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(CLITheme.secondaryText(for: colorScheme))

                                    ForEach(followups, id: \.self) { followup in
                                        HStack(alignment: .top, spacing: 6) {
                                            Image(systemName: "arrow.turn.down.right")
                                                .font(.caption2)
                                                .foregroundStyle(CLITheme.mutedText(for: colorScheme))
                                            Text(followup)
                                                .font(.caption)
                                                .foregroundStyle(CLITheme.secondaryText(for: colorScheme))
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption)
                            Text("AI Expansion")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(CLITheme.purple(for: colorScheme))
                    }
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

                // Enhance button
                Button {
                    onEnhance()
                } label: {
                    HStack(spacing: 4) {
                        if isEnhancing {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text("Enhance")
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(CLITheme.purple(for: colorScheme).opacity(0.15))
                    .foregroundStyle(CLITheme.purple(for: colorScheme))
                    .cornerRadius(12)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(isEnhancing)

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
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                onEnhance()
            } label: {
                Label("Enhance", systemImage: "sparkles")
            }
            .tint(.purple)
            .disabled(isEnhancing)
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                onEnhance()
            } label: {
                Label("Enhance with AI", systemImage: "sparkles")
            }
            .disabled(isEnhancing)

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
            isEnhancing: false,
            onSend: {},
            onEdit: {},
            onEnhance: {},
            onArchiveToggle: {},
            onDelete: {}
        )

        IdeaRowView(
            idea: Idea(
                text: "This is a longer idea that spans multiple lines.\nIt has some additional context here.\nAnd even more details.",
                tags: ["refactoring"]
            ),
            isEnhancing: false,
            onSend: {},
            onEdit: {},
            onEnhance: {},
            onArchiveToggle: {},
            onDelete: {}
        )

        IdeaRowView(
            idea: Idea(
                text: "Simple idea without title or tags"
            ),
            isEnhancing: true,
            onSend: {},
            onEdit: {},
            onEnhance: {},
            onArchiveToggle: {},
            onDelete: {}
        )

        IdeaRowView(
            idea: Idea(
                text: "An enhanced idea",
                title: "Dark Mode",
                tags: ["ui"],
                expandedPrompt: "Implement a comprehensive dark mode feature for the application. This should include:\n\n1. A toggle in settings to switch between light, dark, and system modes\n2. Theme-aware colors for all UI components\n3. Smooth transitions when switching themes",
                suggestedFollowups: [
                    "Add theme persistence across app restarts",
                    "Consider adding custom accent color options",
                    "Test accessibility contrast ratios"
                ]
            ),
            isEnhancing: false,
            onSend: {},
            onEdit: {},
            onEnhance: {},
            onArchiveToggle: {},
            onDelete: {}
        )
    }
}
