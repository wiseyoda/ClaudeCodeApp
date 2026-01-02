import Foundation
import Network
import UIKit

// MARK: - Lifecycle Management
// App lifecycle observers and network monitoring

extension CLIBridgeManager {
    // MARK: - Lifecycle Setup

    func setupLifecycleObservers() {
        // App will resign active (going to background)
        let resignObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppWillResignActive()
            }
        }
        appendLifecycleObserver(resignObserver)

        // App did enter background
        let backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppDidEnterBackground()
            }
        }
        appendLifecycleObserver(backgroundObserver)

        // App did become active (returning from background)
        let activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppDidBecomeActive()
            }
        }
        appendLifecycleObserver(activeObserver)

        log.debug("[CLIBridge] Lifecycle observers set up")
    }

    func setupNetworkMonitoring() {
        initializeNetworkMonitor()

        setNetworkPathUpdateHandler { [weak self] path in
            Task { @MainActor in
                guard let self = self else { return }
                let wasAvailable = self.getIsNetworkAvailable()
                let nowAvailable = path.status == .satisfied
                self.setIsNetworkAvailable(nowAvailable)

                if nowAvailable != wasAvailable {
                    log.debug("[CLIBridge] Network status changed: \(nowAvailable ? "available" : "unavailable")")
                    self.emit(.networkStatusChanged(isOnline: nowAvailable))

                    // Network restored - attempt reconnect if we were disconnected
                    if nowAvailable && !wasAvailable {
                        self.handleNetworkRestored()
                    }
                }
            }
        }

        startNetworkMonitor()
        log.debug("[CLIBridge] Network monitoring started")
    }

    // MARK: - Lifecycle Handlers

    func handleAppWillResignActive() {
        log.debug("[CLIBridge] App will resign active")
        // Don't disconnect yet - WebSocket may stay open briefly
    }

    func handleAppDidEnterBackground() {
        log.debug("[CLIBridge] App entering background, state: \(agentState)")

        // Start background task to keep connection briefly
        beginBackgroundTask { [weak self] in
            // Time's up - clean disconnect but preserve session for reconnection
            log.debug("[CLIBridge] Background time expired")
            self?.disconnectForBackground()
            self?.endBackgroundTask()
        }

        // If agent is idle, we can safely disconnect - agent survives on server
        if agentState == .idle || agentState == .stopped {
            log.debug("[CLIBridge] Agent idle, disconnecting for background")
            disconnectForBackground()
            endBackgroundTask()
        }
        // If running, keep connection open for completion notification
        // iOS gives ~30 seconds max in background
    }

    func handleAppDidBecomeActive() {
        log.debug("[CLIBridge] App became active")
        endBackgroundTask()

        // Reconnect if we were disconnected and have a session
        if !hasActiveWebSocket && sessionId != nil {
            log.debug("[CLIBridge] Reconnecting after foreground")
            reconnectWithExistingSession()
        }
    }

    func handleNetworkRestored() {
        log.debug("[CLIBridge] Network restored")

        // Only reconnect if we were disconnected and have a session
        if !hasActiveWebSocket && sessionId != nil && !getIsManualDisconnect() {
            log.debug("[CLIBridge] Attempting reconnect after network restore")
            reconnectWithExistingSession()
        }
    }
}
