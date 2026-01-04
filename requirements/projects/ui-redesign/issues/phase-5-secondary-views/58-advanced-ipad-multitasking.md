# Issue 58: Advanced iPad Multitasking

**Phase:** 5 (Secondary Views)
**Priority:** Medium
**Status:** Not Started
**Depends On:** Issue #25 (iPad Layouts), Issue #23 (Navigation Architecture)
**Deferred From:** Phase 1 (Issue #25) - Scope refinement

## Goal

Implement advanced iPad multitasking support: Stage Manager window management, external display support, and Split View edge cases for flexible app layouts.

## Scope

- In scope: Stage Manager window size tracking, external display/second window support, dynamic column visibility for 33% width Split View, pointer drag interactions, window restoration.
- Out of scope: iPadOS 17 specific features, keyboard-only navigation optimization (Phase 7), gesture-based split view manipulation (Phase 7).

## Non-goals

- Replace existing navigation architecture (Issue #23)
- Add new view types or feature screens
- Support older iOS versions (iOS 26+ only)

## Dependencies

- Depends On: Issue #25 (iPad Layouts core), Issue #23 (Navigation Architecture with AppState)
- Runtime: iOS 26.2+, SwiftUI 6.2.1+
- Tooling: Xcode 26.2+

## Reference Docs

- Required: [UI Architecture - Adaptive Layouts](../../docs/architecture/ui/adaptive-layouts.md)
- Required: [Design System - iPad Multitasking](../../docs/design/ios26-multitasking.md)
- Optional: Apple's [Multitasking Guide](https://developer.apple.com/documentation/swiftui/multiwindow_and_split_view)

## Touch Set

- Files to create:
  - `WindowSizeManager.swift` - Stage Manager window tracking (~80 lines)
  - `ExternalWindowCoordinator.swift` - External display state management (~60 lines)
  - `SplitViewResizeHandler.swift` - Dynamic column adjustment for edge widths (~50 lines)

- Files to modify:
  - `MainNavigationView.swift` - Add window size and visibility handling
  - `AppState.swift` - Add window management state (windowSize, isExternal, columnMode)
  - `CodingBridgeApp.swift` - Add WindowGroup + external event handling

## Interface Definitions

### New Models

**WindowState** - Track window and multitasking context
```swift
@MainActor @Observable
final class WindowState {
    var size: CGSize = .zero
    var safeAreaInsets: EdgeInsets = .zero
    var isExternalDisplay: Bool = false
    var isDocked: Bool = false  // Stage Manager docking state

    var columnMode: ColumnMode {
        if size.width < 320 {
            return .detailOnly  // Slide Over
        } else if size.width < 500 {
            return .detailOnly  // Narrow Split View
        } else if size.width < 800 {
            return .automatic   // Regular Split View (50%)
        } else {
            return .all         // Wide Split View, iPad landscape
        }
    }

    enum ColumnMode {
        case detailOnly
        case automatic
        case all
    }
}
```

**ExternalDisplayWindow** - Manage secondary window state
```swift
@MainActor @Observable
final class ExternalDisplayWindow {
    var selectedProject: Project?
    var navigationPath = NavigationPath()
    var isActive: Bool = false

    func updateFromMain(_ appState: AppState) {
        // Sync selection but keep independent navigation
        self.selectedProject = appState.selectedProject
    }
}
```

### Modified Models

**AppState** - Extended for window management
```swift
// Add to existing AppState:
@MainActor @Observable
final class AppState {
    // ... existing properties ...
    var windowState: WindowState?
    var externalWindow: ExternalDisplayWindow?
}
```

## Edge Cases

- **Stage Manager window resizes**: Column visibility should adapt dynamically; no visual glitches during resize.
- **App backgrounded with external display**: External window state should persist; reconnect when app returns.
- **External display disconnected**: External window should close gracefully; main app unaffected.
- **Split View at 33% width**: App should show compact sidebar (or hide it); status bar should reposition.
- **Slide Over (320pt)**: Same as iPhone compact mode; sidebar always hidden.
- **Orientation change in external window**: Layout should adapt smoothly; selection persists.
- **Multiple windows on same display**: Pointer location should determine active window; focus management required.

## Acceptance Criteria

- [ ] Stage Manager window size changes trigger column visibility updates
- [ ] External display shows second independent window with navigation state
- [ ] 33% Split View shows compact or hidden sidebar gracefully
- [ ] Slide Over behaves identically to iPhone compact mode
- [ ] Window resize animations are smooth (no layout thrashing)
- [ ] External window state persists across app backgrounding
- [ ] External display disconnection closes window without crashing
- [ ] Pointer interactions work across multiple windows
- [ ] Build passes on iOS 26.2+ (Xcode 26.2)

## Tests

- [ ] Unit tests for WindowState column mode logic
- [ ] Unit tests for ExternalDisplayWindow state sync
- [ ] UI tests for Stage Manager resize scenarios
- [ ] Integration test for external window lifecycle
- [ ] Manual testing on iPad with Stage Manager enabled

## Implementation

### Stage Manager Window Tracking

```swift
struct MainNavigationView: View {
    @Bindable var appState: AppState
    @State private var windowState = WindowState()

    var body: some View {
        NavigationSplitView(columnVisibility: $windowState.columnMode) {
            SidebarView(selection: $appState.selectedProject)
        } detail: {
            DetailContainerView(project: appState.selectedProject)
        }
        .trackWindowSize($windowState.size)
        .onChange(of: windowState.size) { _, newSize in
            // AppState updates through windowState binding
            appState.windowState = windowState
        }
        .onGeometryChange(for: EdgeInsets.self) { proxy in
            proxy.safeAreaInsets
        } action: { insets in
            windowState.safeAreaInsets = insets
        }
    }
}
```

### External Display Window

```swift
@main
struct CodingBridgeApp: App {
    @State private var appState = AppState()
    @State private var externalWindow: ExternalDisplayWindow?

    var body: some Scene {
        WindowGroup {
            MainNavigationView(appState: appState)
                .environment(appState)
        }

        WindowGroup("External Display", id: "external") {
            if let externalWindow {
                NavigationStack(path: $externalWindow.navigationPath) {
                    if let project = externalWindow.selectedProject {
                        ChatView(project: project)
                    } else {
                        EmptyProjectView()
                    }
                }
                .environment(appState)
            }
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "external-window"))
        .onChange(of: appState.selectedProject) { _, newProject in
            // Sync to external window if open
            externalWindow?.updateFromMain(appState)
        }
    }
}
```

### Dynamic Column Visibility Helper

```swift
extension NavigationSplitViewVisibility {
    static func adaptive(for width: CGFloat) -> NavigationSplitViewVisibility {
        switch width {
        case ..<320:        return .detailOnly  // Slide Over
        case 320..<500:     return .detailOnly  // Narrow Split
        case 500..<800:     return .automatic   // Regular Split
        default:            return .all         // Wide/landscape
        }
    }
}
```

### ResizeListener Modifier

```swift
struct WindowSizeModifier: ViewModifier {
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
        modifier(WindowSizeModifier(size: size))
    }
}
```

## Notes

- This issue was deferred from Phase 1 (Issue #25) to keep Phase 1 scope focused on core navigation and layout.
- Stage Manager support requires testing on iPad with Stage Manager enabled (iOS 26.2+).
- External display testing requires a second display connected via USB-C or wireless.
- Window state synchronization should be lightweight; avoid syncing entire AppState to external window.

## Related Issues

- Issue #25 (iPad Layouts) - Core split view and adaptive layouts
- Issue #23 (Navigation Architecture) - Root navigation and AppState
- Phase 7: Advanced gestures and interactions (future enhancement)
