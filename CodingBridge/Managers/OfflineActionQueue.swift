import Foundation

/// Queues approval actions when offline for later processing
@MainActor
final class OfflineActionQueue: ObservableObject {
    static let shared = OfflineActionQueue()

    @Published var pendingActions: [PendingAction] = []

    private let fileURL: URL
    private let dateProvider: () -> Date
    private let isConnected: @MainActor () -> Bool
    private let notificationCenter: NotificationCenter

    // MARK: - Types

    struct PendingAction: Codable, Identifiable {
        let id: String
        let requestId: String
        let approved: Bool
        let timestamp: Date

        init(requestId: String, approved: Bool, timestamp: Date = Date()) {
            self.id = UUID().uuidString
            self.requestId = requestId
            self.approved = approved
            self.timestamp = timestamp
        }
    }

    // MARK: - Initialization

    private init(
        fileURL: URL = OfflineActionQueue.defaultFileURL(),
        dateProvider: @escaping () -> Date = Date.init,
        isConnected: @escaping @MainActor () -> Bool = { NetworkMonitor.shared.isConnected },
        notificationCenter: NotificationCenter = .default
    ) {
        self.fileURL = fileURL
        self.dateProvider = dateProvider
        self.isConnected = isConnected
        self.notificationCenter = notificationCenter
        load()
    }

#if DEBUG
    static func makeForTesting(
        fileURL: URL,
        dateProvider: @escaping () -> Date = Date.init,
        isConnected: @escaping @MainActor () -> Bool = { true },
        notificationCenter: NotificationCenter = .default
    ) -> OfflineActionQueue {
        OfflineActionQueue(
            fileURL: fileURL,
            dateProvider: dateProvider,
            isConnected: isConnected,
            notificationCenter: notificationCenter
        )
    }
#endif

    // MARK: - Queue Management

    /// Queue an approval action for later processing
    func queueApproval(requestId: String, approved: Bool) {
        let action = PendingAction(requestId: requestId, approved: approved, timestamp: dateProvider())
        pendingActions.append(action)
        save()
        log.info("[OfflineQueue] Queued \(approved ? "approval" : "denial") for: \(requestId)")
    }

    /// Process all queued actions (called when network becomes available)
    func processQueue() async {
        guard isConnected() else {
            log.debug("[OfflineQueue] Still offline, skipping processing")
            return
        }

        guard !pendingActions.isEmpty else { return }

        log.info("[OfflineQueue] Processing \(pendingActions.count) queued actions")

        var processedIds: [String] = []

        for action in pendingActions {
            // Check if action is too old (expired)
            if dateProvider().timeIntervalSince(action.timestamp) > 120 { // 2 minutes
                log.warning("[OfflineQueue] Action expired: \(action.requestId)")
                processedIds.append(action.id)
                continue
            }

            // Post notification for ChatViewModel to handle
            notificationCenter.post(
                name: .approvalResponseReady,
                object: nil,
                userInfo: ["requestId": action.requestId, "approved": action.approved]
            )

            processedIds.append(action.id)
        }

        // Remove processed actions
        pendingActions.removeAll { processedIds.contains($0.id) }
        save()
    }

    /// Remove a specific action from the queue
    func removeAction(requestId: String) {
        pendingActions.removeAll { $0.requestId == requestId }
        save()
    }

    /// Clear all pending actions
    func clearAll() {
        pendingActions.removeAll()
        save()
    }

    // MARK: - Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(pendingActions)
            try data.write(to: fileURL)
        } catch {
            log.error("[OfflineQueue] Failed to save: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            pendingActions = try JSONDecoder().decode([PendingAction].self, from: data)
            log.debug("[OfflineQueue] Loaded \(pendingActions.count) pending actions")
        } catch {
            log.error("[OfflineQueue] Failed to load: \(error)")
        }
    }

    nonisolated private static func defaultFileURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("offline-actions.json")
    }
}
