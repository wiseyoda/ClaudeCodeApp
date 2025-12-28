import SwiftUI

// MARK: - Error Insights View

/// Displays error analytics and patterns to help users understand recurring issues
struct ErrorInsightsView: View {
    @ObservedObject private var analytics = ErrorAnalyticsStore.shared
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Time period picker
                    periodPicker

                    // Summary stats
                    if analytics.totalErrors > 0 {
                        summarySection
                        Divider()
                        patternsSection
                        Divider()
                        recentErrorsSection
                    } else {
                        emptyState
                    }
                }
                .padding()
            }
            .navigationTitle("Error Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(role: .destructive) {
                            analytics.clearAll()
                        } label: {
                            Label("Clear All Data", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Time Period", selection: $analytics.selectedPeriod) {
            ForEach(AnalyticsPeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(settings.scaledFont(.body))
                .fontWeight(.semibold)
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            HStack(spacing: 16) {
                StatCard(
                    title: "Total Errors",
                    value: "\(analytics.totalErrors)",
                    icon: "exclamationmark.triangle",
                    color: CLITheme.red(for: colorScheme)
                )

                if let top = analytics.summary.topCategory {
                    StatCard(
                        title: "Most Common",
                        value: top.shortLabel,
                        icon: top.icon,
                        color: top.color(for: colorScheme)
                    )
                }

                StatCard(
                    title: "Categories",
                    value: "\(analytics.summary.uniqueCategories)",
                    icon: "folder",
                    color: CLITheme.blue(for: colorScheme)
                )
            }

            // Transient vs permanent breakdown
            if analytics.summary.transientErrorCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(CLITheme.yellow(for: colorScheme))
                    Text("\(analytics.summary.transientErrorCount) transient (auto-retried)")
                        .font(settings.scaledFont(.small))
                        .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                }
            }
        }
    }

    // MARK: - Patterns Section

    private var patternsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Error Patterns")
                .font(settings.scaledFont(.body))
                .fontWeight(.semibold)
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            ForEach(analytics.patterns.prefix(6)) { pattern in
                PatternRow(pattern: pattern)
            }
        }
    }

    // MARK: - Recent Errors Section

    private var recentErrorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Errors")
                .font(settings.scaledFont(.body))
                .fontWeight(.semibold)
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            ForEach(analytics.recentErrors(limit: 5)) { event in
                RecentErrorRow(event: event)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(CLITheme.green(for: colorScheme))

            Text("No Errors Recorded")
                .font(settings.scaledFont(.body))
                .fontWeight(.semibold)

            Text("Error patterns will appear here as you use the app.")
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(value)
                .font(settings.scaledFont(.body))
                .fontWeight(.bold)
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            Text(title)
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassBackground(cornerRadius: 12)
    }
}

// MARK: - Pattern Row

private struct PatternRow: View {
    let pattern: ErrorPattern

    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Category icon and name
                Image(systemName: pattern.category.icon)
                    .foregroundColor(pattern.category.color(for: colorScheme))

                Text(pattern.category.description)
                    .font(settings.scaledFont(.body))
                    .foregroundColor(CLITheme.primaryText(for: colorScheme))

                Spacer()

                // Count and trend
                HStack(spacing: 4) {
                    Text("\(pattern.count)")
                        .font(settings.scaledFont(.body))
                        .fontWeight(.semibold)

                    Image(systemName: pattern.trend.icon)
                        .font(.system(size: 10))
                        .foregroundColor(pattern.trend.color)
                }
            }

            // Progress bar showing percentage
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(CLITheme.background(for: colorScheme))
                        .frame(height: 4)
                        .cornerRadius(2)

                    Rectangle()
                        .fill(pattern.category.color(for: colorScheme))
                        .frame(width: geo.size.width * CGFloat(pattern.percentage / 100), height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)

            // Suggestion if available
            if let suggestion = pattern.suggestion {
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 10))
                    Text(suggestion)
                        .font(settings.scaledFont(.small))
                }
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }
        }
        .padding(12)
        .glassBackground(cornerRadius: 8)
    }
}

// MARK: - Recent Error Row

private struct RecentErrorRow: View {
    let event: ErrorEvent

    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            // Category icon
            Image(systemName: event.category.icon)
                .foregroundColor(event.category.color(for: colorScheme))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                // Tool name and category
                HStack {
                    Text(event.toolName)
                        .font(settings.scaledFont(.body))
                        .foregroundColor(CLITheme.primaryText(for: colorScheme))

                    Text("•")
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))

                    Text(event.category.shortLabel)
                        .font(settings.scaledFont(.small))
                        .foregroundColor(event.category.color(for: colorScheme))
                }

                // Error snippet
                Text(event.errorSnippet)
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                    .lineLimit(1)
                    .truncationMode(.tail)

                // Timestamp
                Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }

            Spacer()

            // Exit code if present
            if let code = event.exitCode {
                Text("Exit \(code)")
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(CLITheme.background(for: colorScheme))
                    .cornerRadius(4)
            }
        }
        .padding(10)
        .glassBackground(cornerRadius: 8)
    }
}

// MARK: - Preview

#Preview {
    ErrorInsightsView()
        .environmentObject(AppSettings())
}
