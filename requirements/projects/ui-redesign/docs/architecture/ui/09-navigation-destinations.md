# Navigation Destinations


```swift
struct DetailContainerView: View {
    let project: Project?

    var body: some View {
        Group {
            if let project {
                ChatView(project: project)
            } else {
                EmptyProjectView()
            }
        }
        .navigationDestination(for: NavigationDestination.self) { destination in
            switch destination {
            case .projectDetail(let project):
                ProjectDetailView(project: project)
            case .terminal:
                TerminalView()
            case .globalSearch:
                GlobalSearchView()
            case .sessionHistory(let session):
                SessionHistoryView(session: session)
            }
        }
    }
}

enum NavigationDestination: Hashable {
    case projectDetail(Project)
    case terminal
    case globalSearch
    case sessionHistory(Session)
}
```

---
