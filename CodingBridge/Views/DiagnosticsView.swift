import SwiftUI

/// Consolidated diagnostics hub accessible from Settings
struct DiagnosticsView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var healthService = HealthMonitorService.shared
    @ObservedObject var networkMonitor = NetworkMonitor.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                serverHealthSection
                networkSection
                diagnosticActionsSection
                appInfoSection
            }
            .padding()
        }
        .background(CLITheme.background(for: colorScheme))
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            healthService.configure(serverURL: settings.serverURL)
            healthService.startPolling()
            networkMonitor.start()
        }
    }

    // MARK: - Server Health Section

    private var serverHealthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DiagnosticsSectionHeader(title: "Server Health", icon: "server.rack")

            VStack(spacing: 12) {
                // Status row
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(serverStatusColor)
                            .frame(width: 12, height: 12)
                        Text(healthService.serverStatus.displayText)
                            .font(settings.scaledFont(.body))
                            .foregroundColor(CLITheme.primaryText(for: colorScheme))
                    }

                    Spacer()

                    if !healthService.serverVersion.isEmpty {
                        Text("v\(healthService.serverVersion)")
                            .font(settings.scaledFont(.small))
                            .foregroundColor(CLITheme.cyan(for: colorScheme))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(CLITheme.cyan(for: colorScheme).opacity(0.15))
                            .cornerRadius(6)
                    }
                }

                Divider()
                    .background(CLITheme.mutedText(for: colorScheme).opacity(0.3))

                // Stats grid
                HStack(spacing: 0) {
                    DiagnosticsStatItem(
                        label: "Uptime",
                        value: healthService.formattedUptime,
                        icon: "clock"
                    )

                    Divider()
                        .frame(height: 40)
                        .background(CLITheme.mutedText(for: colorScheme).opacity(0.3))

                    DiagnosticsStatItem(
                        label: "Agents",
                        value: "\(healthService.activeAgents)",
                        icon: "person.2"
                    )

                    Divider()
                        .frame(height: 40)
                        .background(CLITheme.mutedText(for: colorScheme).opacity(0.3))

                    DiagnosticsStatItem(
                        label: "Latency",
                        value: healthService.formattedLatency,
                        icon: "bolt"
                    )
                }

                // Last check
                if let lastCheck = healthService.lastCheckRelative {
                    HStack {
                        Text("Last checked: \(lastCheck)")
                            .font(settings.scaledFont(.small))
                            .foregroundColor(CLITheme.mutedText(for: colorScheme))
                        Spacer()
                    }
                }

                // Error message
                if let error = healthService.lastError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 12))
                            .foregroundColor(CLITheme.yellow(for: colorScheme))
                        Text(error)
                            .font(settings.scaledFont(.small))
                            .foregroundColor(CLITheme.yellow(for: colorScheme))
                        Spacer()
                    }
                }
            }
            .padding()
            .background(CLITheme.secondaryBackground(for: colorScheme))
            .cornerRadius(12)
        }
    }

    private var serverStatusColor: Color {
        switch healthService.serverStatus {
        case .connected: return CLITheme.green(for: colorScheme)
        case .disconnected: return CLITheme.red(for: colorScheme)
        case .checking: return CLITheme.yellow(for: colorScheme)
        }
    }

    // MARK: - Network Section

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DiagnosticsSectionHeader(title: "Network", icon: "network")

            VStack(spacing: 12) {
                // Connection status
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: networkMonitor.connectionType.icon)
                            .font(.system(size: 16))
                            .foregroundColor(CLITheme.blue(for: colorScheme))
                        Text(networkMonitor.connectionType.displayName)
                            .font(settings.scaledFont(.body))
                            .foregroundColor(CLITheme.primaryText(for: colorScheme))
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        if networkMonitor.isExpensive {
                            NetworkBadge(text: "Metered", color: CLITheme.yellow(for: colorScheme))
                        }
                        if networkMonitor.isConstrained {
                            NetworkBadge(text: "Low Data", color: CLITheme.orange(for: colorScheme))
                        }
                        if !networkMonitor.isConnected {
                            NetworkBadge(text: "Offline", color: CLITheme.red(for: colorScheme))
                        } else {
                            NetworkBadge(text: "Online", color: CLITheme.green(for: colorScheme))
                        }
                    }
                }

                Divider()
                    .background(CLITheme.mutedText(for: colorScheme).opacity(0.3))

                // Server URL
                VStack(alignment: .leading, spacing: 4) {
                    Text("Server URL")
                        .font(settings.scaledFont(.small))
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    Text(settings.serverURL)
                        .font(settings.scaledFont(.body))
                        .foregroundColor(CLITheme.primaryText(for: colorScheme))
                        .lineLimit(1)
                }
            }
            .padding()
            .background(CLITheme.secondaryBackground(for: colorScheme))
            .cornerRadius(12)
        }
    }

    // MARK: - Diagnostic Actions Section

    private var diagnosticActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DiagnosticsSectionHeader(title: "Tools", icon: "wrench.and.screwdriver")

            VStack(spacing: 0) {
                // Debug Logs
                NavigationLink {
                    DebugLogView()
                        .environmentObject(settings)
                } label: {
                    DiagnosticsActionRow(
                        title: "Debug Logs",
                        subtitle: "View WebSocket messages and events",
                        icon: "list.bullet.rectangle",
                        color: CLITheme.purple(for: colorScheme)
                    )
                }

                Divider()
                    .padding(.leading, 52)

                // Metrics Dashboard
                NavigationLink {
                    MetricsDashboardView()
                        .environmentObject(settings)
                } label: {
                    DiagnosticsActionRow(
                        title: "Server Metrics",
                        subtitle: "View counters, gauges, and histograms",
                        icon: "chart.bar",
                        color: CLITheme.green(for: colorScheme)
                    )
                }

                Divider()
                    .padding(.leading, 52)

                // Force Refresh
                Button {
                    Task {
                        await healthService.forceCheck()
                    }
                } label: {
                    DiagnosticsActionRow(
                        title: "Refresh Connection",
                        subtitle: "Force a server health check",
                        icon: "arrow.clockwise",
                        color: CLITheme.blue(for: colorScheme)
                    )
                }
            }
            .background(CLITheme.secondaryBackground(for: colorScheme))
            .cornerRadius(12)
        }
    }

    // MARK: - App Info Section

    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DiagnosticsSectionHeader(title: "App Info", icon: "info.circle")

            VStack(spacing: 8) {
                InfoRow(label: "App Version", value: appVersion)
                InfoRow(label: "Build", value: buildNumber)
                InfoRow(label: "iOS Version", value: iosVersion)
                InfoRow(label: "Device", value: deviceModel)
            }
            .padding()
            .background(CLITheme.secondaryBackground(for: colorScheme))
            .cornerRadius(12)
        }
    }

    // MARK: - App Info Helpers

    private var appVersion: String {
        AppVersion.version
    }

    private var buildNumber: String {
        AppVersion.build
    }

    private var iosVersion: String {
        "iOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
    }

    private var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}

// MARK: - Supporting Views

private struct DiagnosticsSectionHeader: View {
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

private struct DiagnosticsStatItem: View {
    let label: String
    let value: String
    let icon: String
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
            Text(value)
                .font(settings.scaledFont(.body))
                .fontWeight(.medium)
                .foregroundColor(CLITheme.primaryText(for: colorScheme))
            Text(label)
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct NetworkBadge: View {
    let text: String
    let color: Color
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Text(text)
            .font(settings.scaledFont(.small))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }
}

private struct DiagnosticsActionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(settings.scaledFont(.body))
                    .foregroundColor(CLITheme.primaryText(for: colorScheme))
                Text(subtitle)
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
        }
        .padding()
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            Text(label)
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
            Spacer()
            Text(value)
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DiagnosticsView()
            .environmentObject(AppSettings())
    }
    .preferredColorScheme(.dark)
}
