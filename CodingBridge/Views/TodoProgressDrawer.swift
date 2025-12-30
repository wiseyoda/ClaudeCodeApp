import SwiftUI

// MARK: - Todo Progress Drawer

/// Floating drawer that shows real-time task progress from TodoWrite tool calls.
/// - Collapsed: Shows "X/Y Tasks" chip with progress indicator
/// - Expanded: Shows full todo list with status icons and progress bar
/// - Auto-hides 15s after streaming completes, reappears when new todos arrive
struct TodoProgressDrawer: View {
    let todos: [TodoListView.TodoItem]
    @Binding var isExpanded: Bool
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    private var completedCount: Int {
        todos.filter { $0.status == "completed" }.count
    }

    private var inProgressTask: TodoListView.TodoItem? {
        todos.first { $0.status == "in_progress" }
    }

    private var progress: Double {
        guard !todos.isEmpty else { return 0 }
        return Double(completedCount) / Double(todos.count)
    }

    private var isComplete: Bool {
        completedCount == todos.count && !todos.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Collapsed header (always visible, tap to expand/collapse)
            collapsedHeader

            // Expanded content
            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(CLITheme.secondaryBackground(for: colorScheme))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(CLITheme.mutedText(for: colorScheme).opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Collapsed Header

    private var collapsedHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                // Icon
                Image(systemName: isComplete ? "checkmark.circle.fill" : "checklist")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isComplete ? CLITheme.green(for: colorScheme) : CLITheme.cyan(for: colorScheme))

                // Progress text
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(isComplete ? "All Tasks Complete" : "\(completedCount)/\(todos.count) Tasks")
                            .font(settings.scaledFont(.small).weight(.medium))
                            .foregroundColor(CLITheme.primaryText(for: colorScheme))

                        // Mini progress bar (only when not complete)
                        if !isComplete && todos.count > 1 {
                            miniProgressBar
                        }
                    }

                    // Current task preview (when collapsed and has in-progress task)
                    if !isExpanded, let current = inProgressTask {
                        Text(current.activeForm)
                            .font(settings.scaledFont(.small))
                            .foregroundColor(CLITheme.mutedText(for: colorScheme))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                Spacer()

                // Expand/collapse chevron
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mini Progress Bar

    private var miniProgressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(CLITheme.mutedText(for: colorScheme).opacity(0.2))

                RoundedRectangle(cornerRadius: 2)
                    .fill(isComplete ? CLITheme.green(for: colorScheme) : CLITheme.cyan(for: colorScheme))
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(width: 40, height: 4)
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(spacing: 0) {
            Divider()
                .background(CLITheme.mutedText(for: colorScheme).opacity(0.3))

            ScrollView {
                TodoListView(todos: todos)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .frame(maxHeight: 200) // Limit height to avoid taking over screen
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()

        TodoProgressDrawer(
            todos: [
                .init(content: "Find markdown rendering code", activeForm: "Finding markdown rendering code", status: "completed"),
                .init(content: "Fix bold text font size", activeForm: "Fixing bold text font size", status: "in_progress"),
                .init(content: "Ensure word wrap for lists", activeForm: "Ensuring word wrap for lists", status: "pending"),
                .init(content: "Build and test", activeForm: "Building and testing", status: "pending")
            ],
            isExpanded: .constant(false)
        )
        .environmentObject(AppSettings())

        TodoProgressDrawer(
            todos: [
                .init(content: "Find markdown rendering code", activeForm: "Finding markdown rendering code", status: "completed"),
                .init(content: "Fix bold text font size", activeForm: "Fixing bold text font size", status: "in_progress"),
                .init(content: "Ensure word wrap for lists", activeForm: "Ensuring word wrap for lists", status: "pending"),
                .init(content: "Build and test", activeForm: "Building and testing", status: "pending")
            ],
            isExpanded: .constant(true)
        )
        .environmentObject(AppSettings())

        Spacer()
    }
    .background(Color.black)
}
