# Dependency Injection Map


```
CodingBridgeApp
├── @State appState: AppState
├── @State bridgeManager: CLIBridgeManager
├── @State sshManager: SSHManager
├── @State appSettings: AppSettings
├── Environment: DesignSystem (custom EnvironmentKey)
└── MainNavigationView(appState)
    ├── @Environment(CLIBridgeManager.self) in views
    ├── @Environment(SSHManager.self) in views
    ├── @Environment(AppSettings.self) in views
    └── ChatView
        ├── @State viewModel: ChatViewModel
        ├── @State interactionHandler: StreamInteractionHandler
        └── @Environment(CLIBridgeManager.self) for send/stream
```

Notes:
- Use `@Environment(AppSettings.self)` for app-wide settings.
- Use `@Environment(DesignSystem.self)` for design tokens.
- Use `@State` for view-owned @Observable models.

---
