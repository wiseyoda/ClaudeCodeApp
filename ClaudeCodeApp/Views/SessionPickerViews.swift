import SwiftUI
import UniformTypeIdentifiers

// MARK: - Session Names Storage

/// Stores custom names for sessions (persisted locally)
class SessionNamesStore {
    static let shared = SessionNamesStore()
    private let key = "session_custom_names"

    func getName(for sessionId: String) -> String? {
        let names = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
        return names[sessionId]
    }

    func setName(_ name: String?, for sessionId: String) {
        var names = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
        if let name = name, !name.isEmpty {
            names[sessionId] = name
        } else {
            names.removeValue(forKey: sessionId)
        }
        UserDefaults.standard.set(names, forKey: key)
    }
}

// MARK: - Session Picker

struct SessionPicker: View {
    let sessions: [ProjectSession]
    let project: Project
    @Binding var selected: ProjectSession?
    var isLoading: Bool = false
    var isProcessing: Bool = false
    var activeSessionId: String?  // Currently active session (may be processing)
    let onSelect: (ProjectSession) -> Void
    let onNew: () -> Void
    let onDelete: ((ProjectSession) -> Void)?
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    @State private var showAllSessions = false

    /// Determines if a session should be shown as selected
    private func isSessionSelected(_ session: ProjectSession) -> Bool {
        if let selected = selected {
            return selected.id == session.id
        }
        return activeSessionId == session.id
    }

    /// "New" is selected only when there's no active session at all
    private var isNewSelected: Bool {
        selected == nil && activeSessionId == nil
    }

    /// Sessions sorted by last activity (most recent first), excluding placeholder sessions
    private var sortedSessions: [ProjectSession] {
        sessions
            .filter { session in
                // Filter out placeholder sessions - backend initializes with summary="New Session"
                // These are sessions created but not yet used (no real user message sent)
                session.summary != nil && session.summary != "New Session"
            }
            .sorted { s1, s2 in
                let date1 = parseDate(s1.lastActivity)
                let date2 = parseDate(s2.lastActivity)
                return date1 > date2
            }
    }

    /// Number of sessions not shown in the bar (based on filtered sessions)
    private var hiddenSessionCount: Int {
        max(0, sortedSessions.count - 5)
    }

    private func parseDate(_ isoString: String?) -> Date {
        guard let isoString = isoString else { return .distantPast }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: isoString) ?? .distantPast
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // New button
                Button {
                    onNew()
                } label: {
                    Text("New")
                        .font(settings.scaledFont(.small))
                        .foregroundColor(isNewSelected ? CLITheme.background(for: colorScheme) : CLITheme.cyan(for: colorScheme))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isNewSelected ? CLITheme.cyan(for: colorScheme) : CLITheme.secondaryBackground(for: colorScheme))
                        .cornerRadius(4)
                }

                // Recent sessions (up to 5)
                ForEach(sortedSessions.prefix(5)) { session in
                    sessionButton(for: session)
                }

                // Always show "all sessions" button (with count if > 5)
                Button {
                    showAllSessions = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 11))
                        if hiddenSessionCount > 0 {
                            Text("+\(hiddenSessionCount)")
                                .font(settings.scaledFont(.small))
                        }
                    }
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(CLITheme.secondaryBackground(for: colorScheme))
                    .cornerRadius(4)
                }
                .accessibilityLabel("All sessions")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(CLITheme.background(for: colorScheme))
        .sheet(isPresented: $showAllSessions) {
            SessionPickerSheet(
                project: project,
                sessions: sessions,
                onSelect: { session in
                    showAllSessions = false
                    selected = session
                    onSelect(session)
                },
                onCancel: {
                    showAllSessions = false
                },
                onDelete: onDelete
            )
        }
    }

    @ViewBuilder
    private func sessionButton(for session: ProjectSession) -> some View {
        Button {
            selected = session
            onSelect(session)
        } label: {
            HStack(spacing: 4) {
                // Show processing indicator for active session
                if isProcessing && activeSessionId == session.id {
                    Circle()
                        .fill(CLITheme.yellow(for: colorScheme))
                        .frame(width: 6, height: 6)
                }
                // Show loading indicator when fetching history
                if isLoading && selected?.id == session.id {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                }
                Text(displayName(for: session))
                    .font(settings.scaledFont(.small))
                    .lineLimit(1)
            }
            .foregroundColor(isSessionSelected(session) ? CLITheme.background(for: colorScheme) : CLITheme.primaryText(for: colorScheme))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSessionSelected(session) ? CLITheme.cyan(for: colorScheme) : CLITheme.secondaryBackground(for: colorScheme))
            .cornerRadius(4)
        }
        .disabled(isLoading)
        .contextMenu {
            Button {
                showAllSessions = true
            } label: {
                Label("All Sessions", systemImage: "list.bullet")
            }

            Divider()

            Button(role: .destructive) {
                onDelete?(session)
            } label: {
                Label("Delete Session", systemImage: "trash")
            }
        }
    }

    private func displayName(for session: ProjectSession) -> String {
        if let customName = SessionNamesStore.shared.getName(for: session.id) {
            return customName
        }
        return session.summary ?? "Session"
    }
}

// MARK: - Session Picker Sheet

struct SessionPickerSheet: View {
    let project: Project
    let sessions: [ProjectSession]
    let onSelect: (ProjectSession) -> Void
    let onCancel: () -> Void
    var onDelete: ((ProjectSession) -> Void)?
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var settings: AppSettings

    @State private var sessionToDelete: ProjectSession?
    @State private var sessionToRename: ProjectSession?
    @State private var renameText = ""
    @State private var sessionToExport: ProjectSession?
    @State private var exportedMarkdown: String?
    @State private var showExportSheet = false

    /// Sessions sorted by last activity (most recent first), excluding placeholder sessions
    private var sortedSessions: [ProjectSession] {
        sessions
            .filter { session in
                // Filter out placeholder sessions - backend initializes with summary="New Session"
                // These are sessions created but not yet used (no real user message sent)
                session.summary != nil && session.summary != "New Session"
            }
            .sorted { s1, s2 in
                let date1 = parseDate(s1.lastActivity)
                let date2 = parseDate(s2.lastActivity)
                return date1 > date2
            }
    }

    private func parseDate(_ isoString: String?) -> Date {
        guard let isoString = isoString else { return .distantPast }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: isoString) ?? .distantPast
    }

    var body: some View {
        NavigationStack {
            Group {
                if sortedSessions.isEmpty {
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
                    List(sortedSessions) { session in
                        Button {
                            onSelect(session)
                        } label: {
                            SessionRow(session: session)
                        }
                        .listRowBackground(CLITheme.secondaryBackground(for: colorScheme))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                sessionToDelete = session
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                sessionToExport = session
                                exportSession(session)
                            } label: {
                                Label("Export", systemImage: "square.and.arrow.up")
                            }
                            .tint(CLITheme.cyan(for: colorScheme))
                        }
                        .contextMenu {
                            Button {
                                sessionToRename = session
                                renameText = SessionNamesStore.shared.getName(for: session.id) ?? session.summary ?? ""
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }

                            Button {
                                sessionToExport = session
                                exportSession(session)
                            } label: {
                                Label("Export as Markdown", systemImage: "doc.text")
                            }

                            Divider()

                            Button(role: .destructive) {
                                sessionToDelete = session
                            } label: {
                                Label("Delete Session", systemImage: "trash")
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                }
            }
            .alert("Delete Session?", isPresented: .init(
                get: { sessionToDelete != nil },
                set: { if !$0 { sessionToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    sessionToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let session = sessionToDelete {
                        onDelete?(session)
                        sessionToDelete = nil
                    }
                }
            } message: {
                Text("This will permanently delete this session's history.")
            }
            .alert("Rename Session", isPresented: .init(
                get: { sessionToRename != nil },
                set: { if !$0 { sessionToRename = nil } }
            )) {
                TextField("Session name", text: $renameText)
                Button("Cancel", role: .cancel) {
                    sessionToRename = nil
                    renameText = ""
                }
                Button("Save") {
                    if let session = sessionToRename {
                        SessionNamesStore.shared.setName(renameText.isEmpty ? nil : renameText, for: session.id)
                    }
                    sessionToRename = nil
                    renameText = ""
                }
            } message: {
                Text("Enter a custom name for this session")
            }
            .sheet(isPresented: $showExportSheet) {
                if let markdown = exportedMarkdown {
                    SessionExportSheet(markdown: markdown, sessionId: sessionToExport?.id ?? "session")
                }
            }
        }
    }

    private func exportSession(_ session: ProjectSession) {
        // Build markdown from session info
        var markdown = "# Session: \(SessionNamesStore.shared.getName(for: session.id) ?? session.summary ?? session.id.prefix(8).description)\n\n"
        markdown += "**Project:** \(project.title)\n"
        markdown += "**Path:** \(project.path)\n"
        if let activity = session.lastActivity {
            markdown += "**Last Activity:** \(activity)\n"
        }
        if let count = session.messageCount {
            markdown += "**Messages:** \(count)\n"
        }
        markdown += "\n---\n\n"

        if let lastUser = session.lastUserMessage {
            markdown += "## Last User Message\n\n\(lastUser)\n\n"
        }
        if let lastAssistant = session.lastAssistantMessage {
            markdown += "## Last Assistant Response\n\n\(lastAssistant)\n\n"
        }

        markdown += "\n---\n\n*Exported from ClaudeCodeApp*\n"

        exportedMarkdown = markdown
        showExportSheet = true
    }
}

// MARK: - Session Export Sheet

struct SessionExportSheet: View {
    let markdown: String
    let sessionId: String
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(markdown)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(CLITheme.primaryText(for: colorScheme))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Export Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button {
                            UIPasteboard.general.string = markdown
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }

                        Button {
                            shareMarkdown()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    private func shareMarkdown() {
        let activityVC = UIActivityViewController(
            activityItems: [markdown],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: ProjectSession
    @Environment(\.colorScheme) var colorScheme

    private var displayName: String {
        if let customName = SessionNamesStore.shared.getName(for: session.id) {
            return customName
        }
        if let summary = session.summary, !summary.isEmpty {
            return summary
        }
        return "Session \(session.id.prefix(8))..."
    }

    private var hasCustomName: Bool {
        SessionNamesStore.shared.getName(for: session.id) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(displayName)
                    .font(.system(.body, design: hasCustomName ? .default : .monospaced))
                    .foregroundColor(CLITheme.cyan(for: colorScheme))
                    .lineLimit(1)

                Spacer()

                if let activity = session.lastActivity {
                    Text(formatRelativeTime(activity))
                        .font(.caption)
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                }
            }

            // Show last user message as preview
            if let lastMsg = session.lastUserMessage, !lastMsg.isEmpty {
                Text(lastMsg)
                    .font(.subheadline)
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                    .lineLimit(2)
            }

            HStack {
                if let count = session.messageCount {
                    Text("\(count) messages")
                        .font(.caption)
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                }

                // Show session ID if we have a custom name
                if hasCustomName {
                    Text("•")
                        .font(.caption)
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    Text(session.id.prefix(8) + "...")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                }
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
