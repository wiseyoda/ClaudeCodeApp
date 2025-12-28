# NetworkMonitor

> NWPathMonitor integration for connectivity awareness.

## Implementation

```swift
// CodingBridge/Utilities/NetworkMonitor.swift

import Network

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected = true
    @Published private(set) var connectionType: ConnectionType = .unknown

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    enum ConnectionType {
        case wifi, cellular, wired, unknown
    }

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(path) ?? .unknown
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }

    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .wired }
        return .unknown
    }
}
```

## Background Integration

```swift
// In BackgroundManager

private func handleNetworkChange(isConnected: Bool) async {
    if !isConnected && isAppInBackground {
        await LiveActivityManager.shared.updateActivity(
            status: .processing,
            operation: "Waiting for connection...",
            elapsedSeconds: currentElapsedSeconds
        )

        // Wait 30s before notifying user
        Task {
            try await Task.sleep(for: .seconds(30))
            if !NetworkMonitor.shared.isConnected {
                await NotificationManager.shared.sendNotification(
                    title: "Connection Lost",
                    body: "Task will resume when connected."
                )
            }
        }
    }
}
```

## Offline Action Queue

Queue approvals when offline:

```swift
// CodingBridge/Managers/OfflineActionQueue.swift

@MainActor
final class OfflineActionQueue: ObservableObject {
    static let shared = OfflineActionQueue()

    struct PendingAction: Codable {
        let id: String
        let requestId: String
        let approved: Bool
        let timestamp: Date
    }

    @Published var pendingActions: [PendingAction] = []

    func queueApproval(requestId: String, approved: Bool) {
        let action = PendingAction(
            id: UUID().uuidString,
            requestId: requestId,
            approved: approved,
            timestamp: Date()
        )
        pendingActions.append(action)
        save()
    }

    func processQueue() async {
        guard NetworkMonitor.shared.isConnected else { return }

        for action in pendingActions {
            do {
                try await WebSocketManager.shared.sendApprovalResponse(
                    requestId: action.requestId,
                    approved: action.approved
                )
                pendingActions.removeAll { $0.id == action.id }
                save()
            } catch {
                // Keep in queue for retry
            }
        }
    }
}
```

---
**Prev:** [persistence](./persistence.md) | **Next:** [checklist](./checklist.md) | **Index:** [../00-INDEX.md](../00-INDEX.md)
