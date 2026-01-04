# iOS 26 Navigation APIs


### navigationSubtitle

Add two-line navigation titles for additional context:

```swift
NavigationStack {
    ChatView(project: project)
        .navigationTitle(project.displayName)
        .navigationSubtitle("\(project.sessionCount) sessions")
}
```

Use for:
- Session counts in project views
- Status info (connected/offline)
- Last activity timestamps

---
