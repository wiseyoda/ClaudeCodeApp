import Foundation

// MARK: - AskUserQuestion Tool Types

/// Represents a question option in AskUserQuestion
struct QuestionOption: Identifiable {
    let id = UUID()
    let label: String
    let description: String?

    init(label: String, description: String? = nil) {
        self.label = label
        self.description = description
    }

    /// Parse from dictionary
    static func from(_ dict: [String: Any]) -> QuestionOption? {
        guard let label = dict["label"] as? String else { return nil }
        let description = dict["description"] as? String
        return QuestionOption(label: label, description: description)
    }
}

/// Represents a single question in AskUserQuestion
struct UserQuestion: Identifiable {
    let id = UUID()
    let question: String
    let header: String?
    let options: [QuestionOption]
    let multiSelect: Bool

    /// The user's selected answer(s)
    var selectedOptions: Set<String> = []
    var customAnswer: String = ""  // For "Other" option

    init(question: String, header: String?, options: [QuestionOption], multiSelect: Bool) {
        self.question = question
        self.header = header
        self.options = options
        self.multiSelect = multiSelect
    }

    /// Parse from dictionary
    static func from(_ dict: [String: Any]) -> UserQuestion? {
        guard let question = dict["question"] as? String else { return nil }

        let header = dict["header"] as? String
        let multiSelect = dict["multiSelect"] as? Bool ?? false

        var options: [QuestionOption] = []
        if let optionsArray = dict["options"] as? [[String: Any]] {
            options = optionsArray.compactMap { QuestionOption.from($0) }
        }

        return UserQuestion(question: question, header: header, options: options, multiSelect: multiSelect)
    }
}

/// Represents the full AskUserQuestion tool input
struct AskUserQuestionData: Identifiable {
    let id = UUID()
    /// The server's request ID - needed for respondToQuestion API call
    let requestId: String
    var questions: [UserQuestion]

    init(requestId: String, questions: [UserQuestion]) {
        self.requestId = requestId
        self.questions = questions
    }

    /// Parse from the tool input dictionary
    static func from(_ input: [String: Any], requestId: String) -> AskUserQuestionData? {
        guard let questionsArray = input["questions"] as? [[String: Any]] else {
            return nil
        }

        let questions = questionsArray.compactMap { UserQuestion.from($0) }
        guard !questions.isEmpty else { return nil }

        return AskUserQuestionData(requestId: requestId, questions: questions)
    }

    /// Format answers as a user-friendly response string (for display in chat)
    func formatAnswers() -> String {
        var lines: [String] = []

        for question in questions {
            if let header = question.header {
                lines.append("**\(header)**")
            }

            if !question.customAnswer.isEmpty {
                // User provided custom "Other" answer
                lines.append(question.customAnswer)
            } else if !question.selectedOptions.isEmpty {
                // User selected from options
                let selected = question.selectedOptions.joined(separator: ", ")
                lines.append(selected)
            }

            lines.append("")  // Blank line between questions
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Format answers as a dictionary for the respondToQuestion API
    /// Returns dict keyed by question index (as string) with answer value
    func answersDict() -> [String: Any] {
        var result: [String: Any] = [:]

        for (index, question) in questions.enumerated() {
            let key = String(index)

            if !question.customAnswer.isEmpty {
                // User provided custom "Other" answer
                result[key] = question.customAnswer
            } else if question.multiSelect {
                // Multi-select: return array of selected options
                result[key] = Array(question.selectedOptions)
            } else if let first = question.selectedOptions.first {
                // Single select: return the selected option
                result[key] = first
            }
        }

        return result
    }
}
