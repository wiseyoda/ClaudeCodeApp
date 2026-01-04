# Issue 11: Virtualized Message List

**Phase:** 2 (Core Views)
**Priority:** High
**Status:** Not Started
**Depends On:** Issue 03 (Protocol & Router)
**Target:** iOS 26.2, Xcode 26.2, Swift 6.2.1

## Goal

Implement virtualized scrolling for long conversations (100+ messages) using LazyVStack and iOS 26.2 ScrollPosition API.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue 03 (Protocol & Router).
- Add runtime or tooling dependencies here.

## Touch Set
- Files to create: TBD.
- Files to modify: TBD.

## Interface Definitions
- List new or changed models, protocols, and API payloads.

## Tests
- [ ] Unit tests updated or added.
- [ ] UI tests updated or added (if user flows change).
## Current State

- ChatView uses ScrollViewReader for scroll-to-bottom
- No virtualization - all messages rendered
- Performance degrades with long conversations

## Solution

### MessageListView

```swift
import SwiftUI

struct MessageListView: View {
    let messages: [ChatMessage]
    let statusTracker: CardStatusTracker
    @Binding var scrollPosition: ScrollPosition

    var body: some View {
        ScrollView {
            LazyVStack(spacing: MessageDesignSystem.Spacing.cardGap) {
                ForEach(messages) { message in
                    MessageCardRouter(
                        message: message,
                        statusTracker: statusTracker
                    )
                    .id(message.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition($scrollPosition)
        .scrollTargetBehavior(.viewAligned)
        .defaultScrollAnchor(.bottom)  // New messages appear at bottom
    }
}
```

### iOS 26 Scroll Enhancements

Use newer scroll APIs for better navigation and feedback:

```swift
@Observable
final class MessageScrollState {
    var position: ScrollPosition = .init(idType: String.self)
    var scrolledId: String?
    var isAtBottom = true
    var unreadCount = 0
}

// In MessageListView
ScrollView {
    LazyVStack(spacing: MessageDesignSystem.Spacing.cardGap) {
        ForEach(messages) { message in
            MessageCardRouter(message: message, statusTracker: statusTracker)
                .id(message.id)
        }
    }
    .scrollTargetLayout()
}
.scrollPosition($scrollState.position)
.scrollPosition(id: $scrollState.scrolledId)
.scrollTargetBehavior(.viewAligned)
.scrollIndicatorsFlash(trigger: scrollState.unreadCount)  // iOS 26: Flash indicators on new messages
```

### ScrollPosition Management

```swift
@Observable
final class MessageScrollState {
    var position: ScrollPosition = .init(idType: String.self)
    var scrolledId: String?
    var isAtBottom = true
    var unreadCount = 0

    func scrollToBottom() {
        position.scrollTo(edge: .bottom)
    }

    func scrollTo(messageId: String) {
        position.scrollTo(id: messageId, anchor: .center)
    }
}
```

### Auto-Scroll Behavior

```swift
// In ChatView
.onChange(of: messages.count) { oldCount, newCount in
    if scrollState.isAtBottom && newCount > oldCount {
        // New message arrived, auto-scroll
        withAnimation(MessageDesignSystem.Animation.smooth) {
            scrollState.scrollToBottom()
        }
    } else if newCount > oldCount {
        // User scrolled up, show unread indicator
        scrollState.unreadCount += (newCount - oldCount)
    }
}
```

### Unread Indicator

```swift
struct UnreadIndicator: View {
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: MessageDesignSystem.Spacing.xs) {
                Image(systemName: "chevron.down")
                Text("\(count) new")
            }
            .font(MessageDesignSystem.labelFont())
            .padding(.horizontal, MessageDesignSystem.Spacing.md)
            .padding(.vertical, MessageDesignSystem.Spacing.sm)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
        .sensoryFeedback(.selection, trigger: count)
    }
}
```

### Scroll Position Detection

```swift
// Detect if user is at bottom
.onScrollGeometryChange(for: Bool.self) { geometry in
    let atBottom = geometry.contentOffset.y >=
        geometry.contentSize.height - geometry.containerSize.height - 50
    return atBottom
} action: { wasAtBottom, isAtBottom in
    scrollState.isAtBottom = isAtBottom
    if isAtBottom {
        scrollState.unreadCount = 0
    }
}
```

## Edge Cases

- 10,000+ messages: enforce a soft cap or windowed rendering to avoid memory spikes.
- Large images: defer loading until visible; release off-screen attachments.
- Rapid stream bursts: coalesce scroll updates to avoid stutter.

## Performance Optimizations

### 1. Pre-computed Card Cache

```swift
// In MessageCardRouter init
private let cache: MessageCardCache

init(message: ChatMessage, ...) {
    self.cache = MessageCardCache(message: message, colorScheme: .light)
}
```

### 2. Equatable Conformance

```swift
extension ChatMessage: Equatable {
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.isStreaming == rhs.isStreaming
    }
}

// Prevents unnecessary re-renders
struct MessageCardRouter: View, Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.message == rhs.message
    }
}
```

### 3. ID Stability

```swift
// Use stable IDs, not array indices
ForEach(messages) { message in  // ✓ Uses message.id
ForEach(messages.indices, id: \.self)  // ✗ Causes re-renders
```

## Files to Create

```
CodingBridge/Views/Messages/
├── MessageListView.swift        # Virtualized list
└── MessageScrollState.swift     # Scroll position management

CodingBridge/Views/Components/
└── UnreadIndicator.swift        # "X new messages" pill
```

## Files to Modify

| File | Changes |
|------|---------|
| `ChatView.swift` | Use MessageListView instead of inline ScrollView |
| `MessageCardRouter.swift` | Add Equatable conformance |
| `ChatMessage.swift` | Add Equatable conformance |

## Acceptance Criteria

- [ ] LazyVStack renders only visible messages
- [ ] ScrollPosition API tracks scroll state
- [ ] Auto-scroll when at bottom + new message
- [ ] Unread indicator when scrolled up
- [ ] Tap indicator to scroll to bottom
- [ ] Scroll targets align to card edges
- [ ] Scroll indicators flash on new messages (`.scrollIndicatorsFlash`)
- [ ] Smooth 60fps scroll with 500+ messages
- [ ] Search highlighting still works
- [ ] Build passes on iOS 26.2+ (Xcode 26.2)

## Testing

```swift
class MessageListPerformanceTests: XCTestCase {
    func testScrollPerformance() {
        let messages = (0..<500).map { ChatMessage.mock(id: "\($0)") }

        measure(metrics: [XCTCPUMetric(), XCTMemoryMetric()]) {
            // Scroll through list
        }
    }
}
```
