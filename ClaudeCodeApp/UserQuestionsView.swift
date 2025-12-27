import SwiftUI

/// A view for displaying and collecting answers to Claude's AskUserQuestion tool
struct UserQuestionsView: View {
    @Binding var questionData: AskUserQuestionData
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(questionData.questions.indices, id: \.self) { index in
                        QuestionCard(question: $questionData.questions[index])
                    }
                }
                .padding()
            }
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Claude is asking...")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        let formattedAnswers = questionData.formatAnswers()
                        onSubmit(formattedAnswers)
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(CLITheme.cyan(for: colorScheme))
                    .disabled(!hasAnySelection)
                }
            }
        }
    }

    /// Check if at least one question has a selection
    private var hasAnySelection: Bool {
        questionData.questions.contains { question in
            !question.selectedOptions.isEmpty || !question.customAnswer.isEmpty
        }
    }
}

/// Card view for a single question
struct QuestionCard: View {
    @Binding var question: UserQuestion
    @State private var showOtherField = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header chip if present
            if let header = question.header, !header.isEmpty {
                Text(header.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(CLITheme.cyan(for: colorScheme))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(CLITheme.cyan(for: colorScheme).opacity(0.15))
                    .cornerRadius(4)
            }

            // Question text
            Text(question.question)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            // Multi-select hint
            if question.multiSelect {
                Text("Select all that apply")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }

            // Options
            VStack(spacing: 8) {
                ForEach(question.options) { option in
                    OptionButton(
                        option: option,
                        isSelected: question.selectedOptions.contains(option.label),
                        multiSelect: question.multiSelect,
                        colorScheme: colorScheme
                    ) {
                        toggleOption(option.label)
                    }
                }

                // "Other" option
                OtherOptionButton(
                    isSelected: showOtherField,
                    colorScheme: colorScheme
                ) {
                    showOtherField.toggle()
                    if !showOtherField {
                        question.customAnswer = ""
                    }
                }
            }

            // Custom answer text field (when "Other" is selected)
            if showOtherField {
                TextField("Enter your answer...", text: $question.customAnswer, axis: .vertical)
                    .font(.system(size: 14, design: .monospaced))
                    .padding(12)
                    .background(CLITheme.secondaryBackground(for: colorScheme))
                    .foregroundColor(CLITheme.primaryText(for: colorScheme))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(CLITheme.cyan(for: colorScheme).opacity(0.5), lineWidth: 1)
                    )
            }
        }
        .padding(16)
        .background(CLITheme.secondaryBackground(for: colorScheme))
        .cornerRadius(12)
    }

    private func toggleOption(_ label: String) {
        if question.multiSelect {
            if question.selectedOptions.contains(label) {
                question.selectedOptions.remove(label)
            } else {
                question.selectedOptions.insert(label)
            }
        } else {
            // Single select - clear previous selection
            question.selectedOptions = [label]
            // Clear custom answer when selecting a predefined option
            question.customAnswer = ""
            showOtherField = false
        }
    }
}

/// Button for a single option
struct OptionButton: View {
    let option: QuestionOption
    let isSelected: Bool
    let multiSelect: Bool
    let colorScheme: ColorScheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                // Selection indicator
                Image(systemName: selectionIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? CLITheme.cyan(for: colorScheme) : CLITheme.mutedText(for: colorScheme))

                VStack(alignment: .leading, spacing: 4) {
                    Text(option.label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected
                            ? CLITheme.primaryText(for: colorScheme)
                            : CLITheme.secondaryText(for: colorScheme))

                    if let description = option.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 12))
                            .foregroundColor(CLITheme.mutedText(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(isSelected
                ? CLITheme.cyan(for: colorScheme).opacity(0.1)
                : CLITheme.background(for: colorScheme))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? CLITheme.cyan(for: colorScheme) : CLITheme.mutedText(for: colorScheme).opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var selectionIcon: String {
        if multiSelect {
            return isSelected ? "checkmark.square.fill" : "square"
        } else {
            return isSelected ? "largecircle.fill.circle" : "circle"
        }
    }
}

/// Button for the "Other" option
struct OtherOptionButton: View {
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? CLITheme.yellow(for: colorScheme) : CLITheme.mutedText(for: colorScheme))

                Text("Other")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected
                        ? CLITheme.primaryText(for: colorScheme)
                        : CLITheme.secondaryText(for: colorScheme))

                Spacer()

                Image(systemName: "pencil")
                    .font(.system(size: 12))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }
            .padding(12)
            .background(isSelected
                ? CLITheme.yellow(for: colorScheme).opacity(0.1)
                : CLITheme.background(for: colorScheme))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? CLITheme.yellow(for: colorScheme) : CLITheme.mutedText(for: colorScheme).opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let sampleData = AskUserQuestionData(questions: [
        UserQuestion(
            question: "Which library should we use for date formatting?",
            header: "Library",
            options: [
                QuestionOption(label: "date-fns", description: "Lightweight and modular"),
                QuestionOption(label: "moment.js", description: "Feature-rich but larger bundle"),
                QuestionOption(label: "dayjs", description: "Similar API to moment, smaller size")
            ],
            multiSelect: false
        ),
        UserQuestion(
            question: "Which features do you want to enable?",
            header: "Features",
            options: [
                QuestionOption(label: "Caching", description: "Cache API responses"),
                QuestionOption(label: "Logging", description: "Debug output"),
                QuestionOption(label: "Analytics", description: "Usage tracking")
            ],
            multiSelect: true
        )
    ])

    return UserQuestionsView(
        questionData: .constant(sampleData),
        onSubmit: { answer in print("Answer: \(answer)") },
        onCancel: { print("Cancelled") }
    )
    .preferredColorScheme(.dark)
}
