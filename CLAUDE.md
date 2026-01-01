# CLAUDE.md

iOS client for [cli-bridge](https://github.com/anthropics/claude-code/tree/main/packages/cli-bridge) backend. SwiftUI app targeting iOS 26+ with Citadel SSH library.

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

## Slash Commands

| Command | Description |
|---------|-------------|
| `/bump [major\|minor\|patch]` | Full release workflow: update changelog, bump version, run tests, push to main |

## Versioning

Version is defined in a single location: `Config/Version.xcconfig`

```bash
# To bump version manually:
# 1. Edit Config/Version.xcconfig (MARKETING_VERSION)
# 2. Update CHANGELOG.md
# 3. Commit and tag

# Or use the /bump command for automated workflow
```

The `AppVersion` utility (`Utilities/AppVersion.swift`) provides runtime access:
- `AppVersion.version` - Marketing version (e.g., "0.6.7")
- `AppVersion.build` - Build number
- `AppVersion.fullVersion` - "0.6.7 (1)"
- `AppVersion.userAgent` - "CodingBridge/0.6.7"

## Key Files

| File | Purpose |
|------|---------|
| `CLIBridgeManager.swift` | Core cli-bridge API client, SSE streaming |
| `CLIBridgeAdapter.swift` | Adapts CLIBridgeManager to WebSocket-style interface |
| `CLIBridgeTypes.swift` | All cli-bridge message types and models |
| `SessionStore.swift` | Session state, pagination, real-time updates |
| `SSHManager.swift` | SSH terminal, file ops, git commands via Citadel |
| `ChatView.swift` | Main chat UI, message handling, slash commands |
| `Models.swift` | All data models, enums, persistence stores |
| `AppSettings.swift` | @AppStorage configuration |

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
- Use `@StateObject` for manager ownership in views (CLIBridgeAdapter, SSHManager, IdeasStore)
- Use `@EnvironmentObject` for AppSettings (injected at app root)
- Use singletons for shared stores: `SessionStore.shared`, `CommandStore.shared`, `BookmarkStore.shared`
- Persist to Documents directory using `FileManager.default.urls(for: .documentDirectory)`

## Patterns

```swift
// Correct: View owns the manager
struct ChatView: View {
    @StateObject private var wsManager = CLIBridgeAdapter()
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
App → CLIBridgeAdapter → cli-bridge backend → Claude Code CLI
App → SSHManager → sshd (file ops, git, session history)
```

- **Views/**: 48 UI components (sheets, pickers, message views)
- **Utilities/**: Logger, AppError, ImageUtilities, KeychainHelper, etc. (10 files)
- **Managers/**: BackgroundManager, LiveActivityManager, NotificationManager, etc. (5 files)
- **Models/**: GitModels, ImageAttachment, LiveActivityAttributes, TaskState (4 files)
- **Extensions/**: String+Markdown
- **Persistence/**: DraftInputPersistence, MessageQueuePersistence

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

Connects to [cli-bridge](~/dev/cli-bridge) via REST API with SSE streaming.

**IMPORTANT - API Documentation:**
- **OpenAPI Spec (JSON):** `http://10.0.3.2:3100/openapi.json` - Check this first before implementing API calls
- **Interactive Docs:** `http://10.0.3.2:3100/docs` - Swagger UI for testing endpoints
- Always verify endpoint signatures against the live OpenAPI spec

**Local Development:**
```bash
# Start cli-bridge (in ~/dev/cli-bridge)
deno task dev  # Runs on http://localhost:3100

# Verify it's running
curl -s http://localhost:3100/health
```

**Default Server URL:** `http://localhost:3100` (configurable in app settings)

**Key Endpoints:**
- `GET /health` - Health check
- `POST /agents` - Start new agent session
- `POST /agents/:id/message` - Send message (SSE response)
- `POST /agents/:id/abort` - Abort current operation

Session files: `$HOME/.claude/projects/{encoded-path}/{session}.jsonl`
Path encoding: `/home/dev/project` → `-home-dev-project` (starts with dash)

See `requirements/BACKEND.md` for full API reference.

## Known Issues

| Issue | Location | Priority |
|-------|----------|----------|
| @MainActor on BookmarkStore | `Models.swift` | High |

Many critical issues fixed in v0.4.0. See `ROADMAP.md` for remaining work.

## Testing

300+ unit tests covering parsers and utilities. Test files in `CodingBridgeTests/`.

## iOS Platform Quirks

| Issue | Workaround | Location |
|-------|------------|----------|
| TextEditor paste truncation | First character sometimes dropped when pasting. `SSHKeyDetection` auto-recovers by detecting invalid magic bytes and prepending missing `b` for OpenSSH keys. | `SSHManager.swift:360-384` |
| Smart Punctuation | iOS converts `-` to em/en dashes. `normalizeKeyContent()` converts all Unicode dashes back to ASCII. | `SSHManager.swift:245-281` |
| Text hyphenation | iOS adds soft hyphens to wrapped text. Base64 filtering strips all non-base64 chars. | `SSHManager.swift:339-341` |

## References

- `CHANGELOG.md` - Version history
- `ROADMAP.md` - Remaining work
- `ISSUES.md` - Bug tracking
- `requirements/ARCHITECTURE.md` - System architecture, data flows
- `requirements/BACKEND.md` - API reference
- `requirements/SESSIONS.md` - Session system deep dive
