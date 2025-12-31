import SwiftUI

// MARK: - CLI Message View

struct CLIMessageView: View {
    let message: ChatMessage
    let projectPath: String?
    let projectTitle: String?
    let hideTodoInline: Bool  // Hide inline todo when drawer is showing
    @State private var isExpanded: Bool
    @State private var showCopied = false
    @State private var showActionBar = false  // Track whether to show action bar
    @ObservedObject private var bookmarkStore = BookmarkStore.shared
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    // MARK: - Cached Computed Values (computed once in init to avoid recomputation during scrolling)
    private let cachedToolType: CLITheme.ToolType
    private let cachedToolHeaderText: String
    private let cachedResultCountBadge: String?
    private let cachedToolErrorInfo: ToolErrorInfo?
    private let cachedTimestamp: String

    // MARK: - Shared Formatters (expensive to create, so share across all instances)
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private static let staticFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    /// Threshold for switching from relative to static time (1 hour)
    private static let relativeTimeThreshold: TimeInterval = 3600

    init(message: ChatMessage, projectPath: String? = nil, projectTitle: String? = nil, hideTodoInline: Bool = false) {
        self.message = message
        self.projectPath = projectPath
        self.projectTitle = projectTitle
        self.hideTodoInline = hideTodoInline

        // Pre-compute expensive values once during init
        let toolType = CLITheme.ToolType.from(message.content)
        self.cachedToolType = toolType
        self.cachedToolHeaderText = ToolParser.computeToolHeaderText(for: message.content, toolType: toolType)
        self.cachedResultCountBadge = ToolParser.computeResultCountBadge(for: message.content, role: message.role, toolType: toolType)
        self.cachedToolErrorInfo = message.role == .toolResult
            ? ToolResultParser.parse(message.content, toolName: nil)
            : nil

        // Cache timestamp string - use static format for old messages, relative for recent
        // NOTE: Cached timestamps won't update dynamically (e.g., "2m ago" won't become "3m ago").
        // This is an intentional trade-off for performance - eliminates formatter allocation during scrolling.
        // Timestamps become accurate again when the view is recreated (e.g., navigation, search filter change).
        let age = Date().timeIntervalSince(message.timestamp)
        if age > Self.relativeTimeThreshold {
            // Old message: use static format (doesn't need updating)
            self.cachedTimestamp = Self.staticFormatter.string(from: message.timestamp)
        } else {
            // Recent message: use relative format (won't update, but acceptable UX trade-off)
            self.cachedTimestamp = Self.relativeFormatter.localizedString(for: message.timestamp, relativeTo: Date())
        }

        // Collapse result messages, common tool uses (Bash/Read/Grep/Glob), and thinking blocks by default
        let shouldStartCollapsed = message.role == .resultSuccess ||
            message.role == .toolResult ||
            message.role == .thinking ||
            (message.role == .toolUse && (message.content.hasPrefix("Bash") || message.content.hasPrefix("Read") || message.content.hasPrefix("Grep") || message.content.hasPrefix("Glob")))
        self._isExpanded = State(initialValue: !shouldStartCollapsed)
    }

    private var isBookmarked: Bool {
        bookmarkStore.isBookmarked(messageId: message.id)
    }

    var body: some View {
        // Hide TodoWrite messages and their results completely when drawer is showing
        let isTodoWriteToolUse = message.role == .toolUse && message.content.hasPrefix("TodoWrite")
        let isTodoWriteResult = message.role == .toolResult && message.content.contains("Todos have been modified")
        if hideTodoInline && (isTodoWriteToolUse || isTodoWriteResult) {
            EmptyView()
        } else {
        VStack(alignment: .leading, spacing: 2) {
            // Header line with bullet/icon (skip for assistant - icon is inline with content)
            if message.role != .assistant {
                HStack(spacing: 6) {
                    // Use SF Symbol icons for tools, text bullets for others
                    if message.role == .toolUse {
                        Image(systemName: toolType.icon)
                            .foregroundColor(bulletColor)
                            .font(.system(size: 12))
                    } else {
                        Text(bulletChar)
                            .foregroundColor(bulletColor)
                            .font(settings.scaledFont(.body))
                    }

                    Text(headerText)
                        .foregroundColor(headerColor)
                        .font(settings.scaledFont(.body))

                if isCollapsible {
                    Text(isExpanded ? "[-]" : "[+]")
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                        .font(settings.scaledFont(.small))

                    // Show status text when collapsed - simple italicized text
                    if !isExpanded, let badge = resultCountBadge {
                        Text(badge)
                            .font(.system(size: 12, weight: .medium).italic())
                            .foregroundColor(badgeTextColor)
                    }

                    // Show error summary when collapsed and is an error
                    if !isExpanded, let info = toolErrorInfo, info.category != .success {
                        Text(info.errorSummary)
                            .font(settings.scaledFont(.small))
                            .foregroundColor(CLITheme.mutedText(for: colorScheme))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                // Relative timestamp (skip for toolUse, assistant, error - they show time below content)
                if message.role != .toolUse && message.role != .assistant && message.role != .error {
                    Text(cachedTimestamp)
                        .font(.system(size: 10))
                        .foregroundColor(CLITheme.mutedText(for: colorScheme).opacity(0.7))

                    // Copy button for result content (small, right after timestamp)
                    if message.role == .toolResult && !message.content.isEmpty {
                        Button {
                            HapticManager.light()
                            UIPasteboard.general.string = message.content
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showCopied = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showCopied = false
                                }
                            }
                        } label: {
                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 9))
                                .foregroundColor(
                                    showCopied
                                        ? CLITheme.green(for: colorScheme)
                                        : CLITheme.mutedText(for: colorScheme).opacity(0.6)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(showCopied ? "Copied" : "Copy result")
                    }
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isCollapsible {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(isCollapsible ? (isExpanded ? "Double tap to collapse" : "Double tap to expand") : "")
            .accessibilityAddTraits(isCollapsible ? .isButton : [])
            } // end if message.role != .assistant

            // Content (assistant messages include inline sparkle icon)
            if isExpanded || !isCollapsible {
                if message.role == .assistant {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundColor(CLITheme.purple(for: colorScheme))
                            .font(.system(size: 14))
                        contentView
                    }
                } else {
                    contentView
                        .padding(.leading, 16)
                }
            }

            // Footer for assistant messages: timestamp + copy button
            if message.role == .assistant && !message.content.isEmpty {
                HStack(spacing: 6) {
                    Text(cachedTimestamp)
                        .font(.system(size: 10))
                        .foregroundColor(CLITheme.mutedText(for: colorScheme).opacity(0.7))

                    Button {
                        HapticManager.light()
                        UIPasteboard.general.string = message.content
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCopied = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showCopied = false
                            }
                        }
                    } label: {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9))
                            .foregroundColor(
                                showCopied
                                    ? CLITheme.green(for: colorScheme)
                                    : CLITheme.mutedText(for: colorScheme).opacity(0.6)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showCopied ? "Copied" : "Copy message")

                    Spacer()

                    // Action bar toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showActionBar.toggle()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12))
                            .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("More actions")
                }
                .padding(.leading, 16)
                .padding(.top, 4)
            }

            // Expanded action bar for assistant messages
            if message.role == .assistant && showActionBar && !message.content.isEmpty {
                messageActionBarView
            }

            // Footer for error messages: timestamp + copy button + ellipsis
            if message.role == .error && !message.content.isEmpty {
                HStack(spacing: 6) {
                    Text(cachedTimestamp)
                        .font(.system(size: 10))
                        .foregroundColor(CLITheme.mutedText(for: colorScheme).opacity(0.7))

                    Button {
                        HapticManager.light()
                        UIPasteboard.general.string = message.content
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCopied = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showCopied = false
                            }
                        }
                    } label: {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9))
                            .foregroundColor(
                                showCopied
                                    ? CLITheme.green(for: colorScheme)
                                    : CLITheme.mutedText(for: colorScheme).opacity(0.6)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showCopied ? "Copied" : "Copy error")

                    Spacer()

                    // Action bar toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showActionBar.toggle()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12))
                            .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("More actions")
                }
                .padding(.leading, 16)
                .padding(.top, 4)
            }

            // Expanded action bar for error messages
            if message.role == .error && showActionBar && !message.content.isEmpty {
                ErrorActionBar(content: message.content)
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            // Copy button
            Button {
                HapticManager.light()
                UIPasteboard.general.string = message.content
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            // Share button
            Button {
                shareContent()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            // Bookmark button (only if project context available)
            if let path = projectPath, let title = projectTitle {
                Button {
                    bookmarkStore.toggleBookmark(
                        message: message,
                        projectPath: path,
                        projectTitle: title
                    )
                } label: {
                    Label(
                        isBookmarked ? "Remove Bookmark" : "Bookmark",
                        systemImage: isBookmarked ? "bookmark.fill" : "bookmark"
                    )
                }
            }
        }
        } // else (not hideTodoInline)
    }

    private func shareContent() {
        let activityVC = UIActivityViewController(
            activityItems: [message.content],
            applicationActivities: nil
        )

        // Find the window scene and present
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            // Handle iPad popover
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            rootVC.present(activityVC, animated: true)
        }
    }

    private var bulletChar: String {
        switch message.role {
        case .user: return ">"
        case .assistant: return " "
        case .system: return "*"
        case .error: return "!"
        case .toolUse: return "*"
        case .toolResult: return "└"
        case .resultSuccess: return "*"
        case .thinking: return "💭"
        }
    }

    /// Tool type - uses cached value computed in init
    private var toolType: CLITheme.ToolType {
        cachedToolType
    }

    private var bulletColor: Color {
        switch message.role {
        case .user: return CLITheme.blue(for: colorScheme)
        case .assistant: return CLITheme.primaryText(for: colorScheme)
        case .system: return CLITheme.cyan(for: colorScheme)
        case .error: return CLITheme.red(for: colorScheme)
        case .toolUse: return CLITheme.toolColor(for: cachedToolType, scheme: colorScheme)
        case .toolResult: return CLITheme.mutedText(for: colorScheme)
        case .resultSuccess: return CLITheme.green(for: colorScheme)
        case .thinking: return CLITheme.purple(for: colorScheme)
        }
    }

    private var headerText: String {
        switch message.role {
        case .user: return message.content
        case .assistant: return ""
        case .system: return "System (init)"
        case .error: return "Error"
        case .toolUse:
            return cachedToolHeaderText  // Use cached value
        case .toolResult: return "Result"
        case .resultSuccess: return "Done"
        case .thinking: return "Thinking"
        }
    }

    /// Message action bar for assistant messages
    private var messageActionBarView: some View {
        MessageActionBar(
            message: message,
            projectPath: projectPath ?? "",
            onCopy: {
                UIPasteboard.general.string = message.content
            }
        )
        .padding(.leading, 16)
        .transition(AnyTransition.opacity.combined(with: .move(edge: .top)))
    }

    /// Quick action buttons for tools (copy path, copy command)
    @ViewBuilder
    private var quickActionButtons: some View {
        ToolQuickActions(content: message.content, toolType: cachedToolType)
    }


    /// Parse tool result content into structured error info - uses cached value
    private var toolErrorInfo: ToolErrorInfo? {
        cachedToolErrorInfo
    }

    /// Whether this tool result represents an error
    private var isErrorResult: Bool {
        guard let info = cachedToolErrorInfo else { return false }
        return info.category != .success
    }

    /// Color for the result count badge - green for success, category-specific for errors
    private var badgeColor: Color {
        if message.role == .toolResult {
            // Use cached structured error info for accurate coloring
            if let info = cachedToolErrorInfo {
                return info.category.color(for: colorScheme)
            }
            // Fallback to exit code parsing
            if let exitCode = ToolParser.extractBashExitCode(from: message.content) {
                return exitCode == 0
                    ? CLITheme.green(for: colorScheme)
                    : CLITheme.red(for: colorScheme)
            }
        }
        // Default muted color for other badges
        return CLITheme.mutedText(for: colorScheme)
    }

    /// Text color for status labels - semantic colors optimized for readability
    private var badgeTextColor: Color {
        guard let tint = glassTintForBadge else {
            return CLITheme.mutedText(for: colorScheme)
        }

        switch tint {
        case .success:
            // Dark green in light mode, softer green in dark mode
            return colorScheme == .dark
                ? Color(red: 0.4, green: 0.75, blue: 0.45)
                : Color(red: 0.15, green: 0.5, blue: 0.2)
        case .warning:
            // Dark amber in light mode, softer amber in dark mode
            return colorScheme == .dark
                ? Color(red: 0.9, green: 0.7, blue: 0.35)
                : Color(red: 0.65, green: 0.45, blue: 0.0)
        case .error:
            // Dark red in light mode, softer red in dark mode
            return colorScheme == .dark
                ? Color(red: 0.9, green: 0.45, blue: 0.45)
                : Color(red: 0.7, green: 0.2, blue: 0.2)
        case .info:
            // Dark cyan in light mode, softer cyan in dark mode
            return colorScheme == .dark
                ? Color(red: 0.4, green: 0.75, blue: 0.85)
                : Color(red: 0.0, green: 0.45, blue: 0.55)
        case .neutral, .primary, .accent:
            return CLITheme.mutedText(for: colorScheme)
        }
    }

    /// Glass tint for the result count badge (iOS 26+ Liquid Glass)
    private var glassTintForBadge: CLITheme.GlassTint? {
        if message.role == .toolResult {
            if let info = cachedToolErrorInfo {
                switch info.category {
                case .success: return .success
                case .gitError, .commandFailed, .sshError, .permissionDenied: return .error
                case .invalidArgs, .commandNotFound, .timeout: return .warning
                case .fileConflict, .approvalRequired: return .info
                case .fileNotFound: return .neutral
                case .unknown: return .error
                }
            }
            // Fallback
            if let exitCode = ToolParser.extractBashExitCode(from: message.content) {
                return exitCode == 0 ? .success : .error
            }
        }
        return .neutral
    }

    /// Generate a count badge for collapsed tool outputs - uses cached value
    private var resultCountBadge: String? {
        cachedResultCountBadge
    }

    private var headerColor: Color {
        switch message.role {
        case .user: return CLITheme.blue(for: colorScheme)
        case .assistant: return CLITheme.primaryText(for: colorScheme)
        case .system: return CLITheme.cyan(for: colorScheme)
        case .error: return CLITheme.red(for: colorScheme)
        case .toolUse: return CLITheme.toolColor(for: toolType, scheme: colorScheme)
        case .toolResult: return CLITheme.mutedText(for: colorScheme)
        case .resultSuccess: return CLITheme.green(for: colorScheme)
        case .thinking: return CLITheme.purple(for: colorScheme)
        }
    }

    private var isCollapsible: Bool {
        switch message.role {
        case .system, .toolUse, .toolResult, .resultSuccess, .thinking: return true
        default: return false
        }
    }

    private var accessibilityLabel: String {
        switch message.role {
        case .user: return "You said: \(message.content)"
        case .assistant: return "Claude response"
        case .system: return "System message"
        case .error: return "Error: \(message.content)"
        case .toolUse: return "Tool: \(headerText), \(isExpanded ? "expanded" : "collapsed")"
        case .toolResult: return "Tool result, \(isExpanded ? "expanded" : "collapsed")"
        case .resultSuccess: return "Task completed"
        case .thinking: return "Thinking block, \(isExpanded ? "expanded" : "collapsed")"
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch message.role {
        case .user:
            // Show image if attached (supports both eager and lazy loading)
            LazyMessageImage(imageData: message.imageData, imagePath: message.imagePath)
        case .assistant:
            MarkdownText(message.content)
                .textSelection(.enabled)
        case .system, .resultSuccess:
            Text(message.content)
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                .textSelection(.enabled)
        case .error:
            Text(message.content.formattedUsageLimit)
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.red(for: colorScheme))
                .textSelection(.enabled)
        case .toolUse:
            ToolUseContentView(
                content: message.content,
                hideTodoInline: hideTodoInline,
                isExpanded: $isExpanded
            )
        case .toolResult:
            ToolResultContentView(
                content: message.content,
                isExpanded: $isExpanded
            )
        case .thinking:
            // Truncate long thinking blocks with purple styling
            ThinkingBlockText(
                content: message.content,
                isExpanded: $isExpanded
            )
        }
    }
}

// MARK: - CLI Processing View (iOS 26+ Liquid Glass compatible)

struct CLIProcessingView: View {
    @State private var dotCount = 0
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            Text("+")
                .foregroundColor(CLITheme.primaryText(for: colorScheme))
            Text("Thinking" + String(repeating: ".", count: dotCount))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))
            Spacer()
        }
        .font(settings.scaledFont(.body))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassBackground(tint: .warning, cornerRadius: 8)
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 4
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Claude is thinking")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Quick Action Button (iOS 26+ Liquid Glass compatible)

struct QuickActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    @State private var showConfirmation = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button {
            HapticManager.light()
            action()
            withAnimation(.easeInOut(duration: 0.2)) {
                showConfirmation = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showConfirmation = false
                }
            }
        } label: {
            Image(systemName: showConfirmation ? "checkmark" : icon)
                .font(.system(size: 11))
                .foregroundColor(
                    showConfirmation
                        ? CLITheme.primaryText(for: colorScheme)  // Visible against green glass
                        : CLITheme.mutedText(for: colorScheme)
                )
                .frame(width: 24, height: 24)
                .glassCapsule(tint: showConfirmation ? .success : nil, isInteractive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showConfirmation ? "Copied" : label)
        // iOS 26+: Button will automatically get glass styling via system
    }
}

// MARK: - Lazy Message Image

/// Lazy-loading image view for chat message attachments.
/// Supports both eager (imageData) and lazy (imagePath) loading patterns.
/// Images are loaded asynchronously to avoid blocking the main thread.
struct LazyMessageImage: View {
    let imageData: Data?
    let imagePath: String?

    @State private var loadedImage: UIImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let image = loadedImage ?? eagerImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200, maxHeight: 150)
                    .cornerRadius(8)
            } else if isLoading {
                ProgressView()
                    .frame(width: 200, height: 100)
            }
        }
        .task {
            await loadImageIfNeeded()
        }
    }

    /// Image from eager-loaded data (newly attached images)
    private var eagerImage: UIImage? {
        guard let data = imageData else { return nil }
        return UIImage(data: data)
    }

    /// Load image from path asynchronously (persisted images)
    private func loadImageIfNeeded() async {
        // Skip if already loaded or no path to load from
        guard loadedImage == nil,
              imageData == nil,
              let path = imagePath else { return }

        isLoading = true
        defer { isLoading = false }

        // Load on background thread to avoid blocking UI
        let image = await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
                return nil as UIImage?
            }
            return UIImage(data: data)
        }.value

        await MainActor.run {
            loadedImage = image
        }
    }
}
