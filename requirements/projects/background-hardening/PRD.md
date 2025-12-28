# Product Requirements Document: Background Awareness

> **Product:** CodingBridge iOS App
> **Feature:** Background Task Awareness & Notifications
> **Version:** 1.0
> **Last Updated:** December 2024
> **Status:** Draft

---

## Executive Summary

CodingBridge helps developers interact with Claude, an AI coding assistant, from their iPhone. Currently, if a user sends Claude a task and then switches to another app or locks their phone, they have no idea what's happening. They might miss when Claude needs their permission to continue, or they won't know when Claude finishes their task.

This project adds "background awareness" — the ability for users to stay informed about Claude's progress even when they're not actively looking at the app. Users will see Claude's status on their Lock Screen, receive notifications when Claude needs them, and be able to respond to permission requests without opening the app.

**The core question we're answering:** "Is Claude working, done, or waiting for me?"

---

## Problem Statement

### Current Pain Points

1. **Blind Spot After Leaving the App**
   - Users send Claude a task, then check email or lock their phone
   - They have no visibility into whether Claude is still working
   - They don't know if Claude finished 30 seconds ago or is still going

2. **Missed Permission Requests**
   - Claude sometimes needs permission to run commands or access files
   - If the user isn't looking at the app, they never see these requests
   - Claude sits waiting indefinitely, wasting the user's time

3. **Anxiety About Long Tasks**
   - Running tests, building projects, or complex refactors can take minutes
   - Users feel compelled to keep the app open and watch
   - This defeats the purpose of having an AI assistant

4. **No Quick Actions**
   - Even if users knew Claude needed something, they'd have to:
     - Unlock phone
     - Find the app
     - Open it
     - Wait for it to load
     - Find the permission request
     - Respond
   - This is too many steps for a simple "yes, go ahead" decision

### User Quotes (Hypothetical)

> "I sent Claude a task to run my tests and went to Slack. Ten minutes later I remembered and checked back — the tests finished 8 minutes ago. I wasted all that time."

> "Claude asked for permission to install a package and I didn't see it because I was on a call. My whole task got stuck."

> "I wish I could just glance at my Lock Screen and see if Claude is done yet, like I do with my Uber driver."

---

## Goals

### Primary Goals

1. **Never leave Claude idle** — Users are immediately notified when Claude needs their input
2. **Glanceable status** — Users can see Claude's state from their Lock Screen without unlocking
3. **One-tap responses** — Users can approve or deny permission requests from notifications
4. **Peace of mind** — Users can confidently leave the app knowing they'll be notified

### Success Metrics

| Metric | Target | How We'll Measure |
|--------|--------|-------------------|
| Missed permission requests | 0% | Track approvals that time out without response |
| Notification delivery time | < 5 seconds | Measure time from event to notification display |
| User awareness | 100% | Users always know current task status |
| Return-to-app time | < 10 seconds | Time from notification to user action |

### Non-Goals

- We are NOT building an Apple Watch app (may consider later)
- We are NOT showing every small action Claude takes (too noisy)
- We are NOT adding custom notification sounds (use system defaults)
- We are NOT monitoring SSH connections (only Claude tasks)

---

## User Personas

### Primary Persona: Alex, Mobile Developer

**Background:** Alex is a senior iOS developer who uses Claude Code on their Mac at their desk. They recently started using CodingBridge to interact with Claude from their iPhone when away from their desk — in meetings, on the couch, or during lunch.

**Behaviors:**
- Sends Claude tasks and then switches to other apps
- Checks phone frequently throughout the day
- Values efficiency and hates wasted time
- Uses Do Not Disturb during focus time

**Goals:**
- Stay productive while away from desk
- Not miss important Claude events
- Respond quickly when Claude needs input

**Frustrations:**
- "I never know if Claude is done"
- "I miss permission requests when I'm in other apps"
- "I have to keep checking back manually"

### Secondary Persona: Sam, Backend Engineer

**Background:** Sam uses Claude for complex backend tasks like database migrations, API refactoring, and test suite runs. These tasks can take 5-15 minutes.

**Behaviors:**
- Kicks off long-running tasks and walks away
- Uses iPad and iPhone throughout the day
- Often in meetings or pair programming

**Goals:**
- Know when long tasks finish
- Not block teammates waiting for Claude to complete
- Respond to permissions from any device

**Frustrations:**
- "My test suite takes 10 minutes and I never know when it's done"
- "I started a refactor before a meeting and forgot about it"
- "I have to keep the app open to see progress"

---

## User Stories

### Epic 1: Stay Informed While Away

#### US-1.1: See Claude's Status on Lock Screen
**As a** user who has sent Claude a task,
**I want to** see Claude's current status on my Lock Screen,
**So that** I can check progress with a quick glance without unlocking my phone.

**Acceptance Criteria:**
- When I send Claude a task and lock my phone, I see a status indicator on my Lock Screen
- The status shows the project name, what Claude is doing, and how long it's been running
- The status updates as Claude works (e.g., "Running tests...", "Building project...")
- When Claude finishes, the status shows completion

#### US-1.2: See Claude's Status in Dynamic Island
**As a** user with an iPhone that has Dynamic Island,
**I want to** see Claude's status in the Dynamic Island,
**So that** I can monitor progress while using other apps.

**Acceptance Criteria:**
- While Claude is working, I see a small indicator in the Dynamic Island
- Tapping the Dynamic Island expands to show more details
- The expanded view shows project name, current action, and elapsed time
- The indicator shows different colors/icons for different states (working, waiting, done)

#### US-1.3: Know When Claude Finishes
**As a** user who sent Claude a task,
**I want to** be notified when Claude finishes,
**So that** I can review the results and continue my work.

**Acceptance Criteria:**
- When Claude finishes a task, I receive a notification
- The notification tells me the task succeeded or failed
- The notification shows a brief summary if available
- Tapping the notification opens the app to the completed session

#### US-1.4: Know When Something Goes Wrong
**As a** user who sent Claude a task,
**I want to** be notified if something goes wrong,
**So that** I can address the issue quickly.

**Acceptance Criteria:**
- If Claude encounters an error, I receive a notification
- The notification tells me something went wrong
- Tapping the notification opens the app to see error details
- I'm not bombarded with notifications for every small issue

### Epic 2: Respond to Claude Without Opening App

#### US-2.1: Approve Permissions from Lock Screen
**As a** user who is away from the app,
**I want to** approve Claude's permission requests from my Lock Screen,
**So that** I don't have to open the app for simple yes/no decisions.

**Acceptance Criteria:**
- When Claude needs permission, I receive a notification with "Approve" and "Deny" buttons
- The notification shows what Claude wants to do (e.g., "Run command: npm test")
- Tapping "Approve" lets Claude continue immediately
- Tapping "Deny" tells Claude to skip that action
- Tapping the notification body opens the app for more context

#### US-2.2: Quick Deny for Unwanted Actions
**As a** user who sees Claude requesting something I don't want,
**I want to** deny it quickly from the notification,
**So that** Claude doesn't do something I'll have to undo.

**Acceptance Criteria:**
- The "Deny" button is easily accessible
- Tapping "Deny" immediately stops that specific action
- Claude acknowledges the denial and continues with other work if possible
- I don't need to open the app to deny

#### US-2.3: See What I'm Approving
**As a** user who receives an approval request,
**I want to** understand what I'm approving before deciding,
**So that** I can make an informed decision without opening the app.

**Acceptance Criteria:**
- The notification shows the type of action (run command, write file, etc.)
- The notification shows a summary of the specific action
- For sensitive actions, I can expand the notification for more details
- The information is clear enough to decide without opening the app

#### US-2.4: Timeout for Unanswered Requests
**As a** user who might miss or ignore a permission request,
**I want** Claude to eventually move on after waiting a reasonable time,
**So that** my task isn't stuck forever waiting for me.

**Acceptance Criteria:**
- If I don't respond to a permission request within 60 seconds, Claude times out
- Claude logs that the request timed out
- Claude continues with other work if possible
- The notification is cleared from my device
- I can see in the app that a request timed out

### Epic 3: Track Progress on Long Tasks

#### US-3.1: See Progress on Multi-Step Tasks
**As a** user who sent Claude a multi-step task,
**I want to** see how far along Claude is,
**So that** I have realistic expectations about when it will finish.

**Acceptance Criteria:**
- When Claude has a todo list (multiple steps), I see progress like "3 of 7 tasks"
- The current task name is visible
- Progress updates as Claude completes each step
- I can see this on Lock Screen without unlocking

#### US-3.2: See Elapsed Time
**As a** user waiting for Claude,
**I want to** see how long Claude has been working,
**So that** I know if something might be stuck.

**Acceptance Criteria:**
- The Lock Screen status shows elapsed time (e.g., "2:45")
- The time updates in real-time
- If a task runs unusually long, I'm informed

#### US-3.3: Get Notified for Very Long Tasks
**As a** user who started a task that's taking over an hour,
**I want to** be reminded that it's still running,
**So that** I don't forget about it entirely.

**Acceptance Criteria:**
- If a task runs for over 1 hour, I receive a reminder notification
- The notification tells me the task is still running
- I can see the elapsed time and what Claude is currently doing
- This helps me notice if something might be stuck

### Epic 4: Control My Notification Preferences

#### US-4.1: Enable/Disable Background Features
**As a** user who wants control over notifications,
**I want to** choose which background features are enabled,
**So that** I can customize the experience to my preferences.

**Acceptance Criteria:**
- Settings include toggles for: Live Activities, Background Notifications
- I can disable features I don't want
- Disabled features stay off until I re-enable them
- Default is enabled for best experience

#### US-4.2: Control Lock Screen Privacy
**As a** user who cares about privacy,
**I want to** hide sensitive details from my Lock Screen,
**So that** others can't see what Claude is doing.

**Acceptance Criteria:**
- Setting to show/hide details on Lock Screen
- When hidden, Lock Screen shows generic "Claude needs attention" instead of commands
- I can still see full details when I open the app
- Default is to hide details for privacy

#### US-4.3: Allow Important Notifications During Focus
**As a** user who uses Do Not Disturb,
**I want** critical notifications (like permission requests) to still reach me,
**So that** Claude doesn't get stuck while I'm in focus mode.

**Acceptance Criteria:**
- Permission requests are marked as "Time Sensitive"
- They appear even when Do Not Disturb is on
- I can disable this if I prefer complete silence
- Regular completion notifications respect Do Not Disturb

#### US-4.4: See Permission Status in Settings
**As a** user setting up the app,
**I want to** see if notifications are properly configured,
**So that** I know I won't miss important events.

**Acceptance Criteria:**
- Settings show current notification permission status
- Settings show if Live Activities are enabled
- If something is disabled, I see how to enable it
- "Open Settings" button takes me to iOS Settings if needed

### Epic 5: Handle Edge Cases Gracefully

#### US-5.1: Resume After Losing Connection
**As a** user whose connection dropped while Claude was working,
**I want** the app to recover gracefully,
**So that** I don't lose my work or get confused about status.

**Acceptance Criteria:**
- If connection drops, the app tries to reconnect automatically
- Status updates resume when connection is restored
- I'm only notified if reconnection fails after several attempts
- My pending messages are preserved and resent

#### US-5.2: Handle App Being Closed
**As a** user who force-closes the app while Claude is working,
**I want to** see what happened when I reopen the app,
**So that** I can pick up where I left off.

**Acceptance Criteria:**
- When I reopen the app after force-closing, I see if Claude was working
- If Claude needed permission, I see the pending request
- If Claude finished, I see the results
- The app helps me understand what happened while it was closed

#### US-5.3: Handle No Internet
**As a** user who approves a request while offline,
**I want** my approval to be sent when I'm back online,
**So that** my response isn't lost.

**Acceptance Criteria:**
- If I tap "Approve" with no internet, the app queues my response
- I see confirmation that it will be sent when online
- When connection returns, the approval is sent automatically
- I'm notified if the request expired before I got back online

#### US-5.4: Use Multiple Devices
**As a** user with iPhone and iPad,
**I want** notifications to be synchronized across devices,
**So that** I don't see stale requests after responding on another device.

**Acceptance Criteria:**
- If I approve on iPhone, the notification clears on iPad
- Both devices show the same current status
- I don't accidentally approve twice from different devices

#### US-5.5: Switch Between App and Desktop
**As a** user who starts a task on iPhone then opens my Mac,
**I want** my iPhone to know the session moved,
**So that** I don't have conflicting notifications.

**Acceptance Criteria:**
- If I continue the session on Mac, my iPhone notification updates
- The Lock Screen status shows "Continued on another device"
- I don't get stuck notifications for an old session

### Epic 6: First-Time Setup

#### US-6.1: Request Notification Permission
**As a** new user,
**I want** the app to explain why it needs notification permission,
**So that** I understand the value before granting access.

**Acceptance Criteria:**
- Before requesting permission, the app explains the benefits
- I understand that notifications tell me when Claude needs me
- The permission request happens at an appropriate time (not immediately on launch)
- If I deny, the app works but shows me what I'm missing

#### US-6.2: Request Live Activity Permission
**As a** new user,
**I want** to understand what Live Activities are,
**So that** I can decide if I want them enabled.

**Acceptance Criteria:**
- The app explains Live Activities in simple terms
- I understand they show status on my Lock Screen
- I can enable or disable them in settings
- The app works fine without them, just with less visibility

#### US-6.3: Onboarding for Background Features
**As a** new user,
**I want** a brief explanation of background features,
**So that** I know what to expect when I leave the app.

**Acceptance Criteria:**
- During onboarding, I learn about Lock Screen status
- I learn about notification actions (Approve/Deny)
- I understand I'll be notified when Claude needs me
- The explanation is brief and skippable

---

## User Flows

### Flow 1: Happy Path — Task Completes While Away

```
User opens app
    ↓
User sends Claude a task
    ↓
User locks phone / switches to another app
    ↓
Lock Screen shows Claude working (project name, elapsed time)
    ↓
Claude finishes task
    ↓
User receives notification: "Task Complete"
    ↓
User taps notification
    ↓
App opens to completed session
```

### Flow 2: Permission Request While Away

```
User sends Claude a task and locks phone
    ↓
Claude needs permission to run a command
    ↓
User receives notification with Approve/Deny buttons
    ↓
User reads summary: "Run: npm test"
    ↓
User taps "Approve" (without unlocking)
    ↓
Claude continues
    ↓
Lock Screen status updates to "Running tests..."
    ↓
Task completes
    ↓
User receives completion notification
```

### Flow 3: User Misses Permission Request

```
User sends Claude a task
    ↓
Claude needs permission
    ↓
Notification sent, but user is busy
    ↓
60 seconds pass with no response
    ↓
Claude times out and logs the skip
    ↓
Notification is cleared
    ↓
When user checks, they see timeout in history
```

### Flow 4: User Denies Permission

```
Claude requests permission: "Delete all test files"
    ↓
User sees notification
    ↓
User taps "Deny"
    ↓
Claude acknowledges: "Okay, I'll skip that action"
    ↓
Claude continues with other work
    ↓
User sees in history that they denied the action
```

### Flow 5: Long-Running Task with Progress

```
User sends: "Run all tests and fix any failures"
    ↓
Claude creates todo list: 5 items
    ↓
User locks phone
    ↓
Lock Screen shows: "1 of 5 tasks • Running unit tests..."
    ↓
Progress updates: "2 of 5 tasks • Fixing auth test..."
    ↓
Progress updates: "3 of 5 tasks..."
    ↓
Task completes after 8 minutes
    ↓
User receives: "Task Complete — All tests passing"
```

---

## Feature Requirements

### Lock Screen Status

**What users see:**
- Project name (e.g., "MyApp")
- Current action (e.g., "Running tests...")
- Elapsed time (e.g., "3:42")
- Progress indicator if multi-step (e.g., "3 of 7")
- Status color (blue = working, orange = waiting, green = done, red = error)

**What users can do:**
- Tap to open app
- See Approve/Deny buttons when permission needed

### Notifications

**Types of notifications:**

| Event | Title | Body Example | Actions |
|-------|-------|--------------|---------|
| Permission needed | "Approval Needed" | "Run: npm test" | Approve, Deny |
| Question asked | "Claude has a question" | "Which database should we use?" | Open App |
| Task complete | "Task Complete" | "All tests passed" | None |
| Task failed | "Task Failed" | "Build error occurred" | Open App |
| Task paused | "Task Paused" | "Open app to continue" | Open App |

**Notification behavior:**
- Sound: System default for important events, silent for status updates
- Badge: Shows count of pending actions
- Grouping: Multiple notifications from same session are grouped

### Settings

**User-controllable options:**
- Enable/disable Live Activities (Lock Screen status)
- Enable/disable background notifications
- Show/hide details on Lock Screen (privacy)
- Allow notifications during Focus mode
- Continue in Low Power Mode (may affect battery)

---

## Out of Scope

The following are explicitly NOT part of this project:

1. **Apple Watch app** — Future consideration, not now
2. **Custom notification sounds** — Use system defaults
3. **Rich media in notifications** — Keep it simple text
4. **SSH operation monitoring** — Only Claude tasks, not SSH
5. **Real-time code preview** — Just status, not actual code
6. **Siri integration** — Future enhancement
7. **Widget on Home Screen** — Future enhancement (Phase 4)
8. **Android version** — iOS only

---

## Dependencies

### What We Need From Engineering

1. **Backend changes** — Server needs to send push notifications
2. **Apple Developer setup** — Push notification certificates, App Groups
3. **Widget extension** — Separate target for Lock Screen display

### What We Need From Design

1. **Lock Screen layouts** — Compact and expanded views
2. **Notification copy** — Clear, concise wording for all notification types
3. **Settings screen** — New section for background preferences
4. **Status icons/colors** — Visual language for different states

### External Dependencies

1. **Apple Push Notification service** — For remote notifications
2. **User's iOS settings** — Notification and Live Activity permissions

---

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| User denies notification permission | Can't notify when Claude needs input | Medium | Clear value prop during onboarding, settings remind user |
| iOS limits background time | Status might become stale | Medium | Use push notifications as backup |
| Push notifications delayed | User doesn't respond in time | Low | 60-second timeout is forgiving, local notifications as primary |
| Battery drain concerns | Users disable features | Low | Optimize for efficiency, test battery impact |
| Notification overload | Users turn off all notifications | Medium | Only notify for important events, no spam |

---

## Success Criteria

### Must Have (Launch Blocker)

- [ ] Users see Claude's status on Lock Screen while task is running
- [ ] Users receive notification when Claude needs permission
- [ ] Users can approve/deny from notification without opening app
- [ ] Users receive notification when task completes
- [ ] Settings allow users to control notification preferences

### Should Have (High Priority)

- [ ] Progress indicator for multi-step tasks
- [ ] Elapsed time display
- [ ] Privacy option to hide details on Lock Screen
- [ ] Notifications work during Do Not Disturb (time-sensitive)
- [ ] Graceful handling of permission request timeouts

### Nice to Have (If Time Permits)

- [ ] Multiple device synchronization
- [ ] Session handoff awareness
- [ ] Long-running task reminders (>1 hour)
- [ ] Offline approval queuing

---

## Timeline

### Phase 1: Foundation (First)
- Basic notification system
- "Task complete" and "Task failed" notifications
- Approval request notifications with actions
- Settings for notification preferences

### Phase 2: Lock Screen Status (Second)
- Live Activity showing Claude's status
- Dynamic Island support
- Progress indicators
- Elapsed time display

### Phase 3: Advanced Features (Third)
- Push notifications when app is fully closed
- Multi-device notification clearing
- Permission request timeouts
- Offline approval queuing

### Phase 4: Future Enhancements (Later)
- Home Screen widget
- Apple Watch support
- Siri Shortcuts
- Custom notification sounds

---

## Open Questions

1. **What should happen if Claude times out waiting?**
   - Decision: Claude continues with other work, logs the skip

2. **Should we notify for EVERY permission or just important ones?**
   - Decision: Notify for all, users can see what Claude wants to do

3. **How long should we wait before timing out?**
   - Decision: 60 seconds — long enough to respond, short enough to not block

4. **Should Lock Screen show actual commands?**
   - Decision: User choice — default to hidden for privacy, can enable in settings

---

## Appendix: Glossary

| Term | Definition |
|------|------------|
| Live Activity | iOS feature showing real-time status on Lock Screen and Dynamic Island |
| Dynamic Island | The pill-shaped area at top of newer iPhones that shows activity |
| Permission Request | When Claude asks user's approval before running a command or accessing something |
| Push Notification | Notification sent from server, works even when app is closed |
| Local Notification | Notification created by the app itself, requires app to be running |
| Focus Mode | iOS feature (formerly Do Not Disturb) that silences notifications |
| Time-Sensitive | Notification type that can break through Focus Mode |
| Session | A conversation with Claude about a specific project |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | Dec 2024 | Product | Initial draft |
