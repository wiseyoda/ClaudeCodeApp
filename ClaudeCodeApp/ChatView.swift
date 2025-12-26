import SwiftUI

struct ChatView: View {
    let project: Project
    let apiClient: APIClient
    @EnvironmentObject var settings: AppSettings

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var sessionId: String?
    @State private var isProcessing = false
    @State private var currentStreamingText = ""
    @State private var hasShownSystemInit = false
    @State private var processingStartTime: Date?
    @State private var tokenCount: Int = 0
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(messages) { message in
                            CLIMessageView(message: message)
                                .id(message.id)
                        }

                        // Streaming indicator
                        if isProcessing {
                            if currentStreamingText.isEmpty {
                                CLIProcessingView()
                                    .id("streaming")
                            } else {
                                CLIMessageView(message: ChatMessage(
                                    role: .assistant,
                                    content: currentStreamingText,
                                    timestamp: Date(),
                                    isStreaming: true
                                ))
                                .id("streaming")
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(CLITheme.background)
                .onChange(of: messages.count) { _, _ in
                    withAnimation {
                        if let lastId = messages.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        } else {
                            proxy.scrollTo("streaming", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: currentStreamingText) { _, _ in
                    withAnimation {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
            }

            // Status bar
            CLIStatusBar(
                isProcessing: isProcessing,
                startTime: processingStartTime,
                tokenCount: tokenCount
            )

            // Terminal input
            CLIInputView(
                text: $inputText,
                isProcessing: isProcessing,
                isFocused: _isInputFocused,
                onSend: { Task { await sendMessage() } }
            )

            // Mode selector
            CLIModeSelector()
        }
        .background(CLITheme.background)
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CLITheme.secondaryBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        messages = []
                        sessionId = nil
                        hasShownSystemInit = false
                    } label: {
                        Label("New Chat", systemImage: "plus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(CLITheme.secondaryText)
                }
            }
        }
    }

    private func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Add user message
        let userMessage = ChatMessage(role: .user, content: text, timestamp: Date())
        messages.append(userMessage)

        inputText = ""
        isProcessing = true
        processingStartTime = Date()
        currentStreamingText = ""

        do {
            let newSessionId = try await apiClient.sendMessage(
                text,
                project: project,
                sessionId: sessionId
            ) { event in
                DispatchQueue.main.async {
                    switch event {
                    case .text(let fullText):
                        currentStreamingText = fullText
                    case .toolUse(let name, let input):
                        let toolMsg = ChatMessage(
                            role: .toolUse,
                            content: "\(name)(\(input))",
                            timestamp: Date()
                        )
                        messages.append(toolMsg)
                    case .toolResult(let result):
                        let resultMsg = ChatMessage(
                            role: .toolResult,
                            content: result.prefix(500) + (result.count > 500 ? "..." : ""),
                            timestamp: Date()
                        )
                        messages.append(resultMsg)
                    case .complete:
                        break
                    case .debug(let raw):
                        let debugMsg = ChatMessage(
                            role: .system,
                            content: raw,
                            timestamp: Date()
                        )
                        messages.append(debugMsg)
                    case .systemInit(let model, let session, let tools, let cwd):
                        if !hasShownSystemInit {
                            hasShownSystemInit = true
                            var lines: [String] = []
                            if let model = model { lines.append("Model: \(model)") }
                            if let session = session { lines.append("Session: \(session)") }
                            lines.append("Tools: \(tools) available")
                            if let cwd = cwd { lines.append("CWD: \(cwd)") }
                            let systemMsg = ChatMessage(
                                role: .system,
                                content: lines.joined(separator: "\n"),
                                timestamp: Date()
                            )
                            messages.append(systemMsg)
                        }
                    case .resultInfo(let success, let durationMs, let cost, let inputTokens, let outputTokens):
                        var lines: [String] = []
                        if let ms = durationMs { lines.append("Duration: \(ms)ms") }
                        if let c = cost { lines.append("Cost: $\(String(format: "%.4f", c))") }
                        if let inTok = inputTokens, let outTok = outputTokens {
                            lines.append("Tokens: \(inTok) in, \(outTok) out")
                            tokenCount += inTok + outTok
                        }
                        let resultMsg = ChatMessage(
                            role: .resultSuccess,
                            content: lines.isEmpty ? (success ? "Done" : "Failed") : lines.joined(separator: " | "),
                            timestamp: Date()
                        )
                        messages.append(resultMsg)
                    }
                }
            }

            // Add final assistant message
            if !currentStreamingText.isEmpty {
                let assistantMessage = ChatMessage(
                    role: .assistant,
                    content: currentStreamingText,
                    timestamp: Date()
                )
                messages.append(assistantMessage)
            } else {
                let noResponseMessage = ChatMessage(
                    role: .error,
                    content: "No response received",
                    timestamp: Date()
                )
                messages.append(noResponseMessage)
            }

            sessionId = newSessionId
            currentStreamingText = ""

        } catch {
            let errorMessage = ChatMessage(
                role: .error,
                content: "Error: \(error.localizedDescription)",
                timestamp: Date()
            )
            messages.append(errorMessage)
        }

        isProcessing = false
        processingStartTime = nil
    }
}

// MARK: - CLI Message View

struct CLIMessageView: View {
    let message: ChatMessage
    @State private var isExpanded: Bool
    @EnvironmentObject var settings: AppSettings

    init(message: ChatMessage) {
        self.message = message
        self._isExpanded = State(initialValue: message.role != .resultSuccess && message.role != .toolResult)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Header line with bullet
            HStack(spacing: 6) {
                Text(bulletChar)
                    .foregroundColor(bulletColor)
                    .font(settings.scaledFont(.body))

                Text(headerText)
                    .foregroundColor(headerColor)
                    .font(settings.scaledFont(.body))

                if isCollapsible {
                    Text(isExpanded ? "[-]" : "[+]")
                        .foregroundColor(CLITheme.mutedText)
                        .font(settings.scaledFont(.small))
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

            // Content
            if isExpanded || !isCollapsible {
                contentView
                    .padding(.leading, 16)
            }
        }
        .padding(.vertical, 4)
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
        }
    }

    private var bulletColor: Color {
        switch message.role {
        case .user: return CLITheme.blue
        case .assistant: return CLITheme.primaryText
        case .system: return CLITheme.cyan
        case .error: return CLITheme.red
        case .toolUse: return CLITheme.green
        case .toolResult: return CLITheme.mutedText
        case .resultSuccess: return CLITheme.green
        }
    }

    private var headerText: String {
        switch message.role {
        case .user: return message.content
        case .assistant: return ""
        case .system: return "System (init)"
        case .error: return "Error"
        case .toolUse: return message.content
        case .toolResult: return "Result"
        case .resultSuccess: return "Done"
        }
    }

    private var headerColor: Color {
        switch message.role {
        case .user: return CLITheme.blue
        case .assistant: return CLITheme.primaryText
        case .system: return CLITheme.cyan
        case .error: return CLITheme.red
        case .toolUse: return CLITheme.yellow
        case .toolResult: return CLITheme.mutedText
        case .resultSuccess: return CLITheme.green
        }
    }

    private var isCollapsible: Bool {
        switch message.role {
        case .system, .toolResult, .resultSuccess: return true
        default: return false
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch message.role {
        case .user:
            EmptyView() // User message shown in header
        case .assistant:
            MarkdownText(message.content)
                .textSelection(.enabled)
        case .system, .resultSuccess:
            Text(message.content)
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.secondaryText)
                .textSelection(.enabled)
        case .error:
            Text(message.content)
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.red)
                .textSelection(.enabled)
        case .toolUse:
            EmptyView() // Tool use shown in header
        case .toolResult:
            Text(message.content)
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.secondaryText)
                .lineLimit(isExpanded ? nil : 3)
                .textSelection(.enabled)
        }
    }
}

// MARK: - CLI Processing View

struct CLIProcessingView: View {
    @State private var dotCount = 0
    @EnvironmentObject var settings: AppSettings
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            Text("+")
                .foregroundColor(CLITheme.yellow)
            Text("Thinking" + String(repeating: ".", count: dotCount))
                .foregroundColor(CLITheme.yellow)
            Spacer()
        }
        .font(settings.scaledFont(.body))
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 4
        }
    }
}

// MARK: - CLI Status Bar

struct CLIStatusBar: View {
    let isProcessing: Bool
    let startTime: Date?
    let tokenCount: Int
    @EnvironmentObject var settings: AppSettings

    @State private var elapsedTime: String = "0s"
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 12) {
            if isProcessing {
                HStack(spacing: 4) {
                    Circle()
                        .fill(CLITheme.yellow)
                        .frame(width: 6, height: 6)
                    Text("processing")
                        .foregroundColor(CLITheme.yellow)
                }
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(CLITheme.green)
                        .frame(width: 6, height: 6)
                    Text("ready")
                        .foregroundColor(CLITheme.green)
                }
            }

            Spacer()

            if tokenCount > 0 {
                Text("\(formatTokens(tokenCount)) tokens")
                    .foregroundColor(CLITheme.mutedText)
            }

            if isProcessing {
                Text(elapsedTime)
                    .foregroundColor(CLITheme.mutedText)
            }
        }
        .font(settings.scaledFont(.small))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(CLITheme.secondaryBackground)
        .onReceive(timer) { _ in
            if let start = startTime {
                let elapsed = Int(Date().timeIntervalSince(start))
                if elapsed < 60 {
                    elapsedTime = "\(elapsed)s"
                } else {
                    elapsedTime = "\(elapsed / 60)m \(elapsed % 60)s"
                }
            }
        }
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        }
        return "\(count)"
    }
}

// MARK: - CLI Input View

struct CLIInputView: View {
    @Binding var text: String
    let isProcessing: Bool
    @FocusState var isFocused: Bool
    let onSend: () -> Void
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        HStack(spacing: 8) {
            Text(">")
                .foregroundColor(CLITheme.green)
                .font(settings.scaledFont(.body))

            TextField("", text: $text, axis: .vertical)
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.primaryText)
                .lineLimit(1...5)
                .focused($isFocused)
                .disabled(isProcessing)
                .onSubmit { onSend() }
                .placeholder(when: text.isEmpty) {
                    Text("Type a message...")
                        .foregroundColor(CLITheme.mutedText)
                        .font(settings.scaledFont(.body))
                }

            if !text.isEmpty && !isProcessing {
                Button(action: onSend) {
                    Image(systemName: "return")
                        .foregroundColor(CLITheme.green)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(CLITheme.background)
    }
}

// MARK: - CLI Mode Selector

struct CLIModeSelector: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.claudeMode = settings.claudeMode.next()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: settings.claudeMode.icon)
                    .font(.system(size: 12))
                Text(settings.claudeMode.displayName)
                    .font(settings.scaledFont(.small))
                Text("- Tap to cycle")
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.mutedText)
            }
            .foregroundColor(settings.claudeMode.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CLITheme.secondaryBackground)
    }
}

// MARK: - Markdown Text View

struct MarkdownText: View {
    let content: String
    @EnvironmentObject var settings: AppSettings

    init(_ content: String) {
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                blockView(for: block)
            }
        }
    }

    private enum Block {
        case paragraph(String)
        case header(String, Int) // content, level (1-6)
        case codeBlock(String, String?) // content, language
        case bulletList([String])
        case numberedList([String])
        case table([[String]]) // rows of cells
    }

    private func parseBlocks() -> [Block] {
        var blocks: [Block] = []
        let lines = content.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Code block
            if line.hasPrefix("```") {
                let language = String(line.dropFirst(3))
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                blocks.append(.codeBlock(codeLines.joined(separator: "\n"), language.isEmpty ? nil : language))
                i += 1
                continue
            }

            // Headers
            if line.hasPrefix("#") {
                let headerMatch = line.prefix(while: { $0 == "#" })
                let level = min(headerMatch.count, 6)
                let headerText = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                if !headerText.isEmpty {
                    blocks.append(.header(headerText, level))
                }
                i += 1
                continue
            }

            // Table (detect by | at start and |---)
            if line.contains("|") && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                var tableLines: [String] = []
                while i < lines.count && lines[i].contains("|") {
                    let tableLine = lines[i].trimmingCharacters(in: .whitespaces)
                    // Skip separator lines like |---|---|
                    if !tableLine.contains("---") {
                        tableLines.append(tableLine)
                    }
                    i += 1
                }
                if !tableLines.isEmpty {
                    let rows = tableLines.map { row -> [String] in
                        row.split(separator: "|", omittingEmptySubsequences: false)
                            .map { String($0).trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                    }
                    blocks.append(.table(rows))
                }
                continue
            }

            // Numbered list
            if line.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil {
                var items: [String] = []
                while i < lines.count {
                    if lines[i].range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil {
                        let itemText = lines[i].replacingOccurrences(of: #"^\d+\.\s+"#, with: "", options: .regularExpression)
                        items.append(itemText)
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(.numberedList(items))
                continue
            }

            // Bullet list
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                var items: [String] = []
                while i < lines.count && (lines[i].hasPrefix("- ") || lines[i].hasPrefix("* ")) {
                    items.append(String(lines[i].dropFirst(2)))
                    i += 1
                }
                blocks.append(.bulletList(items))
                continue
            }

            // Regular paragraph
            if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                blocks.append(.paragraph(line))
            }
            i += 1
        }

        return blocks
    }

    @ViewBuilder
    private func blockView(for block: Block) -> some View {
        switch block {
        case .paragraph(let text):
            renderInlineMarkdown(text)
        case .header(let text, let level):
            headerView(text: text, level: level)
        case .codeBlock(let code, let language):
            VStack(alignment: .leading, spacing: 4) {
                if let lang = language, !lang.isEmpty {
                    Text(lang)
                        .font(settings.scaledFont(.small))
                        .foregroundColor(CLITheme.mutedText)
                }
                Text(code)
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.cyan)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CLITheme.secondaryBackground)
                    .cornerRadius(6)
            }
        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(settings.scaledFont(.body))
                            .foregroundColor(CLITheme.green)
                        renderInlineMarkdown(item)
                    }
                }
            }
        case .numberedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(settings.scaledFont(.body))
                            .foregroundColor(CLITheme.yellow)
                            .frame(minWidth: 20, alignment: .trailing)
                        renderInlineMarkdown(item)
                    }
                }
            }
        case .table(let rows):
            tableView(rows: rows)
        }
    }

    @ViewBuilder
    private func headerView(text: String, level: Int) -> some View {
        HStack(spacing: 6) {
            Text(String(repeating: "#", count: level))
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.mutedText)
            Text(text)
                .font(level == 1 ? settings.scaledFont(.large) : settings.scaledFont(.body))
                .foregroundColor(level <= 2 ? CLITheme.cyan : CLITheme.primaryText)
                .fontWeight(level <= 2 ? .semibold : .medium)
        }
        .padding(.top, level <= 2 ? 8 : 4)
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private func tableView(rows: [[String]]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        Text(cell)
                            .font(settings.scaledFont(.small))
                            .foregroundColor(rowIndex == 0 ? CLITheme.cyan : CLITheme.primaryText)
                            .fontWeight(rowIndex == 0 ? .semibold : .regular)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(rowIndex == 0 ? CLITheme.secondaryBackground : Color.clear)
                    }
                }
                if rowIndex == 0 {
                    Rectangle()
                        .fill(CLITheme.mutedText.opacity(0.3))
                        .frame(height: 1)
                }
            }
        }
        .background(CLITheme.background)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(CLITheme.mutedText.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func renderInlineMarkdown(_ text: String) -> some View {
        // Use AttributedString for inline markdown (bold, italic, code)
        if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributed)
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.primaryText)
                .tint(CLITheme.cyan)
        } else {
            Text(text)
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.primaryText)
        }
    }
}

// MARK: - Placeholder Extension

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    let settings = AppSettings()
    return NavigationStack {
        ChatView(
            project: Project(path: "/test/project", encodedName: "test"),
            apiClient: APIClient(settings: settings)
        )
    }
    .environmentObject(settings)
}
