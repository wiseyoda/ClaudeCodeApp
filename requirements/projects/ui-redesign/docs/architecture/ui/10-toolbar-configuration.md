# Toolbar Configuration


### Sidebar Toolbar

```swift
struct SidebarView: View {
    var body: some View {
        List { /* ... */ }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("New Project", action: newProject)
                    Button("Clone from GitHub", action: cloneProject)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}
```

### Chat Toolbar

```swift
struct ChatView: View {
    var body: some View {
        VStack { /* ... */ }
        .toolbar {
            ToolbarItem(placement: .principal) {
                ProjectTitleView(project: project)
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Sessions", action: showSessions)
                    Button("Search", action: showSearch)
                    Divider()
                    Button("Export", action: export)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }

            ToolbarItem(placement: .secondaryAction) {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                }
            }
        }
    }
}
```

---
