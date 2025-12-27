import SwiftUI
import Foundation

// MARK: - Todo List View for TodoWrite Tool

struct TodoListView: View {
    let todos: [TodoItem]
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    struct TodoItem {
        let content: String
        let activeForm: String
        let status: String  // "pending", "in_progress", "completed"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(todos.enumerated()), id: \.offset) { index, todo in
                HStack(alignment: .top, spacing: 8) {
                    // Status indicator
                    statusIcon(for: todo.status)
                        .frame(width: 16)

                    // Todo content
                    VStack(alignment: .leading, spacing: 2) {
                        Text(todo.status == "in_progress" ? todo.activeForm : todo.content)
                            .font(settings.scaledFont(.small))
                            .foregroundColor(textColor(for: todo.status))
                            .strikethrough(todo.status == "completed", color: CLITheme.mutedText(for: colorScheme))
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(backgroundColor(for: todo.status))
                .cornerRadius(6)
            }
        }
    }

    @ViewBuilder
    private func statusIcon(for status: String) -> some View {
        switch status {
        case "completed":
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(CLITheme.green(for: colorScheme))
        case "in_progress":
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(CLITheme.cyan(for: colorScheme))
        default:  // pending
            Image(systemName: "circle")
                .font(.system(size: 14))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
        }
    }

    private func textColor(for status: String) -> Color {
        switch status {
        case "completed":
            return CLITheme.mutedText(for: colorScheme)
        case "in_progress":
            return CLITheme.cyan(for: colorScheme)
        default:
            return CLITheme.secondaryText(for: colorScheme)
        }
    }

    private func backgroundColor(for status: String) -> Color {
        switch status {
        case "in_progress":
            return CLITheme.cyan(for: colorScheme).opacity(0.1)
        default:
            return Color.clear
        }
    }

    /// Parse TodoWrite content into TodoItems
    static func parseTodoContent(_ content: String) -> [TodoItem]? {
        guard content.hasPrefix("TodoWrite") else { return nil }

        // Extract the todos array part
        // Format: TodoWrite(todos: [{...}, {...}])
        guard let todosStart = content.range(of: "todos: ["),
              let lastBracket = content.lastIndex(of: "]") else {
            return nil
        }

        // Get the array content between the outer brackets
        let arrayStart = todosStart.upperBound
        guard arrayStart < lastBracket else {
            // Empty array case: todos: []
            return []
        }
        let arrayContent = String(content[arrayStart..<lastBracket])

        var items: [TodoItem] = []

        // Parse each todo item - they're JSON objects with curly braces
        // Format: {"status": "completed", "activeForm": "...", "content": "..."}
        var depth = 0
        var currentItem = ""
        var inString = false
        var prevChar: Character = " "

        for char in arrayContent {
            if char == "\"" && prevChar != "\\" {
                inString = !inString
            }

            if !inString {
                if char == "{" {
                    depth += 1
                    if depth == 1 {
                        currentItem = ""
                        prevChar = char
                        continue
                    }
                } else if char == "}" {
                    depth -= 1
                    if depth == 0 {
                        // Parse this item
                        if let item = parseItem(currentItem) {
                            items.append(item)
                        }
                        currentItem = ""
                        prevChar = char
                        continue
                    }
                }
            }

            if depth >= 1 {
                currentItem.append(char)
            }
            prevChar = char
        }

        return items
    }

    private static func parseItem(_ itemString: String) -> TodoItem? {
        // Parse key-value pairs from format: "key": "value", "key2": "value2"
        var dict: [String: String] = [:]

        // Simple regex-like parsing for "key": "value" pairs
        let pattern = #""(\w+)":\s*"([^"\\]*(?:\\.[^"\\]*)*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(itemString.startIndex..., in: itemString)
        let matches = regex.matches(in: itemString, range: range)

        for match in matches {
            if let keyRange = Range(match.range(at: 1), in: itemString),
               let valueRange = Range(match.range(at: 2), in: itemString) {
                let key = String(itemString[keyRange])
                let value = String(itemString[valueRange])
                dict[key] = value
            }
        }

        guard let content = dict["content"],
              let status = dict["status"] else {
            return nil
        }

        let activeForm = dict["activeForm"] ?? content
        return TodoItem(content: content, activeForm: activeForm, status: status)
    }
}
