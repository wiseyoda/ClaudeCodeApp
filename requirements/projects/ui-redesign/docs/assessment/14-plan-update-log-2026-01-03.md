# Plan Update Log (2026-01-03)


This log records each recommendation from the assessment and the decision applied to the project plan.

### Completed or In-Flight (Plan Already Updated)

- Build config alignment: README/BUILD-CONFIG now agree on iOS 26.2 + Swift 6.2.1.
- Spec hierarchy updated to include BUILD-CONFIG and MODELS/API-CONTRACTS.
- Issue template created; required sections backfilled across all issues.
- Status Dashboard initialized (real Now/Next/Last Updated).
- API contracts expanded to full StreamEvent surface.
- Production readiness issues added: #47–#51 (crash reporting, telemetry, privacy manifest, release pipeline, App Store assets).

### Accepted: New Issues Added to the Plan

- #52 Error Recovery UI (retry, offline banners, recovery actions).
- #53 Offline Mode (queueing, read-only state, OfflineActionQueue mapping).
- #54 Push Notifications (Live Activity updates, rich notification support).
- #55 App Shortcuts (Siri/App Intents shortcuts).
- #56 iCloud Sync (optional; only if product requires it).
- #57 Export/Share (session export + share flow).
- #58 Performance Profiling (continuous profiling + regression tests).
- #59 Dependency Graph (Mermaid dependency visualization).
- #60 Code Review Checklist (Swift 6 + iOS 26 + accessibility + perf).
- #61 Swift Style + DocC Standards (formatting and doc comment guidance).
- #62 Migration Helpers (Observable migration recipes/scripts).
- #63 Error Types (AppError hierarchy implementation).
- #64 Rich Text Editing (AttributedString/TextEditor adoption).
- #65 DeclaredAgeRange Compliance (Texas SB 2420).
- #66 State Restoration (NSUserActivity/state restoration flows).
- #67 Rich Notifications (notification actions + rich content).
- #68 Share Extension (optional; share content into CodingBridge).
- #69 Voice Input (SpeechManager mapping; optional).

### Accepted: Existing Issues to Expand

- #40 Testing Strategy: add specific device targets, memory limits, snapshot strategy, network mocking, test data factories, CI enforcement.
- #10 Observable Migration: add migration test cases and persistence validation.
- #38 Accessibility: add automated accessibility test hooks.
- #43 Handoff/Links: add deep link schema and routing details.
- #44 Debug Tooling: add SwiftUI Instruments guidance.
- #46 Localization: add String Catalog setup + pluralization examples.
- #20 Live Activities: reference #54 for push updates and rich notifications.
- #22 Keyboard Shortcuts: reference #55 for App Shortcuts.
- #33 Global Search: add algorithm + indexing strategy notes.
- #02/#03/#07/#08/#09/#12/#13/#16: add concrete code and test examples.
- README Definition of Done: include CHANGELOG/release notes requirement.
- Phase sequencing: adopt recommended Phase 0 execution order and mark parallelizable issues.
- ../architecture/data/README.md: add explicit retry/backoff details as part of #52.

### Deferred or Optional (Tracked in Plan)

- iCloud Sync (#56) and Share Extension (#68) are optional; implement only if product scope requires them.
- Voice Input (#69) is optional; implement only if voice input is required.
- Swift 6.2.1 advanced features (~Copyable, typed throws) are deferred to implementation-time decisions and tracked in #61.

### Unmapped File Ownership Decisions

- SpeechManager.swift -> #69 Voice Input.
- HealthMonitorService.swift -> #48 Telemetry & Monitoring.
- OfflineActionQueue.swift -> #53 Offline Mode.
- BackgroundManager.swift -> #54 Push Notifications and BUILD-CONFIG background modes.
