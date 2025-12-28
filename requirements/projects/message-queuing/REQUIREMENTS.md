# Message Queuing Requirements

## Functional Requirements

### FR-1: Automatic Queuing

**FR-1.1** When the agent is busy and user sends a message, the message MUST be added to the queue automatically (no explicit "queue" action needed).

**FR-1.2** "Busy" state is defined as ANY of:
- `isProcessing == true` (response streaming)
- `isToolExecuting == true` (tool running)
- `isPendingApproval == true` (awaiting user approval)

**FR-1.3** When not busy, messages MUST be sent immediately (bypass queue).

**FR-1.4** Visual feedback MUST indicate the message was queued, not sent.

### FR-2: Queue Execution

**FR-2.1** Queued messages MUST execute in FIFO order by default.

**FR-2.2** Urgent messages MUST execute before non-urgent messages (priority queue).

**FR-2.3** Queue processing MUST start automatically when busy state ends.

**FR-2.4** Only ONE message from queue is processed at a time.

**FR-2.5** Next message MUST NOT be sent until `claude-complete` or `claude-error` received.

### FR-3: Queue Persistence

**FR-3.1** Queue MUST be saved to disk when messages are added/removed/modified.

**FR-3.2** Queue MUST be restored on app launch.

**FR-3.3** Queue is per-session (each session has its own queue).

**FR-3.4** Storage location: `Documents/queue-{sessionId}.json`

**FR-3.5** Queue data MUST include: message content, priority, timestamp, attachments.

### FR-4: Queue Size Limits

**FR-4.1** Default maximum queue size: 10 messages.

**FR-4.2** Maximum queue size MUST be configurable in settings (range: 5-20).

**FR-4.3** When queue is full, new messages MUST be rejected with clear error.

**FR-4.4** User MUST be warned when queue reaches 80% capacity.

### FR-5: Queue Management

**FR-5.1** User MUST be able to cancel (remove) individual queued messages.

**FR-5.2** User MUST be able to cancel all queued messages at once.

**FR-5.3** User MUST be able to reorder queued messages via drag-and-drop.

**FR-5.4** User MUST be able to edit queued message content before execution.

**FR-5.5** Cancelled messages MUST be removed from persistence immediately.

### FR-6: Priority System

**FR-6.1** Messages have two priority levels: normal and urgent.

**FR-6.2** Urgent messages MUST be inserted at the front of the queue.

**FR-6.3** Multiple urgent messages maintain FIFO order among themselves.

**FR-6.4** User can promote a normal message to urgent via queue panel.

**FR-6.5** User can demote an urgent message to normal via queue panel.

### FR-7: Error Handling

**FR-7.1** When a queued message fails, queue processing MUST stop.

**FR-7.2** Failed message MUST remain at front of queue with error indicator.

**FR-7.3** User MUST be notified of the failure via alert or banner.

**FR-7.4** User can choose to: retry, skip, edit, or cancel the failed message.

**FR-7.5** Retry uses existing exponential backoff (1s, 2s, 4s, max 3 attempts).

### FR-8: Attachments

**FR-8.1** Queued messages MAY include image attachments.

**FR-8.2** Attachment data MUST be persisted with the queued message.

**FR-8.3** Queue panel MUST show attachment indicator for messages with images.

---

## Non-Functional Requirements

### NFR-1: Performance

**NFR-1.1** Adding to queue MUST complete in < 100ms.

**NFR-1.2** Queue persistence MUST NOT block UI thread.

**NFR-1.3** Queue restore on launch MUST complete in < 500ms.

### NFR-2: Reliability

**NFR-2.1** Queue MUST survive app crashes (persist on every change).

**NFR-2.2** Corrupt queue file MUST be handled gracefully (start fresh, log error).

**NFR-2.3** Queue state MUST be consistent between UI and storage.

### NFR-3: Usability

**NFR-3.1** Queue panel MUST be accessible in < 2 taps from chat view.

**NFR-3.2** Queue status MUST be visible without opening panel (badge/indicator).

**NFR-3.3** Queuing MUST feel seamless - no extra steps to queue vs send.

### NFR-4: Accessibility

**NFR-4.1** Queue panel MUST support VoiceOver.

**NFR-4.2** Queue actions MUST have accessibility labels.

**NFR-4.3** Drag-to-reorder MUST have accessible alternative (move up/down buttons).

---

## Data Model

```swift
struct QueuedMessage: Identifiable, Codable {
    let id: UUID
    var content: String
    let projectPath: String
    let sessionId: String
    var priority: MessagePriority
    let createdAt: Date
    var imageData: Data?
    var attempts: Int
    var lastError: String?

    enum MessagePriority: String, Codable {
        case normal
        case urgent
    }
}
```

## State Machine

```
                    ┌─────────────────────────────────────┐
                    │                                     │
                    ▼                                     │
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌────────┴─┐
│  Empty   │───▶│ Queued   │───▶│Executing │───▶│ Complete │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
                    │                 │
                    │                 │ (error)
                    │                 ▼
                    │           ┌──────────┐
                    │           │  Failed  │
                    │           └──────────┘
                    │                 │
                    │◀────────────────┘ (retry/skip/edit)
```

## User Stories

### US-1: Queue While Typing
> As a user, I want to continue typing while Claude responds, so I don't lose my train of thought.

### US-2: Batch Commands
> As a user, I want to queue up multiple commands while Claude works, so I can walk away and let them execute.

### US-3: Manage Queue
> As a user, I want to see and manage my pending messages, so I can change my mind before they execute.

### US-4: Urgent Override
> As a user, I want to send an urgent message that jumps the queue, so I can interrupt with critical requests.

### US-5: Resume After Restart
> As a user, I want my queued messages to survive app restarts, so I don't lose pending work.
