import Network
import Combine
import Foundation

/// Monitors network connectivity using NWPathMonitor
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected = true
    @Published private(set) var connectionType: ConnectionType = .unknown
    @Published private(set) var isExpensive = false
    @Published private(set) var isConstrained = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.codingbridge.networkmonitor")
    private var isMonitoring = false

    enum ConnectionType: String {
        case wifi, cellular, wired, unknown

        var displayName: String {
            switch self {
            case .wifi: return "Wi-Fi"
            case .cellular: return "Cellular"
            case .wired: return "Ethernet"
            case .unknown: return "Unknown"
            }
        }

        var icon: String {
            switch self {
            case .wifi: return "wifi"
            case .cellular: return "antenna.radiowaves.left.and.right"
            case .wired: return "cable.connector"
            case .unknown: return "questionmark.circle"
            }
        }
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Start/Stop

    func start() {
        guard !isMonitoring else { return }

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
        }

        monitor.start(queue: queue)
        isMonitoring = true
        log.info("[Network] Monitoring started")
    }

    func stop() {
        guard isMonitoring else { return }
        monitor.cancel()
        isMonitoring = false
        log.info("[Network] Monitoring stopped")
    }

    // MARK: - Path Handling

    private func handlePathUpdate(_ path: NWPath) {
        let wasConnected = isConnected
        isConnected = path.status == .satisfied
        connectionType = getConnectionType(path)
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained

        // Log significant changes
        if wasConnected != isConnected {
            log.info("[Network] Connection \(isConnected ? "restored" : "lost")")

            if isConnected {
                // Process any queued offline actions
                Task {
                    await OfflineActionQueue.shared.processQueue()
                }

                // Notify interested parties
                NotificationCenter.default.post(name: .networkDidBecomeAvailable, object: nil)
            } else {
                NotificationCenter.default.post(name: .networkDidBecomeUnavailable, object: nil)
            }
        }
    }

    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .wired }
        return .unknown
    }

    // MARK: - Status Description

    var statusDescription: String {
        guard isConnected else { return "No connection" }

        var parts = [connectionType.displayName]
        if isExpensive { parts.append("metered") }
        if isConstrained { parts.append("low data") }

        return parts.joined(separator: ", ")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let networkDidBecomeAvailable = Notification.Name("networkDidBecomeAvailable")
    static let networkDidBecomeUnavailable = Notification.Name("networkDidBecomeUnavailable")
}
