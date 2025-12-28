import Foundation

/// Per-project settings that override global AppSettings
struct ProjectSettings: Codable, Equatable {
    /// Override for skipPermissions: nil = use global, true = always skip, false = never skip
    var skipPermissionsOverride: Bool?

    init(skipPermissionsOverride: Bool? = nil) {
        self.skipPermissionsOverride = skipPermissionsOverride
    }
}

/// Manages persistent storage of per-project settings
/// Follows the same pattern as IdeasStore for consistency
@MainActor
class ProjectSettingsStore: ObservableObject {
    static let shared = ProjectSettingsStore()

    @Published private var projectSettings: [String: ProjectSettings] = [:]

    private let settingsDirectory = "project-settings"
    private let settingsFile = "settings.json"
    private let baseDirectory: URL
    private let fileManager: FileManager
    private let loadSynchronously: Bool

    /// Background queue for file I/O to avoid blocking main thread
    private static let fileQueue = DispatchQueue(label: "com.claudecodeapp.projectsettingsstore", qos: .userInitiated)

    private var fileURL: URL {
        let settingsDirURL = baseDirectory.appendingPathComponent(settingsDirectory)

        // Create settings directory if needed
        if !fileManager.fileExists(atPath: settingsDirURL.path) {
            try? fileManager.createDirectory(at: settingsDirURL, withIntermediateDirectories: true)
        }

        return settingsDirURL.appendingPathComponent(settingsFile)
    }

    private static var defaultBaseDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    init(
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.baseDirectory = baseDirectory ?? Self.defaultBaseDirectory
        self.fileManager = fileManager
        // Load synchronously when a custom baseDirectory is provided (for tests)
        self.loadSynchronously = baseDirectory != nil
        load()
    }

    // MARK: - Public API

    /// Get settings for a project (creates default if none exist)
    func settings(for projectPath: String) -> ProjectSettings {
        let encodedPath = encodeProjectPath(projectPath)
        return projectSettings[encodedPath] ?? ProjectSettings()
    }

    /// Update settings for a project
    func updateSettings(for projectPath: String, settings: ProjectSettings) {
        let encodedPath = encodeProjectPath(projectPath)
        projectSettings[encodedPath] = settings
        save()
    }

    /// Get the skip permissions override for a project (nil = use global)
    func skipPermissionsOverride(for projectPath: String) -> Bool? {
        return settings(for: projectPath).skipPermissionsOverride
    }

    /// Set the skip permissions override for a project
    func setSkipPermissionsOverride(for projectPath: String, override: Bool?) {
        var currentSettings = settings(for: projectPath)
        currentSettings.skipPermissionsOverride = override
        updateSettings(for: projectPath, settings: currentSettings)
    }

    /// Get the effective skip permissions value for a project
    /// Takes into account both the project override and global setting
    func effectiveSkipPermissions(for projectPath: String, globalSetting: Bool) -> Bool {
        if let override = skipPermissionsOverride(for: projectPath) {
            return override
        }
        return globalSetting
    }

    /// Clear settings for a project (revert to global defaults)
    func clearSettings(for projectPath: String) {
        let encodedPath = encodeProjectPath(projectPath)
        projectSettings.removeValue(forKey: encodedPath)
        save()
    }

    // MARK: - Private Helpers

    private func encodeProjectPath(_ path: String) -> String {
        // Encode project path: /path/to/project -> -path-to-project
        return path.replacingOccurrences(of: "/", with: "-")
    }

    // MARK: - Persistence

    private func load() {
        let url = fileURL

        if loadSynchronously {
            // Synchronous load for tests
            loadSync(from: url)
        } else {
            // Perform file I/O on background queue to avoid blocking main thread
            ProjectSettingsStore.fileQueue.async { [weak self] in
                guard FileManager.default.fileExists(atPath: url.path) else {
                    Task { @MainActor [weak self] in
                        self?.projectSettings = [:]
                    }
                    return
                }

                do {
                    let data = try Data(contentsOf: url)
                    let loadedSettings = try JSONDecoder().decode([String: ProjectSettings].self, from: data)
                    Task { @MainActor [weak self] in
                        self?.projectSettings = loadedSettings
                    }
                } catch {
                    log.error("Failed to load project settings: \(error)")
                    Task { @MainActor [weak self] in
                        self?.projectSettings = [:]
                    }
                }
            }
        }
    }

    private func loadSync(from url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            projectSettings = [:]
            return
        }

        do {
            let data = try Data(contentsOf: url)
            projectSettings = try JSONDecoder().decode([String: ProjectSettings].self, from: data)
        } catch {
            log.error("Failed to load project settings: \(error)")
            projectSettings = [:]
        }
    }

    private func save() {
        // Capture data needed for background save
        let settingsToSave = projectSettings
        let url = fileURL

        if loadSynchronously {
            // Synchronous save for tests
            do {
                let data = try JSONEncoder().encode(settingsToSave)
                try data.write(to: url, options: .atomic)
            } catch {
                log.error("Failed to save project settings: \(error)")
            }
        } else {
            // Perform file I/O on background queue to avoid blocking main thread
            ProjectSettingsStore.fileQueue.async {
                do {
                    let data = try JSONEncoder().encode(settingsToSave)
                    try data.write(to: url, options: .atomic)
                } catch {
                    log.error("Failed to save project settings: \(error)")
                }
            }
        }
    }
}
