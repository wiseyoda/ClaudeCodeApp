# Background Hardening Project

> Comprehensive background task, notification, and Live Activity system for CodingBridge iOS app.

## Project Summary

Transform CodingBridge from a foreground-only app into a background-aware application that keeps developers informed about Claude's status without requiring constant app focus. The core value proposition: **"Is Claude working, done, or waiting for me?"**

## Problem Statement

Currently, CodingBridge has minimal background infrastructure:
- App suspends after ~30 seconds in background
- WebSocket disconnects, losing task progress
- No visibility into Claude's status from Lock Screen
- Permission approvals require opening the app
- Long-running tasks (tests, builds) provide no feedback when backgrounded

## Goals

1. **Never leave Claude idle** - Immediately notify when user input is required
2. **Glanceable status** - See Claude's state from Lock Screen/Dynamic Island
3. **Actionable notifications** - Approve/deny permissions without opening app
4. **Graceful backgrounding** - Preserve state, recover silently from disconnects
5. **Battery-conscious** - Minimize background runtime while maintaining functionality

## Core Requirements

### Task States

The app should clearly communicate these states:

| State | Description | User Action Needed |
|-------|-------------|-------------------|
| **Processing** | Claude is actively working | None - just monitoring |
| **Awaiting Approval** | Claude needs permission to proceed | Approve or Deny |
| **Awaiting Answer** | Claude asked a question via AskUserQuestion | Respond in app |
| **Complete** | Task finished successfully | None |
| **Error** | Task failed or connection lost | Review in app |

### Live Activity Display

**Dynamic Island (Compact):**
- Project name (truncated)
- Status indicator (working/waiting/done)
- Elapsed time

**Dynamic Island (Expanded):**
- Full project name
- Current high-level operation description
- Elapsed time
- Status with appropriate iconography

**Lock Screen:**
- Project name and path
- Current operation (e.g., "Running tests", "Building project")
- Progress indicator:
  - TodoWrite-based when available (e.g., "3 of 7 tasks complete")
  - Elapsed time otherwise
- Status-specific actions (Approve/Deny when awaiting approval)

### Notification Behavior

| Event | When App Foreground | When App Background |
|-------|--------------------|--------------------|
| Task starts | No notification | Live Activity starts |
| Progress update | No notification | Live Activity updates (silent) |
| Approval needed | In-app banner | Push notification with actions |
| Question asked | In-app display | Push notification |
| Task complete | No notification | Push notification with sound |
| Error occurred | In-app alert | Push notification with sound |

### Background Behavior

1. **When user backgrounds app during processing:**
   - Start Live Activity immediately
   - Use `BGContinuedProcessingTask` (iOS 26) to extend runtime
   - Maintain WebSocket connection as long as possible
   - If suspended, register for push notifications to resume

2. **On connection failure:**
   - Silent retry with exponential backoff
   - Only notify if unrecoverable after multiple attempts
   - Preserve message queue for retry on reconnect

3. **State preservation:**
   - Save draft input text immediately
   - Persist pending messages to disk (not just memory)
   - Store last known task state for recovery

### Approval Actions from Lock Screen

When Claude requests permission (tool approval), show actionable notification:
- **Approve** button - sends approval, continues task
- **Deny** button - sends denial, Claude acknowledges
- Tap notification body - opens app for more context

### Long-Running Tasks (>1 hour)

- Convert Live Activity to periodic push notifications
- Log warning that task is unusually long
- Continue monitoring via push token until completion

## Non-Goals (Explicit Exclusions)

- Play-by-play tool usage updates (too noisy)
- Sound notifications for every progress update
- Apple Watch as primary target (nice-to-have only)
- SSH operation monitoring (WebSocket tasks only)
- Custom notification sounds (use system defaults)

## Success Metrics

1. **Zero missed approvals** - User always knows when Claude needs input
2. **<5 second notification latency** - Prompt delivery of status changes
3. **Graceful recovery rate >95%** - Silent reconnection after network issues
4. **Live Activity accuracy** - Status always reflects actual task state

## Technical Constraints

- iOS 26.2 minimum deployment target
- Direct APNs integration (no Firebase)
- Backend modifications to claudecodeui fork required
- Must work with existing WebSocket message protocol

## Dependencies

### iOS APIs Required
- ActivityKit (Live Activities)
- BackgroundTasks (BGContinuedProcessingTask, BGAppRefreshTask)
- UserNotifications (UNNotificationAction, push notifications)
- Network framework (connection monitoring)

### Backend Requirements
- APNs integration (p8 certificate, token-based auth)
- Push token registration endpoint
- Live Activity push notification support
- WebSocket events for state changes (some may already exist)

## References

### Apple Documentation
- [ActivityKit](https://developer.apple.com/documentation/activitykit)
- [BGTaskScheduler](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler)
- [Starting Live Activities with Push Notifications](https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications)
- [WWDC 2025: Finish tasks in the background](https://developer.apple.com/videos/play/wwdc2025/227/)

### Best Practices
- [iOS 18 Live Activities Best Practices](https://www.pushwoosh.com/blog/ios-live-activities/)
- [Mastering Background Tasks](https://medium.com/@dhruvmanavadaria/mastering-background-tasks-in-ios-bgtaskscheduler-silent-push-and-background-fetch-with-6b5c502d7448)

## Related Documents

- [ARCHITECTURE.md](./ARCHITECTURE.md) - System design and component interactions
- [LIVE-ACTIVITIES.md](./LIVE-ACTIVITIES.md) - ActivityKit implementation details
- [BACKGROUND-TASKS.md](./BACKGROUND-TASKS.md) - BGTaskScheduler patterns
- [NOTIFICATIONS.md](./NOTIFICATIONS.md) - Push and local notification design
- [BACKEND-CHANGES.md](./BACKEND-CHANGES.md) - APNs integration requirements
- [PHASES.md](./PHASES.md) - Incremental implementation plan
- [EDGE-CASES-AND-SETTINGS.md](./EDGE-CASES-AND-SETTINGS.md) - Edge cases, user settings, network handling
