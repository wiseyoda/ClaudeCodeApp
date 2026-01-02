import Foundation

// MARK: - Archived Projects Store

/// Stores archived project paths
@MainActor
class ArchivedProjectsStore: ObservableObject {
    static let shared = ArchivedProjectsStore()

    @Published private(set) var archivedPaths: Set<String> = []

    private static let storageKey = "archived_project_paths"

    init() {
        loadArchived()
    }

    /// Check if a project is archived
    func isArchived(_ projectPath: String) -> Bool {
        archivedPaths.contains(projectPath)
    }

    /// Archive a project
    func archive(_ projectPath: String) {
        archivedPaths.insert(projectPath)
        saveArchived()
    }

    /// Unarchive a project
    func unarchive(_ projectPath: String) {
        archivedPaths.remove(projectPath)
        saveArchived()
    }

    /// Toggle archive status
    func toggleArchive(_ projectPath: String) {
        if isArchived(projectPath) {
            unarchive(projectPath)
        } else {
            archive(projectPath)
        }
    }

    private func loadArchived() {
        if let paths = UserDefaults.standard.array(forKey: Self.storageKey) as? [String] {
            archivedPaths = Set(paths)
        }
    }

    private func saveArchived() {
        UserDefaults.standard.set(Array(archivedPaths), forKey: Self.storageKey)
    }
}
