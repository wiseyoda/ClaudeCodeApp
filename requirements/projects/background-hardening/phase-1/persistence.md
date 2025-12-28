# Persistence

> State persistence to survive backgrounding and termination.

## Message Queue Persistence

Ensure pending WebSocket messages survive backgrounding:

```swift
// CodingBridge/Persistence/MessageQueuePersistence.swift

@MainActor
final class MessageQueuePersistence {
    static let shared = MessageQueuePersistence()

    private let fileURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pending-messages.json")
    }()

    func save() async {
        let queue = WebSocketManager.shared.pendingMessages
        guard !queue.isEmpty else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }

        do {
            let data = try JSONEncoder().encode(queue)
            try data.write(to: fileURL)
            setDataProtection(for: fileURL)
        } catch {
            Logger.background.error("Failed to save message queue: \(error)")
        }
    }

    func load() async -> [PendingMessage] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }

        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([PendingMessage].self, from: data)
        } catch {
            return []
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func setDataProtection(for url: URL) {
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
    }
}
```

## Draft Input Persistence

```swift
// CodingBridge/Persistence/DraftInputPersistence.swift

@MainActor
final class DraftInputPersistence {
    static let shared = DraftInputPersistence()

    private let key = "draftInput"
    private let sessionKey = "draftInputSessionId"

    var currentDraft: String {
        get { UserDefaults.standard.string(forKey: key) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    var draftSessionId: String? {
        get { UserDefaults.standard.string(forKey: sessionKey) }
        set { UserDefaults.standard.set(newValue, forKey: sessionKey) }
    }

    func save() async {
        // UserDefaults persists automatically
    }

    func loadForSession(_ sessionId: String) -> String? {
        guard draftSessionId == sessionId else { return nil }
        return currentDraft
    }

    func clear() {
        currentDraft = ""
        draftSessionId = nil
    }
}
```

## Processing State

```swift
// In WebSocketManager

func handleBackgroundRecovery() async {
    let pendingMessages = await MessageQueuePersistence.shared.load()

    if !pendingMessages.isEmpty {
        for message in pendingMessages {
            messageQueue.append(message)
        }
    }

    if UserDefaults.standard.bool(forKey: "wasProcessing") {
        await reconnect()
    }
}

func markProcessingComplete() {
    UserDefaults.standard.set(false, forKey: "wasProcessing")
    MessageQueuePersistence.shared.clear()
}
```

## Data Protection

Use `.completeUntilFirstUserAuthentication` for files that need background access:

```swift
// Files accessible after first unlock (survives background)
FileProtectionType.completeUntilFirstUserAuthentication

// For Keychain items
kSecAttrAccessibleAfterFirstUnlock
```

---
**Prev:** [notification-manager](./notification-manager.md) | **Next:** [network-monitor](./network-monitor.md) | **Index:** [../00-INDEX.md](../00-INDEX.md)
