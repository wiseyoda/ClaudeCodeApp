# CLAUDE.md

iOS client for [claudecodeui](https://github.com/siteboon/claudecodeui). SwiftUI app targeting iOS 26+ with Citadel SSH library.

## Commands

**IMPORTANT: Always use iPhone 17 Pro with iOS 26.2 - this is the current development target.**

```bash
# Build
xcodebuild -project CodingBridge.xcodeproj -scheme CodingBridge -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'

# Test
xcodebuild test -project CodingBridge.xcodeproj -scheme CodingBridge -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'

# Open in Xcode
open CodingBridge.xcodeproj
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

**IMPORTANT - Adding Files:**
- MUST add new `.swift` files to `project.pbxproj` (use `xcodebuild` or Xcode)
- After creating a file, run build to verify it's included—unlinked files won't compile

**IMPORTANT - Thread Safety:**
- MUST add `@MainActor` to any new `ObservableObject` class
- MUST use `Task { @MainActor in }` for UI updates from async contexts
- NEVER update `@Published` properties from background threads

**IMPORTANT - Security:**
- MUST escape all file paths passed to `SSHManager.executeCommand()` using proper shell quoting
- NEVER store secrets in `@AppStorage` (use Keychain via `KeychainHelper`)
- NEVER commit credentials or API keys

**IMPORTANT - SSH Shell Expansion:**
- MUST use `$HOME` instead of `~` for home directory paths in SSH commands
- MUST use double quotes (`"..."`) not single quotes (`'...'`) when paths contain `$HOME`
- Single quotes prevent shell variable expansion, causing paths to fail silently
- See `.claude/rules/ssh-security.md` for examples

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

Session files: `$HOME/.claude/projects/{encoded-path}/{session}.jsonl`
Path encoding: `/home/dev/project` → `-home-dev-project` (starts with dash)

**Note**: The backend API only returns ~5 sessions per project. The app loads all sessions via SSH for accurate counts. See `requirements/SESSIONS.md` for the full session system documentation.

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

300+ unit tests covering parsers and utilities. Test files in `CodingBridgeTests/`.

## iOS Platform Quirks

| Issue | Workaround | Location |
|-------|------------|----------|
| TextEditor paste truncation | First character sometimes dropped when pasting. `SSHKeyDetection` auto-recovers by detecting invalid magic bytes and prepending missing `b` for OpenSSH keys. | `SSHManager.swift:360-384` |
| Smart Punctuation | iOS converts `-` to em/en dashes. `normalizeKeyContent()` converts all Unicode dashes back to ASCII. | `SSHManager.swift:245-281` |
| Text hyphenation | iOS adds soft hyphens to wrapped text. Base64 filtering strips all non-base64 chars. | `SSHManager.swift:339-341` |

## References

- `README.md` - Feature overview, setup guide
- `ROADMAP.md` - Priorities, known issues with line numbers
- `requirements/ARCHITECTURE.md` - Full system architecture, data flows
- `requirements/BACKEND.md` - API reference, troubleshooting
- `requirements/SESSIONS.md` - Session system deep dive (file formats, API limitations, SSH loading)
- `requirements/OVERVIEW.md` - Functional requirements
- `requirements/QNAP-CONTAINER.md` - QNAP container setup, persistence, troubleshooting
