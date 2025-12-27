import SwiftUI

/// Horizontal scrolling tag chips with consistent hash-based colors
struct TagsFlowView: View {
    let tags: [String]
    var onTap: ((String) -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    private let tagColors: [Color] = [
        .blue, .purple, .pink, .orange, .green, .cyan, .indigo, .mint, .teal
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    TagChip(
                        tag: tag,
                        color: colorForTag(tag),
                        onTap: onTap != nil ? { onTap?(tag) } : nil
                    )
                }
            }
        }
    }

    /// Consistent color based on tag hash for visual consistency
    func colorForTag(_ tag: String) -> Color {
        tagColors[abs(tag.hashValue) % tagColors.count]
    }
}

/// Individual tag chip with optional tap action
struct TagChip: View {
    let tag: String
    let color: Color
    var onTap: (() -> Void)?

    var body: some View {
        Group {
            if let onTap = onTap {
                Button(action: onTap) {
                    chipContent
                }
                .buttonStyle(.plain)
            } else {
                chipContent
            }
        }
    }

    private var chipContent: some View {
        Text(tag)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

/// Removable tag chip for editor views
struct RemovableTagChip: View {
    let tag: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

/// Tag filter chip for drawer filtering
struct TagFilterChip: View {
    let tag: String
    let isSelected: Bool
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                }
                Text(tag)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? color.opacity(0.3) : color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? color : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Tags Flow") {
    VStack(spacing: 20) {
        Text("Read-only tags:")
        TagsFlowView(tags: ["swift", "ios", "refactoring", "bug-fix", "feature"])

        Text("Tappable tags:")
        TagsFlowView(tags: ["swift", "ios", "refactoring"]) { tag in
            print("Tapped: \(tag)")
        }

        Text("Removable tags:")
        HStack {
            RemovableTagChip(tag: "swift", color: .blue) {}
            RemovableTagChip(tag: "ios", color: .purple) {}
        }

        Text("Filter chips:")
        HStack {
            TagFilterChip(tag: "All", isSelected: true, color: .blue) {}
            TagFilterChip(tag: "swift", isSelected: false, color: .purple) {}
            TagFilterChip(tag: "ios", isSelected: false, color: .orange) {}
        }
    }
    .padding()
}
