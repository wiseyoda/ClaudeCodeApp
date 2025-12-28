import Foundation
import SwiftUI

// MARK: - Error Event

/// A single error event for analytics tracking
struct ErrorEvent: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let sessionId: String?
    let projectPath: String?
    let toolName: String
    let category: ToolErrorCategory
    let exitCode: Int?
    let errorSnippet: String  // First 200 chars of error

    init(
        sessionId: String? = nil,
        projectPath: String? = nil,
        toolName: String,
        category: ToolErrorCategory,
        exitCode: Int? = nil,
        errorSnippet: String
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.sessionId = sessionId
        self.projectPath = projectPath
        self.toolName = toolName
        self.category = category
        self.exitCode = exitCode
        self.errorSnippet = String(errorSnippet.prefix(200))
    }
}

// MARK: - Error Pattern

/// A detected pattern of recurring errors
struct ErrorPattern: Identifiable {
    let id = UUID()
    let category: ToolErrorCategory
    let count: Int
    let percentage: Double
    let trend: Trend
    let suggestion: String?

    enum Trend {
        case increasing
        case stable
        case decreasing

        var icon: String {
            switch self {
            case .increasing: return "arrow.up.right"
            case .stable: return "arrow.right"
            case .decreasing: return "arrow.down.right"
            }
        }

        var color: Color {
            switch self {
            case .increasing: return .red
            case .stable: return .yellow
            case .decreasing: return .green
            }
        }
    }
}

// MARK: - Time Period

/// Time periods for analytics aggregation
enum AnalyticsPeriod: String, CaseIterable {
    case today = "Today"
    case week = "7 Days"
    case month = "30 Days"
    case all = "All Time"

    var days: Int? {
        switch self {
        case .today: return 1
        case .week: return 7
        case .month: return 30
        case .all: return nil
        }
    }

    var startDate: Date {
        guard let days = days else {
            return Date.distantPast
        }
        return Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }
}

// MARK: - Error Analytics Store

/// Tracks tool errors over time and provides analytics insights
@MainActor
class ErrorAnalyticsStore: ObservableObject {
    static let shared = ErrorAnalyticsStore()

    /// All recorded error events
    @Published private(set) var events: [ErrorEvent] = []

    /// Error counts by category for current period
    @Published private(set) var categoryCounts: [ToolErrorCategory: Int] = [:]

    /// Currently selected time period
    @Published var selectedPeriod: AnalyticsPeriod = .week {
        didSet { recalculateStats() }
    }

    /// Total errors in current period
    @Published private(set) var totalErrors: Int = 0

    /// Success rate in current period
    @Published private(set) var successRate: Double = 0

    /// Detected patterns
    @Published private(set) var patterns: [ErrorPattern] = []

    /// Maximum events to keep (older ones are pruned)
    private let maxEvents = 1000

    /// File URL for persistence
    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("error-analytics.json")
    }

    private init() {
        load()
        recalculateStats()
    }

    // MARK: - Public API

    /// Track a new error event
    func track(_ errorInfo: ToolErrorInfo, sessionId: String? = nil, projectPath: String? = nil) {
        // Don't track successes in analytics (only failures)
        guard errorInfo.category != .success else { return }

        let event = ErrorEvent(
            sessionId: sessionId,
            projectPath: projectPath,
            toolName: errorInfo.toolName ?? "unknown",
            category: errorInfo.category,
            exitCode: errorInfo.exitCode,
            errorSnippet: errorInfo.errorSummary
        )

        events.append(event)
        log.debug("Tracked error: \(event.category.rawValue) from \(event.toolName)")

        // Prune old events if needed
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }

        recalculateStats()
        save()
    }

    /// Track from a tool result string
    func trackToolResult(_ content: String, toolName: String, sessionId: String? = nil, projectPath: String? = nil) {
        let errorInfo = ToolResultParser.parse(content, toolName: toolName)
        track(errorInfo, sessionId: sessionId, projectPath: projectPath)
    }

    /// Get events filtered by current period
    func eventsInPeriod() -> [ErrorEvent] {
        let start = selectedPeriod.startDate
        return events.filter { $0.timestamp >= start }
    }

    /// Get events for a specific category
    func events(for category: ToolErrorCategory) -> [ErrorEvent] {
        eventsInPeriod().filter { $0.category == category }
    }

    /// Clear all analytics data
    func clearAll() {
        events.removeAll()
        recalculateStats()
        save()
        log.info("Error analytics cleared")
    }

    /// Get recent errors (last N)
    func recentErrors(limit: Int = 10) -> [ErrorEvent] {
        Array(events.suffix(limit).reversed())
    }

    // MARK: - Pattern Detection

    /// Analyze errors and detect patterns
    private func detectPatterns() -> [ErrorPattern] {
        let periodEvents = eventsInPeriod()
        guard !periodEvents.isEmpty else { return [] }

        var patterns: [ErrorPattern] = []
        let total = Double(periodEvents.count)

        // Group by category and calculate stats
        let grouped = Dictionary(grouping: periodEvents) { $0.category }

        for (category, categoryEvents) in grouped.sorted(by: { $0.value.count > $1.value.count }) {
            let count = categoryEvents.count
            let percentage = (Double(count) / total) * 100

            // Calculate trend by comparing first half to second half
            let midpoint = periodEvents.count / 2
            let firstHalf = periodEvents.prefix(midpoint).filter { $0.category == category }.count
            let secondHalf = periodEvents.suffix(midpoint).filter { $0.category == category }.count

            let trend: ErrorPattern.Trend
            if secondHalf > firstHalf + 2 {
                trend = .increasing
            } else if firstHalf > secondHalf + 2 {
                trend = .decreasing
            } else {
                trend = .stable
            }

            patterns.append(ErrorPattern(
                category: category,
                count: count,
                percentage: percentage,
                trend: trend,
                suggestion: category.suggestedAction
            ))
        }

        return patterns
    }

    // MARK: - Statistics

    private func recalculateStats() {
        let periodEvents = eventsInPeriod()

        // Count by category
        categoryCounts = Dictionary(grouping: periodEvents) { $0.category }
            .mapValues { $0.count }

        // Total errors (excluding success which we don't track)
        totalErrors = periodEvents.count

        // Detect patterns
        patterns = detectPatterns()

        // Success rate would need total tool calls tracked, which we don't have
        // For now, just show error count trends
        successRate = 0
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            log.debug("No error analytics file found, starting fresh")
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            events = try JSONDecoder().decode([ErrorEvent].self, from: data)
            log.info("Loaded \(events.count) error events")
        } catch {
            log.error("Failed to load error analytics: \(error)")
            events = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(events)
            try data.write(to: fileURL, options: .atomic)
            log.debug("Saved \(events.count) error events")
        } catch {
            log.error("Failed to save error analytics: \(error)")
        }
    }
}

// MARK: - Summary Statistics

extension ErrorAnalyticsStore {
    /// Summary of error statistics for display
    struct Summary {
        let totalErrors: Int
        let topCategory: ToolErrorCategory?
        let topCategoryCount: Int
        let transientErrorCount: Int
        let uniqueCategories: Int
    }

    /// Get summary statistics for current period
    var summary: Summary {
        let periodEvents = eventsInPeriod()

        let topEntry = categoryCounts.max(by: { $0.value < $1.value })

        let transientCount = periodEvents.filter { $0.category.isTransient }.count

        return Summary(
            totalErrors: totalErrors,
            topCategory: topEntry?.key,
            topCategoryCount: topEntry?.value ?? 0,
            transientErrorCount: transientCount,
            uniqueCategories: categoryCounts.count
        )
    }
}
