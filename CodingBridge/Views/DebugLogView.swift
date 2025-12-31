import SwiftUI

// MARK: - Debug Log View

/// View for displaying and filtering debug logs
struct DebugLogView: View {
    @Bindable var store = DebugLogStore.shared  // @Bindable enables $store.property bindings
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @State private var selectedEntry: DebugLogEntry?
    @State private var showFilters = false
    @State private var showCopiedToast = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))

                    TextField("Search logs...", text: $store.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, design: .monospaced))

                    if !store.searchText.isEmpty {
                        Button {
                            store.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(CLITheme.mutedText(for: colorScheme))
                        }
                    }
                }
                .padding(10)
                .background(CLITheme.secondaryBackground(for: colorScheme))

                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DebugLogType.allCases, id: \.self) { type in
                            DebugFilterChip(
                                type: type,
                                isSelected: store.typeFilter.contains(type)
                            ) {
                                if store.typeFilter.contains(type) {
                                    store.typeFilter.remove(type)
                                } else {
                                    store.typeFilter.insert(type)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(CLITheme.background(for: colorScheme))

                Divider()

                // Log entries
                if store.filteredEntries.isEmpty {
                    emptyState
                } else {
                    logList
                }
            }
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Debug Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            store.copyToClipboard()
                            showCopiedToast = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showCopiedToast = false
                            }
                        } label: {
                            Label("Copy All", systemImage: "doc.on.doc")
                        }

                        Button(role: .destructive) {
                            store.clear()
                        } label: {
                            Label("Clear Logs", systemImage: "trash")
                        }

                        Divider()

                        Toggle(isOn: $store.isEnabled) {
                            Label("Enable Logging", systemImage: "record.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .overlay {
                if showCopiedToast {
                    VStack {
                        Spacer()
                        Text("Copied to clipboard")
                            .font(.caption)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(CLITheme.secondaryBackground(for: colorScheme))
                            .cornerRadius(8)
                            .shadow(radius: 4)
                            .padding(.bottom, 20)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.2), value: showCopiedToast)
                }
            }
            .sheet(item: $selectedEntry) { entry in
                DebugLogDetailView(entry: entry)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: store.isEnabled ? "doc.text" : "pause.circle")
                .font(.system(size: 48))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))

            Text(store.isEnabled ? "No logs yet" : "Logging disabled")
                .font(.headline)
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            Text(store.isEnabled
                 ? "WebSocket messages will appear here"
                 : "Enable debug logging in settings to capture messages")
                .font(.caption)
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if !store.isEnabled {
                Button {
                    store.isEnabled = true
                } label: {
                    Text("Enable Logging")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(CLITheme.blue(for: colorScheme))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.top, 8)
            }

            Spacer()
        }
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(store.filteredEntries) { entry in
                    DebugLogRow(entry: entry)
                        .listRowBackground(CLITheme.secondaryBackground(for: colorScheme))
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        .id(entry.id)
                        .onTapGesture {
                            selectedEntry = entry
                        }
                }
            }
            .listStyle(.plain)
            .onChange(of: store.entries.count) { _, _ in
                // Auto-scroll to latest
                if let last = store.filteredEntries.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Debug Filter Chip

private struct DebugFilterChip: View {
    let type: DebugLogType
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var chipColor: Color {
        switch type.colorName {
        case "blue": return CLITheme.blue(for: colorScheme)
        case "green": return CLITheme.green(for: colorScheme)
        case "red": return CLITheme.red(for: colorScheme)
        case "orange": return CLITheme.yellow(for: colorScheme)
        default: return CLITheme.secondaryText(for: colorScheme)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.system(size: 10))
                Text(type.rawValue)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? chipColor.opacity(0.2) : CLITheme.secondaryBackground(for: colorScheme))
            .foregroundColor(isSelected ? chipColor : CLITheme.secondaryText(for: colorScheme))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? chipColor : Color.clear, lineWidth: 1)
            )
        }
    }
}

// MARK: - Debug Log Row

private struct DebugLogRow: View {
    let entry: DebugLogEntry
    @Environment(\.colorScheme) var colorScheme

    private var typeColor: Color {
        switch entry.type.colorName {
        case "blue": return CLITheme.blue(for: colorScheme)
        case "green": return CLITheme.green(for: colorScheme)
        case "red": return CLITheme.red(for: colorScheme)
        case "orange": return CLITheme.yellow(for: colorScheme)
        default: return CLITheme.secondaryText(for: colorScheme)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header row
            HStack(spacing: 8) {
                Image(systemName: entry.type.icon)
                    .font(.system(size: 12))
                    .foregroundColor(typeColor)

                Text(entry.type.rawValue)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(typeColor)

                Spacer()

                Text(entry.formattedTimestamp)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }

            // Message preview (truncated)
            Text(entry.message.prefix(200) + (entry.message.count > 200 ? "..." : ""))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))
                .lineLimit(3)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Debug Log Detail View

struct DebugLogDetailView: View {
    let entry: DebugLogEntry
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @State private var showCopied = false

    private var typeColor: Color {
        switch entry.type.colorName {
        case "blue": return CLITheme.blue(for: colorScheme)
        case "green": return CLITheme.green(for: colorScheme)
        case "red": return CLITheme.red(for: colorScheme)
        case "orange": return CLITheme.yellow(for: colorScheme)
        default: return CLITheme.secondaryText(for: colorScheme)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack(spacing: 12) {
                        Image(systemName: entry.type.icon)
                            .font(.system(size: 20))
                            .foregroundColor(typeColor)
                            .frame(width: 40, height: 40)
                            .background(typeColor.opacity(0.15))
                            .cornerRadius(8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.type.rawValue)
                                .font(.headline)
                                .foregroundColor(typeColor)

                            Text(entry.formattedTimestamp)
                                .font(.caption.monospaced())
                                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                        }

                        Spacer()
                    }
                    .padding(.horizontal)

                    Divider()

                    // Message content
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Message")
                            .font(.caption.bold())
                            .foregroundColor(CLITheme.secondaryText(for: colorScheme))

                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(entry.formattedMessage)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(CLITheme.primaryText(for: colorScheme))
                                .textSelection(.enabled)
                        }
                        .padding(12)
                        .background(CLITheme.secondaryBackground(for: colorScheme))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)

                    // Details if present
                    if let details = entry.details {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Details")
                                .font(.caption.bold())
                                .foregroundColor(CLITheme.secondaryText(for: colorScheme))

                            Text(details)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(CLITheme.primaryText(for: colorScheme))
                                .textSelection(.enabled)
                                .padding(12)
                                .background(CLITheme.secondaryBackground(for: colorScheme))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }

                    Spacer()
                }
                .padding(.vertical)
            }
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Log Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        UIPasteboard.general.string = entry.formattedMessage
                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCopied = false
                        }
                    } label: {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Preview

#Preview {
    DebugLogView()
}
