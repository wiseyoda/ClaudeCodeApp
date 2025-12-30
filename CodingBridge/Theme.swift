import SwiftUI

// CLI-inspired theme colors supporting dark and light modes
// iOS 26+ Liquid Glass compatible
enum CLITheme {
    // MARK: - Background Colors

    /// Primary background color - adapts to Liquid Glass on iOS 26+
    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.08, green: 0.08, blue: 0.08)  // Near black
            : Color(red: 0.96, green: 0.96, blue: 0.96)  // Light gray
    }

    /// Secondary background color - adapts to Liquid Glass on iOS 26+
    static func secondaryBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.12, green: 0.12, blue: 0.12)
            : Color.white
    }

    // MARK: - Text Colors

    static func primaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white : Color(red: 0.1, green: 0.1, blue: 0.1)
    }

    static func secondaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.6) : Color(white: 0.4)
    }

    static func mutedText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.4) : Color(white: 0.55)
    }

    // MARK: - Accent Colors
    // These are adjusted for better contrast in each mode

    static func green(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.4, green: 0.8, blue: 0.4)
            : Color(red: 0.2, green: 0.6, blue: 0.2)
    }

    static func yellow(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.9, green: 0.8, blue: 0.4)
            : Color(red: 0.7, green: 0.55, blue: 0.0)
    }

    static func orange(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.9, green: 0.6, blue: 0.3)
            : Color(red: 0.85, green: 0.45, blue: 0.1)
    }

    static func red(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.9, green: 0.4, blue: 0.4)
            : Color(red: 0.8, green: 0.25, blue: 0.25)
    }

    static func cyan(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.4, green: 0.8, blue: 0.9)
            : Color(red: 0.0, green: 0.55, blue: 0.7)
    }

    static func purple(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.7, green: 0.5, blue: 0.9)
            : Color(red: 0.5, green: 0.3, blue: 0.7)
    }

    static func blue(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.4, green: 0.6, blue: 0.9)
            : Color(red: 0.2, green: 0.4, blue: 0.8)
    }

    // MARK: - Tool Type Colors
    // Each tool gets a distinct color for visual differentiation

    enum ToolType: String, CaseIterable {
        case bash = "Bash"
        case read = "Read"
        case write = "Write"
        case edit = "Edit"
        case grep = "Grep"
        case glob = "Glob"
        case task = "Task"
        case todoWrite = "TodoWrite"
        case webFetch = "WebFetch"
        case webSearch = "WebSearch"
        case askUser = "AskUserQuestion"
        case lsp = "LSP"
        case taskOutput = "TaskOutput"
        case other = ""

        static func from(_ content: String) -> ToolType {
            // Extract tool name from content like "Bash(command: ls)"
            let toolName: String
            if let parenIndex = content.firstIndex(of: "(") {
                toolName = String(content[..<parenIndex])
            } else {
                toolName = content.components(separatedBy: " ").first ?? content
            }

            return ToolType(rawValue: toolName) ?? .other
        }

        var icon: String {
            switch self {
            case .bash: return "terminal"
            case .read: return "doc.text"
            case .write: return "doc.badge.plus"
            case .edit: return "pencil.line"
            case .grep: return "magnifyingglass"
            case .glob: return "folder.badge.questionmark"
            case .task: return "person.crop.circle.badge.clock"
            case .todoWrite: return "checklist"
            case .webFetch: return "globe"
            case .webSearch: return "globe.badge.chevron.backward"
            case .askUser: return "questionmark.circle"
            case .lsp: return "chevron.left.forwardslash.chevron.right"
            case .taskOutput: return "arrow.down.doc"
            case .other: return "wrench"
            }
        }

        /// User-friendly display name for the tool
        var displayName: String {
            switch self {
            case .bash: return "Terminal"
            case .read: return "Read"
            case .write: return "Write"
            case .edit: return "Edit"
            case .grep: return "Search"
            case .glob: return "Find"
            case .task: return "Agent"
            case .todoWrite: return "Todo"
            case .webFetch: return "Fetch"
            case .webSearch: return "Web"
            case .askUser: return "Ask"
            case .lsp: return "LSP"
            case .taskOutput: return "Output"
            case .other: return "Tool"
            }
        }
    }

    static func toolColor(for tool: ToolType, scheme: ColorScheme) -> Color {
        switch tool {
        case .bash:
            return scheme == .dark
                ? Color(red: 1.0, green: 0.6, blue: 0.2)   // Orange
                : Color(red: 0.85, green: 0.4, blue: 0.0)
        case .read:
            return scheme == .dark
                ? Color(red: 0.4, green: 0.7, blue: 1.0)   // Light blue
                : Color(red: 0.2, green: 0.5, blue: 0.9)
        case .write:
            return scheme == .dark
                ? Color(red: 0.3, green: 0.85, blue: 0.5)  // Green
                : Color(red: 0.15, green: 0.65, blue: 0.3)
        case .edit:
            return scheme == .dark
                ? Color(red: 1.0, green: 0.85, blue: 0.3)  // Yellow
                : Color(red: 0.75, green: 0.6, blue: 0.0)
        case .grep:
            return scheme == .dark
                ? Color(red: 0.8, green: 0.5, blue: 1.0)   // Purple
                : Color(red: 0.55, green: 0.3, blue: 0.8)
        case .glob:
            return scheme == .dark
                ? Color(red: 0.4, green: 0.9, blue: 0.9)   // Cyan
                : Color(red: 0.0, green: 0.6, blue: 0.7)
        case .task:
            return scheme == .dark
                ? Color(red: 1.0, green: 0.5, blue: 0.7)   // Pink
                : Color(red: 0.85, green: 0.3, blue: 0.5)
        case .todoWrite:
            return scheme == .dark
                ? Color(red: 0.5, green: 0.9, blue: 0.5)   // Bright green
                : Color(red: 0.2, green: 0.7, blue: 0.3)
        case .webFetch, .webSearch:
            return scheme == .dark
                ? Color(red: 0.4, green: 0.8, blue: 0.9)   // Teal
                : Color(red: 0.1, green: 0.55, blue: 0.65)
        case .askUser:
            return scheme == .dark
                ? Color(red: 0.9, green: 0.7, blue: 0.3)   // Gold
                : Color(red: 0.7, green: 0.5, blue: 0.1)
        case .lsp:
            return scheme == .dark
                ? Color(red: 0.6, green: 0.8, blue: 1.0)   // Sky blue
                : Color(red: 0.3, green: 0.5, blue: 0.8)
        case .taskOutput:
            return scheme == .dark
                ? Color(red: 0.7, green: 0.9, blue: 0.6)   // Light green
                : Color(red: 0.4, green: 0.65, blue: 0.3)
        case .other:
            return scheme == .dark
                ? Color(red: 0.6, green: 0.6, blue: 0.6)   // Gray
                : Color(red: 0.4, green: 0.4, blue: 0.4)
        }
    }

    // MARK: - Diff Colors

    static func diffAdded(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.2, green: 0.3, blue: 0.2)
            : Color(red: 0.85, green: 0.95, blue: 0.85)
    }

    static func diffRemoved(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.3, green: 0.2, blue: 0.2)
            : Color(red: 0.95, green: 0.85, blue: 0.85)
    }

    static func diffAddedText(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.5, green: 0.9, blue: 0.5)
            : Color(red: 0.15, green: 0.5, blue: 0.15)
    }

    static func diffRemovedText(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.9, green: 0.5, blue: 0.5)
            : Color(red: 0.6, green: 0.15, blue: 0.15)
    }

    // MARK: - Fonts

    static let monoFont = Font.system(.body, design: .monospaced)
    static let monoSmall = Font.system(.caption, design: .monospaced)
    static let monoLarge = Font.system(.title3, design: .monospaced)

    // MARK: - iOS 26+ Glass Tint Colors

    /// Tint colors for glass effects with semantic meaning
    enum GlassTint {
        case primary    // Blue - primary actions
        case success    // Green - success/completion
        case warning    // Yellow/Orange - warnings
        case error      // Red - errors
        case info       // Cyan - informational
        case accent     // Purple - accent/highlight
        case neutral    // Gray - neutral/muted

        func color(for scheme: ColorScheme) -> Color {
            switch self {
            case .primary: return CLITheme.blue(for: scheme)
            case .success: return CLITheme.green(for: scheme)
            case .warning: return CLITheme.yellow(for: scheme)
            case .error: return CLITheme.red(for: scheme)
            case .info: return CLITheme.cyan(for: scheme)
            case .accent: return CLITheme.purple(for: scheme)
            case .neutral: return CLITheme.mutedText(for: scheme)
            }
        }
    }
}

// MARK: - iOS 26 Native Glass Effect View Modifier

/// View modifier for applying native iOS 26 Liquid Glass effects
/// Uses the native .glassEffect() API with semantic tinting
struct GlassEffectModifier: ViewModifier {
    let tint: CLITheme.GlassTint?
    let cornerRadius: CGFloat
    let isInteractive: Bool
    @Environment(\.colorScheme) private var colorScheme

    init(tint: CLITheme.GlassTint? = nil, cornerRadius: CGFloat = 12, isInteractive: Bool = false) {
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.isInteractive = isInteractive
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)

        // Build the glass style with optional tint and interactivity
        let glassStyle: Glass = {
            var glass = Glass.regular
            if let tint = tint {
                glass = glass.tint(tint.color(for: colorScheme))
            }
            if isInteractive {
                glass = glass.interactive()
            }
            return glass
        }()

        // In dark mode, add a subtle border for better definition
        let borderColor = colorScheme == .dark
            ? Color.white.opacity(0.15)
            : Color.black.opacity(0.08)

        return content
            .glassEffect(glassStyle, in: shape)
            .overlay(
                shape.stroke(borderColor, lineWidth: 0.5)
            )
    }
}

/// View modifier for capsule-shaped glass effects (buttons, pills)
/// Uses native iOS 26 .glassEffect() API
struct GlassCapsuleModifier: ViewModifier {
    let tint: CLITheme.GlassTint?
    let isInteractive: Bool
    @Environment(\.colorScheme) private var colorScheme

    init(tint: CLITheme.GlassTint? = nil, isInteractive: Bool = true) {
        self.tint = tint
        self.isInteractive = isInteractive
    }

    func body(content: Content) -> some View {
        // Build the glass style with optional tint and interactivity
        let glassStyle: Glass = {
            var glass = Glass.regular
            if let tint = tint {
                glass = glass.tint(tint.color(for: colorScheme))
            }
            if isInteractive {
                glass = glass.interactive()
            }
            return glass
        }()

        // In dark mode, add a subtle border for better definition
        let borderColor = colorScheme == .dark
            ? Color.white.opacity(0.15)
            : Color.black.opacity(0.08)

        return content
            .glassEffect(glassStyle, in: Capsule())
            .overlay(
                Capsule().stroke(borderColor, lineWidth: 0.5)
            )
    }
}

// MARK: - View Extension for Glass Effects

extension View {
    /// Apply a glass effect to the view (iOS 26+ Liquid Glass compatible)
    /// - Parameters:
    ///   - tint: Optional semantic tint color
    ///   - cornerRadius: Corner radius for the glass shape
    ///   - isInteractive: Whether the glass responds to touch (iOS 26+ only)
    func glassBackground(
        tint: CLITheme.GlassTint? = nil,
        cornerRadius: CGFloat = 12,
        isInteractive: Bool = false
    ) -> some View {
        modifier(GlassEffectModifier(tint: tint, cornerRadius: cornerRadius, isInteractive: isInteractive))
    }

    /// Apply a capsule-shaped glass effect (for buttons, pills)
    func glassCapsule(
        tint: CLITheme.GlassTint? = nil,
        isInteractive: Bool = true
    ) -> some View {
        modifier(GlassCapsuleModifier(tint: tint, isInteractive: isInteractive))
    }

    /// Apply glass effect to a message bubble
    func glassMessageBubble(role: ChatMessage.Role, colorScheme: ColorScheme) -> some View {
        let tint: CLITheme.GlassTint? = {
            switch role {
            case .user: return .primary
            case .assistant: return nil
            case .error: return .error
            case .toolUse, .toolResult, .resultSuccess: return .info
            case .thinking: return .accent
            case .system: return .neutral
            }
        }()

        return self.glassBackground(tint: tint, cornerRadius: 16)
    }
}

// MARK: - Connection Status Indicator

/// A subtle colored dot indicating WebSocket connection state
struct ConnectionStatusIndicator: View {
    let state: ConnectionState
    @Environment(\.colorScheme) var colorScheme

    private let dotSize: CGFloat = 8

    var body: some View {
        HStack(spacing: 4) {
            // Animated dot for connecting/reconnecting states
            ZStack {
                Circle()
                    .fill(dotColor)
                    .frame(width: dotSize, height: dotSize)

                // Pulsing animation for connecting states
                if state.isConnecting {
                    Circle()
                        .stroke(dotColor.opacity(0.5), lineWidth: 2)
                        .frame(width: dotSize + 4, height: dotSize + 4)
                        .modifier(PulseAnimation())
                }
            }
            .frame(width: dotSize + 6, height: dotSize + 6)

            // Show text only when not connected
            if !state.isConnected {
                Text(state.displayText)
                    .font(.system(size: 10))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.accessibilityLabel)
    }

    private var dotColor: Color {
        Self.dotColor(for: state, scheme: colorScheme)
    }

    static func dotColor(for state: ConnectionState, scheme: ColorScheme) -> Color {
        switch state {
        case .connected:
            return CLITheme.green(for: scheme)
        case .connecting, .reconnecting:
            return CLITheme.yellow(for: scheme)
        case .disconnected:
            return CLITheme.red(for: scheme)
        }
    }
}

/// Pulsing animation modifier for connection indicator
private struct PulseAnimation: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.5 : 1.0)
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

// MARK: - Connection Status Preview

#Preview("Connection States") {
    VStack(spacing: 20) {
        HStack {
            Text("Connected:")
            ConnectionStatusIndicator(state: .connected)
        }
        HStack {
            Text("Connecting:")
            ConnectionStatusIndicator(state: .connecting)
        }
        HStack {
            Text("Reconnecting:")
            ConnectionStatusIndicator(state: .reconnecting(attempt: 2))
        }
        HStack {
            Text("Disconnected:")
            ConnectionStatusIndicator(state: .disconnected)
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}
