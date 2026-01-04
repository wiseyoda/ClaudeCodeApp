# Issue 44: Debug Tooling

**Phase:** 0 (Foundation)
**Priority:** Medium
**Status:** Not Started
**Depends On:** None

## Goal

Provide a consistent development and preview toolkit for the redesign.

## Non-goals
- TBD.

## Dependencies
- See **Depends On** header; add runtime or tooling dependencies here.

## Tests
- [ ] Unit tests updated or added.
- [ ] UI tests updated or added (if user flows change).
## Scope

- Mock data factories for messages, tools, sessions, projects
- Preview helpers for all card views and sheets
- Debug menu to toggle common states
- Slow network simulation hooks (REST + WebSocket)

## Touch Set

- `CodingBridge/Debug/`
- `CodingBridge/TestFixtures/`
- `CodingBridge/ViewModels/`

## Interface Definitions

```swift
struct MockFactory {
    static func chatMessage(role: ChatMessage.Role) -> ChatMessage
    static func project() -> Project
    static func session() -> ProjectSession
    static func streamEvents() -> [StreamEvent]
}
```

## Implementation

### Mock Data Factories

```
CodingBridge/Debug/
├── MockFactory.swift           # ChatMessage, Project, Session mocks
├── MockStreamEvents.swift      # StreamEvent sequences
└── PreviewFixtures.swift       # Shared sample data
```

### Preview Helpers

```swift
#Preview("Tool Card - Loading") {
    ToolCardView(message: .mockToolUse())
}
```

### Debug Menu (DEBUG only)

- Open via shake gesture or hidden long-press
- Toggles: offline mode, streaming on/off, long session (500+)
- Buttons: seed sample data, clear cache, reset flags

### Network Simulation

- REST: use `URLProtocol` stub in debug builds
- WebSocket: add a debug entry point in `CLIBridgeManager` to inject StreamEvents

### SwiftUI Instruments

- Use SwiftUI Instruments to detect skipped updates and rendering issues.
- Record baseline traces for ChatView and long-session scrolling.
- Document known hotspots and expected update frequency.

## Edge Cases

- Debug hooks included in Release builds (must be stripped).
- Mock data diverges from docs/contracts/models (use shared fixtures).
- Preview crashes from missing environment dependencies.

## Acceptance Criteria

- [ ] Mock factory covers all message roles
- [ ] Preview fixtures used across Chat/Card/Settings/Sheets
- [ ] Debug menu available in DEBUG only
- [ ] Slow network and offline states reproducible
- [ ] No debug hooks compiled into Release builds

## Testing

- Manual: toggle debug states and verify UI updates.
