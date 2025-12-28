import SwiftUI

// MARK: - Commands View (Category List)

/// Main view showing all command categories
struct CommandsView: View {
    @ObservedObject var commandStore: CommandStore
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var showingAddCommand = false
    @State private var selectedCategory: String?

    var body: some View {
        NavigationStack {
            List {
                if commandStore.categories.isEmpty {
                    emptyState
                } else {
                    ForEach(commandStore.categories, id: \.self) { category in
                        NavigationLink(value: category) {
                            CategoryRow(
                                category: category,
                                count: commandStore.count(in: category),
                                settings: settings,
                                colorScheme: colorScheme
                            )
                        }
                        .listRowBackground(CLITheme.background(for: colorScheme))
                    }
                    .onDelete(perform: deleteCategories)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Commands")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { category in
                CommandListView(
                    category: category,
                    commandStore: commandStore
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingAddCommand = true
                        } label: {
                            Label("New Command", systemImage: "plus")
                        }

                        Button {
                            showingAddCategory = true
                        } label: {
                            Label("New Category", systemImage: "folder.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Category", isPresented: $showingAddCategory) {
                TextField("Category name", text: $newCategoryName)
                Button("Cancel", role: .cancel) {
                    newCategoryName = ""
                }
                Button("Create") {
                    if !newCategoryName.isEmpty {
                        // Create a placeholder command in the new category
                        selectedCategory = newCategoryName
                        newCategoryName = ""
                        showingAddCommand = true
                    }
                }
            } message: {
                Text("Enter a name for the new category")
            }
            .sheet(isPresented: $showingAddCommand) {
                CommandEditorSheet(
                    commandStore: commandStore,
                    initialCategory: selectedCategory
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))

            Text("No Commands Yet")
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            Text("Save common prompts to reuse across projects")
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
                .multilineTextAlignment(.center)

            Button {
                showingAddCommand = true
            } label: {
                Label("Add Command", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func deleteCategories(at offsets: IndexSet) {
        let categoriesToDelete = offsets.map { commandStore.categories[$0] }
        for category in categoriesToDelete {
            // Delete all commands in this category
            let commands = commandStore.commands(in: category)
            for command in commands {
                commandStore.delete(command)
            }
        }
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let category: String
    let count: Int
    let settings: AppSettings
    let colorScheme: ColorScheme

    var body: some View {
        HStack {
            Image(systemName: iconForCategory(category))
                .foregroundColor(CLITheme.cyan(for: colorScheme))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(category)
                    .font(settings.scaledFont(.body))
                    .foregroundColor(CLITheme.primaryText(for: colorScheme))

                Text("\(count) command\(count == 1 ? "" : "s")")
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func iconForCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "git": return "arrow.triangle.branch"
        case "code review": return "eye"
        case "testing": return "checkmark.circle"
        case "docs", "documentation": return "doc.text"
        case "debug", "debugging": return "ant"
        case "refactor", "refactoring": return "arrow.triangle.2.circlepath"
        case "deploy", "deployment": return "shippingbox"
        default: return "folder"
        }
    }
}

// MARK: - Command List View (Commands in Category)

struct CommandListView: View {
    let category: String
    @ObservedObject var commandStore: CommandStore
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    @State private var showingAddCommand = false
    @State private var editingCommand: SavedCommand?

    var commands: [SavedCommand] {
        commandStore.commands(in: category)
    }

    var body: some View {
        List {
            if commands.isEmpty {
                emptyState
            } else {
                ForEach(commands) { command in
                    CommandRow(
                        command: command,
                        settings: settings,
                        colorScheme: colorScheme,
                        onTap: {
                            editingCommand = command
                        }
                    )
                    .listRowBackground(CLITheme.background(for: colorScheme))
                }
                .onDelete(perform: deleteCommands)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(CLITheme.background(for: colorScheme))
        .navigationTitle(category)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddCommand = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddCommand) {
            CommandEditorSheet(
                commandStore: commandStore,
                initialCategory: category
            )
        }
        .sheet(item: $editingCommand) { command in
            CommandEditorSheet(
                commandStore: commandStore,
                editingCommand: command
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))

            Text("No commands in \(category)")
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            Button {
                showingAddCommand = true
            } label: {
                Label("Add Command", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func deleteCommands(at offsets: IndexSet) {
        commandStore.deleteCommands(at: offsets, in: category)
    }
}

// MARK: - Command Row

struct CommandRow: View {
    let command: SavedCommand
    let settings: AppSettings
    let colorScheme: ColorScheme
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Text(command.name)
                    .font(settings.scaledFont(.body))
                    .foregroundColor(CLITheme.primaryText(for: colorScheme))

                Text(command.content)
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                    .lineLimit(2)

                if let lastUsed = command.lastUsedAt {
                    Text("Last used: \(lastUsed.relativeFormatted)")
                        .font(settings.scaledFont(.small))
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Command Editor Sheet

struct CommandEditorSheet: View {
    @ObservedObject var commandStore: CommandStore
    var editingCommand: SavedCommand?
    var initialCategory: String?

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    @State private var name: String = ""
    @State private var content: String = ""
    @State private var category: String = ""
    @State private var isNewCategory = false
    @State private var newCategoryName: String = ""

    private var isEditing: Bool { editingCommand != nil }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !content.trimmingCharacters(in: .whitespaces).isEmpty &&
        !effectiveCategory.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var effectiveCategory: String {
        isNewCategory ? newCategoryName : category
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Command name", text: $name)
                        .font(settings.scaledFont(.body))
                } header: {
                    Text("Name")
                }

                Section {
                    TextEditor(text: $content)
                        .font(settings.scaledFont(.body))
                        .frame(minHeight: 100)
                } header: {
                    Text("Prompt")
                } footer: {
                    Text("The message that will be sent to Claude")
                }

                Section {
                    if !commandStore.categories.isEmpty {
                        Picker("Category", selection: $category) {
                            ForEach(commandStore.categories, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                        .disabled(isNewCategory)

                        Toggle("Create new category", isOn: $isNewCategory)
                    }

                    if isNewCategory || commandStore.categories.isEmpty {
                        TextField("New category name", text: $newCategoryName)
                            .font(settings.scaledFont(.body))
                    }
                } header: {
                    Text("Category")
                }
            }
            .scrollContentBackground(.hidden)
            .background(CLITheme.secondaryBackground(for: colorScheme))
            .navigationTitle(isEditing ? "Edit Command" : "New Command")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        saveCommand()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let command = editingCommand {
                    name = command.name
                    content = command.content
                    category = command.category
                } else if let initial = initialCategory {
                    if commandStore.categories.contains(initial) {
                        category = initial
                    } else {
                        isNewCategory = true
                        newCategoryName = initial
                    }
                } else if let first = commandStore.categories.first {
                    category = first
                } else {
                    isNewCategory = true
                }
            }
        }
    }

    private func saveCommand() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedContent = content.trimmingCharacters(in: .whitespaces)
        let trimmedCategory = effectiveCategory.trimmingCharacters(in: .whitespaces)

        if let existing = editingCommand {
            let updated = SavedCommand(
                id: existing.id,
                name: trimmedName,
                content: trimmedContent,
                category: trimmedCategory,
                createdAt: existing.createdAt,
                lastUsedAt: existing.lastUsedAt
            )
            commandStore.update(updated)
        } else {
            let newCommand = SavedCommand(
                name: trimmedName,
                content: trimmedContent,
                category: trimmedCategory
            )
            commandStore.add(newCommand)
        }

        dismiss()
    }
}

// MARK: - Date Extension

extension Date {
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
