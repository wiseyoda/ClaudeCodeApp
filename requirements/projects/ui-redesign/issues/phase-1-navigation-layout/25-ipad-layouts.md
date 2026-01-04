# Issue 25: iPad Layouts

**Phase:** 1 (Navigation & Layout)
**Priority:** High
**Status:** Not Started
**Depends On:** Issue #23 (Navigation Architecture), Issue #24 (Sidebar)

## Goal

Core iPad layout support: NavigationSplitView with adaptive sidebars, responsive chat view layout, and pointer interactions.

## Scope
- In scope: NavigationSplitView adaptive column visibility, responsive chat view (status bar positioning), pointer hover effects, context menus with keyboard hints, popover vs sheet adaptation.
- Out of scope: Stage Manager window tracking (Phase 5, Issue TBD), external display support (Phase 5, Issue TBD), iPad-specific gesture interactions beyond standard SwiftUI.

## Non-goals
- Advanced multitasking (Stage Manager, Split View edge cases like 33% width)
- External display/window management
- Keyboard shortcut customization

## Dependencies
- Depends On: Issue #23 (Navigation Architecture), Issue #24 (Sidebar).
- Add runtime or tooling dependencies here.

## Touch Set
- Files to create: AdaptiveStack.swift, ResponsiveGrid.swift (optional, if needed), LayoutGuide.swift (helpers)
- Files to modify: MainNavigationView.swift (column visibility management), ChatView.swift (adaptive status bar positioning), SidebarView.swift (hover effects)

## Interface Definitions

### New Helpers

**LayoutGuide** - Device context detection
```swift
struct LayoutGuide {
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

    var deviceContext: DeviceContext {
        if isCompact {
            return windowSize.width < 320 ? .slideOver : .compact
        } else if isWide {
            return .wide
        } else {
            return .regular
        }
    }

    enum DeviceContext {
        case compact       // iPhone, narrow iPad
        case slideOver     // 320pt slide-over panel
        case regular       // iPad portrait
        case wide          // iPad landscape, 1000pt+
    }
}
```

### Modified Views
- **MainNavigationView**: Track column visibility state, respond to size class changes
- **ChatView**: Conditional status bar positioning (inline on regular, above input on compact)
- **SidebarView**: Add onHover hover effects for project rows

## Edge Cases

- **Device rotation**: Size class may change (compact → regular or vice versa); NavigationSplitView should smoothly transition between TabView and split layout; AppState persists selection.
- **Sidebar collapse on narrow**: When width < 500pt in split view, sidebar should collapse or become detail-only; column visibility should update automatically.
- **Popover vs Sheet transition**: When moving from iPhone to iPad (or rotating), active sheet should convert to popover; existing sheet dismisses gracefully.
- **Keyboard focus on iPad**: When hardware keyboard connected, input field auto-focuses; when disconnected, focus resets.
- **Status bar positioning conflict**: On narrow iPad (regular width but not enough room), status bar should move above input to prevent layout overflow.
- **Hover states on iPhone**: iPhone doesn't support hover; onHover effects should be no-op on compact devices.

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

**Note:** Stage Manager window tracking and external display support moved to Phase 5 (Issue TBD). See Section: "Deferred to Phase 5" below.

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

## Deferred to Phase 5

The following features are removed from Phase 1 scope and have been tracked separately:
- Stage Manager window size tracking and column visibility adaptation
- External display/second window support
- Advanced Split View edge cases (33% width, Stage Manager panel resizing)

**Status**: A new Phase 5 issue has been created to track these features. See Phase 5 roadmap.

## Files to Create

```
CodingBridge/Layout/
├── AdaptiveStack.swift            # ~40 lines
└── LayoutGuide.swift              # ~50 lines (device context detection)
```

## Files to Modify

| File | Changes |
|------|---------|
| `MainNavigationView.swift` | Column visibility state, size class change handling |
| `ChatView.swift` | Adaptive status bar positioning (inline vs above input) |
| `SidebarView.swift` | Hover effects for project rows |

## Acceptance Criteria

- [ ] NavigationSplitView column visibility adapts to size class
- [ ] Sidebar visible on iPad landscape, collapsed on portrait
- [ ] Sidebar collapses when width < 500pt
- [ ] Chat view status bar positioned inline on regular width, above input on compact
- [ ] Popovers show on iPad (regular+), sheets on iPhone (compact)
- [ ] Hover effects on project rows and interactive elements
- [ ] Context menus display keyboard shortcuts as hints
- [ ] Keyboard focus auto-set on iPad with hardware keyboard
- [ ] Device rotation transitions smoothly between TabView and NavigationSplitView
- [ ] Build passes on iOS 26.2+ (Xcode 26.2)

## Testing

### Manual Testing Matrix

| Scenario | Test | Notes |
|----------|------|-------|
| iPhone | TabView active, no sidebar | Test all four tabs |
| iPad Landscape | Sidebar visible, detail fills remaining space | Sidebar width 280-400pt |
| iPad Portrait | Sidebar may collapse depending on orientation | Column visibility: .automatic |
| iPad Rotate iPhone→iPad | TabView → NavigationSplitView transition smooth | Selection persists |
| iPad Rotate iPad→iPhone | NavigationSplitView → TabView transition smooth | Selection persists |
| Chat View - iPhone | Status bar above input | Compact layout |
| Chat View - iPad | Status bar inline with message list | Regular layout |
| Hover - iPad | Project rows highlight on hover | iPhone: no effect |
| Context Menu - iPad | Long-press shows menu with keyboard hints | Desktop trackpad supported |
| Narrow Split (>500pt width) | Sidebar visible but compressed | Min width: 280pt |

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
