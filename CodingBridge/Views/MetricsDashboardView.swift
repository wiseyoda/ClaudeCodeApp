import SwiftUI

/// Displays detailed server metrics from the /metrics endpoint
struct MetricsDashboardView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    @State private var metrics: CLIMetricsResponse?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = error {
                errorView(error)
            } else if let metrics = metrics {
                metricsContent(metrics)
            } else {
                emptyView
            }
        }
        .background(CLITheme.background(for: colorScheme))
        .navigationTitle("Server Metrics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .refreshable {
            await fetchMetrics()
        }
        .task {
            await fetchMetrics()
        }
    }

    // MARK: - Content Views

    private func metricsContent(_ metrics: CLIMetricsResponse) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Overview
                overviewSection(metrics)

                // Counters
                if let counters = metrics.counters, !counters.isEmpty {
                    countersSection(counters)
                }

                // Gauges
                if let gauges = metrics.gauges, !gauges.isEmpty {
                    gaugesSection(gauges)
                }

                // Histograms
                if let histograms = metrics.histograms, !histograms.isEmpty {
                    histogramsSection(histograms)
                }
            }
            .padding()
        }
    }

    private func overviewSection(_ metrics: CLIMetricsResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Overview", icon: "gauge.open.with.lines.needle.33percent")

            HStack(spacing: 12) {
                OverviewCard(
                    title: "Version",
                    value: metrics.version,
                    icon: "tag",
                    color: CLITheme.blue(for: colorScheme)
                )

                OverviewCard(
                    title: "Uptime",
                    value: HealthMonitorService.shared.formatUptime(metrics.uptime),
                    icon: "clock",
                    color: CLITheme.cyan(for: colorScheme)
                )

                OverviewCard(
                    title: "Agents",
                    value: "\(metrics.agents)",
                    icon: "person.2",
                    color: CLITheme.purple(for: colorScheme)
                )
            }
        }
    }

    private func countersSection(_ counters: [String: Int]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Counters", icon: "number")

            VStack(spacing: 8) {
                ForEach(counters.keys.sorted(), id: \.self) { key in
                    MetricRow(
                        name: formatMetricName(key),
                        value: "\(counters[key] ?? 0)",
                        color: CLITheme.orange(for: colorScheme)
                    )
                }
            }
            .padding()
            .background(CLITheme.secondaryBackground(for: colorScheme))
            .cornerRadius(12)
        }
    }

    private func gaugesSection(_ gauges: [String: Double]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Gauges", icon: "gauge")

            VStack(spacing: 8) {
                ForEach(gauges.keys.sorted(), id: \.self) { key in
                    MetricRow(
                        name: formatMetricName(key),
                        value: formatGaugeValue(gauges[key] ?? 0),
                        color: CLITheme.green(for: colorScheme)
                    )
                }
            }
            .padding()
            .background(CLITheme.secondaryBackground(for: colorScheme))
            .cornerRadius(12)
        }
    }

    private func histogramsSection(_ histograms: [String: CLIHistogramStats]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Histograms", icon: "chart.bar")

            VStack(spacing: 12) {
                ForEach(histograms.keys.sorted(), id: \.self) { key in
                    if let stats = histograms[key] {
                        HistogramCard(name: formatMetricName(key), stats: stats)
                    }
                }
            }
        }
    }

    // MARK: - Loading/Error Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: CLITheme.blue(for: colorScheme)))

            Text("Loading metrics...")
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(CLITheme.yellow(for: colorScheme))

            Text("Failed to Load Metrics")
                .font(settings.scaledFont(.large))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            Text(error)
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task { await fetchMetrics() }
            }
            .foregroundColor(CLITheme.blue(for: colorScheme))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))

            Text("No Metrics Available")
                .font(settings.scaledFont(.large))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            Text("No metrics have been collected yet.\nMetrics will appear as the server processes requests.")
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data Fetching

    private func fetchMetrics() async {
        isLoading = true
        error = nil

        do {
            let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)
            metrics = try await apiClient.getMetrics()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Formatting Helpers

    private func formatMetricName(_ name: String) -> String {
        // Convert snake_case or camelCase to Title Case
        name
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
            .capitalized
    }

    private func formatGaugeValue(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value)
        } else if value < 0.01 {
            return String(format: "%.4f", value)
        } else if value < 1 {
            return String(format: "%.3f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

// MARK: - Supporting Views

private struct SectionHeader: View {
    let title: String
    let icon: String
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))

            Text(title)
                .font(settings.scaledFont(.body))
                .fontWeight(.medium)
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
        }
    }
}

private struct OverviewCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text(value)
                .font(settings.scaledFont(.body))
                .fontWeight(.medium)
                .foregroundColor(CLITheme.primaryText(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(CLITheme.secondaryBackground(for: colorScheme))
        .cornerRadius(12)
    }
}

private struct MetricRow: View {
    let name: String
    let value: String
    let color: Color
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            Text(name)
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            Spacer()

            Text(value)
                .font(settings.scaledFont(.body))
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

private struct HistogramCard: View {
    let name: String
    let stats: CLIHistogramStats
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(settings.scaledFont(.body))
                .fontWeight(.medium)
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            HStack(spacing: 16) {
                StatItem(label: "Min", value: formatValue(stats.min))
                StatItem(label: "Avg", value: formatValue(stats.avg))
                StatItem(label: "Max", value: formatValue(stats.max))
            }

            HStack(spacing: 16) {
                StatItem(label: "P50", value: formatValue(stats.p50))
                StatItem(label: "P95", value: formatValue(stats.p95))
                StatItem(label: "Count", value: "\(stats.count)")
            }
        }
        .padding()
        .background(CLITheme.secondaryBackground(for: colorScheme))
        .cornerRadius(12)
    }

    private func formatValue(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value)
        } else if value < 1 {
            return String(format: "%.3f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

private struct StatItem: View {
    let label: String
    let value: String
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))

            Text(value)
                .font(settings.scaledFont(.body))
                .fontWeight(.medium)
                .foregroundColor(CLITheme.green(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MetricsDashboardView()
            .environmentObject(AppSettings())
    }
    .preferredColorScheme(.dark)
}
