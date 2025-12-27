import SwiftUI

// MARK: - Session Picker

struct SessionPicker: View {
    let sessions: [ProjectSession]
    @Binding var selected: ProjectSession?
    var isLoading: Bool = false
    let onSelect: (ProjectSession) -> Void
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    selected = nil
                } label: {
                    Text("New")
                        .font(settings.scaledFont(.small))
                        .foregroundColor(selected == nil ? CLITheme.background(for: colorScheme) : CLITheme.cyan(for: colorScheme))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selected == nil ? CLITheme.cyan(for: colorScheme) : CLITheme.secondaryBackground(for: colorScheme))
                        .cornerRadius(4)
                }

                ForEach(sessions.prefix(5)) { session in
                    Button {
                        selected = session
                        onSelect(session)
                    } label: {
                        HStack(spacing: 4) {
                            // Show loading indicator for selected session
                            if isLoading && selected?.id == session.id {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 12, height: 12)
                            }
                            Text(session.summary ?? "Session")
                                .font(settings.scaledFont(.small))
                                .lineLimit(1)
                        }
                        .foregroundColor(selected?.id == session.id ? CLITheme.background(for: colorScheme) : CLITheme.primaryText(for: colorScheme))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selected?.id == session.id ? CLITheme.cyan(for: colorScheme) : CLITheme.secondaryBackground(for: colorScheme))
                        .cornerRadius(4)
                    }
                    .disabled(isLoading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(CLITheme.background(for: colorScheme))
    }
}

// MARK: - Session Picker Sheet

struct SessionPickerSheet: View {
    let project: Project
    let sessions: [ProjectSession]
    let onSelect: (ProjectSession) -> Void
    let onCancel: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48))
                            .foregroundColor(CLITheme.mutedText(for: colorScheme))

                        Text("No Previous Sessions")
                            .font(.headline)
                            .foregroundColor(CLITheme.primaryText(for: colorScheme))

                        Text("Start a conversation to create your first session.")
                            .font(.subheadline)
                            .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List(sessions) { session in
                        Button {
                            onSelect(session)
                        } label: {
                            SessionRow(session: session)
                        }
                        .listRowBackground(CLITheme.secondaryBackground(for: colorScheme))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Resume Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                }
            }
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: ProjectSession
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.id.prefix(8) + "...")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(CLITheme.cyan(for: colorScheme))

                Spacer()

                if let activity = session.lastActivity {
                    Text(formatRelativeTime(activity))
                        .font(.caption)
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                }
            }

            if let summary = session.summary, !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundColor(CLITheme.primaryText(for: colorScheme))
                    .lineLimit(2)
            } else if let lastMsg = session.lastUserMessage, !lastMsg.isEmpty {
                Text(lastMsg)
                    .font(.subheadline)
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                    .lineLimit(2)
            }

            if let count = session.messageCount {
                Text("\(count) messages")
                    .font(.caption)
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }
        }
        .padding(.vertical, 4)
    }

    private func formatRelativeTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: isoString) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: isoString) else {
                return isoString
            }
            return relativeString(from: date)
        }
        return relativeString(from: date)
    }

    private func relativeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
