import SwiftUI

// MARK: - Message Filter Options

enum MessageFilter: String, CaseIterable {
    case all = "All"
    case user = "User"
    case assistant = "Assistant"
    case tools = "Tools"
    case thinking = "Thinking"

    var icon: String {
        switch self {
        case .all: return "line.3.horizontal.decrease.circle"
        case .user: return "person.fill"
        case .assistant: return "sparkle"
        case .tools: return "wrench.fill"
        case .thinking: return "brain"
        }
    }

    func matches(_ role: ChatMessage.Role) -> Bool {
        switch self {
        case .all: return true
        case .user: return role == .user
        case .assistant: return role == .assistant
        case .tools: return role == .toolUse || role == .toolResult || role == .resultSuccess
        case .thinking: return role == .thinking
        }
    }
}

// MARK: - Search Bar

struct ChatSearchBar: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool
    @Binding var selectedFilter: MessageFilter
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // Search field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                        .font(.system(size: 14))

                    TextField("Search messages...", text: $searchText)
                        .font(settings.scaledFont(.body))
                        .foregroundColor(CLITheme.primaryText(for: colorScheme))
                        .autocorrectionDisabled()

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(CLITheme.mutedText(for: colorScheme))
                                .font(.system(size: 14))
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(CLITheme.background(for: colorScheme))
                .cornerRadius(8)

                // Cancel button
                Button("Cancel") {
                    searchText = ""
                    isSearching = false
                    selectedFilter = .all
                }
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.blue(for: colorScheme))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(CLITheme.secondaryBackground(for: colorScheme))

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MessageFilter.allCases, id: \.self) { filter in
                        FilterChip(
                            filter: filter,
                            isSelected: selectedFilter == filter
                        ) {
                            selectedFilter = filter
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .background(CLITheme.secondaryBackground(for: colorScheme))

            Divider()
                .background(CLITheme.mutedText(for: colorScheme))
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let filter: MessageFilter
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: filter.icon)
                    .font(.system(size: 10))
                Text(filter.rawValue)
                    .font(settings.scaledFont(.small))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(isSelected ? CLITheme.blue(for: colorScheme) : CLITheme.background(for: colorScheme))
            .foregroundColor(isSelected ? .white : CLITheme.secondaryText(for: colorScheme))
            .cornerRadius(12)
        }
    }
}

// MARK: - Search Result Count

struct SearchResultCount: View {
    let count: Int
    let searchText: String
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if !searchText.isEmpty {
            HStack {
                Text("\(count) result\(count == 1 ? "" : "s") for \"\(searchText)\"")
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(CLITheme.secondaryBackground(for: colorScheme))
        }
    }
}

// MARK: - Search Highlight Extension

extension String {
    /// Returns ranges of all occurrences of the search text (case-insensitive)
    func searchRanges(of searchText: String) -> [Range<String.Index>] {
        guard !searchText.isEmpty else { return [] }
        var ranges: [Range<String.Index>] = []
        var searchStartIndex = self.startIndex

        while searchStartIndex < self.endIndex,
              let range = self.range(of: searchText, options: .caseInsensitive, range: searchStartIndex..<self.endIndex) {
            ranges.append(range)
            searchStartIndex = range.upperBound
        }

        return ranges
    }
}

// MARK: - Highlighted Text View

struct HighlightedText: View {
    let text: String
    let searchText: String
    let baseFont: Font
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if searchText.isEmpty {
            Text(text)
                .font(baseFont)
        } else {
            highlightedContent
        }
    }

    private var highlightedContent: some View {
        let ranges = text.searchRanges(of: searchText)

        if ranges.isEmpty {
            return AnyView(Text(text).font(baseFont))
        }

        var segments: [(String, Bool)] = []
        var currentIndex = text.startIndex

        for range in ranges {
            // Add text before the match
            if currentIndex < range.lowerBound {
                segments.append((String(text[currentIndex..<range.lowerBound]), false))
            }
            // Add the match
            segments.append((String(text[range]), true))
            currentIndex = range.upperBound
        }

        // Add remaining text
        if currentIndex < text.endIndex {
            segments.append((String(text[currentIndex..<text.endIndex]), false))
        }

        // iOS 26+: Text '+' operator deprecated, use attributed string instead
        var attributedString = AttributedString()
        for segment in segments {
            var part = AttributedString(segment.0)
            part.font = baseFont
            if segment.1 {
                // Highlighted segment
                part.inlinePresentationIntent = .stronglyEmphasized
                part.foregroundColor = CLITheme.yellow(for: colorScheme)
            }
            attributedString.append(part)
        }
        return AnyView(Text(attributedString))
    }
}
