import SwiftUI

/// Minimal UI for fast idea capture via long-press on FAB
struct QuickCaptureSheet: View {
    @Binding var isPresented: Bool
    let onSave: (String) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextEditor(text: $text)
                    .focused($isFocused)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(CLITheme.secondaryBackground(for: colorScheme))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(CLITheme.mutedText(for: colorScheme).opacity(0.3), lineWidth: 1)
                    )
                    .frame(minHeight: 120)

                HStack {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(CLITheme.yellow(for: colorScheme))
                    Text("Tap Save to capture. Edit details later.")
                        .font(.caption)
                        .foregroundStyle(CLITheme.secondaryText(for: colorScheme))
                }

                Spacer()
            }
            .padding()
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Quick Idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            onSave(trimmed)
                        }
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                // Delay focus to ensure sheet animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isFocused = true
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Preview

#Preview("Quick Capture") {
    struct PreviewWrapper: View {
        @State private var isPresented = true

        var body: some View {
            Color.gray
                .sheet(isPresented: $isPresented) {
                    QuickCaptureSheet(isPresented: $isPresented) { text in
                        print("Saved: \(text)")
                    }
                }
        }
    }

    return PreviewWrapper()
}
