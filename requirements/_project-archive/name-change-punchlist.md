# Name Change Punchlist: ClaudeCode → CodingBridge

> Comprehensive audit of all references requiring evaluation after renaming from "ClaudeCode" to "CodingBridge"

## Summary

The app has been partially renamed. The display name and bundle identifier are updated, but many internal references remain.

### Already Changed
- Display name: `Coding Bridge` (in project.pbxproj)
- Bundle identifier: `com.level.CodingBridgeApp` → should be `com.level.CodingBridge`
- Main app struct: `CodingBridgeApp` (in ClaudeCodeAppApp.swift line 16)

### Naming Conventions (iOS Best Practices)

Following Apple's Xcode template conventions:

| Item | Convention | Value |
|------|------------|-------|
| **Module/Target Name** | No "App" suffix | `CodingBridge` |
| **Main Struct** | "App" suffix | `CodingBridgeApp` |
| **Entry File** | Matches main struct | `CodingBridgeApp.swift` |
| **Source Directory** | Matches module | `CodingBridge/` |
| **Test Target** | Module + "Tests" | `CodingBridgeTests` |
| **Test Directory** | Matches test target | `CodingBridgeTests/` |
| **Xcode Project** | Matches module | `CodingBridge.xcodeproj` |
| **Bundle ID (App)** | No "App" suffix | `com.level.CodingBridge` |
| **Bundle ID (Tests)** | Target + "Tests" | `com.level.CodingBridgeTests` |
| **Internal Identifiers** | Lowercase, simple | `com.codingbridge.*` |

### Files That Reference Claude AI (Keep As-Is)

These refer to the Claude AI service, not the app name:
- `ClaudeHelper.swift` / `ClaudeHelperTests.swift` - Helper for Claude AI
- `ClaudeModel` enum - Claude AI model types
- `ClaudeMode` enum - Claude AI operation modes

---

## 1. Directory & File Renames (Filesystem)

| Current | Target | Priority |
|---------|--------|----------|
| `ClaudeCodeApp/` | `CodingBridge/` | High |
| `ClaudeCodeAppTests/` | `CodingBridgeTests/` | High |
| `ClaudeCodeApp.xcodeproj/` | `CodingBridge.xcodeproj/` | High |
| `ClaudeCodeApp/ClaudeCodeAppApp.swift` | `CodingBridge/CodingBridgeApp.swift` | High |
| `ClaudeCodeAppTests/ClaudeCodeAppTests.swift` | `CodingBridgeTests/CodingBridgeTests.swift` | High |
| `ClaudeCodeApp/ClaudeHelper.swift` | `CodingBridge/ClaudeHelper.swift` | None (keep) |
| `ClaudeCodeAppTests/ClaudeHelperTests.swift` | `CodingBridgeTests/ClaudeHelperTests.swift` | None (keep name) |
| `ClaudeCodeAppTests/ClaudeHelperSessionIdTests.swift` | `CodingBridgeTests/ClaudeHelperSessionIdTests.swift` | None (keep name) |

**Note**: Xcode scheme file at `ClaudeCodeApp.xcodeproj/xcshareddata/xcschemes/ClaudeCodeApp.xcscheme` → `CodingBridge.xcodeproj/xcshareddata/xcschemes/CodingBridge.xcscheme`

---

## 2. Xcode Project Configuration

### project.pbxproj Changes

| Line | Current | Target |
|------|---------|--------|
| 18 | `ClaudeCodeAppApp.swift in Sources` | `CodingBridgeApp.swift in Sources` |
| 79 | `remoteInfo = ClaudeCodeApp` | `remoteInfo = CodingBridge` |
| 94 | `path = ClaudeCodeAppApp.swift` | `path = CodingBridgeApp.swift` |
| 149 | `path = ClaudeCodeAppTests` | `path = CodingBridgeTests` |
| 174-175 | `ClaudeCodeApp`, `ClaudeCodeAppTests` groups | `CodingBridge`, `CodingBridgeTests` |
| 181 | `ClaudeCodeApp` group | `CodingBridge` |
| 212 | `path = ClaudeCodeApp` | `path = CodingBridge` |
| 297-302 | `ClaudeCodeAppTests` references | `CodingBridgeTests` |
| 322 | `productName = ClaudeCodeApp` | `productName = CodingBridge` |
| 345 | `PBXProject "ClaudeCodeApp"` | `PBXProject "CodingBridge"` |
| 401 | `ClaudeCodeAppApp.swift in Sources` | `CodingBridgeApp.swift in Sources` |
| 479, 500 | `PRODUCT_BUNDLE_IDENTIFIER = patrickpatterson.ClaudeCodeAppTests` | `com.level.CodingBridgeTests` |
| 662, 697 | `PRODUCT_BUNDLE_IDENTIFIER = com.level.CodingBridgeApp` | `com.level.CodingBridge` |
| 717 | `Build configuration list for PBXProject "ClaudeCodeApp"` | `PBXProject "CodingBridge"` |

### Scheme File

| Current | Target |
|---------|--------|
| `ClaudeCodeApp.xcscheme` | `CodingBridge.xcscheme` |
| All `container:ClaudeCodeApp.xcodeproj` refs | `container:CodingBridge.xcodeproj` |

### buildServer.json

| Line | Current | Target |
|------|---------|--------|
| 15 | `ClaudeCodeApp.xcodeproj/project.xcworkspace` | `CodingBridge.xcodeproj/project.xcworkspace` |
| 16 | `DerivedData/ClaudeCodeApp-*` | Auto-regenerates |
| 17 | `scheme: "ClaudeCodeApp"` | `scheme: "CodingBridge"` |

---

## 3. Swift Code Changes

### DispatchQueue Labels

These are internal identifiers, safe to change:

| File | Line | Current | Target |
|------|------|---------|--------|
| `WebSocketManager.swift` | 59 | `"com.claudecodeapp.websocket.parsing"` | `"com.codingbridge.websocket.parsing"` |
| `Models.swift` | 638 | `"com.claudecodeapp.messagestore"` | `"com.codingbridge.messagestore"` |
| `Models.swift` | 999 | `"com.claudecodeapp.bookmarkstore"` | `"com.codingbridge.bookmarkstore"` |
| `IdeasStore.swift` | 94 | `"com.claudecodeapp.ideasstore"` | `"com.codingbridge.ideasstore"` |
| `ProjectCache.swift` | 19 | `"com.claudecodeapp.projectcache"` | `"com.codingbridge.projectcache"` |
| `ProjectSettingsStore.swift` | 28 | `"com.claudecodeapp.projectsettingsstore"` | `"com.codingbridge.projectsettingsstore"` |
| `CommandStore.swift` | 44 | `"com.claudecodeapp.commandstore"` | `"com.codingbridge.commandstore"` |

### Keychain Service Identifier (Migration Required)

| File | Line | Current | Target | Notes |
|------|------|---------|--------|-------|
| `SSHManager.swift` | 34 | `"com.claudecodeapp.sshkeys"` | `"com.codingbridge.sshkeys"` | **Requires migration code** |

**Keychain Migration Strategy:**
```swift
// Add to SSHManager.init() or a migration function
private func migrateKeychainIfNeeded() {
    let oldService = "com.claudecodeapp.sshkeys"
    let newService = "com.codingbridge.sshkeys"

    // Check if old keychain items exist
    // Copy to new service identifier
    // Delete old items after successful copy
}
```

### Struct/Class Names

| File | Line | Current | Target |
|------|------|---------|--------|
| `CodingBridgeTests.swift` | 2-3 | Comments: `ClaudeCodeAppTests` | `CodingBridgeTests` |
| `CodingBridgeTests.swift` | 10 | `struct ClaudeCodeAppTests` | `struct CodingBridgeTests` |

### Classes to Keep (Reference Claude AI)

| File | Class/Enum | Reason |
|------|------------|--------|
| `ClaudeHelper.swift` | `class ClaudeHelper` | Helper for Claude AI service |
| `Models.swift` | `enum ClaudeModel` | Claude AI model types (opus, sonnet, etc.) |
| `AppSettings.swift` | `enum ClaudeMode` | Claude AI operation modes |

---

## 4. UI Strings (User-Visible)

### Info.plist Usage Descriptions

| Key | Current | Target |
|-----|---------|--------|
| `NSMicrophoneUsageDescription` | "Claude Code needs microphone access to transcribe your voice messages." | "Coding Bridge needs microphone access to transcribe your voice messages." |
| `NSSpeechRecognitionUsageDescription` | "Claude Code uses speech recognition to convert your voice to text." | "Coding Bridge uses speech recognition to convert your voice to text." |
| `NSPhotoLibraryUsageDescription` | "Claude Code needs photo library access to attach images to messages." | "Coding Bridge needs photo library access to attach images to messages." |

### Navigation Titles & UI Text

| File | Line | Current | Target |
|------|------|---------|--------|
| `ContentView.swift` | 51 | `.navigationTitle("Claude Code")` | `.navigationTitle("Coding Bridge")` |
| `ContentView.swift` | 508 | `"Open a project in Claude Code to see it here"` | `"Open a project to see it here"` |
| `WebSocketManager.swift` | 1023 | `title: "Claude Code"` (notification) | `title: "Coding Bridge"` |

### Strings to Keep (Reference Claude AI, Not App)

| File | Line | String | Reason |
|------|------|--------|--------|
| `UserQuestionsView.swift` | 47 | `"Claude is asking..."` | Claude AI is asking |
| `CLIStatusBarViews.swift` | 349, 351 | `"Claude is..."` | Claude AI status |
| `CLIMessageView.swift` | 656 | `"Claude response"` | Claude AI response |
| `CLIMessageView.swift` | 748 | `"Claude is thinking"` | Claude AI thinking |
| `ChatView.swift` | 904 | `"Analyze this Claude Code response"` | Refers to Claude Code CLI tool |
| `ChatView.swift` | 2033, 2037 | `"Claude Commands"` | Claude AI commands |
| `ContentView.swift` | 1334 | Settings section `"Claude"` | Claude AI settings |
| `QuickSettingsSheet.swift` | 49, 110 | `"Claude"`, `"wait for Claude"` | Claude AI |
| Various | - | `claudeMode.displayName` | Claude AI mode enum |

---

## 5. Documentation Updates

### High Priority (Referenced by Developers)

| File | Changes Needed |
|------|----------------|
| `CLAUDE.md` | `ClaudeCodeApp.xcodeproj` → `CodingBridge.xcodeproj`, scheme name, test paths |
| `README.md` | Title "Claude Code iOS App" → "Coding Bridge", commands, description |
| `AGENTS.md` | All `ClaudeCodeApp/` paths → `CodingBridge/`, commands |
| `ROADMAP.md` | Title, test commands |
| `TEST-COVERAGE.md` | All `ClaudeCodeAppTests/` paths → `CodingBridgeTests/`, commands |

### Medium Priority

| File | Changes Needed |
|------|----------------|
| `FUTURE-IDEAS.md` | `ClaudeCodeApp` references → `CodingBridge` |
| `CHANGELOG.md` | Already has rebranding note, verify title |
| `requirements/ARCHITECTURE.md` | Diagram labels, commands |
| `requirements/SESSIONS.md` | Keep example paths (external `.claude/projects/` paths) |
| `requirements/BACKEND.md` | Review for app name references |

### Low Priority (Historical)

| File | Action |
|------|--------|
| `SESSION-ANALYSIS.md` | Optional - historical analysis document |
| `session-qa.md` | Optional - historical investigation |
| `ISSUES.md` | Review |

### Agent Configuration

| File | Changes Needed |
|------|----------------|
| `.claude/agents/ios-test-coverage.md` | `ClaudeCodeApp` → `CodingBridge`, `ClaudeCodeAppTests` → `CodingBridgeTests` |
| `.claude/agents/session-log-analyzer.md` | `ClaudeCodeApp` references |

---

## 6. References to Keep (External Systems)

These reference the external `claudecodeui` backend and should NOT be changed:

| Pattern | Locations | Reason |
|---------|-----------|--------|
| `claudecodeui` | CLAUDE.md, README.md, backend refs | External project name |
| `github.com/siteboon/claudecodeui` | Documentation | External URL |
| `"claudecodeui backend"` | Comments, docs | External system name |
| `Claude CLI` | Documentation | External tool name |
| `~/.claude/projects/` | SSH paths | External file system paths |

---

## 7. Test File Updates

### File Content Changes

| File (after rename) | Changes Needed |
|---------------------|----------------|
| `CodingBridgeTests.swift` | Rename struct to `CodingBridgeTests`, update file comments |
| `ClaudeHelperTests.swift` | Keep name (tests Claude AI helper), update example paths if needed |

### Test Import Statements

All test files need `@testable import` updated:

```swift
// Current (in all test files)
@testable import ClaudeCodeApp

// After rename
@testable import CodingBridge
```

**Files requiring import update:**
- All 39 test files in `CodingBridgeTests/`

---

## 8. Execution Order

### Phase 1: Xcode Project Rename (Use Xcode)

1. **Commit current state** - ensure clean git status
2. **Open in Xcode** - `open ClaudeCodeApp.xcodeproj`
3. **Rename project** - Click project in navigator → rename to `CodingBridge`
4. **Rename targets** - Click each target → rename `ClaudeCodeApp` → `CodingBridge`, `ClaudeCodeAppTests` → `CodingBridgeTests`
5. **Rename scheme** - Product → Scheme → Manage Schemes → rename to `CodingBridge`
6. **Update bundle IDs** - Build Settings → `com.level.CodingBridge`, `com.level.CodingBridgeTests`
7. **Build to verify** - ⌘B

### Phase 2: File Renames (Filesystem)

```bash
# Rename directories (do this from project root)
mv ClaudeCodeApp CodingBridge
mv ClaudeCodeAppTests CodingBridgeTests
mv ClaudeCodeApp.xcodeproj CodingBridge.xcodeproj

# Rename files
mv CodingBridge/ClaudeCodeAppApp.swift CodingBridge/CodingBridgeApp.swift
mv CodingBridgeTests/ClaudeCodeAppTests.swift CodingBridgeTests/CodingBridgeTests.swift
```

### Phase 3: Code Changes

1. **Update test imports** - Find/replace `@testable import ClaudeCodeApp` → `@testable import CodingBridge`
2. **Update struct name** - In `CodingBridgeTests.swift`: `struct ClaudeCodeAppTests` → `struct CodingBridgeTests`
3. **Update DispatchQueue labels** - All `com.claudecodeapp.*` → `com.codingbridge.*`
4. **Add keychain migration** - Implement migration in SSHManager
5. **Update UI strings** - Info.plist, ContentView, WebSocketManager

### Phase 4: Documentation

1. **Update CLAUDE.md** - All commands and paths
2. **Update README.md** - Title and description
3. **Update other docs** - AGENTS.md, ROADMAP.md, TEST-COVERAGE.md

### Phase 5: Verify

```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/ClaudeCodeApp-*
rm -rf ~/Library/Developer/Xcode/DerivedData/CodingBridge-*

# Build
xcodebuild -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'

# Run tests
xcodebuild test -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'
```

---

## 9. Migration Considerations

### Keychain Migration (Required)

The SSHManager uses `"com.claudecodeapp.sshkeys"` as the keychain service identifier. Changing this will orphan existing saved SSH keys.

**Recommended: Add migration code**

```swift
// SSHManager.swift - add to init or create migration function
private static let oldKeychainService = "com.claudecodeapp.sshkeys"
private static let newKeychainService = "com.codingbridge.sshkeys"

private func migrateKeychainIfNeeded() {
    // Check if already migrated
    guard UserDefaults.standard.bool(forKey: "keychainMigrated") == false else { return }

    // Migrate all keys from old service to new service
    let keysToMigrate = ["privateKey", "authPassword", "authToken", "apiKey"]

    for key in keysToMigrate {
        if let data = loadFromKeychain(service: Self.oldKeychainService, account: key) {
            saveToKeychain(data, service: Self.newKeychainService, account: key)
            deleteFromKeychain(service: Self.oldKeychainService, account: key)
        }
    }

    UserDefaults.standard.set(true, forKey: "keychainMigrated")
}
```

### UserDefaults Keys

Most `@AppStorage` keys are generic and won't need changing:
- `sshHost`, `sshPort`, `sshUsername` - OK
- `debugLoggingEnabled`, `lockToPortrait` - OK
- `appTheme`, `fontSize` - OK

**No migration needed** for UserDefaults.

### Documents Directory

Persisted files in Documents directory use path-based names, not app-branded names:
- `bookmarks.json`, `commands.json` - OK
- `ideas-{path}.json`, `{encoded-path}.json` - OK

**No migration needed** for Documents files.

---

## 10. Summary

### Files to Rename

| Type | Count |
|------|-------|
| Directories | 3 (`ClaudeCodeApp/`, `ClaudeCodeAppTests/`, `ClaudeCodeApp.xcodeproj/`) |
| Swift files | 2 (`ClaudeCodeAppApp.swift`, `ClaudeCodeAppTests.swift`) |
| Scheme file | 1 |

### Code Changes

| Type | Count |
|------|-------|
| DispatchQueue labels | 7 |
| Keychain identifier | 1 (+ migration code) |
| Struct rename | 1 |
| Test imports | 39 files |
| UI strings | 3 |
| Info.plist strings | 3 |

### Documentation

| Priority | Count |
|----------|-------|
| High | 5 files |
| Medium | 5 files |
| Low/Optional | 3 files |
| Agent configs | 2 files |

### Checklist

- [ ] Phase 1: Xcode project rename
- [ ] Phase 2: Filesystem renames
- [ ] Phase 3: Code changes (imports, labels, keychain migration)
- [ ] Phase 4: UI strings
- [ ] Phase 5: Documentation
- [ ] Phase 6: Build and test
- [ ] Phase 7: Commit and verify
