import SwiftUI

// MARK: - Custom Model Picker Sheet

struct CustomModelPickerSheet: View {
    @Binding var customModelId: String
    let onConfirm: (String) -> Void
    let onCancel: () -> Void
    @Environment(\.colorScheme) var colorScheme

    /// Example custom model IDs (full SDK model IDs for non-standard models)
    /// Standard models (opus, sonnet, haiku) are available in the picker - custom is for others
    private var exampleModels: String {
        """
        For non-standard models, enter full SDK model ID:
        • claude-sonnet-4-5-20250929[1m]
        • claude-3-opus-20240229
        • anthropic.claude-v2

        Standard models (opus, sonnet, haiku) are in the picker above.
        """
    }

    /// Placeholder for custom model ID
    private var placeholder: String {
        "e.g., claude-sonnet-4-5-20250929[1m]"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Enter a custom model ID")
                    .font(CLITheme.monoFont)
                    .foregroundColor(CLITheme.primaryText(for: colorScheme))

                TextField(placeholder, text: $customModelId)
                    .font(CLITheme.monoFont)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                Text(exampleModels)
                    .font(CLITheme.monoSmall)
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding()
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Custom Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Switch") { onConfirm(customModelId) }
                        .disabled(customModelId.isEmpty)
                }
            }
        }
    }
}
