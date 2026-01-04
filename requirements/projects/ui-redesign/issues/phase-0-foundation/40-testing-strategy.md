---
number: 40
title: Testing Strategy
phase: phase-0-foundation
priority: High
depends_on: null
acceptance_criteria: 6
files_to_touch: 1
status: pending
completed_by: null
completed_at: null
verified_by: null
verified_at: null
commit: null
spot_checked: false
blocked_reason: null
---

# Issue 40: Testing Strategy

**Phase:** 0 (Foundation)
**Priority:** High
**Status:** Not Started
**Depends On:** None

## Required Documentation

Before starting work on this issue, review these architecture and design documents:

### Core Architecture
- **[System Overview](../../docs/architecture/data/01-system-overview.md)** - Overall architecture to test
- **[Data Flow (Messages)](../../docs/architecture/data/03-data-flow-messages.md)** - Message normalization to test
- **[State Management](../../docs/architecture/ui/07-state-management.md)** - State patterns to test
- **[Navigation Pattern](../../docs/architecture/ui/01-navigation-pattern.md)** - Navigation to test
- **[Testing Navigation](../../docs/architecture/ui/13-testing-navigation.md)** - Navigation testing patterns

### Foundation
- **[Design Decisions](../../docs/overview/design-decisions.md)** - Key decisions that need test coverage
- **[Swift 6 Concurrency Model](../../docs/architecture/data/02-swift-6-concurrency-model.md)** - Concurrency patterns to test

### Workflows
- **[Execution Guardrails](../../docs/workflows/guardrails.md)** - Development rules and constraints

## Goal

Define a production-ready testing strategy before implementation begins.

## Non-goals
- See "Out of Scope" section.

## Dependencies
- See **Depends On** header; add runtime or tooling dependencies here.

## Touch Set
- Files to create:
  - `CodingBridgeTests/TestSupport/MockFactory.swift`
  - `CodingBridgeTests/TestSupport/FixtureCatalog.swift`
  - `CodingBridgeUITests/TestSupport/WebSocketReplay.swift`
  - `TEST-PERF.md` (if performance metrics are tracked separately)
- Files to modify:
  - `CodingBridgeTests/*.swift`
  - `CodingBridgeUITests/*.swift`
  - `TEST-COVERAGE.md`
  - `CodingBridgeTests/IntegrationTestConfig.swift`
  - `CodingBridge/SessionRepository.swift` (extend `MockSessionRepository` as needed)

## Interface Definitions
- No API payload changes.

```swift
struct MockFactory {
    static func chatMessage(role: ChatMessage.Role) -> ChatMessage
    static func project() -> Project
    static func session() -> ProjectSession
    static func streamEvents() -> [StreamEvent]
}
```

```swift
enum FixtureCatalog {
    static let longSessionMessages: [ChatMessage]
    static let toolHeavySession: [ChatMessage]
    static let errorBurstSession: [ChatMessage]
}
```

```swift
final class WebSocketReplay {
    init(events: [StreamEvent])
    func play(to handler: @escaping (StreamEvent) -> Void)
    func cancel()
}
```

## Edge Cases
- UI tests running without a backend (must use harness or skip).
- Flaky timing from streaming updates and long-running tools.
- Large sessions causing slow UI test interactions or timeouts.
- Permission prompts or OS alerts blocking UI test flows.
- Deterministic time and random seeds for reproducible tests.

## Tests
- [ ] Unit tests updated or added.
- [ ] UI tests updated or added (if user flows change).
## Scope

- Unit test coverage targets for core models/utilities
- XCUITest coverage for critical user flows
- Performance benchmarks for long sessions
- Accessibility audit checklist and automation hooks

## Out of Scope

- Third-party snapshot tooling unless approved

## Strategy

### Unit Tests (CodingBridgeTests)

Targets:
- Message normalization and validation
- Message routing and card rendering logic
- AppState and navigation state
- Stores and persistence adapters

Coverage target:
- >= 80% for redesigned modules (measured per target)

### UI Tests (CodingBridgeUITests)

Critical flows:
- Launch app and connect to backend
- Create/select project and send a message
- Scroll 200+ messages and jump to unread
- Open settings, change a value, verify persistence
- Open terminal, send a command, verify output

### Snapshot Testing (Optional)

- Use native Xcode snapshot testing if approved.
- Establish an accept/reject workflow for UI regressions.

### Network Mocking

- Use `URLProtocol` stubs or a mock transport layer for REST.
- Provide a deterministic WebSocket replay harness for UI tests.

### Test Data Factories

- Add `Message.mock()`, `Project.mock()`, and `Session.mock()` helpers.
- Keep fixtures in a single test utilities module.

### Performance Benchmarks

Use XCTest metrics or Instruments profile notes:
- iPhone 17 Pro: 500+ messages at 60fps (16.7ms frame budget)
- iPad Pro: 1000+ messages at 60fps
- Cold launch < 2s on iPhone 17 Pro (iOS 26.2)
- Memory < 200MB for 500 messages, no sustained growth

### CI Integration

- Run unit tests + UI tests on each PR.
- Publish coverage summary to CI logs.
- Gate merges if coverage < 80% for redesigned modules.

### Coverage Enforcement

- Add a coverage threshold check (target >= 80% per redesigned module).
- Track deltas in `TEST-COVERAGE.md`.

### Leak Detection

- Run Instruments Leaks on long sessions
- Capture a baseline memory graph before/after 30 minutes of activity

### Accessibility Audit

- Xcode Accessibility Inspector pass (manual)
- UI tests assert key labels/traits (automated)
- Dynamic Type sanity pass (AX5)

## Implementation Notes

- Add coverage notes to `TEST-COVERAGE.md` as new modules land.
- Use the UI test harness (`CODINGBRIDGE_UITEST_MODE=1`) for deterministic flows.
- Record performance results in `TEST-COVERAGE.md` or a new `TEST-PERF.md`.

## Acceptance Criteria

- [ ] Unit test coverage target defined and tracked
- [ ] XCUITest scenarios implemented for critical flows
- [ ] Performance benchmarks documented
- [ ] Accessibility audit checklist added to UI tests
- [ ] Coverage enforcement in CI documented
- [ ] Build passes with tests enabled
