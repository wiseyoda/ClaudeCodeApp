import Foundation

/// A saved command that can be reused across projects
struct SavedCommand: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var content: String
    var category: String
    var createdAt: Date
    var lastUsedAt: Date?

    init(id: UUID = UUID(), name: String, content: String, category: String, createdAt: Date = Date(), lastUsedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.content = content
        self.category = category
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
}

/// Manages persistent storage of saved commands
@MainActor
class CommandStore: ObservableObject {
    static let shared = CommandStore()

    @Published var commands: [SavedCommand] = []

    private let fileName = "commands.json"

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    init() {
        load()
    }

    // MARK: - CRUD Operations

    func add(_ command: SavedCommand) {
        commands.append(command)
        save()
    }

    func update(_ command: SavedCommand) {
        if let index = commands.firstIndex(where: { $0.id == command.id }) {
            commands[index] = command
            save()
        }
    }

    func delete(_ command: SavedCommand) {
        commands.removeAll { $0.id == command.id }
        save()
    }

    func deleteCommands(at offsets: IndexSet, in category: String) {
        let categoryCommands = commands(in: category)
        let idsToDelete = offsets.map { categoryCommands[$0].id }
        commands.removeAll { idsToDelete.contains($0.id) }
        save()
    }

    func markUsed(_ command: SavedCommand) {
        if let index = commands.firstIndex(where: { $0.id == command.id }) {
            commands[index].lastUsedAt = Date()
            save()
        }
    }

    // MARK: - Queries

    /// All unique categories, sorted alphabetically
    var categories: [String] {
        Array(Set(commands.map { $0.category })).sorted()
    }

    /// Commands in a specific category, sorted by last used (most recent first), then by name
    func commands(in category: String) -> [SavedCommand] {
        commands
            .filter { $0.category == category }
            .sorted { cmd1, cmd2 in
                // Sort by last used (most recent first), then by name
                if let date1 = cmd1.lastUsedAt, let date2 = cmd2.lastUsedAt {
                    return date1 > date2
                } else if cmd1.lastUsedAt != nil {
                    return true
                } else if cmd2.lastUsedAt != nil {
                    return false
                }
                return cmd1.name.localizedCaseInsensitiveCompare(cmd2.name) == .orderedAscending
            }
    }

    /// Count of commands in a category
    func count(in category: String) -> Int {
        commands.filter { $0.category == category }.count
    }

    /// All commands sorted for picker (by category, then by last used/name)
    var allCommandsGrouped: [(category: String, commands: [SavedCommand])] {
        categories.map { category in
            (category: category, commands: commands(in: category))
        }
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            // Create default commands for first launch
            createDefaultCommands()
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            commands = try JSONDecoder().decode([SavedCommand].self, from: data)
        } catch {
            log.error("Failed to load commands: \(error)")
            commands = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(commands)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            log.error("Failed to save commands: \(error)")
        }
    }

    private func createDefaultCommands() {
        commands = [
            // Git
            SavedCommand(name: "Commit changes", content: "Review the current changes and create a commit with a descriptive message", category: "Git"),
            SavedCommand(name: "Push and create PR", content: "Push the current branch and create a pull request with a summary of changes", category: "Git"),
            SavedCommand(name: "Review staged files", content: "Show me what's staged for commit and review the changes", category: "Git"),

            // Code Review
            SavedCommand(name: "Review this file", content: "Review this file for bugs, security issues, and improvements", category: "Code Review"),
            SavedCommand(name: "Find potential bugs", content: "Analyze the codebase for potential bugs and issues", category: "Code Review"),

            // Testing
            SavedCommand(name: "Run tests", content: "Run the test suite and show me any failures", category: "Testing"),
            SavedCommand(name: "Fix failing tests", content: "Run tests and fix any failures", category: "Testing"),
            SavedCommand(name: "Add test coverage", content: "Add tests for uncovered code paths", category: "Testing"),

            // Docs
            SavedCommand(name: "Explain this code", content: "Explain what this code does in detail", category: "Docs"),
            SavedCommand(name: "Add documentation", content: "Add documentation comments to the public APIs", category: "Docs")
        ]
        save()
    }
}
