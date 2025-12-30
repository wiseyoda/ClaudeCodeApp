# Message Queuing Architecture

## Overview

Client-side message queue implemented entirely in the iOS app. The backend and Claude CLI remain unchanged - they continue to expect sequential message processing.

## System Context

```
┌─────────────────────────────────────────────────────────────────┐
│                         iOS App                                  │
│                                                                 │
│  ┌─────────────┐    ┌──────────────┐    ┌──────────────────┐   │
│  │  ChatView   │───▶│ MessageQueue │───▶│ CLIBridgeAdapter │   │
│  │  (Input)    │    │   Manager    │    │   (Send)         │   │
│  └─────────────┘    └──────────────┘    └──────────────────┘   │
│         │                  │                     │              │
│         │                  │                     ▼              │
│         │                  │            ┌──────────────┐        │
│         │                  │            │  SSE Stream  │        │
│         │                  │            └──────────────┘        │
│         │                  ▼                     │              │
│         │          ┌──────────────┐              │              │
│         │          │  Persistence │              │              │
│         │          │  (Documents) │              │              │
│         │          └──────────────┘              │              │
│         │                                        │              │
│         ▼                                        ▼              │
│  ┌─────────────┐                        ┌──────────────┐        │
│  │ QueuePanel  │                        │  cli-bridge  │        │
│  │   (UI)      │                        │ (unchanged)  │        │
│  └─────────────┘                        └──────────────┘        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### MessageQueueManager

New `@MainActor` class that owns the queue state and coordinates between UI and SSE streaming.

```swift
@MainActor
class MessageQueueManager: ObservableObject {
    // Published state for UI binding
    @Published private(set) var queue: [QueuedMessage] = []
    @Published private(set) var isExecuting: Bool = false
    @Published private(set) var currentError: QueueError?

    // Configuration
    var maxQueueSize: Int = 10

    // Dependencies
    private let bridgeAdapter: CLIBridgeAdapter
    private let persistence: QueuePersistence

    // Core operations
    func enqueue(_ message: QueuedMessage) throws
    func dequeue(id: UUID)
    func dequeueAll()
    func reorder(from: IndexSet, to: Int)
    func edit(id: UUID, newContent: String)
    func setPriority(id: UUID, priority: MessagePriority)

    // Execution control
    func processNext()
    func retry()
    func skip()
    func pause()
    func resume()
}
```

### QueuePersistence

Handles saving/loading queue to disk. Async file I/O to avoid blocking UI.

```swift
actor QueuePersistence {
    private let baseURL: URL

    func save(_ queue: [QueuedMessage], sessionId: String) async throws
    func load(sessionId: String) async throws -> [QueuedMessage]
    func delete(sessionId: String) async throws
}
```

### BusyStateAggregator

Combines multiple busy signals into single state for queue gating.

```swift
@MainActor
class BusyStateAggregator: ObservableObject {
    @Published private(set) var isBusy: Bool = false

    // Input signals
    var isProcessing: Bool = false { didSet { updateBusy() } }
    var isToolExecuting: Bool = false { didSet { updateBusy() } }
    var isPendingApproval: Bool = false { didSet { updateBusy() } }

    private func updateBusy() {
        isBusy = isProcessing || isToolExecuting || isPendingApproval
    }
}
```

## Data Flow

### Sending a Message (Normal Flow)

```
User types message
        │
        ▼
┌───────────────────┐
│ Is agent busy?    │
└───────────────────┘
        │
    ┌───┴───┐
    │       │
   Yes      No
    │       │
    ▼       ▼
┌───────┐ ┌────────────────┐
│ Queue │ │ Send directly  │
│ it    │ │ via SSE stream │
└───────┘ └────────────────┘
    │
    ▼
┌───────────────────┐
│ Persist to disk   │
└───────────────────┘
    │
    ▼
┌───────────────────┐
│ Update UI         │
│ (show in panel)   │
└───────────────────┘
```

### Queue Processing (Execution Flow)

```
Agent becomes idle (claude-complete received)
        │
        ▼
┌───────────────────┐
│ Queue empty?      │
└───────────────────┘
        │
    ┌───┴───┐
    │       │
   Yes      No
    │       │
    ▼       ▼
┌───────┐ ┌────────────────┐
│ Done  │ │ Pop front msg  │
└───────┘ └────────────────┘
                │
                ▼
        ┌───────────────────┐
        │ Send via          │
        │ SSE stream        │
        └───────────────────┘
                │
                ▼
        ┌───────────────────┐
        │ Set isExecuting   │
        │ = true            │
        └───────────────────┘
                │
        ┌───────┴───────┐
        │               │
    Success          Failure
        │               │
        ▼               ▼
┌───────────────┐ ┌───────────────┐
│ Remove from   │ │ Stop queue    │
│ queue+disk    │ │ Show error    │
└───────────────┘ └───────────────┘
        │
        ▼
┌───────────────────┐
│ Haptic feedback   │
└───────────────────┘
        │
        ▼
    (repeat)
```

## File Changes

### New Files

| File | Purpose |
|------|---------|
| `MessageQueueManager.swift` | Queue state and operations |
| `QueuePersistence.swift` | Disk I/O for queue data |
| `BusyStateAggregator.swift` | Combines busy signals |
| `QueuedMessage.swift` | Data model (or add to Models.swift) |
| `Views/QueuePanelView.swift` | Collapsible queue UI |
| `Views/QueuedMessageRow.swift` | Individual message row |

### Modified Files

| File | Changes |
|------|---------|
| `CLIBridgeAdapter.swift` | Expose busy signals, add queue integration hooks |
| `CLIBridgeManager.swift` | Add callbacks for processing completion |
| `ChatView.swift` | Replace direct send with queue-aware send |
| `CLIInputView.swift` | Remove `isProcessing` disable, add urgent toggle |
| `AppSettings.swift` | Add `maxQueueSize` setting |
| `CodingBridgeApp.swift` | Inject MessageQueueManager into environment |

## Integration Points

### CLIBridgeAdapter Integration

```swift
// CLIBridgeAdapter.swift additions

// Expose busy state signals
@Published var isToolExecuting: Bool = false
@Published var isPendingApproval: Bool = false

// Callback when processing completes (success or error)
var onProcessingComplete: ((Result<Void, Error>) -> Void)?

// In SSE event handlers:
// tool_use event:
    isToolExecuting = true
// tool_result event:
    isToolExecuting = false
// permission_request event:
    isPendingApproval = true
// permission_response:
    isPendingApproval = false
// result event:
    onProcessingComplete?(.success(()))
// error event:
    onProcessingComplete?(.failure(error))
```

### ChatView Integration

```swift
// ChatView.swift changes

@StateObject private var queueManager = MessageQueueManager()

func sendMessage(_ content: String, urgent: Bool = false) {
    let message = QueuedMessage(
        content: content,
        projectPath: projectPath,
        sessionId: sessionId,
        priority: urgent ? .urgent : .normal
    )

    if busyState.isBusy {
        try? queueManager.enqueue(message)
    } else {
        bridgeAdapter.sendMessage(content, ...)
    }
}
```

## Persistence Format

Queue file: `Documents/queue-{sessionId}.json`

```json
{
  "version": 1,
  "sessionId": "abc123",
  "messages": [
    {
      "id": "uuid-1",
      "content": "Run the tests",
      "projectPath": "/Users/dev/project",
      "sessionId": "abc123",
      "priority": "normal",
      "createdAt": "2024-01-15T10:30:00Z",
      "imageData": null,
      "attempts": 0,
      "lastError": null
    },
    {
      "id": "uuid-2",
      "content": "Fix the type errors",
      "projectPath": "/Users/dev/project",
      "sessionId": "abc123",
      "priority": "urgent",
      "createdAt": "2024-01-15T10:31:00Z",
      "imageData": "base64...",
      "attempts": 0,
      "lastError": null
    }
  ]
}
```

## Error Handling

### Queue Full

```swift
enum QueueError: Error {
    case queueFull(current: Int, max: Int)
    case messageNotFound(id: UUID)
    case persistenceFailed(underlying: Error)
    case executionFailed(message: String)
}

// When queue is full:
throw QueueError.queueFull(current: queue.count, max: maxQueueSize)
// UI shows: "Queue full (10/10). Cancel a message or wait for one to complete."
```

### Execution Failure

1. Mark message with `lastError`
2. Set `isExecuting = false`
3. Keep message at front of queue
4. Publish `currentError` for UI to display
5. Wait for user action (retry/skip/edit/cancel)

## Thread Safety

- `MessageQueueManager` is `@MainActor` - all state access is main-thread-safe
- `QueuePersistence` is an `actor` - file I/O is serialized and async
- UI bindings via `@Published` automatically dispatch to main thread

## Testing Strategy

| Test Type | Focus |
|-----------|-------|
| Unit | Queue operations (enqueue, dequeue, reorder, priority) |
| Unit | Persistence save/load/corruption handling |
| Unit | Busy state aggregation |
| Integration | Queue + SSE stream flow |
| UI | Queue panel interactions |
