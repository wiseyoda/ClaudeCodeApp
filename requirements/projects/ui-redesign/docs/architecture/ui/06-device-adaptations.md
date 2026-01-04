# Device Adaptations


### iPhone (Compact Width)

```
┌─────────────────────┐
│ ← Projects          │  ← Navigation bar
├─────────────────────┤
│ □ project-1         │
│ □ project-2         │
│ □ project-3    ───────→ Tap pushes to ChatView
│ □ project-4         │
├─────────────────────┤
│ [+] New Project     │
│ ⚙️ Settings          │
└─────────────────────┘
```

- Sidebar is the initial view
- Tapping a project pushes to ChatView
- Back button returns to project list
- Sheets present from bottom

### iPad Landscape

```
┌─────────────┬───────────────────────────────────────────┐
│  Projects   │                 ChatView                   │
├─────────────┤  ┌─────────────────────────────────────┐  │
│ □ proj-1    │  │         MessageListView             │  │
│ ■ proj-2 ◀──│──│                                     │  │
│ □ proj-3    │  │         (messages here)             │  │
│             │  │                                     │  │
│─────────────│  └─────────────────────────────────────┘  │
│ [+] New     │  ┌─────────────────────────────────────┐  │
│ ⚙️ Settings  │  │            InputView                │  │
│ 🖥️ Terminal  │  └─────────────────────────────────────┘  │
└─────────────┴───────────────────────────────────────────┘
```

- Persistent sidebar (320pt)
- Detail shows selected project's ChatView
- Popovers for pickers instead of sheets

### iPad Portrait

- Sidebar hidden by default
- Swipe from left edge to reveal
- Toggle button in toolbar

### Stage Manager

```swift
var body: some View {
    NavigationSplitView { /* ... */ }
    .onGeometryChange(for: CGSize.self) { proxy in
        proxy.size
    } action: { size in
        // Adapt layout based on window size
        if size.width < 500 {
            columnVisibility = .detailOnly
        } else {
            columnVisibility = .all
        }
    }
}
```

## Layout Summary

| Device | Layout |
|--------|--------|
| iPhone | Compact: List → Detail push navigation |
| iPad Portrait | Sidebar collapsed, swipe to reveal |
| iPad Landscape | Persistent sidebar + detail |
| iPad Split View | Adaptive column widths |
| iPad Slide Over | Compact mode |
| Stage Manager | Resizable windows, multiple instances |

---
