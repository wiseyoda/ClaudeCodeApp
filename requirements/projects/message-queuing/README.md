# Message Queuing Feature

Queue messages while the agent is busy, executing them in FIFO order with optional priority support.

## Problem Statement

Currently, the iOS app blocks all input while Claude is processing a message. Users must wait for each response before sending the next prompt. This interrupts workflow when users have multiple related tasks or want to batch commands.

## Solution

Implement client-side message queuing that:
- Automatically queues messages sent while the agent is busy
- Executes queued messages in FIFO order (with optional urgent priority)
- Persists queue across app restarts
- Provides a collapsible queue management panel

## Key Requirements

| Requirement | Decision |
|-------------|----------|
| Implementation scope | iOS client only (backend unchanged) |
| Queue display | Collapsible panel, separate from chat |
| Persistence | Saved to disk, restored on launch |
| Max queue size | 5-10 messages (configurable) |
| Error handling | Stop queue on failure, let user decide |
| Priority support | Yes - urgent messages can jump queue |
| Input method | Auto-queue when busy (seamless UX) |
| Feedback | Visual indicators + haptic feedback |

## Busy State Definition

The app is considered "busy" (queuing active) when ANY of these are true:
- Response streaming in progress
- Tool execution running (Bash, Edit, Read, etc.)
- Pending approval waiting for user action

## Queue Management Capabilities

- Cancel individual messages
- Cancel all (clear queue)
- Reorder messages (drag to change order)
- Edit queued message content before execution

## Research Findings

**Backend**: Does NOT support concurrent message processing. Single-stream model expects one message at a time with response before next.

**Existing Code**: `CLIBridgeManager.swift` handles message sending. (Note: `MessageQueuePersistence.swift` was removed in codebase simplification #25 as it was dead code - queuing would need to be implemented from scratch.)

**Current Behavior**: UI completely blocks input via `isProcessing` flag. Need to change this to allow input that queues instead.

## Documents

| Document | Purpose |
|----------|---------|
| [REQUIREMENTS.md](./REQUIREMENTS.md) | Detailed functional requirements |
| [ARCHITECTURE.md](./ARCHITECTURE.md) | Technical design and data flows |
| [IMPLEMENTATION-PLAN.md](./IMPLEMENTATION-PLAN.md) | Step-by-step build plan |
| [UI-SPEC.md](./UI-SPEC.md) | UI/UX design specification |

## Success Criteria

1. User can type and send messages while agent is processing
2. Messages execute in order after current response completes
3. Queue survives app restart
4. User can cancel, reorder, and edit queued messages
5. Urgent messages can jump to front of queue
6. Queue panel is unobtrusive but accessible
