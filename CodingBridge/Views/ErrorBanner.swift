import SwiftUI

// MARK: - Error Banner

/// Toast-style error banner that slides in from the top
/// Displays errors from ErrorStore with retry and details options
struct ErrorBanner: View {
    @ObservedObject var errorStore = ErrorStore.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack {
            if let error = errorStore.currentError {
                errorContent(error)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: errorStore.currentError?.id)
    }

    @ViewBuilder
    private func errorContent(_ error: DisplayableError) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row: Icon, Title, Actions
            HStack(alignment: .center, spacing: 10) {
                // Error icon
                Image(systemName: error.error.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                // Title
                Text(error.title)
                    .font(CLITheme.monoFont)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()

                // Retry button (if retryable)
                if error.canRetry {
                    Button {
                        errorStore.retry()
                    } label: {
                        if error.isRetrying {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                        } else {
                            Text("Retry")
                                .font(CLITheme.monoSmall)
                                .fontWeight(.medium)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(6)
                    .disabled(error.isRetrying)
                }

                // Dismiss button
                Button {
                    errorStore.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(6)
            }

            // Description
            Text(error.description)
                .font(CLITheme.monoSmall)
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            // Expand/collapse for recovery suggestion
            if let suggestion = error.recoverySuggestion {
                Button {
                    errorStore.toggleExpanded()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: error.isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                        Text(error.isExpanded ? "Hide details" : "Show details")
                            .font(CLITheme.monoSmall)
                    }
                    .foregroundColor(.white.opacity(0.7))
                }

                // Recovery suggestion (when expanded)
                if error.isExpanded {
                    Divider()
                        .background(Color.white.opacity(0.3))

                    Text(suggestion)
                        .font(CLITheme.monoSmall)
                        .foregroundColor(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(CLITheme.red(for: colorScheme).opacity(0.95))
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @StateObject private var errorStore = ErrorStore.shared

        var body: some View {
            ZStack {
                Color.gray.opacity(0.2).ignoresSafeArea()

                VStack(spacing: 20) {
                    Button("Show Network Error") {
                        ErrorStore.shared.post(.networkUnavailable) {
                            print("Retrying...")
                        }
                    }

                    Button("Show Auth Error") {
                        ErrorStore.shared.post(.authenticationFailed)
                    }

                    Button("Show SSH Error") {
                        ErrorStore.shared.post(.sshConnectionFailed("Connection refused"))
                    }

                    Button("Clear All") {
                        ErrorStore.shared.clearAll()
                    }
                }

                ErrorBanner()
            }
        }
    }

    return PreviewWrapper()
}
