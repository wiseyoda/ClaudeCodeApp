# CLAUDE.md

iOS client for [claudecodeui](https://github.com/siteboon/claudecodeui). SwiftUI app targeting iOS 17+ with Citadel SSH library.

## Commands

```bash
# Build
xcodebuild -project ClaudeCodeApp.xcodeproj -scheme ClaudeCodeApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Test
xcodebuild test -project ClaudeCodeApp.xcodeproj -scheme ClaudeCodeApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Open in Xcode
open ClaudeCodeApp.xcodeproj
```

## Key Files

| File | Purpose |
|------|---------|
| `WebSocketManager.swift` | All backend communication, streaming, reconnection |
| `SSHManager.swift` | SSH terminal, file ops, git commands via Citadel |
| `ChatView.swift` | Main chat UI, message handling, slash commands |
| `Models.swift` | All data models, enums, persistence stores |
| `AppSettings.swift` | @AppStorage configuration |
| `IdeasStore.swift` | Per-project idea capture |

## Rules

**IMPORTANT - Thread Safety:**
- MUST add `@MainActor` to any new `ObservableObject` class
- MUST use `Task { @MainActor in }` for UI updates from async contexts
- NEVER update `@Published` properties from background threads

**IMPORTANT - Security:**
- MUST escape all file paths passed to `SSHManager.executeCommand()` using proper shell quoting
- NEVER store secrets in `@AppStorage` (use Keychain via `KeychainHelper`)
- NEVER commit credentials or API keys

**Code Patterns:**
- Use `@StateObject` for manager ownership in views (WebSocketManager, SSHManager, IdeasStore)
- Use `@EnvironmentObject` for AppSettings (injected at app root)
- Use singletons for shared stores: `CommandStore.shared`, `BookmarkStore.shared`
- Persist to Documents directory using `FileManager.default.urls(for: .documentDirectory)`

## Patterns

```swift
// Correct: View owns the manager
struct ChatView: View {
    @StateObject private var wsManager = WebSocketManager()
}

// Correct: Shared settings from environment
struct SomeView: View {
    @EnvironmentObject var settings: AppSettings
}

// Correct: MainActor for ObservableObject
@MainActor
class APIClient: ObservableObject {
    @Published var projects: [Project] = []
}

// Correct: Escape paths for SSH
let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
let command = "cat '\(escaped)'"
```

## Architecture

```
App → WebSocketManager → claudecodeui backend → Claude CLI
App → SSHManager → sshd (file ops, git, session history)
```

- **Views/**: 26 UI components (sheets, pickers, message views)
- **Utilities/**: Logger, AppError, ImageUtilities
- **Extensions/**: String+Markdown

See `requirements/ARCHITECTURE.md` for full structure and data flows.

## Persistence

| Store | Location | Purpose |
|-------|----------|---------|
| MessageStore | `Documents/{encoded-path}.json` | Chat history (50 msgs) |
| BookmarkStore | `Documents/bookmarks.json` | Saved messages |
| CommandStore | `Documents/commands.json` | Saved prompts |
| IdeasStore | `Documents/ideas-{path}.json` | Per-project ideas |
| SessionNamesStore | UserDefaults | Custom session names |

## Backend

Connects to claudecodeui via WebSocket (`ws://host:port/ws?token=JWT`). Auth via POST `/api/auth/login`.

Session files: `~/.claude/projects/{encoded-path}/{session}.jsonl`
Path encoding: `/home/dev/project` → `-home-dev-project` (starts with dash)

See `requirements/BACKEND.md` for full API reference.

## Known Issues (Fix These!)

| Issue | Location | Priority |
|-------|----------|----------|
| WebSocket state race | `WebSocketManager.swift:196-230` | Critical |
| Missing @MainActor | `APIClient.swift`, `BookmarkStore` in Models.swift | Critical |
| SpeechManager no deinit | `SpeechManager.swift` | Critical |
| SSH password in UserDefaults | `AppSettings.swift:179` | High |
| Command injection | `SSHManager.swift:700,747,856` | High |

See `ROADMAP.md` Priority 1 for full list with line numbers.

## Testing

28+ unit tests covering parsers and utilities. Test files in `ClaudeCodeAppTests/`.

## References

- `README.md` - Feature overview, setup guide
- `ROADMAP.md` - Priorities, known issues with line numbers
- `requirements/ARCHITECTURE.md` - Full system architecture, data flows
- `requirements/BACKEND.md` - API reference, troubleshooting
- `requirements/OVERVIEW.md` - Functional requirements
