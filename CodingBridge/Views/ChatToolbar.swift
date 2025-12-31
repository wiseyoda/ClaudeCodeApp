import SwiftUI

// MARK: - Chat Title View

/// Principal toolbar content showing project name and git status indicator
struct ChatTitleView: View {
    let displayName: String
    let gitStatus: GitStatus
    let onRefreshGitStatus: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            Text(displayName)
                .font(.headline)
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            Button {
                onRefreshGitStatus()
            } label: {
                GitStatusIndicator(status: gitStatus)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Git status")
            .accessibilityHint("Tap to refresh git status")
            .accessibilityValue(gitStatus.accessibilityLabel)
        }
    }
}

// MARK: - Chat Toolbar Actions

/// Trailing toolbar actions: search, ideas, and menu
struct ChatToolbarActions: View {
    let isSearching: Bool
    let ideasCount: Int
    let isProcessing: Bool
    let onToggleSearch: () -> Void
    let onShowIdeas: () -> Void
    let onQuickCapture: () -> Void
    let onNewChat: () -> Void
    let onShowBookmarks: () -> Void
    let onAbort: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            searchButton
            ideasButton
            moreOptionsMenu
        }
    }

    // MARK: - Search Button

    private var searchButton: some View {
        Button {
            onToggleSearch()
        } label: {
            Image(systemName: isSearching ? "magnifyingglass.circle.fill" : "magnifyingglass")
                .foregroundColor(isSearching ? CLITheme.blue(for: colorScheme) : CLITheme.secondaryText(for: colorScheme))
        }
        .accessibilityLabel(isSearching ? "Close search" : "Search messages")
    }

    // MARK: - Ideas Button

    private var ideasButton: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "lightbulb")
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))

            if ideasCount > 0 {
                Text(ideasCount > 99 ? "99+" : "\(ideasCount)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(CLITheme.red(for: colorScheme))
                    .clipShape(Capsule())
                    .offset(x: 8, y: -8)
            }
        }
        .onTapGesture {
            onShowIdeas()
        }
        .onLongPressGesture(minimumDuration: 0.4) {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            onQuickCapture()
        }
        .accessibilityLabel("Ideas")
        .accessibilityHint("Tap to open ideas drawer, hold to quick capture")
        .accessibilityValue(ideasCount > 0 ? "\(ideasCount) ideas" : "No ideas")
    }

    // MARK: - More Options Menu

    private var moreOptionsMenu: some View {
        Menu {
            Button {
                onNewChat()
            } label: {
                Label("New Chat", systemImage: "plus")
            }

            Button {
                onShowBookmarks()
            } label: {
                Label("Bookmarks", systemImage: "bookmark")
            }

            if isProcessing {
                Button(role: .destructive) {
                    onAbort()
                } label: {
                    Label("Abort", systemImage: "stop.circle")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
        }
        .accessibilityLabel("Chat options")
        .accessibilityHint("Open menu with new chat, bookmarks, and abort options")
    }
}

// MARK: - Preview

#Preview("Title View") {
    NavigationStack {
        Text("Content")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ChatTitleView(
                        displayName: "My Project",
                        gitStatus: .clean,
                        onRefreshGitStatus: {}
                    )
                }
            }
    }
}

#Preview("Toolbar Actions") {
    NavigationStack {
        Text("Content")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ChatToolbarActions(
                        isSearching: false,
                        ideasCount: 5,
                        isProcessing: false,
                        onToggleSearch: {},
                        onShowIdeas: {},
                        onQuickCapture: {},
                        onNewChat: {},
                        onShowBookmarks: {},
                        onAbort: {}
                    )
                }
            }
    }
}
