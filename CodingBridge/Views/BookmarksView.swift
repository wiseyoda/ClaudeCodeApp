import SwiftUI

struct BookmarksView: View {
    @ObservedObject var bookmarkStore = BookmarkStore.shared
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""

    private var filteredBookmarks: [BookmarkedMessage] {
        bookmarkStore.searchBookmarks(searchText)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if bookmarkStore.bookmarks.isEmpty {
                    emptyStateView
                } else {
                    bookmarksList
                }
            }
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CLITheme.secondaryBackground(for: colorScheme), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(CLITheme.blue(for: colorScheme))
                }
            }
            .searchable(text: $searchText, prompt: "Search bookmarks...")
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 48))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))

            Text("No Bookmarks")
                .font(settings.scaledFont(.large))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            Text("Star important messages to save them here")
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bookmarksList: some View {
        List {
            ForEach(filteredBookmarks) { bookmark in
                BookmarkRow(bookmark: bookmark)
                    .listRowBackground(CLITheme.background(for: colorScheme))
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            }
            .onDelete(perform: deleteBookmarks)
        }
        .listStyle(.plain)
        .background(CLITheme.background(for: colorScheme))
    }

    private func deleteBookmarks(at offsets: IndexSet) {
        for index in offsets {
            let bookmark = filteredBookmarks[index]
            bookmarkStore.removeBookmark(messageId: bookmark.messageId)
        }
    }
}

struct BookmarkRow: View {
    let bookmark: BookmarkedMessage
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    private var roleIcon: String {
        switch bookmark.role {
        case .user: return "person.fill"
        case .assistant: return "sparkle"
        case .toolUse, .toolResult, .resultSuccess: return "wrench.fill"
        case .thinking: return "brain"
        case .system, .error: return "exclamationmark.circle"
        case .localCommand, .localCommandStdout: return "terminal"
        }
    }

    private var roleColor: Color {
        switch bookmark.role {
        case .user: return CLITheme.green(for: colorScheme)
        case .assistant: return CLITheme.blue(for: colorScheme)
        case .toolUse, .toolResult, .resultSuccess: return CLITheme.cyan(for: colorScheme)
        case .thinking: return CLITheme.purple(for: colorScheme)
        case .system, .error: return CLITheme.yellow(for: colorScheme)
        case .localCommand, .localCommandStdout: return CLITheme.cyan(for: colorScheme)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with project and role
            HStack {
                Image(systemName: roleIcon)
                    .font(.system(size: 12))
                    .foregroundColor(roleColor)

                Text(bookmark.projectTitle)
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                    .lineLimit(1)

                Spacer()

                Text(bookmark.bookmarkedAt, style: .relative)
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }

            // Content preview
            Text(bookmark.content)
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))
                .lineLimit(4)

            // Original timestamp
            Text("Originally: \(bookmark.timestamp, style: .date)")
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button {
                UIPasteboard.general.string = bookmark.content
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            Button(role: .destructive) {
                BookmarkStore.shared.removeBookmark(messageId: bookmark.messageId)
            } label: {
                Label("Remove Bookmark", systemImage: "bookmark.slash")
            }
        }
    }
}
