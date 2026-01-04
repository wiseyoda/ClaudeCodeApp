# Issue 27: Settings Redesign

**Phase:** 4 (Settings & Configuration)
**Priority:** High
**Status:** Not Started
**Depends On:** Issue #17 (Liquid Glass)

## Goal

Redesign settings as a grouped Form in a sheet, following iOS Settings app patterns.

## Decisions

- Add a global Haptics toggle wired to HapticManager.
- Diagnostics consolidates error analytics + error insights (no Firebase logic yet).
- Connection status reflects NetworkMonitor (wifi/cellular + constrained/expensive).

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue #17 (Liquid Glass).
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
## Design

```
┌─────────────────────────────────────────────┐
│              ═══ Settings                   │
├─────────────────────────────────────────────┤
│ CONNECTION                                  │
│ ┌─────────────────────────────────────────┐ │
│ │ 🌐 Server URL                           │ │
│ │    http://localhost:3100                │ │
│ ├─────────────────────────────────────────┤ │
│ │ 📡 Connection Status                    │ │
│ │    ● Connected                          │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ CLAUDE                                      │
│ ┌─────────────────────────────────────────┐ │
│ │ 🤖 Default Model                        │ │
│ │    Sonnet                           ▶  │ │
│ ├─────────────────────────────────────────┤ │
│ │ 🧠 Thinking Mode                        │ │
│ │    Normal                           ▶  │ │
│ ├─────────────────────────────────────────┤ │
│ │ 🔓 Skip Permissions                     │ │
│ │    ○ Off                                │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ DISPLAY                                     │
│ ┌─────────────────────────────────────────┐ │
│ │ 🎨 Theme                                │ │
│ │    System                           ▶  │ │
│ ├─────────────────────────────────────────┤ │
│ │ 📝 Font Size                            │ │
│ │    Medium                           ▶  │ │
│ ├─────────────────────────────────────────┤ │
│ │ 💭 Show Thinking Blocks                 │ │
│ │    ● On                                 │ │
│ ├─────────────────────────────────────────┤ │
│ │ 📳 Haptics                              │ │
│ │    ● On                                 │ │
│ ├─────────────────────────────────────────┤ │
│ │ ✨ Status Messages                       │ │
│ │    Collection                       ▶  │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ SSH                                         │
│ ┌─────────────────────────────────────────┐ │
│ │ 🖥️ Host                                 │ │
│ │    192.168.1.100                        │ │
│ ├─────────────────────────────────────────┤ │
│ │ 🔑 Authentication                       │ │
│ │    SSH Key                          ▶  │ │
│ ├─────────────────────────────────────────┤ │
│ │ 📥 Import SSH Key                       │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ADVANCED                                    │
│ ┌─────────────────────────────────────────┐ │
│ │ 🐛 Diagnostics                      ▶  │ │
│ ├─────────────────────────────────────────┤ │
│ │ 📊 Debug Logs                       ▶  │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

## Implementation

### SettingsSheet

```swift
struct SettingsSheet: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var settings: AppSettings

    var body: some View {
        NavigationStack {
            Form {
                ConnectionSection(settings: settings)
                ClaudeSection(settings: settings)
                DisplaySection(settings: settings)
                SSHSection(settings: settings)
                AdvancedSection()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationBackground(.glass)
    }
}
```

### Connection Section

```swift
struct ConnectionSection: View {
    @Bindable var settings: AppSettings
    @Environment(CLIBridgeManager.self) var bridgeManager
    @Environment(NetworkMonitor.self) var networkMonitor

    var body: some View {
        Section {
            LabeledContent {
                TextField("URL", text: $settings.serverURL)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
            } label: {
                Label("Server URL", systemImage: "globe")
            }

            LabeledContent {
                HStack {
                    Circle()
                        .fill(bridgeManager.isConnected ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(bridgeManager.isConnected ? "Connected" : "Disconnected")
                }
            } label: {
                Label("Status", systemImage: "antenna.radiowaves.left.and.right")
            }

            LabeledContent {
                Text(networkMonitor.connectionSummary)
            } label: {
                Label("Network", systemImage: "wifi")
            }

            if !bridgeManager.isConnected {
                Button("Reconnect") {
                    Task { await bridgeManager.connect() }
                }
            }
        } header: {
            Text("Connection")
        } footer: {
            Text("Connect to your cli-bridge server")
        }
    }
}
```

### Claude Section

```swift
struct ClaudeSection: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Section {
            Picker(selection: $settings.defaultModel) {
                ForEach(ClaudeModel.allCases, id: \.self) { model in
                    Text(model.displayName).tag(model)
                }
            } label: {
                Label("Default Model", systemImage: "cpu")
            }

            Picker(selection: $settings.thinkingMode) {
                ForEach(ThinkingMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            } label: {
                Label("Thinking Mode", systemImage: "brain")
            }

            Toggle(isOn: $settings.skipPermissions) {
                Label("Skip Permissions", systemImage: "lock.open")
            }
        } header: {
            Text("Claude")
        } footer: {
            if settings.skipPermissions {
                Text("Warning: Tools will execute without approval")
                    .foregroundStyle(.orange)
            }
        }
    }
}
```

### Display Section

```swift
struct DisplaySection: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Section {
            Picker(selection: $settings.appTheme) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Text(theme.displayName).tag(theme)
                }
            } label: {
                Label("Theme", systemImage: "paintbrush")
            }

            Picker(selection: $settings.fontSize) {
                ForEach(FontSizePreset.allCases, id: \.self) { size in
                    Text(size.displayName).tag(size)
                }
            } label: {
                Label("Font Size", systemImage: "textformat.size")
            }

            Toggle(isOn: $settings.showThinkingBlocks) {
                Label("Show Thinking", systemImage: "thought.bubble")
            }

            Toggle(isOn: $settings.autoScrollEnabled) {
                Label("Auto-scroll", systemImage: "arrow.down.to.line")
            }

            Toggle(isOn: $settings.hapticsEnabled) {
                Label("Haptics", systemImage: "waveform.path")
            }

            NavigationLink {
                MessageCollectionView()
            } label: {
                Label("Status Messages", systemImage: "sparkles")
            }
        } header: {
            Text("Display")
        }
    }
}
```

### SSH Section

```swift
struct SSHSection: View {
    @Bindable var settings: AppSettings
    @State private var showKeyImport = false

    var body: some View {
        Section {
            LabeledContent {
                TextField("Host", text: $settings.sshHost)
                    .keyboardType(.asciiCapable)
            } label: {
                Label("Host", systemImage: "server.rack")
            }

            LabeledContent {
                TextField("Port", value: $settings.sshPort, format: .number)
                    .keyboardType(.numberPad)
            } label: {
                Label("Port", systemImage: "number")
            }

            LabeledContent {
                TextField("Username", text: $settings.sshUsername)
                    .textContentType(.username)
                    .autocapitalization(.none)
            } label: {
                Label("Username", systemImage: "person")
            }

            Picker(selection: $settings.sshAuthMethod) {
                Text("Password").tag(SSHAuthMethod.password)
                Text("SSH Key").tag(SSHAuthMethod.key)
            } label: {
                Label("Authentication", systemImage: "key")
            }

            if settings.sshAuthMethod == .key {
                Button {
                    showKeyImport = true
                } label: {
                    Label("Import SSH Key", systemImage: "arrow.down.doc")
                }
            }
        } header: {
            Text("SSH")
        } footer: {
            Text("SSH is used for file browsing and terminal access")
        }
        .sheet(isPresented: $showKeyImport) {
            SSHKeyImportSheet()
        }
    }
}
```

### Advanced Section

```swift
struct AdvancedSection: View {
    var body: some View {
        Section {
            NavigationLink {
                DiagnosticsView()
            } label: {
                Label("Diagnostics", systemImage: "stethoscope")
            }

            NavigationLink {
                DebugLogView()
            } label: {
                Label("Debug Logs", systemImage: "doc.text.magnifyingglass")
            }

            NavigationLink {
                AboutView()
            } label: {
                Label("About", systemImage: "info.circle")
            }
        } header: {
            Text("Advanced")
        } footer: {
            Text("Diagnostics consolidates error analytics and insights (Firebase comes later).")
        }
    }
}
```

### AppSettings Migration

```swift
@Observable
final class AppSettings {
    // Connection
    var serverURL: String = "http://localhost:3100"

    // Claude
    var defaultModel: ClaudeModel = .sonnet
    var thinkingMode: ThinkingMode = .normal
    var skipPermissions: Bool = false

    // Display
    var appTheme: AppTheme = .system
    var fontSize: FontSizePreset = .medium
    var showThinkingBlocks: Bool = true
    var autoScrollEnabled: Bool = true

    // SSH
    var sshHost: String = ""
    var sshPort: Int = 22
    var sshUsername: String = ""
    var sshAuthMethod: SSHAuthMethod = .password

    // Persistence
    private let defaults = UserDefaults.standard

    init() {
        load()
    }

    func load() {
        serverURL = defaults.string(forKey: "serverURL") ?? serverURL
        // ... load other settings
    }

    func save() {
        defaults.set(serverURL, forKey: "serverURL")
        // ... save other settings
    }
}
```

## Files to Create

```
CodingBridge/Features/Settings/
├── SettingsSheet.swift            # ~50 lines
├── ConnectionSection.swift        # ~60 lines
├── ClaudeSection.swift            # ~50 lines
├── DisplaySection.swift           # ~50 lines
├── SSHSection.swift               # ~80 lines
├── AdvancedSection.swift          # ~40 lines
└── AboutView.swift                # ~50 lines
```

## Files to Modify

| File | Changes |
|------|---------|
| `AppSettings.swift` | Migrate to @Observable, add sections |
| `QuickSettingsSheet.swift` | Update to use new AppSettings |

## Security Checklist

- [ ] Auth tokens stored in Keychain (never AppStorage)
- [ ] SSH keys imported into secure storage
- [ ] Server URL validated and not logged
- [ ] Settings migration follows Issue #10

## Acceptance Criteria

- [ ] Settings in grouped Form layout
- [ ] All sections with proper headers/footers
- [ ] Pickers for model, theme, etc.
- [ ] Toggles for boolean settings
- [ ] SSH key import works
- [ ] Settings persist across launches
- [ ] Glass effect on sheet background
- [ ] Navigation links to advanced views
- [ ] Security checklist complete
- [ ] Build passes

## Testing

```swift
struct SettingsTests: XCTestCase {
    func testSettingsPersistence() {
        let settings = AppSettings()
        settings.serverURL = "http://test:3100"
        settings.save()

        let newSettings = AppSettings()
        XCTAssertEqual(newSettings.serverURL, "http://test:3100")
    }

    func testDefaultValues() {
        let settings = AppSettings()
        XCTAssertEqual(settings.defaultModel, .sonnet)
        XCTAssertEqual(settings.fontSize, .medium)
        XCTAssertFalse(settings.skipPermissions)
    }
}
```
