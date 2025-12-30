import SwiftUI

/// Displays CLI Bridge server health status and connection info
struct ServerHealthView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var healthService = HealthMonitorService.shared
    @ObservedObject var networkMonitor = NetworkMonitor.shared

    var body: some View {
        VStack(spacing: 16) {
            connectionStatusCard
            serverStatsRow
            networkInfoSection
            quickActionsSection
        }
        .padding()
        .onAppear {
            healthService.configure(serverURL: settings.serverURL)
            healthService.startPolling()
        }
        .onDisappear {
            healthService.stopPolling()
        }
    }

    // MARK: - Connection Status Card

    private var connectionStatusCard: some View {
        HStack(spacing: 12) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 16, height: 16)

                if healthService.serverStatus == .checking {
                    Circle()
                        .stroke(statusColor.opacity(0.5), lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .modifier(PulsingAnimation())
                }
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(settings.scaledFont(.large))
                    .fontWeight(.medium)
                    .foregroundColor(CLITheme.primaryText(for: colorScheme))

                if let lastCheck = healthService.lastCheckRelative {
                    Text("Last checked: \(lastCheck)")
                        .font(settings.scaledFont(.small))
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                }
            }

            Spacer()

            // Version badge
            if !healthService.serverVersion.isEmpty {
                Text("v\(healthService.serverVersion)")
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.cyan(for: colorScheme))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(CLITheme.cyan(for: colorScheme).opacity(0.15))
                    .cornerRadius(8)
            }
        }
        .padding()
        .glassBackground(tint: glassTint, cornerRadius: 16)
    }

    private var statusTitle: String {
        switch healthService.serverStatus {
        case .connected:
            return "Connected to CLI Bridge"
        case .disconnected:
            return "Disconnected"
        case .checking:
            return "Checking connection..."
        }
    }

    private var statusColor: Color {
        switch healthService.serverStatus {
        case .connected:
            return CLITheme.green(for: colorScheme)
        case .disconnected:
            return CLITheme.red(for: colorScheme)
        case .checking:
            return CLITheme.yellow(for: colorScheme)
        }
    }

    private var glassTint: CLITheme.GlassTint? {
        switch healthService.serverStatus {
        case .connected: return .success
        case .disconnected: return .error
        case .checking: return .warning
        }
    }

    // MARK: - Server Stats Row

    private var serverStatsRow: some View {
        HStack(spacing: 12) {
            // Uptime
            StatCard(
                icon: "clock",
                title: "Uptime",
                value: healthService.formattedUptime,
                color: CLITheme.cyan(for: colorScheme)
            )

            // Active Agents
            StatCard(
                icon: "person.2",
                title: "Agents",
                value: "\(healthService.activeAgents)",
                color: CLITheme.purple(for: colorScheme)
            )

            // Latency
            StatCard(
                icon: "bolt",
                title: "Latency",
                value: healthService.formattedLatency,
                color: latencyColor
            )
        }
    }

    private var latencyColor: Color {
        switch healthService.latencyStatus {
        case .good: return CLITheme.green(for: colorScheme)
        case .moderate: return CLITheme.yellow(for: colorScheme)
        case .poor: return CLITheme.red(for: colorScheme)
        }
    }

    // MARK: - Network Info Section

    private var networkInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Network")
                .font(settings.scaledFont(.small))
                .fontWeight(.medium)
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))

            HStack(spacing: 12) {
                // Connection type
                HStack(spacing: 6) {
                    Image(systemName: networkMonitor.connectionType.icon)
                        .font(.system(size: 14))
                        .foregroundColor(CLITheme.blue(for: colorScheme))

                    Text(networkMonitor.connectionType.displayName)
                        .font(settings.scaledFont(.body))
                        .foregroundColor(CLITheme.primaryText(for: colorScheme))
                }

                Spacer()

                // Badges
                HStack(spacing: 8) {
                    if networkMonitor.isExpensive {
                        Badge(text: "Metered", color: CLITheme.yellow(for: colorScheme))
                    }
                    if networkMonitor.isConstrained {
                        Badge(text: "Low Data", color: CLITheme.orange(for: colorScheme))
                    }
                    if !networkMonitor.isConnected {
                        Badge(text: "Offline", color: CLITheme.red(for: colorScheme))
                    }
                }
            }
            .padding()
            .background(CLITheme.secondaryBackground(for: colorScheme))
            .cornerRadius(12)
        }
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Actions")
                .font(settings.scaledFont(.small))
                .fontWeight(.medium)
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))

            HStack(spacing: 12) {
                ActionButton(
                    icon: "arrow.clockwise",
                    title: "Refresh",
                    color: CLITheme.blue(for: colorScheme)
                ) {
                    Task {
                        await healthService.forceCheck()
                    }
                }

                NavigationLink {
                    DebugLogView()
                        .environmentObject(settings)
                } label: {
                    ActionButtonLabel(
                        icon: "list.bullet.rectangle",
                        title: "Debug Logs",
                        color: CLITheme.purple(for: colorScheme)
                    )
                }

                NavigationLink {
                    MetricsDashboardView()
                        .environmentObject(settings)
                } label: {
                    ActionButtonLabel(
                        icon: "chart.bar",
                        title: "Metrics",
                        color: CLITheme.green(for: colorScheme)
                    )
                }
            }
        }
    }
}

// MARK: - Supporting Views

private struct StatCard: View {
    let icon: String
    let title: String
    let value: String
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

private struct Badge: View {
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
            .cornerRadius(8)
    }
}

private struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            ActionButtonLabel(icon: icon, title: title, color: color)
        }
    }
}

private struct ActionButtonLabel: View {
    let icon: String
    let title: String
    let color: Color
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text(title)
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(CLITheme.secondaryBackground(for: colorScheme))
        .cornerRadius(12)
    }
}

private struct PulsingAnimation: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.3 : 1.0)
            .opacity(isAnimating ? 0 : 0.7)
            .animation(
                .easeOut(duration: 1.0)
                .repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ServerHealthView()
            .environmentObject(AppSettings())
    }
    .preferredColorScheme(.dark)
}
