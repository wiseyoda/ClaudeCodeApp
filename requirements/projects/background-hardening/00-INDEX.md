# Background Hardening Project

> Keep developers informed about Claude's status without requiring constant app focus.

**Core question:** "Is Claude working, done, or waiting for me?"

**Getting started?** See [PROMPTS.md](./PROMPTS.md) for copy/paste prompts.

## Quick Links

| Doc | Purpose |
|-----|---------|
| [Goals](./01-GOALS.md) | Success metrics, non-goals |
| [States](./02-STATES.md) | Task state machine |
| [Architecture](./03-ARCHITECTURE.md) | Component diagram, file structure |

## Implementation Phases

### Phase 1: Background Basics + Local Notifications
> Foundation for background awareness

| Doc | Component |
|-----|-----------|
| [background-manager](./phase-1/background-manager.md) | BGTaskScheduler, scene phase handling |
| [notification-manager](./phase-1/notification-manager.md) | Local notifications, categories, actions |
| [persistence](./phase-1/persistence.md) | Message queue, draft input, state recovery |
| [network-monitor](./phase-1/network-monitor.md) | NWPathMonitor integration |
| [checklist](./phase-1/checklist.md) | Deliverables and testing |

### Phase 2: Live Activities
> Glanceable status on Lock Screen and Dynamic Island

| Doc | Component |
|-----|-----------|
| [activity-attributes](./phase-2/activity-attributes.md) | Shared ActivityAttributes struct |
| [live-activity-manager](./phase-2/live-activity-manager.md) | ActivityKit lifecycle |
| [widget-extension](./phase-2/widget-extension.md) | Extension setup, App Group |
| [ui-views](./phase-2/ui-views.md) | Lock Screen, Dynamic Island views |
| [checklist](./phase-2/checklist.md) | Deliverables and testing |

### Phase 3: Push + Actionable Approvals
> Remote notifications, approve/deny from Lock Screen

| Doc | Component |
|-----|-----------|
| [push-token-manager](./phase-3/push-token-manager.md) | APNs token registration |
| [notification-actions](./phase-3/notification-actions.md) | Approve/Deny handling |
| [backend-api](./phase-3/backend-api.md) | Push endpoints, APNs integration |
| [backend-events](./phase-3/backend-events.md) | Session handler triggers |
| [checklist](./phase-3/checklist.md) | Deliverables and testing |

## Reference

| Doc | Topic |
|-----|-------|
| [settings](./ref/settings.md) | User preferences, permission status |
| [deep-links](./ref/deep-links.md) | URL scheme, notification navigation |
| [privacy](./ref/privacy.md) | Content filtering, data protection |
| [edge-cases](./ref/edge-cases.md) | Force-quit, Low Power Mode, timeouts |
| [multi-device](./ref/multi-device.md) | Session handoff, notification sync |
| [provisioning](./ref/provisioning.md) | Apple Developer setup, entitlements |
| [testflight](./ref/testflight.md) | APNs environments, testing workflow |

## Current Status

| Phase | Status | Dependencies |
|-------|--------|--------------|
| Phase 1 | Deliverables complete, testing needed | None |
| Phase 2 | Not started | Phase 1 |
| Phase 3 | Not started | Phase 1+2, Backend APNs |

## File Counts

- Core docs: 3
- Phase 1: 5 docs
- Phase 2: 5 docs
- Phase 3: 5 docs
- Reference: 7 docs
- **Total: 25 focused docs** (avg ~150 lines each)
