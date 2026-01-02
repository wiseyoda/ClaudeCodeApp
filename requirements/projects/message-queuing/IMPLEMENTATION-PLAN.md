# Message Queuing Implementation Plan

## Phase 1: Foundation

Build core queue infrastructure without UI. Queue works programmatically.

### Step 1.1: Data Model

Create `QueuedMessage` model with all required fields.

**File:** `CodingBridge/Models.swift` (add to existing)

```swift
struct QueuedMessage: Identifiable, Codable, Equatable {
    let id: UUID
    var content: String
    let projectPath: String
    let sessionId: String
    var priority: MessagePriority
    let createdAt: Date
    var imageData: Data?
    var attempts: Int
    var lastError: String?

    enum MessagePriority: String, Codable, CaseIterable {
        case normal
        case urgent
    }

    init(
        id: UUID = UUID(),
        content: String,
        projectPath: String,
        sessionId: String,
        priority: MessagePriority = .normal,
        imageData: Data? = nil
    ) {
        self.id = id
        self.content = content
        self.projectPath = projectPath
        self.sessionId = sessionId
        self.priority = priority
        self.createdAt = Date()
        self.imageData = imageData
        self.attempts = 0
        self.lastError = nil
    }
}
```

**Tests:** `CodingBridgeTests/QueuedMessageTests.swift`
- Codable round-trip
- Equality
- Default values

---

### Step 1.2: Queue Persistence

Create actor for async file I/O.

**File:** `CodingBridge/Utilities/QueuePersistence.swift`

```swift
actor QueuePersistence {
    private let fileManager = FileManager.default

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func fileURL(for sessionId: String) -> URL {
        documentsURL.appendingPathComponent("queue-\(sessionId).json")
    }

    func save(_ messages: [QueuedMessage], sessionId: String) async throws {
        let url = fileURL(for: sessionId)
        let data = try JSONEncoder().encode(messages)
        try data.write(to: url, options: .atomic)
    }

    func load(sessionId: String) async throws -> [QueuedMessage] {
        let url = fileURL(for: sessionId)
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([QueuedMessage].self, from: data)
    }

    func delete(sessionId: String) async throws {
        let url = fileURL(for: sessionId)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}
```

**Tests:** `CodingBridgeTests/QueuePersistenceTests.swift`
- Save and load round-trip
- Load non-existent returns empty array
- Delete removes file
- Corrupt file handling

---

### Step 1.3: Message Queue Manager

Core queue operations without WebSocket stream integration yet.

**File:** `CodingBridge/MessageQueueManager.swift`

```swift
@MainActor
class MessageQueueManager: ObservableObject {
    @Published private(set) var queue: [QueuedMessage] = []
    @Published private(set) var isExecuting: Bool = false
    @Published private(set) var currentError: QueueError?

    var maxQueueSize: Int = 10

    private let persistence = QueuePersistence()
    private var currentSessionId: String?

    // MARK: - Queue Operations

    func enqueue(_ message: QueuedMessage) throws {
        guard queue.count < maxQueueSize else {
            throw QueueError.queueFull(current: queue.count, max: maxQueueSize)
        }

        if message.priority == .urgent {
            // Insert after other urgent messages, before normal
            let insertIndex = queue.firstIndex { $0.priority == .normal } ?? queue.endIndex
            queue.insert(message, at: insertIndex)
        } else {
            queue.append(message)
        }

        currentSessionId = message.sessionId
        Task { try? await persist() }
    }

    func dequeue(id: UUID) {
        queue.removeAll { $0.id == id }
        Task { try? await persist() }
    }

    func dequeueAll() {
        queue.removeAll()
        Task { try? await persist() }
    }

    func reorder(from source: IndexSet, to destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
        Task { try? await persist() }
    }

    func edit(id: UUID, newContent: String) {
        guard let index = queue.firstIndex(where: { $0.id == id }) else { return }
        queue[index].content = newContent
        Task { try? await persist() }
    }

    func setPriority(id: UUID, priority: QueuedMessage.MessagePriority) {
        guard let index = queue.firstIndex(where: { $0.id == id }) else { return }
        var message = queue.remove(at: index)
        message.priority = priority
        try? enqueue(message)  // Re-insert with new priority
    }

    // MARK: - Persistence

    func loadQueue(sessionId: String) async {
        currentSessionId = sessionId
        do {
            queue = try await persistence.load(sessionId: sessionId)
        } catch {
            Logger.shared.error("Failed to load queue: \(error)")
            queue = []
        }
    }

    private func persist() async throws {
        guard let sessionId = currentSessionId else { return }
        try await persistence.save(queue, sessionId: sessionId)
    }

    // MARK: - Computed Properties

    var count: Int { queue.count }
    var isEmpty: Bool { queue.isEmpty }
    var isFull: Bool { queue.count >= maxQueueSize }
    var nextMessage: QueuedMessage? { queue.first }
}

enum QueueError: Error, LocalizedError {
    case queueFull(current: Int, max: Int)
    case messageNotFound(id: UUID)
    case persistenceFailed(underlying: Error)
    case executionFailed(message: String)

    var errorDescription: String? {
        switch self {
        case .queueFull(let current, let max):
            return "Queue full (\(current)/\(max))"
        case .messageNotFound:
            return "Message not found"
        case .persistenceFailed(let error):
            return "Failed to save queue: \(error.localizedDescription)"
        case .executionFailed(let message):
            return message
        }
    }
}
```

**Tests:** `CodingBridgeTests/MessageQueueManagerTests.swift`
- Enqueue adds to end
- Urgent enqueue inserts before normal
- Dequeue removes correct message
- Reorder works
- Edit updates content
- Priority change reorders
- Queue full throws error
- Persistence integration

---

## Phase 2: Busy State & CLI Bridge Integration

Connect queue to WebSocket streaming lifecycle.

### Step 2.1: Busy State Aggregator

Combine multiple busy signals.

**File:** `CodingBridge/Utilities/BusyStateAggregator.swift`

```swift
@MainActor
class BusyStateAggregator: ObservableObject {
    @Published private(set) var isBusy: Bool = false

    var isProcessing: Bool = false { didSet { update() } }
    var isToolExecuting: Bool = false { didSet { update() } }
    var isPendingApproval: Bool = false { didSet { update() } }

    private func update() {
        isBusy = isProcessing || isToolExecuting || isPendingApproval
    }
}
```

---

### Step 2.2: CLIBridgeManager Extensions

Add hooks for queue integration.

**File:** `CodingBridge/CLIBridgeManager.swift` (modify)

Changes:
1. Use existing `@Published var agentState: CLIAgentState` for busy detection
2. Use existing `@Published var pendingPermission: PermissionRequestMessage?` for approval state
3. Add `var onProcessingComplete: ((Result<Void, Error>) -> Void)?`
4. StreamEvent handlers already update agent state
5. Call `onProcessingComplete` on `.result` and `.error` events

---

### Step 2.3: Queue Execution Logic

Add execution flow to MessageQueueManager.

**Add to `MessageQueueManager.swift`:**

```swift
// MARK: - Execution

private weak var bridgeManager: CLIBridgeManager?

func configure(bridgeManager: CLIBridgeManager) {
    self.bridgeManager = bridgeManager
    bridgeManager.onProcessingComplete = { [weak self] result in
        Task { @MainActor in
            self?.handleProcessingComplete(result)
        }
    }
}

func processNext() {
    guard !isExecuting, let message = nextMessage else { return }

    isExecuting = true
    currentError = nil

    bridgeManager?.sendMessage(
        message.content,
        projectPath: message.projectPath,
        sessionId: message.sessionId,
        imageData: message.imageData
    )
}

private func handleProcessingComplete(_ result: Result<Void, Error>) {
    isExecuting = false

    switch result {
    case .success:
        // Remove completed message
        if let first = queue.first {
            queue.removeFirst()
            Task { try? await persist() }
            HapticManager.shared.notification(.success)
        }
        // Process next if any
        if !isEmpty {
            processNext()
        }

    case .failure(let error):
        // Mark message as failed
        if var first = queue.first {
            first.attempts += 1
            first.lastError = error.localizedDescription
            queue[0] = first
            Task { try? await persist() }
        }
        currentError = .executionFailed(message: error.localizedDescription)
        HapticManager.shared.notification(.error)
    }
}

func retry() {
    guard currentError != nil else { return }
    currentError = nil
    processNext()
}

func skip() {
    guard let first = queue.first else { return }
    dequeue(id: first.id)
    currentError = nil
    processNext()
}
```

---

## Phase 3: UI Integration

### Step 3.1: Settings Addition

**File:** `CodingBridge/AppSettings.swift` (modify)

```swift
@AppStorage("maxQueueSize") var maxQueueSize: Int = 10
```

Add UI in SettingsSheet for configuring queue size (5-20 range).

---

### Step 3.2: ChatView Integration

**File:** `CodingBridge/ChatView.swift` (modify)

1. Add `@StateObject private var queueManager = MessageQueueManager()`
2. Add `@StateObject private var busyState = BusyStateAggregator()`
3. Connect busyState to bridgeManager published properties
4. Replace direct send logic with queue-aware send:

```swift
func sendMessage(_ content: String, imageData: Data?, urgent: Bool = false) {
    let message = QueuedMessage(
        content: content,
        projectPath: projectPath,
        sessionId: currentSessionId,
        priority: urgent ? .urgent : .normal,
        imageData: imageData
    )

    if busyState.isBusy {
        do {
            try queueManager.enqueue(message)
            // Show "Queued" feedback
        } catch {
            // Show queue full error
        }
    } else {
        // Send directly (existing logic)
        bridgeAdapter.sendMessage(content, ...)
    }
}
```

5. Load queue on session change
6. Start queue processing when busyState becomes false

---

### Step 3.3: Input View Changes

**File:** `CodingBridge/Views/CLIInputView.swift` (modify)

1. Remove `isProcessing` disable on text input
2. Add urgent toggle (long-press or button)
3. Change send button behavior:
   - When busy: show "queue" icon instead of "send"
   - Visual feedback on queue action

---

### Step 3.4: Queue Panel View

**File:** `CodingBridge/Views/QueuePanelView.swift` (new)

Collapsible panel showing queued messages with management controls.

```swift
struct QueuePanelView: View {
    @ObservedObject var queueManager: MessageQueueManager
    @State private var isExpanded = false
    @State private var editingMessage: QueuedMessage?

    var body: some View {
        VStack(spacing: 0) {
            // Header (always visible)
            HStack {
                Image(systemName: "tray.full")
                Text("Queue (\(queueManager.count))")
                Spacer()
                Button { isExpanded.toggle() } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .onTapGesture { isExpanded.toggle() }

            // Expanded content
            if isExpanded {
                if queueManager.isEmpty {
                    Text("No queued messages")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(queueManager.queue) { message in
                            QueuedMessageRow(
                                message: message,
                                onEdit: { editingMessage = message },
                                onCancel: { queueManager.dequeue(id: message.id) },
                                onTogglePriority: {
                                    let newPriority: QueuedMessage.MessagePriority =
                                        message.priority == .urgent ? .normal : .urgent
                                    queueManager.setPriority(id: message.id, priority: newPriority)
                                }
                            )
                        }
                        .onMove { queueManager.reorder(from: $0, to: $1) }
                    }
                    .listStyle(.plain)

                    // Clear all button
                    Button("Clear All", role: .destructive) {
                        queueManager.dequeueAll()
                    }
                    .padding()
                }
            }
        }
        .sheet(item: $editingMessage) { message in
            EditQueuedMessageSheet(message: message) { newContent in
                queueManager.edit(id: message.id, newContent: newContent)
            }
        }
    }
}
```

---

### Step 3.5: Queue Status Indicator

Add small badge/indicator in ChatView header showing queue count when > 0.

---

## Phase 4: Polish & Testing

### Step 4.1: Haptic Feedback

**File:** `CodingBridge/Utilities/HapticManager.swift`

Add haptic triggers:
- Message queued: light impact
- Message started executing: medium impact
- Message completed: success notification
- Error: error notification

---

### Step 4.2: Error UI

Add error banner when queue processing fails:
- Show error message
- Retry / Skip / Edit / Cancel buttons

---

### Step 4.3: Accessibility

- VoiceOver labels for queue panel
- Move up/down buttons as alternative to drag reorder
- Announce queue changes

---

### Step 4.4: Testing

| Test Suite | Coverage |
|------------|----------|
| `QueuedMessageTests` | Model, Codable |
| `QueuePersistenceTests` | File I/O, corruption |
| `MessageQueueManagerTests` | All queue operations |
| `BusyStateAggregatorTests` | State combination |
| `QueueIntegrationTests` | End-to-end with mock CLIBridgeManager |

---

## Implementation Order

```
Phase 1 (Foundation)
├── Step 1.1: QueuedMessage model + tests
├── Step 1.2: QueuePersistence + tests
└── Step 1.3: MessageQueueManager + tests

Phase 2 (Integration)
├── Step 2.1: BusyStateAggregator
├── Step 2.2: CLIBridgeManager extensions
└── Step 2.3: Queue execution logic

Phase 3 (UI)
├── Step 3.1: Settings addition
├── Step 3.2: ChatView integration
├── Step 3.3: Input view changes
├── Step 3.4: QueuePanelView
└── Step 3.5: Queue status indicator

Phase 4 (Polish)
├── Step 4.1: Haptic feedback
├── Step 4.2: Error UI
├── Step 4.3: Accessibility
└── Step 4.4: Comprehensive testing
```

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Queue processing races | Use `@MainActor` throughout, single execution point |
| Persistence corruption | Validate on load, fallback to empty queue |
| Memory pressure (images) | Consider storing image data separately, load on demand |
| User confusion | Clear visual distinction between "sent" and "queued" |
