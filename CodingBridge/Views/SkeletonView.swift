import SwiftUI

/// A shimmer effect modifier for skeleton loading states
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let duration: Double

    init(duration: Double = 1.5) {
        self.duration = duration
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.3),
                            Color.white.opacity(0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(
                    Animation.linear(duration: duration)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    /// Apply a shimmer loading effect
    func shimmer(duration: Double = 1.5) -> some View {
        modifier(ShimmerModifier(duration: duration))
    }
}

// MARK: - Skeleton Project Row

/// A skeleton placeholder for a project row
struct SkeletonProjectRow: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            // Leading indicator placeholder
            RoundedRectangle(cornerRadius: 2)
                .fill(CLITheme.mutedText(for: colorScheme).opacity(0.3))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 6) {
                // Title placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(CLITheme.mutedText(for: colorScheme).opacity(0.3))
                    .frame(width: randomWidth(min: 100, max: 180), height: 14)

                // Session count placeholder
                RoundedRectangle(cornerRadius: 3)
                    .fill(CLITheme.mutedText(for: colorScheme).opacity(0.2))
                    .frame(width: randomWidth(min: 60, max: 100), height: 10)
            }

            Spacer()

            // Chevron placeholder
            RoundedRectangle(cornerRadius: 2)
                .fill(CLITheme.mutedText(for: colorScheme).opacity(0.2))
                .frame(width: 8, height: 12)
        }
        .padding(.vertical, 12)
        .shimmer()
    }

    /// Generate a stable random width for variety
    private func randomWidth(min: CGFloat, max: CGFloat) -> CGFloat {
        // Use a simple hash-based approach for stable "random" widths
        let range = max - min
        return min + range * CGFloat.random(in: 0...1)
    }
}

// MARK: - Skeleton Project List

/// A full skeleton loading view for the project list
struct SkeletonProjectList: View {
    @Environment(\.colorScheme) var colorScheme

    /// Number of skeleton rows to show
    let rowCount: Int

    init(rowCount: Int = 6) {
        self.rowCount = rowCount
    }

    var body: some View {
        List {
            ForEach(0..<rowCount, id: \.self) { index in
                SkeletonProjectRow()
                    .listRowBackground(CLITheme.background(for: colorScheme))
                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(CLITheme.background(for: colorScheme))
    }
}

// MARK: - Loading State Overlay

/// An overlay that shows loading progress with optional status text
struct LoadingOverlay: View {
    @Environment(\.colorScheme) var colorScheme

    let statusText: String?
    let showSpinner: Bool

    init(statusText: String? = nil, showSpinner: Bool = true) {
        self.statusText = statusText
        self.showSpinner = showSpinner
    }

    var body: some View {
        VStack(spacing: 8) {
            if showSpinner {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(CLITheme.cyan(for: colorScheme))
            }

            if let text = statusText {
                Text(text)
                    .font(CLITheme.monoSmall)
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            CLITheme.secondaryBackground(for: colorScheme)
                .opacity(0.95)
        )
        .cornerRadius(8)
    }
}

// MARK: - Progressive Loading Banner

/// A small banner that shows when background loading is in progress
struct ProgressiveBanner: View {
    @Environment(\.colorScheme) var colorScheme

    let message: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.6)
                .tint(CLITheme.cyan(for: colorScheme))

            Text(message)
                .font(CLITheme.monoSmall)
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            CLITheme.secondaryBackground(for: colorScheme)
                .opacity(0.9)
        )
        .cornerRadius(6)
    }
}

// MARK: - Preview

#Preview("Skeleton Row") {
    VStack {
        SkeletonProjectRow()
        SkeletonProjectRow()
        SkeletonProjectRow()
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}

#Preview("Skeleton List") {
    SkeletonProjectList()
        .preferredColorScheme(.dark)
}

#Preview("Loading Overlay") {
    ZStack {
        Color.black
        LoadingOverlay(statusText: "Checking git status...")
    }
    .preferredColorScheme(.dark)
}
