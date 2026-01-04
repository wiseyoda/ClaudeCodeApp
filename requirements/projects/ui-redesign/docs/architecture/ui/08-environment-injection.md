# Environment Injection


### Design System

```swift
struct DesignSystemKey: EnvironmentKey {
    static let defaultValue = DesignSystem()
}

extension EnvironmentValues {
    var designSystem: DesignSystem {
        get { self[DesignSystemKey.self] }
        set { self[DesignSystemKey.self] = newValue }
    }
}

// Usage
@Environment(\.designSystem) var ds

Text("Hello")
    .font(ds.fonts.body)
    .padding(ds.spacing.md)
```

### Services

```swift
// In CodingBridgeApp
@State private var bridgeManager = CLIBridgeManager()
@State private var sshManager = SSHManager()

var body: some Scene {
    WindowGroup {
        MainNavigationView(appState: appState)
            .environment(bridgeManager)
            .environment(sshManager)
    }
}

// In views
@Environment(CLIBridgeManager.self) var bridgeManager
```

---
