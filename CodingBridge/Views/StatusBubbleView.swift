//
//  StatusBubbleView.swift
//  CodingBridge
//
//  Created on 2025-12-31.
//
//  Inline chat bubble showing Claude's current state with animated icons,
//  shimmer text effects, and rotating fun/pop-culture messages.
//  Replaces the basic CLIProcessingView.
//

import SwiftUI

// MARK: - StatusBubbleView

struct StatusBubbleView: View {
    let state: CLIAgentState
    let tool: String?

    @StateObject private var messageStore = StatusMessageStore.shared
    @State private var currentMessage: StatusMessage?
    @State private var elapsedSeconds: Int = 0
    @State private var showElapsedTime: Bool = false

    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    // Timer for message rotation (8-12 seconds, randomized)
    @State private var rotationTimer: Timer?
    // Timer for elapsed time updates
    @State private var elapsedTimer: Timer?
    // Start time for tracking duration
    @State private var startTime: Date = Date()
    // Time when current message was displayed (for minimum display enforcement)
    @State private var messageDisplayTime: Date = Date()
    // Minimum seconds a message must stay on screen before switching
    private let minimumDisplaySeconds: TimeInterval = 5.0

    var body: some View {
        if state != .idle && state != .stopped {
            HStack(spacing: 6) {
                // Emoji only (no SF Symbol icon)
                if let message = currentMessage, !message.emoji.isEmpty {
                    Text(message.emoji)
                        .font(.system(size: 12))
                }

                // Message text with shimmer + animated ellipsis
                messageView

                Spacer()

                // Elapsed time (after 10s)
                if showElapsedTime {
                    elapsedTimeView
                }
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .padding(.horizontal, 20)  // Internal margin
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                colorScheme == .dark
                    ? Color(white: 0.15)  // Slightly lighter than secondaryBackground (0.12)
                    : Color(white: 0.95)
            )
            .onAppear {
                startAnimations()
            }
            .onDisappear {
                stopAnimations()
            }
            .onChange(of: state) { _, _ in
                resetForNewState()
            }
            .onChange(of: tool) { _, _ in
                resetForNewState()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.updatesFrequently)
        }
    }

    // MARK: - Message View

    @ViewBuilder
    private var messageView: some View {
        let baseText = (currentMessage?.text ?? "Working")
            .trimmingTrailingEllipsis()

        HStack(spacing: 0) {
            Text(baseText)
                .modifier(StatusShimmerModifier(accentColor: toolAccentColor))

            AnimatedEllipsis()
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
    }

    /// Color accent based on current tool
    private var toolAccentColor: Color {
        guard let tool = tool else {
            return state == .thinking ? .purple : .orange
        }
        switch tool.lowercased() {
        case "bash": return .orange
        case "read": return .green
        case "edit", "write": return .blue
        case "grep", "glob": return .cyan
        case "webfetch", "websearch": return .purple
        case "task": return .yellow
        default: return .orange
        }
    }

    // MARK: - Elapsed Time View

    @ViewBuilder
    private var elapsedTimeView: some View {
        Text("(\(elapsedSeconds)s)")
            .font(settings.scaledFont(.small))
            .foregroundColor(CLITheme.mutedText(for: colorScheme))
            .monospacedDigit()
            .transition(.opacity.animation(.easeInOut(duration: 0.3)))
    }

    // MARK: - Computed Properties

    private var accessibilityLabel: String {
        let stateLabel: String
        switch state {
        case .thinking:
            stateLabel = "Claude is thinking"
        case .executing:
            stateLabel = tool.map { "Claude is using \($0)" } ?? "Claude is working"
        case .idle, .stopped:
            stateLabel = "Ready for input"
        case .starting:
            stateLabel = "Claude is starting"
        case .recovering:
            stateLabel = "Claude is recovering"
        case .waitingInput:
            stateLabel = "Waiting for input"
        case .waitingPermission:
            stateLabel = "Waiting for approval"
        case .networkUnavailable:
            stateLabel = "Network unavailable"
        }

        if showElapsedTime {
            return "\(stateLabel), \(elapsedSeconds) seconds elapsed"
        }
        return stateLabel
    }

    // MARK: - Timer Management

    private func startAnimations() {
        startTime = Date()
        elapsedSeconds = 0
        showElapsedTime = false

        // Initial message
        selectNewMessage()

        // Rotation timer (4-5 seconds, randomized)
        scheduleRotation()

        // Elapsed timer (every second)
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                elapsedSeconds = Int(Date().timeIntervalSince(startTime))
                if elapsedSeconds >= 10 {
                    showElapsedTime = true
                }
            }
        }
    }

    private func stopAnimations() {
        rotationTimer?.invalidate()
        rotationTimer = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    private func resetForNewState() {
        // Check if minimum display time has elapsed
        let timeSinceLastMessage = Date().timeIntervalSince(messageDisplayTime)

        if timeSinceLastMessage >= minimumDisplaySeconds {
            // Enough time has passed - switch immediately
            stopAnimations()
            startAnimations()
        } else {
            // Schedule a switch after the remaining minimum time
            let remainingTime = minimumDisplaySeconds - timeSinceLastMessage
            rotationTimer?.invalidate()
            rotationTimer = Timer.scheduledTimer(withTimeInterval: remainingTime, repeats: false) { _ in
                Task { @MainActor in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectNewMessage()
                    }
                    scheduleRotation()
                }
            }
        }
    }

    private func scheduleRotation() {
        rotationTimer?.invalidate()

        // Random interval between 8-12 seconds
        let interval = Double.random(in: 8.0...12.0)

        rotationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectNewMessage()
                }
                scheduleRotation()
            }
        }
    }

    private func selectNewMessage() {
        currentMessage = messageStore.selectMessage(for: state, tool: tool)
        messageDisplayTime = Date()
    }
}

// MARK: - String Extension

private extension String {
    /// Removes trailing "..." from the string (for messages that already have ellipsis)
    func trimmingTrailingEllipsis() -> String {
        if hasSuffix("...") {
            return String(dropLast(3))
        }
        return self
    }
}

// MARK: - Status Shimmer Modifier

/// Text shimmer that sweeps a tool-colored highlight across from left to right
struct StatusShimmerModifier: ViewModifier {
    let accentColor: Color
    @State private var phase: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        let baseColor = CLITheme.primaryText(for: colorScheme)
        let dimColor = CLITheme.mutedText(for: colorScheme)

        // Build gradient stops ensuring they're always valid (0-1, ascending order)
        let stops = buildGradientStops(phase: phase, dimColor: dimColor, baseColor: baseColor, accentColor: accentColor)

        content
            .foregroundStyle(
                LinearGradient(
                    stops: stops,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }

    /// Build gradient stops that are always valid (locations 0-1, ascending order)
    private func buildGradientStops(phase: CGFloat, dimColor: Color, baseColor: Color, accentColor: Color) -> [Gradient.Stop] {
        // The shimmer effect: dim -> base -> ACCENT (at phase) -> base -> dim
        // We need to clamp all locations to [0, 1] and ensure ascending order

        let highlightWidth: CGFloat = 0.15
        let left = max(0, phase - highlightWidth)
        let center = max(left + 0.001, min(0.999, phase))  // Ensure center > left and < right
        let right = min(1, phase + highlightWidth)

        // Build stops in guaranteed ascending order
        var stops: [Gradient.Stop] = []

        // Start with dim
        stops.append(.init(color: dimColor, location: 0))

        // Only add intermediate stops if they're in valid range
        if left > 0.001 {
            stops.append(.init(color: baseColor, location: left))
        }

        if center > 0.002 && center < 0.998 {
            stops.append(.init(color: accentColor, location: center))
        }

        if right < 0.999 && right > center {
            stops.append(.init(color: baseColor, location: right))
        }

        // End with dim
        stops.append(.init(color: dimColor, location: 1))

        return stops
    }
}

// MARK: - Animated Ellipsis

/// Typewriter-style animated ellipsis: "." -> ".." -> "..." -> "...." with random timing
struct AnimatedEllipsis: View {
    @State private var dotCount: Int = 1
    @State private var timer: Timer?

    private let maxDots = 4
    private let minInterval: Double = 0.25
    private let maxInterval: Double = 0.45

    var body: some View {
        Text(String(repeating: ".", count: dotCount))
            .onAppear {
                startAnimation()
            }
            .onDisappear {
                stopAnimation()
            }
    }

    private func startAnimation() {
        scheduleNextDot()
    }

    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleNextDot() {
        timer?.invalidate()

        // Random interval for organic feel
        let interval = Double.random(in: minInterval...maxInterval)

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            Task { @MainActor in
                if dotCount >= maxDots {
                    dotCount = 1
                } else {
                    dotCount += 1
                }
                scheduleNextDot()
            }
        }
    }
}

// MARK: - Preview

#Preview("Thinking State") {
    VStack(spacing: 20) {
        StatusBubbleView(state: .thinking, tool: nil)
        StatusBubbleView(state: .executing, tool: nil)
        StatusBubbleView(state: .executing, tool: "Bash")
        StatusBubbleView(state: .executing, tool: "Read")
    }
    .padding()
    .environmentObject(AppSettings())
}
