# Issue 40: Testing Strategy

**Phase:** 0 (Foundation)
**Priority:** High
**Status:** Not Started
**Depends On:** None

## Goal

Define a production-ready testing strategy before implementation begins.

## Non-goals
- See "Out of Scope" section.

## Dependencies
- See **Depends On** header; add runtime or tooling dependencies here.

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
