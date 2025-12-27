import SwiftUI

// MARK: - CLI Message View

struct CLIMessageView: View {
    let message: ChatMessage
    @State private var isExpanded: Bool
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    init(message: ChatMessage) {
        self.message = message
        // Collapse result messages, Grep/Glob tool uses, and thinking blocks by default
        let shouldStartCollapsed = message.role == .resultSuccess ||
            message.role == .toolResult ||
            message.role == .thinking ||
            (message.role == .toolUse && (message.content.hasPrefix("Grep") || message.content.hasPrefix("Glob")))
        self._isExpanded = State(initialValue: !shouldStartCollapsed)
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
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(isCollapsible ? (isExpanded ? "Double tap to collapse" : "Double tap to expand") : "")
            .accessibilityAddTraits(isCollapsible ? .isButton : [])

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
        case .thinking: return "💭"
        }
    }

    private var bulletColor: Color {
        switch message.role {
        case .user: return CLITheme.blue(for: colorScheme)
        case .assistant: return CLITheme.primaryText(for: colorScheme)
        case .system: return CLITheme.cyan(for: colorScheme)
        case .error: return CLITheme.red(for: colorScheme)
        case .toolUse: return CLITheme.green(for: colorScheme)
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
            // Show just tool name in header (e.g., "Grep" from "Grep(pattern: ...)")
            if let parenIndex = message.content.firstIndex(of: "(") {
                return String(message.content[..<parenIndex])
            }
            return message.content
        case .toolResult: return "Result"
        case .resultSuccess: return "Done"
        case .thinking: return "Thinking"
        }
    }

    private var headerColor: Color {
        switch message.role {
        case .user: return CLITheme.blue(for: colorScheme)
        case .assistant: return CLITheme.primaryText(for: colorScheme)
        case .system: return CLITheme.cyan(for: colorScheme)
        case .error: return CLITheme.red(for: colorScheme)
        case .toolUse: return CLITheme.yellow(for: colorScheme)
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
            // Show image if attached
            if let imageData = message.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200, maxHeight: 150)
                    .cornerRadius(8)
            }
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
            // Show specialized views for certain tools
            if message.content.hasPrefix("Edit"),
               let parsed = DiffView.parseEditContent(message.content) {
                DiffView(oldString: parsed.old, newString: parsed.new)
            } else if message.content.hasPrefix("TodoWrite"),
                      let todos = TodoListView.parseTodoContent(message.content) {
                TodoListView(todos: todos)
            } else {
                Text(message.content)
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                    .textSelection(.enabled)
            }
        case .toolResult:
            VStack(alignment: .leading, spacing: 4) {
                Text(message.content)
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                    .lineLimit(isExpanded ? nil : 3)
                    .textSelection(.enabled)
                // Show "Show more" hint if content is long and collapsed
                if !isExpanded && message.content.count > 200 {
                    Text("[\(message.content.count) chars - tap header to expand]")
                        .font(settings.scaledFont(.small))
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                        .italic()
                }
            }
        case .thinking:
            Text(message.content)
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.purple(for: colorScheme).opacity(0.8))
                .italic()
                .textSelection(.enabled)
        }
    }
}

// MARK: - CLI Processing View

struct CLIProcessingView: View {
    @State private var dotCount = 0
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            Text("+")
                .foregroundColor(CLITheme.yellow(for: colorScheme))
            Text("Thinking" + String(repeating: ".", count: dotCount))
                .foregroundColor(CLITheme.yellow(for: colorScheme))
            Spacer()
        }
        .font(settings.scaledFont(.body))
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 4
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Claude is thinking")
        .accessibilityAddTraits(.updatesFrequently)
    }
}
