# Goals and Success Metrics

## Primary Goals

1. **Never leave Claude idle** - Immediately notify when user input is required
2. **Glanceable status** - See Claude's state from Lock Screen without unlocking
3. **One-tap responses** - Approve/deny permissions from notifications
4. **Peace of mind** - Confidently leave the app knowing you'll be notified

## Success Metrics

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Missed permission requests | 0% | Track approvals that timeout without response |
| Notification delivery latency | < 5 seconds | Time from event to notification display |
| Graceful recovery rate | > 95% | Silent reconnection after network issues |
| Live Activity accuracy | 100% | Status always reflects actual task state |

## Non-Goals (Explicit Exclusions)

- Play-by-play tool usage updates (too noisy)
- Sound notifications for every progress update
- Apple Watch as primary target (nice-to-have only)
- SSH operation monitoring (WebSocket tasks only)
- Custom notification sounds (use system defaults)
- Rich media in notifications (keep it simple text)
- Siri integration (future enhancement)
- Home Screen widget (Phase 4 future work)

## Technical Constraints

- iOS 26.2 minimum deployment target
- Direct APNs integration (no Firebase)
- Backend modifications to claudecodeui fork required
- Must work with existing WebSocket message protocol

## Phase Dependencies

```
Phase 1: Background Basics
    └── Phase 2: Live Activities
            └── Phase 3: Push + Actions (requires backend APNs)
```

## Rollback Plan

Each phase can be disabled independently via feature flags:

```swift
struct BackgroundFeatureFlags {
    static var enableBackgroundTasks = true
    static var enableLiveActivities = true
    static var enablePushNotifications = true
    static var enableActionableNotifications = true
}
```

---
**Next:** [States](./02-STATES.md) | **Index:** [00-INDEX.md](./00-INDEX.md)
