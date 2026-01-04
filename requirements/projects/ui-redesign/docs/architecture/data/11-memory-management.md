# Memory Management


### Weak References in Closures

```swift
// Correct: Use weak self to prevent retain cycles
Task { [weak self] in
    guard let self else { return }
    await self.handleResult(result)
}

// Correct: Use capture list
manager.onEvent = { [weak self] event in
    self?.processEvent(event)
}
```

### Actor Cleanup

```swift
actor CardStatusTracker {
    private var cleanupTasks: [String: Task<Void, Never>] = [:]

    func complete(toolUseId: String) {
        // Cancel any existing cleanup task
        cleanupTasks[toolUseId]?.cancel()

        // Start new cleanup
        cleanupTasks[toolUseId] = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            activeStatuses.removeValue(forKey: toolUseId)
            cleanupTasks.removeValue(forKey: toolUseId)
        }
    }

    func clearAll() {
        cleanupTasks.values.forEach { $0.cancel() }
        cleanupTasks.removeAll()
        activeStatuses.removeAll()
    }
}
```

---
