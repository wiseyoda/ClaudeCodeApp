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
@MainActor
class IdeasStore: ObservableObject {
    @Published var ideas: [Idea] = []

    private let projectPath: String
    private let ideasDirectory = "ideas"

    private var fileURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let ideasDirURL = documentsURL.appendingPathComponent(ideasDirectory)

        // Create ideas directory if needed
        if !FileManager.default.fileExists(atPath: ideasDirURL.path) {
            try? FileManager.default.createDirectory(at: ideasDirURL, withIntermediateDirectories: true)
        }

        // Encode project path: /path/to/project → -path-to-project
        let encodedPath = projectPath
            .replacingOccurrences(of: "/", with: "-")

        return ideasDirURL.appendingPathComponent("\(encodedPath).json")
    }

    init(projectPath: String) {
        self.projectPath = projectPath
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
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            ideas = []
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            ideas = try JSONDecoder().decode([Idea].self, from: data)
        } catch {
            log.error("Failed to load ideas for \(projectPath): \(error)")
            ideas = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(ideas)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            log.error("Failed to save ideas for \(projectPath): \(error)")
        }
    }
}
