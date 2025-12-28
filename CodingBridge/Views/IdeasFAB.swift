import SwiftUI

/// Floating action button for accessing the Ideas Drawer
/// - Tap: Opens the Ideas Drawer
/// - Long-press: Shows Quick Capture sheet
struct IdeasFAB: View {
    let ideaCount: Int
    let onTap: () -> Void
    let onLongPress: () -> Void

    @State private var isPressed = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main button
            Circle()
                .fill(CLITheme.secondaryBackground(for: colorScheme))
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                .overlay(
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(CLITheme.yellow(for: colorScheme))
                )
                .scaleEffect(isPressed ? 0.92 : 1.0)
                .opacity(isPressed ? 0.8 : 1.0)

            // Badge
            if ideaCount > 0 {
                Text(ideaCount > 99 ? "99+" : "\(ideaCount)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(CLITheme.red(for: colorScheme))
                    .clipShape(Capsule())
                    .offset(x: 6, y: -6)
            }
        }
        .contentShape(Circle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(
            minimumDuration: 0.4,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {
                // Haptic feedback on long press
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                onLongPress()
            }
        )
        .accessibilityLabel("Ideas")
        .accessibilityHint("Tap to open ideas drawer, hold to quick capture")
        .accessibilityValue(ideaCount > 0 ? "\(ideaCount) ideas" : "No ideas")
    }
}

// MARK: - Preview

#Preview("Ideas FAB States") {
    VStack(spacing: 40) {
        HStack(spacing: 40) {
            VStack {
                IdeasFAB(ideaCount: 0, onTap: {}, onLongPress: {})
                Text("Empty")
                    .font(.caption)
            }

            VStack {
                IdeasFAB(ideaCount: 3, onTap: {}, onLongPress: {})
                Text("3 ideas")
                    .font(.caption)
            }

            VStack {
                IdeasFAB(ideaCount: 42, onTap: {}, onLongPress: {})
                Text("42 ideas")
                    .font(.caption)
            }

            VStack {
                IdeasFAB(ideaCount: 150, onTap: {}, onLongPress: {})
                Text("99+ ideas")
                    .font(.caption)
            }
        }
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}

#Preview("Dark Mode") {
    HStack(spacing: 40) {
        IdeasFAB(ideaCount: 5, onTap: {}, onLongPress: {})
        IdeasFAB(ideaCount: 0, onTap: {}, onLongPress: {})
    }
    .padding(40)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
