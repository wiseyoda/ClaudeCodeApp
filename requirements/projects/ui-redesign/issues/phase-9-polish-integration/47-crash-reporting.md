# Issue 47: Crash Reporting

**Phase:** 9 (Polish & Integration)
**Priority:** High
**Status:** Not Started
**Depends On:** 44 (Debug Tooling), 45 (Feature Flags)

## Goal

Integrate crash reporting with privacy-respecting defaults and release gating.

## Scope

- In scope: crash capture, non-fatal error reporting, symbolication support, and environment gating.
- Out of scope: product analytics, growth tracking, or cross-app attribution.

## Non-goals

- No marketing analytics or user-level profiling.

## Dependencies

- Issue 44 for debug logging hooks.
- Issue 45 for rollout controls and kill switches.

## Touch Set

- Files to create: `CodingBridge/Monitoring/CrashReporter.swift` (protocol + implementation).
- Files to modify: `CodingBridge/App/CodingBridgeApp.swift`, `CodingBridge/AppSettings.swift`, `Info.plist` (if required by provider).

## Interface Definitions

- `CrashReporter` protocol with `start()`, `record(error:)`, `setUserContext(_:)`.
- `CrashReportingConfig` with build channel (debug/beta/release), opt-in state, and redaction rules.

## Edge Cases

- Offline startup or provider endpoint outage.
- User opts out or privacy mode enabled.
- Crash in early app init before dependencies are ready.

## Acceptance Criteria

- [ ] Crash reporter initializes only for beta/release builds (or explicit opt-in).
- [ ] PII and file contents are redacted by default.
- [ ] Symbolication pipeline documented and verified.
- [ ] Kill switch available via feature flags.

## Tests

- [ ] Unit tests for config gating and redaction rules.
- [ ] Smoke test in beta build to confirm crash ingestion.
