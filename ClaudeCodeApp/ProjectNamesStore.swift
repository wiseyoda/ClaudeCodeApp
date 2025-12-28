import Foundation

/// Stores custom display names for projects (persisted locally via UserDefaults)
/// Follows the same pattern as SessionNamesStore
class ProjectNamesStore {
    static let shared = ProjectNamesStore()
    private let key = "project_custom_names"

    /// Get custom name for a project by its path
    func getName(for projectPath: String) -> String? {
        let names = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
        return names[projectPath]
    }

    /// Set or clear custom name for a project
    func setName(_ name: String?, for projectPath: String) {
        var names = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
        if let name = name, !name.isEmpty {
            names[projectPath] = name
        } else {
            names.removeValue(forKey: projectPath)
        }
        UserDefaults.standard.set(names, forKey: key)
    }

    /// Check if a project has a custom name
    func hasCustomName(for projectPath: String) -> Bool {
        getName(for: projectPath) != nil
    }
}
