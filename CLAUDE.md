# CodingBridge

iOS client for [cli-bridge](https://github.com/wiseyoda/cli-bridge). SwiftUI app targeting iOS 26+.

## Quick Start

```bash
# Build
xcodebuild -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'

# Test
xcodebuild test -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'

# Open in Xcode
open CodingBridge.xcodeproj
```

**Always use iPhone 17 Pro with iOS 26.2** - this is the development target.

## Backend

```bash
# Start local dev server (REQUIRED for development)
cd ~/dev/cli-bridge && deno task dev

# Verify
curl -s http://localhost:3100/health
```

| Environment | URL | Use |
|-------------|-----|-----|
| Local dev | `http://localhost:3100` | Always use for development |
| Production | `http://172.20.0.2:3100` | QNAP container (Tailscale) |

**API docs**: http://localhost:3100/docs

---

## Critical Rules

### Files

New `.swift` files must be added to `project.pbxproj` or they won't compile. The **xcode-linker agent** handles this automatically - it runs after creating Swift files to link them and verify the build passes.

### Thread Safety

- **MUST** add `@MainActor` to any `ObservableObject` class
- **MUST** use `Task { @MainActor in }` for UI updates from async contexts
- **NEVER** update `@Published` properties from background threads

### Security

- **MUST** escape file paths passed to `SSHManager.executeCommand()`
- **NEVER** store secrets in `@AppStorage` - use `KeychainHelper`
- **NEVER** commit credentials or API keys
- See @.claude/rules/ssh-security.md for shell escaping rules

### SSH Paths

- **MUST** use `$HOME` instead of `~` for home directory paths
- **MUST** use double quotes (`"..."`) when paths contain `$HOME`
- Single quotes prevent shell expansion - paths fail silently

---

## Architecture

```
App → CLIBridgeManager → cli-bridge backend → Claude Code CLI
App → SSHManager → sshd (file ops, git)
```

### Key Files

| File | Purpose |
|------|---------|
| `CLIBridgeManager.swift` | Core API client, WebSocket streaming |
| `CLIBridgeAdapter.swift` | Adapts manager to callback interface |
| `ChatViewModel.swift` | Chat state, message handling |
| `SessionStore.swift` | Session state, pagination |
| `SSHManager.swift` | SSH terminal, file ops, git |
| `Models.swift` | Data models, persistence stores |
| `Generated/` | OpenAPI-generated types (143 files) |

### Patterns

```swift
// View owns manager
@StateObject private var manager = CLIBridgeAdapter()

// Shared settings from environment
@EnvironmentObject var settings: AppSettings

// Singleton stores
@ObservedObject var commands = CommandStore.shared
```

See @.claude/rules/swiftui-patterns.md for more patterns.

---

## Common Tasks

### Regenerate API Types

```bash
./scripts/regenerate-api-types.sh
```

Run after cli-bridge API changes. Generates types in `CodingBridge/Generated/`.

### Add New Features

See @.claude/rules/adding-features.md for:
- Adding tool types
- Adding persistence stores
- Adding sheets/modals
- Adding slash commands

### Version Bump

```bash
/bump [major|minor|patch]
```

Or manually edit `Config/Version.xcconfig`.

---

## Persistence

| Store | Location |
|-------|----------|
| MessageStore | `Documents/{encoded-path}.json` |
| BookmarkStore | `Documents/bookmarks.json` |
| CommandStore | `Documents/commands.json` |
| IdeasStore | `Documents/ideas-{path}.json` |

Path encoding: `/home/dev/project` → `-home-dev-project`

---

## iOS Quirks

| Issue | Workaround |
|-------|------------|
| TextEditor paste drops first char | `SSHKeyDetection` auto-recovers for SSH keys |
| Smart punctuation converts dashes | `normalizeKeyContent()` converts back to ASCII |
| Text hyphenation adds soft hyphens | Base64 filtering strips non-base64 chars |

---

## References

- CHANGELOG.md - Version history (read when needed)
- @ROADMAP.md - Current work
- @requirements/ARCHITECTURE.md - Full architecture
- @requirements/BACKEND.md - API reference
