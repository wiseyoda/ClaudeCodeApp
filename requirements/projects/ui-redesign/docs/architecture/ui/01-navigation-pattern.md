# Navigation Pattern


### NavigationSplitView (Root)

The app uses `NavigationSplitView` as the root navigation container, providing:
- **iPad**: Persistent sidebar with detail area
- **iPhone**: Automatic adaptation to push navigation
- **Stage Manager**: Resizable window support

```swift
@MainActor @Observable
final class AppState {
    var selectedProject: Project?
    var navigationPath = NavigationPath()
    var columnVisibility: NavigationSplitViewVisibility = .automatic
}

struct MainNavigationView: View {
    @Bindable var appState: AppState

    var body: some View {
        NavigationSplitView(columnVisibility: $appState.columnVisibility) {
            SidebarView(selection: $appState.selectedProject)
        } detail: {
            NavigationStack(path: $appState.navigationPath) {
                DetailContainerView(project: appState.selectedProject)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
```

### Column Configuration

| Context | Sidebar Width | Detail Width |
|---------|---------------|--------------|
| iPad Landscape | 320pt | Remaining |
| iPad Portrait | Collapsible | Full |
| iPhone | Hidden | Full |
| Split View 50% | 280pt | Remaining |
| Split View 33% | Hidden | Full |

---
