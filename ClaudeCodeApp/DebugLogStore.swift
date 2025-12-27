import Foundation
import UIKit

// MARK: - Debug Log Types

/// Type of debug log entry
enum DebugLogType: String, CaseIterable {
    case sent = "SENT"
    case received = "RECV"
    case error = "ERROR"
    case info = "INFO"
    case connection = "CONN"

    var icon: String {
        switch self {
        case .sent: return "arrow.up.circle"
        case .received: return "arrow.down.circle"
        case .error: return "exclamationmark.triangle"
        case .info: return "info.circle"
        case .connection: return "wifi"
        }
    }

    var colorName: String {
        switch self {
        case .sent: return "blue"
        case .received: return "green"
        case .error: return "red"
        case .info: return "gray"
        case .connection: return "orange"
        }
    }
}

// MARK: - Debug Log Entry

/// A single debug log entry
struct DebugLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: DebugLogType
    let message: String
    let details: String?

    /// Pretty-print JSON if the message is valid JSON
    var formattedMessage: String {
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return message
        }
        return prettyString
    }

    /// Timestamp formatted for display
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}

// MARK: - Debug Log Store

/// Singleton store for debug logs, used to capture WebSocket traffic
@MainActor
class DebugLogStore: ObservableObject {
    static let shared = DebugLogStore()

    /// All captured log entries
    @Published var entries: [DebugLogEntry] = []

    /// Whether debug logging is enabled (controlled by AppSettings)
    @Published var isEnabled: Bool = false

    /// Maximum number of entries to keep (prevents memory issues)
    let maxEntries = 500

    /// Filter for log types
    @Published var typeFilter: Set<DebugLogType> = Set(DebugLogType.allCases)

    /// Search text filter
    @Published var searchText: String = ""

    private init() {}

    // MARK: - Logging Methods

    /// Log a message
    func log(_ message: String, type: DebugLogType, details: String? = nil) {
        guard isEnabled else { return }

        let entry = DebugLogEntry(
            timestamp: Date(),
            type: type,
            message: message,
            details: details
        )

        entries.append(entry)

        // Trim if over max
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    /// Log outgoing WebSocket message
    func logSent(_ message: String) {
        log(message, type: .sent)
    }

    /// Log incoming WebSocket message
    func logReceived(_ message: String) {
        log(message, type: .received)
    }

    /// Log error
    func logError(_ message: String, details: String? = nil) {
        log(message, type: .error, details: details)
    }

    /// Log connection event
    func logConnection(_ message: String) {
        log(message, type: .connection)
    }

    /// Log info message
    func logInfo(_ message: String) {
        log(message, type: .info)
    }

    // MARK: - Filtering

    /// Filtered entries based on current filters
    var filteredEntries: [DebugLogEntry] {
        entries.filter { entry in
            // Type filter
            guard typeFilter.contains(entry.type) else { return false }

            // Search filter
            if !searchText.isEmpty {
                let searchLower = searchText.lowercased()
                return entry.message.lowercased().contains(searchLower) ||
                       entry.type.rawValue.lowercased().contains(searchLower) ||
                       (entry.details?.lowercased().contains(searchLower) ?? false)
            }

            return true
        }
    }

    // MARK: - Actions

    /// Clear all entries
    func clear() {
        entries.removeAll()
    }

    /// Export logs as text
    func exportAsText() -> String {
        filteredEntries.map { entry in
            "[\(entry.formattedTimestamp)] [\(entry.type.rawValue)] \(entry.message)"
        }.joined(separator: "\n\n---\n\n")
    }

    /// Copy logs to pasteboard
    func copyToClipboard() {
        UIPasteboard.general.string = exportAsText()
    }
}
