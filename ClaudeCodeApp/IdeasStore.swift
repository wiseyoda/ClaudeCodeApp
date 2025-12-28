import Foundation

/// An idea captured during a Claude session
struct Idea: Identifiable, Codable, Equatable {
    var id: UUID
    var text: String                    // Required - the idea content
    var title: String?                  // Optional - brief label
    var tags: [String]                  // Free-form tags
    var createdAt: Date
    var updatedAt: Date
    var expandedPrompt: String?         // AI-generated expansion (cached)
    var suggestedFollowups: [String]?   // AI-suggested related ideas
    var isArchived: Bool                // Whether the idea is archived

    init(
        id: UUID = UUID(),
        text: String,
        title: String? = nil,
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        expandedPrompt: String? = nil,
        suggestedFollowups: [String]? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.text = text
        self.title = title
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.expandedPrompt = expandedPrompt
        self.suggestedFollowups = suggestedFollowups
        self.isArchived = isArchived
    }

    /// Format the idea as a well-structured markdown prompt for Claude
    var formattedPrompt: String {
        var parts: [String] = []

        // Title
        if let title = title, !title.isEmpty {
            parts.append("# Idea: \(title)")
        } else {
            parts.append("# Idea")
        }

        // Description
        parts.append("\n## Description\n\(text)")

        // Tags
        if !tags.isEmpty {
            let tagList = tags.map { "`\($0)`" }.joined(separator: " ")
            parts.append("\n## Tags\n\(tagList)")
        }

        // AI-enhanced prompt (if available)
        if let expanded = expandedPrompt, !expanded.isEmpty {
            parts.append("\n## AI-Enhanced Prompt\n\(expanded)")
        }

        // Suggested follow-ups (if available)
        if let followups = suggestedFollowups, !followups.isEmpty {
            let followupList = followups.map { "- \($0)" }.joined(separator: "\n")
            parts.append("\n## Suggested Follow-ups\n\(followupList)")
        }

        return parts.joined(separator: "\n")
    }
}

/// Manages persistent storage of ideas per project
///
/// ## iOS 26+ Migration: @IncrementalState
/// This store manages per-project ideas and is a candidate for @IncrementalState.
/// The migration will improve List performance when users have many ideas.
///
/// Migration steps:
/// 1. Change `@Published var ideas` to `@IncrementalState var ideas`
/// 2. Add `.incrementalID()` modifier to IdeaRow views using `idea.id`
/// 3. Use incremental update methods for add/update/delete/archive operations
@MainActor
class IdeasStore: ObservableObject {
    /// iOS 26+: Consider migrating to @IncrementalState for better List performance
    @Published var ideas: [Idea] = []

    private let projectPath: String
    private let ideasDirectory = "ideas"
    private let baseDirectory: URL
    private let fileManager: FileManager
    private let loadSynchronously: Bool

    /// Background queue for file I/O to avoid blocking main thread
    private static let fileQueue = DispatchQueue(label: "com.claudecodeapp.ideasstore", qos: .userInitiated)

    private var fileURL: URL {
        let ideasDirURL = baseDirectory.appendingPathComponent(ideasDirectory)

        // Create ideas directory if needed
        if !fileManager.fileExists(atPath: ideasDirURL.path) {
            try? fileManager.createDirectory(at: ideasDirURL, withIntermediateDirectories: true)
        }

        // Encode project path: /path/to/project → -path-to-project
        let encodedPath = projectPath
            .replacingOccurrences(of: "/", with: "-")

        return ideasDirURL.appendingPathComponent("\(encodedPath).json")
    }

    private static var defaultBaseDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    init(
        projectPath: String,
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.projectPath = projectPath
        self.baseDirectory = baseDirectory ?? Self.defaultBaseDirectory
        self.fileManager = fileManager
        // Load synchronously when a custom baseDirectory is provided (for tests)
        self.loadSynchronously = baseDirectory != nil
        load()
    }

    // MARK: - CRUD Operations

    func add(_ idea: Idea) {
        var newIdea = idea
        newIdea.updatedAt = Date()
        ideas.insert(newIdea, at: 0) // Most recent first
        save()
    }

    func update(_ idea: Idea) {
        if let index = ideas.firstIndex(where: { $0.id == idea.id }) {
            var updated = idea
            updated.updatedAt = Date()
            ideas[index] = updated
            save()
        }
    }

    func delete(_ idea: Idea) {
        ideas.removeAll { $0.id == idea.id }
        save()
    }

    func deleteIdeas(at offsets: IndexSet) {
        ideas.remove(atOffsets: offsets)
        save()
    }

    /// Quick add from text only (for quick capture)
    func quickAdd(_ text: String) {
        let idea = Idea(text: text.trimmingCharacters(in: .whitespacesAndNewlines))
        add(idea)
    }

    // MARK: - Archive Operations

    /// Archive an idea
    func archive(_ idea: Idea) {
        if let index = ideas.firstIndex(where: { $0.id == idea.id }) {
            ideas[index].isArchived = true
            ideas[index].updatedAt = Date()
            save()
        }
    }

    /// Restore an archived idea
    func unarchive(_ idea: Idea) {
        if let index = ideas.firstIndex(where: { $0.id == idea.id }) {
            ideas[index].isArchived = false
            ideas[index].updatedAt = Date()
            save()
        }
    }

    /// Count of active (non-archived) ideas
    var activeCount: Int {
        ideas.filter { !$0.isArchived }.count
    }

    /// Count of archived ideas
    var archivedCount: Int {
        ideas.filter { $0.isArchived }.count
    }

    // MARK: - Queries

    /// All unique tags across all ideas, sorted alphabetically
    var allTags: [String] {
        Array(Set(ideas.flatMap { $0.tags })).sorted()
    }

    /// Ideas with a specific tag
    func ideas(withTag tag: String) -> [Idea] {
        ideas.filter { $0.tags.contains(tag) }
    }

    /// Ideas sorted by most recently updated
    var sortedIdeas: [Idea] {
        ideas.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Filter ideas by search text (searches title, text, and tags)
    func filter(by searchText: String) -> [Idea] {
        guard !searchText.isEmpty else { return sortedIdeas }

        let lowercased = searchText.lowercased()
        return sortedIdeas.filter { idea in
            (idea.title?.lowercased().contains(lowercased) ?? false) ||
            idea.text.lowercased().contains(lowercased) ||
            idea.tags.contains { $0.lowercased().contains(lowercased) }
        }
    }

    /// Filter ideas by tag, search text, and archived status
    func filter(byTag tag: String?, searchText: String = "", showArchived: Bool = false) -> [Idea] {
        var filtered = sortedIdeas

        // Filter by archived status
        filtered = filtered.filter { $0.isArchived == showArchived }

        if let tag = tag, !tag.isEmpty {
            filtered = filtered.filter { $0.tags.contains(tag) }
        }

        if !searchText.isEmpty {
            let lowercased = searchText.lowercased()
            filtered = filtered.filter { idea in
                (idea.title?.lowercased().contains(lowercased) ?? false) ||
                idea.text.lowercased().contains(lowercased) ||
                idea.tags.contains { $0.lowercased().contains(lowercased) }
            }
        }

        return filtered
    }

    // MARK: - AI Enhancement

    /// Update an idea with AI-generated expansion
    func updateWithEnhancement(ideaId: UUID, expandedPrompt: String, suggestedFollowups: [String]) {
        if let index = ideas.firstIndex(where: { $0.id == ideaId }) {
            ideas[index].expandedPrompt = expandedPrompt
            ideas[index].suggestedFollowups = suggestedFollowups
            ideas[index].updatedAt = Date()
            save()
        }
    }

    /// Clear AI enhancement from an idea
    func clearEnhancement(ideaId: UUID) {
        if let index = ideas.firstIndex(where: { $0.id == ideaId }) {
            ideas[index].expandedPrompt = nil
            ideas[index].suggestedFollowups = nil
            ideas[index].updatedAt = Date()
            save()
        }
    }

    // MARK: - Persistence

    private func load() {
        let url = fileURL
        let path = projectPath

        if loadSynchronously {
            // Synchronous load for tests
            loadSync(from: url, path: path)
        } else {
            // Perform file I/O on background queue to avoid blocking main thread
            IdeasStore.fileQueue.async { [weak self] in
                guard FileManager.default.fileExists(atPath: url.path) else {
                    Task { @MainActor [weak self] in
                        self?.ideas = []
                    }
                    return
                }

                do {
                    let data = try Data(contentsOf: url)
                    let loadedIdeas = try JSONDecoder().decode([Idea].self, from: data)
                    Task { @MainActor [weak self] in
                        self?.ideas = loadedIdeas
                    }
                } catch {
                    log.error("Failed to load ideas for \(path): \(error)")
                    Task { @MainActor [weak self] in
                        self?.ideas = []
                    }
                }
            }
        }
    }

    private func loadSync(from url: URL, path: String) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            ideas = []
            return
        }

        do {
            let data = try Data(contentsOf: url)
            ideas = try JSONDecoder().decode([Idea].self, from: data)
        } catch {
            log.error("Failed to load ideas for \(path): \(error)")
            ideas = []
        }
    }

    private func save() {
        // Capture data needed for background save
        let ideasToSave = ideas
        let url = fileURL
        let path = projectPath

        if loadSynchronously {
            // Synchronous save for tests
            do {
                let data = try JSONEncoder().encode(ideasToSave)
                try data.write(to: url, options: .atomic)
            } catch {
                log.error("Failed to save ideas for \(path): \(error)")
            }
        } else {
            // Perform file I/O on background queue to avoid blocking main thread
            IdeasStore.fileQueue.async {
                do {
                    let data = try JSONEncoder().encode(ideasToSave)
                    try data.write(to: url, options: .atomic)
                } catch {
                    log.error("Failed to save ideas for \(path): \(error)")
                }
            }
        }
    }
}
