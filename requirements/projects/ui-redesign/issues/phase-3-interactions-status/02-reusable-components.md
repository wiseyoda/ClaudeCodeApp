---
number: 02
title: Reusable Components
phase: phase-3-interactions-status
status: pending
completed_by: null
completed_at: null
verified_by: null
verified_at: null
commit: null
spot_checked: false
blocked_reason: null
---

# Issue 02: Reusable Components

**Phase:** 3 (Interactions & Status)
**Priority:** High
**Status:** Not Started
**Depends On:** Issue 01 (Design Tokens)

## Goal

Create reusable UI components that all card views will share.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue 01 (Design Tokens).
- Add runtime or tooling dependencies here.

## Touch Set
- Files to create: TBD.
- Files to modify: TBD.

## Interface Definitions
- List new or changed models, protocols, and API payloads.

## Edge Cases
- TBD.

## Tests
- [ ] Unit tests updated or added.
- [ ] UI tests updated or added (if user flows change).
## Files to Create

```
CodingBridge/Views/Components/
├── ExpandChevron.swift          # Animated collapse indicator
├── StatusBadge.swift            # Semantic status pills
├── MessageTimestamp.swift       # Relative/compact time display
├── QuickActionButton.swift      # Action with visual feedback
├── MessageActions.swift         # MessageActionBar (copy/share/bookmark)
└── CollapsibleSection.swift     # Animated disclosure
└── SkeletonView.swift           # Loading placeholders
```

## Implementation

### ExpandChevron.swift

```swift
import SwiftUI

/// Animated chevron that rotates based on expanded state
struct ExpandChevron: View {
    let isExpanded: Bool
    var size: CGFloat = 12

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
            .animation(MessageDesignSystem.Animation.quick, value: isExpanded)
    }
}
```

### StatusBadge.swift

```swift
import SwiftUI

/// Semantic status pill with icon and label
struct StatusBadge: View {
    enum Status {
        case success
        case error
        case warning
        case info
        case pending

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            case .pending: return "clock.fill"
            }
        }

        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            case .warning: return .orange
            case .info: return .blue
            case .pending: return .secondary
            }
        }
    }

    let status: Status
    let label: String?

    init(_ status: Status, label: String? = nil) {
        self.status = status
        self.label = label
    }

    var body: some View {
        HStack(spacing: MessageDesignSystem.Spacing.xs) {
            Image(systemName: status.icon)
            if let label {
                Text(label)
            }
        }
        .font(MessageDesignSystem.labelFont())
        .foregroundStyle(status.color)
        .padding(.horizontal, MessageDesignSystem.Spacing.sm)
        .padding(.vertical, MessageDesignSystem.Spacing.xxs)
        .background(status.color.opacity(0.1))
        .clipShape(Capsule())
    }
}
```

### MessageTimestamp.swift

```swift
import SwiftUI

/// Displays timestamp in relative or compact format
struct MessageTimestamp: View {
    let date: Date
    var style: Style = .relative

    enum Style {
        case relative   // "2 min ago"
        case compact    // "10:30 AM"
        case full       // "Jan 3, 10:30 AM"
    }

    var body: some View {
        Text(formattedDate)
            .font(MessageDesignSystem.labelFont())
            .foregroundStyle(.secondary)
    }

    private var formattedDate: String {
        switch style {
        case .relative:
            return date.timeAgo()
        case .compact:
            return date.formatted(date: .omitted, time: .shortened)
        case .full:
            return date.formatted(date: .abbreviated, time: .shortened)
        }
    }
}

private extension Date {
    func timeAgo() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
```

### QuickActionButton.swift

```swift
import SwiftUI

/// Action button with haptic feedback and visual response
struct QuickActionButton: View {
    let icon: String
    let label: String?
    let action: () -> Void

    @State private var isPressed = false

    init(_ icon: String, label: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.action = action
    }

    var body: some View {
        Button {
            HapticManager.shared.impact(.light)
            action()
        } label: {
            HStack(spacing: MessageDesignSystem.Spacing.xs) {
                Image(systemName: icon)
                if let label {
                    Text(label)
                }
            }
            .font(MessageDesignSystem.labelFont())
            .foregroundStyle(.secondary)
            .padding(MessageDesignSystem.Spacing.sm)
            .background(.quaternary.opacity(isPressed ? 0.8 : 0))
            .clipShape(RoundedRectangle(cornerRadius: MessageDesignSystem.CornerRadius.sm))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}
```

Note: HapticManager should respect the global Haptics toggle in Settings.

### MessageActions.swift

```swift
import SwiftUI

/// Action bar with copy/share/bookmark buttons
struct MessageActions: View {
    let onCopy: () -> Void
    let onShare: (() -> Void)?
    let onBookmark: (() -> Void)?
    let isBookmarked: Bool

    init(
        onCopy: @escaping () -> Void,
        onShare: (() -> Void)? = nil,
        onBookmark: (() -> Void)? = nil,
        isBookmarked: Bool = false
    ) {
        self.onCopy = onCopy
        self.onShare = onShare
        self.onBookmark = onBookmark
        self.isBookmarked = isBookmarked
    }

    var body: some View {
        HStack(spacing: MessageDesignSystem.Spacing.md) {
            QuickActionButton("doc.on.doc", action: onCopy)

            if let onShare {
                QuickActionButton("square.and.arrow.up", action: onShare)
            }

            if let onBookmark {
                QuickActionButton(
                    isBookmarked ? "bookmark.fill" : "bookmark",
                    action: onBookmark
                )
            }

            Spacer()
        }
    }
}
```

### CollapsibleSection.swift

```swift
import SwiftUI

/// Animated collapsible container
struct CollapsibleSection<Header: View, Content: View>: View {
    @Binding var isExpanded: Bool
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(MessageDesignSystem.Animation.gentle) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    ExpandChevron(isExpanded: isExpanded)
                    header()
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .padding(.top, MessageDesignSystem.Spacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
```

## Acceptance Criteria

- [ ] All 6 component files created
- [ ] Components use MessageDesignSystem tokens
- [ ] Components have SwiftUI previews
- [ ] Files linked in project.pbxproj
- [ ] Build passes

## Testing

```swift
class ComponentTests: XCTestCase {
    func testStatusBadgeColors() {
        XCTAssertEqual(StatusBadge.Status.success.color, .green)
        XCTAssertEqual(StatusBadge.Status.error.color, .red)
    }
}
```

## Previews

Each component should have a preview showing all variants:

```swift
#Preview("StatusBadge") {
    VStack(spacing: 12) {
        StatusBadge(.success, label: "Done")
        StatusBadge(.error, label: "Failed")
        StatusBadge(.warning)
        StatusBadge(.info, label: "Note")
        StatusBadge(.pending, label: "Running")
    }
    .padding()
}
```

## Code Examples

TBD. Add concrete Swift examples before implementation.

## Test Examples

TBD. Add XCTest examples before implementation.
