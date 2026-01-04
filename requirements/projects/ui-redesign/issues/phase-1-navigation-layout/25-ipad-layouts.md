# Issue 25: iPad Layouts

**Phase:** 1 (Navigation & Layout)
**Priority:** High
**Status:** Not Started
**Depends On:** Issue #23 (Navigation Architecture), Issue #24 (Sidebar)

## Goal

Full iPad multitasking support: Split View, Slide Over, Stage Manager, and adaptive layouts.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue #23 (Navigation Architecture), Issue #24 (Sidebar).
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
## Device Contexts

| Context | Width | Layout |
|---------|-------|--------|
| iPhone | < 400pt | Compact, push navigation |
| iPad Portrait | 768pt | Sidebar collapsed |
| iPad Landscape | 1024pt+ | Sidebar + detail |
| Split View 50% | 507pt | Sidebar collapsed or visible |
| Split View 33% | 320pt | Compact mode |
| Slide Over | 320pt | Compact mode |
| Stage Manager | Variable | Adaptive |

## Implementation

### Adaptive NavigationSplitView

```swift
struct MainNavigationView: View {
    @Bindable var appState: AppState
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        NavigationSplitView(columnVisibility: $appState.columnVisibility) {
            SidebarView(selection: $appState.selectedProject, onShowSheet: showSheet)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        } detail: {
            NavigationStack(path: $appState.navigationPath) {
                DetailContainerView(project: appState.selectedProject, onShowSheet: showSheet)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: horizontalSizeClass) { _, newClass in
            if newClass == .compact {
                appState.columnVisibility = .detailOnly
            }
        }
    }
}
```

### Window Size Tracking

```swift
struct WindowSizeReader: ViewModifier {
    @Binding var size: CGSize

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newSize in
                size = newSize
            }
    }
}

extension View {
    func trackWindowSize(_ size: Binding<CGSize>) -> some View {
        modifier(WindowSizeReader(size: size))
    }
}
```

### Adaptive Layout Helper

```swift
struct AdaptiveLayout: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var windowSize: CGSize = .zero

    var isCompact: Bool {
        horizontalSizeClass == .compact || windowSize.width < 500
    }

    var isRegular: Bool {
        horizontalSizeClass == .regular && windowSize.width >= 500
    }

    var isWide: Bool {
        windowSize.width >= 1000
    }
}
```

### Chat View Adaptations

```swift
struct ChatView: View {
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        VStack(spacing: 0) {
            if sizeClass == .regular {
                // Wide layout: status bar inline
                HStack {
                    StatusBarView()
                    Spacer()
                }
                .padding(.horizontal)
            }

            MessageListView(messages: messages)

            if sizeClass == .compact {
                // Compact: status bar above input
                StatusBarView()
                    .padding(.horizontal)
            }

            InputView(text: $inputText, onSend: sendMessage)
        }
    }
}
```

### Popover vs Sheet

```swift
struct ChatView: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @State private var showSessionPicker = false

    var body: some View {
        VStack { /* ... */ }
        .toolbar {
            ToolbarItem {
                Button("Sessions") {
                    showSessionPicker = true
                }
                .if(sizeClass == .regular) { view in
                    view.popover(isPresented: $showSessionPicker) {
                        SessionPickerSheet(project: project)
                            .frame(minWidth: 400, minHeight: 500)
                    }
                }
                .if(sizeClass == .compact) { view in
                    view.sheet(isPresented: $showSessionPicker) {
                        SessionPickerSheet(project: project)
                    }
                }
            }
        }
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
```

### Keyboard Focus on iPad

```swift
struct ChatView: View {
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack {
            MessageListView()
                .onTapGesture {
                    isInputFocused = false
                }

            InputView()
                .focused($isInputFocused)
        }
        .onAppear {
            // Auto-focus on iPad with hardware keyboard
            if UIDevice.current.userInterfaceIdiom == .pad {
                isInputFocused = true
            }
        }
    }
}
```

### Stage Manager Window

```swift
struct MainNavigationView: View {
    @State private var windowSize: CGSize = .zero

    var body: some View {
        NavigationSplitView(columnVisibility: $appState.columnVisibility) {
            SidebarView(...)
        } detail: {
            DetailContainerView(...)
        }
        .trackWindowSize($windowSize)
        .onChange(of: windowSize) { _, newSize in
            // Adapt to window size changes (Stage Manager)
            if newSize.width < 500 {
                appState.columnVisibility = .detailOnly
            } else if newSize.width < 800 {
                appState.columnVisibility = .automatic
            } else {
                appState.columnVisibility = .all
            }
        }
    }
}
```

### External Display Support

```swift
@main
struct CodingBridgeApp: App {
    var body: some Scene {
        WindowGroup {
            MainNavigationView(appState: AppState())
        }
        .handlesExternalEvents(matching: ["*"])
    }
}
```

Guidelines:
- Allow a second window on external display (independent navigation state).
- Keep sidebar/detail adaptive to window size.

### Pointer Interactions

```swift
struct ProjectRowView: View {
    @State private var isHovered = false

    var body: some View {
        HStack { /* ... */ }
        .background(isHovered ? Color.primary.opacity(0.05) : .clear)
        .onHover { hovering in
            isHovered = hovering
        }
        .hoverEffect(.highlight)
    }
}
```

### Context Menus

```swift
.contextMenu {
    Button { /* ... */ } label: {
        Label("Copy", systemImage: "doc.on.doc")
    }
    .keyboardShortcut("c", modifiers: .command)

    Button { /* ... */ } label: {
        Label("Delete", systemImage: "trash")
    }
    .keyboardShortcut(.delete, modifiers: [])
}
```

## Files to Create

```
CodingBridge/Layout/
├── AdaptiveStack.swift            # ~40 lines
├── ResponsiveGrid.swift           # ~50 lines
└── WindowSizeReader.swift         # ~30 lines
```

## Files to Modify

| File | Changes |
|------|---------|
| `MainNavigationView.swift` | Window size tracking, column visibility |
| `ChatView.swift` | Adaptive status bar, popover vs sheet |
| `SidebarView.swift` | Hover effects |

## Acceptance Criteria

- [ ] Split View works at all widths
- [ ] Slide Over works in compact mode
- [ ] Stage Manager window resizing works
- [ ] External display supports a second window
- [ ] Sidebar auto-hides when narrow
- [ ] Popovers on iPad, sheets on iPhone
- [ ] Hover effects on interactive elements
- [ ] Keyboard shortcuts work
- [ ] Context menus have keyboard hints
- [ ] Build passes

## Testing

### Manual Testing Matrix

| Scenario | Test |
|----------|------|
| iPad Landscape | Sidebar visible, detail fills remaining space |
| iPad Portrait | Sidebar collapsed, swipe to reveal |
| Split View 50% | Both apps visible, sidebar may collapse |
| Split View 33% | Compact mode, sidebar hidden |
| Slide Over | Compact mode |
| Stage Manager small | Compact mode |
| Stage Manager large | Full layout |
| Rotate device | Layout adapts smoothly |

```swift
struct LayoutTests: XCTestCase {
    func testWindowSizeTracking() {
        var trackedSize: CGSize = .zero

        let view = Text("Test")
            .trackWindowSize(.constant(.init(width: 1000, height: 800)))

        // Verify size is tracked
        XCTAssertEqual(trackedSize.width, 1000)
    }
}
```
