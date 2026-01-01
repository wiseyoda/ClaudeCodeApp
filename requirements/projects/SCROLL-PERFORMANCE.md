# Scroll Performance Optimization Plan

> Created: 2025-12-31
> Status: In Progress
> Branch: `feature/list-scroll-performance`

## Problem

ChatView with 200 messages enabled exhibits jerky scrolling after load.

## Root Causes Identified

### 1. VStack Instead of LazyVStack (Critical)
**Location:** `ChatView.swift:451`

```swift
VStack(alignment: .leading, spacing: 2) {
    ForEach(viewModel.groupedDisplayItems) { item in
        DisplayItemView(...)
    }
}
```

**Impact:** All 200 messages are rendered upfront, not lazily. Each message includes expensive MarkdownText parsing.

### 2. @ObservedObject on Shared Store (High)
**Location:** `CLIMessageView.swift:13`

```swift
@ObservedObject private var bookmarkStore = BookmarkStore.shared
```

**Impact:** Every CLIMessageView instance observes BookmarkStore. Any bookmark change triggers 200 view re-renders.

### 3. GeometryReader in Scroll Background (Medium)
**Location:** `ChatView.swift:354-363`

```swift
.background(
    GeometryReader { geo in
        Color.clear
            .preference(key: BottomVisiblePreferenceKey.self, ...)
    }
)
```

**Impact:** Fires preference changes on every scroll frame.

### 4. DragGesture State Updates During Scroll (Medium)
**Location:** `ChatView.swift:381-388`

```swift
.simultaneousGesture(
    DragGesture(minimumDistance: 20)
        .onChanged { _ in
            isInputFocused = false
            viewModel.showScrollToBottom = true  // State change every drag
        }
)
```

**Impact:** Updates state on every drag event during scroll.

## Solution: Use List with Cell Recycling

### Why List Over LazyVStack?

Per research (fatbobman, Hacking with Swift, WWDC 2025):

| Metric | List | LazyVStack |
|--------|------|------------|
| Cell Recycling | Yes (UICollectionView) | No (views stay in memory) |
| Memory (200 items) | ~129 MB | ~149 MB |
| Scroll Hangs | 4.6 | 78 |
| iOS 26 Edge Effects | Automatic | Manual |

### iOS 26 Enhancements

- **@IncrementalState**: Fine-grained state updates (future enhancement)
- **Rebuilt rendering pipeline**: Biggest SwiftUI perf improvements ever
- **Scroll edge effects**: Automatic Liquid Glass blur at edges

## Implementation Plan

### Phase 1: Switch to List

Replace `messagesListView` VStack with List:

```swift
private var messagesListView: some View {
    List {
        // Loading indicator
        if viewModel.isLoadingHistory && viewModel.messages.isEmpty {
            loadingHistoryView
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }

        ForEach(viewModel.groupedDisplayItems) { item in
            DisplayItemView(
                item: item,
                projectPath: project.path,
                projectTitle: project.title,
                hideTodoInline: viewModel.showTodoDrawer
            )
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
            .listRowBackground(Color.clear)
            .environment(\.retryAction, viewModel.retryMessage)
        }

        if viewModel.isProcessing {
            streamingIndicatorView
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }

        // Bottom anchor
        Spacer()
            .frame(height: 1)
            .id("bottomAnchor")
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .background(CLITheme.background(for: colorScheme))
}
```

### Phase 2: Remove BookmarkStore Observer

Change CLIMessageView to check bookmark status on-demand:

```swift
// Before (every message observes store)
@ObservedObject private var bookmarkStore = BookmarkStore.shared

// After (check on demand, no observation)
private var isBookmarked: Bool {
    BookmarkStore.shared.isBookmarked(messageId: message.id)
}
```

### Phase 3: Throttle Scroll State Updates

Replace continuous state updates with threshold-based updates.

## Files to Modify

| File | Changes |
|------|---------|
| `ChatView.swift` | Replace VStack with List in `messagesListView` |
| `CLIMessageView.swift` | Remove @ObservedObject, use direct access |

## Testing

1. Load ChatView with 200 messages
2. Scroll rapidly up and down
3. Verify smooth 60fps scrolling (120fps on ProMotion)
4. Verify auto-scroll still works on new messages
5. Verify bookmarking still functions
6. Verify context menus work

## Rollback

If issues occur, revert to `main` branch. The feature branch preserves the implementation for debugging.

## References

- [List vs LazyVStack (fatbobman)](https://fatbobman.com/en/posts/list-or-lazyvstack/)
- [SwiftUI Scroll Performance (Jacob's Tech Tavern)](https://blog.jacobstechtavern.com/p/swiftui-scroll-performance-the-120fps)
- [What's New in SwiftUI iOS 26 (Hacking with Swift)](https://www.hackingwithswift.com/articles/278/whats-new-in-swiftui-for-ios-26)
- [@IncrementalState WWDC 2025](https://medium.com/@shubhamsanghavi100/incrementalstate-in-swiftui-unlocking-performance-in-ios-26-wwdc-2025-deep-dive-c36abe54f5bd)
