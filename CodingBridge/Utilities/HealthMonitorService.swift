import Foundation
import Combine

/// Server health status
enum ServerStatus: Equatable {
    case connected
    case disconnected
    case checking

    var displayText: String {
        switch self {
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .checking: return "Checking..."
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .connected: return "Server status: Connected"
        case .disconnected: return "Server status: Disconnected"
        case .checking: return "Server status: Checking connection"
        }
    }
}

/// Singleton service that monitors CLI Bridge server health
@MainActor
final class HealthMonitorService: ObservableObject {
    static let shared = HealthMonitorService()

    // MARK: - Published State

    @Published private(set) var serverStatus: ServerStatus = .disconnected
    @Published private(set) var lastCheck: Date?
    @Published private(set) var serverVersion: String = ""
    @Published private(set) var uptime: Int = 0
    @Published private(set) var activeAgents: Int = 0
    @Published private(set) var latency: TimeInterval = 0
    @Published private(set) var lastError: String?

    // MARK: - Configuration

    private var serverURL: String = ""
    private var pollTimer: Timer?
    private var isPolling = false

    /// Base poll interval (30 seconds)
    private let basePollInterval: TimeInterval = 30

    /// Current backoff interval (increases on failures)
    private var currentBackoffInterval: TimeInterval = 5

    /// Maximum backoff interval
    private let maxBackoffInterval: TimeInterval = 30

    /// Number of consecutive failures
    private var consecutiveFailures = 0

    // MARK: - Dependencies

    private let networkMonitor = NetworkMonitor.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupNetworkObserver()
    }

    // MARK: - Configuration

    /// Configure the service with the server URL
    func configure(serverURL: String) {
        self.serverURL = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    // MARK: - Polling Control

    /// Start automatic health polling
    func startPolling() {
        guard !isPolling else { return }
        isPolling = true
        currentBackoffInterval = 5
        consecutiveFailures = 0

        // Start network monitoring if not already started
        networkMonitor.start()

        // Initial check
        Task {
            await checkHealth()
        }

        scheduleNextPoll(interval: basePollInterval)
        log.info("[Health] Started polling every \(Int(basePollInterval))s")
    }

    /// Stop automatic health polling
    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        isPolling = false
        log.info("[Health] Stopped polling")
    }

    /// Force an immediate health check
    func forceCheck() async {
        await checkHealth()
    }

    // MARK: - Network Observer

    private func setupNetworkObserver() {
        // Observe network status changes
        networkMonitor.$isConnected
            .dropFirst()
            .sink { [weak self] isConnected in
                Task { @MainActor in
                    guard let self = self else { return }

                    if isConnected {
                        // Network restored - check immediately
                        self.currentBackoffInterval = 5
                        self.consecutiveFailures = 0
                        await self.checkHealth()
                    } else {
                        // Network lost - update status
                        self.serverStatus = .disconnected
                        self.lastError = "No network connection"
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Health Check Implementation

    private func checkHealth() async {
        // Don't poll if offline
        guard networkMonitor.isConnected else {
            serverStatus = .disconnected
            lastError = "No network connection"
            return
        }

        // Don't poll if no server configured
        guard !serverURL.isEmpty else {
            serverStatus = .disconnected
            lastError = "No server configured"
            return
        }

        serverStatus = .checking
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            let apiClient = CLIBridgeAPIClient(serverURL: serverURL)
            let response = try await apiClient.healthCheck()

            // Calculate latency
            latency = CFAbsoluteTimeGetCurrent() - startTime

            // Update state
            serverStatus = response.status == "ok" ? .connected : .disconnected
            serverVersion = response.version
            uptime = response.uptime ?? 0
            activeAgents = response.agents ?? 0
            lastCheck = Date()
            lastError = nil

            // Reset backoff on success
            consecutiveFailures = 0
            currentBackoffInterval = 5

            log.debug("[Health] Check succeeded: v\(serverVersion), \(latency * 1000)ms latency")

        } catch {
            serverStatus = .disconnected
            lastError = error.localizedDescription
            consecutiveFailures += 1

            // Exponential backoff: 5s → 10s → 20s → 30s max
            currentBackoffInterval = min(
                currentBackoffInterval * 2,
                maxBackoffInterval
            )

            log.warning("[Health] Check failed (\(consecutiveFailures)x): \(error.localizedDescription)")

            // Schedule faster retry with backoff
            if isPolling {
                scheduleNextPoll(interval: currentBackoffInterval)
            }
        }
    }

    private func scheduleNextPoll(interval: TimeInterval) {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isPolling else { return }
                await self.checkHealth()

                // Schedule next poll (success uses base interval, failure uses backoff)
                if self.serverStatus == .connected {
                    self.scheduleNextPoll(interval: self.basePollInterval)
                }
            }
        }
    }

    // MARK: - Formatted Values

    /// Formatted uptime string (e.g., "2d 5h 30m")
    var formattedUptime: String {
        formatUptime(uptime)
    }

    /// Format uptime seconds to human-readable string
    func formatUptime(_ seconds: Int) -> String {
        guard seconds > 0 else { return "0s" }

        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        var parts: [String] = []
        if days > 0 { parts.append("\(days)d") }
        if hours > 0 { parts.append("\(hours)h") }
        if minutes > 0 { parts.append("\(minutes)m") }
        if secs > 0 && days == 0 { parts.append("\(secs)s") }

        return parts.isEmpty ? "0s" : parts.joined(separator: " ")
    }

    /// Formatted latency string (e.g., "42ms")
    var formattedLatency: String {
        let ms = Int(latency * 1000)
        return "\(ms)ms"
    }

    /// Latency status for color coding
    var latencyStatus: LatencyStatus {
        let ms = latency * 1000
        if ms < 100 { return .good }
        if ms < 500 { return .moderate }
        return .poor
    }

    enum LatencyStatus {
        case good      // < 100ms - green
        case moderate  // 100-500ms - yellow
        case poor      // > 500ms - red
    }

    // Shared formatter for relative time (expensive to create)
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    /// Time since last check as relative string
    var lastCheckRelative: String? {
        guard let lastCheck = lastCheck else { return nil }
        return Self.relativeFormatter.localizedString(for: lastCheck, relativeTo: Date())
    }
}
