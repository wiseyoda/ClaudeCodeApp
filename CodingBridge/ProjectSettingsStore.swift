import Foundation

/// Per-project settings that override global AppSettings
struct ProjectSettings: Codable, Equatable {
    /// Override for permission mode: nil = use global, otherwise use this mode
    var permissionModeOverride: PermissionMode?

    /// Enable sub-repository discovery for this project (default: false)
    /// When enabled, the app will scan for nested git repos within the project
    var enableSubrepoDiscovery: Bool

    init(permissionModeOverride: PermissionMode? = nil, enableSubrepoDiscovery: Bool = false) {
        self.permissionModeOverride = permissionModeOverride
        self.enableSubrepoDiscovery = enableSubrepoDiscovery
    }

    // Custom decoder for backwards compatibility with cached data missing new fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        permissionModeOverride = try container.decodeIfPresent(PermissionMode.self, forKey: .permissionModeOverride)
        enableSubrepoDiscovery = try container.decodeIfPresent(Bool.self, forKey: .enableSubrepoDiscovery) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case permissionModeOverride
        case enableSubrepoDiscovery
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
    private static let fileQueue = DispatchQueue(label: "com.codingbridge.projectsettingsstore", qos: .userInitiated)

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
        let encodedPath = ProjectPathEncoder.encode(projectPath)
        return projectSettings[encodedPath] ?? ProjectSettings()
    }

    /// Update settings for a project
    func updateSettings(for projectPath: String, settings: ProjectSettings) {
        let encodedPath = ProjectPathEncoder.encode(projectPath)
        projectSettings[encodedPath] = settings
        save()
    }

    /// Get the permission mode override for a project (nil = use global)
    func permissionModeOverride(for projectPath: String) -> PermissionMode? {
        return settings(for: projectPath).permissionModeOverride
    }

    /// Set the permission mode override for a project
    func setPermissionModeOverride(for projectPath: String, mode: PermissionMode?) {
        var currentSettings = settings(for: projectPath)
        currentSettings.permissionModeOverride = mode
        updateSettings(for: projectPath, settings: currentSettings)
    }

    /// Clear settings for a project (revert to global defaults)
    func clearSettings(for projectPath: String) {
        let encodedPath = ProjectPathEncoder.encode(projectPath)
        projectSettings.removeValue(forKey: encodedPath)
        save()
    }

    /// Check if sub-repository discovery is enabled for a project (default: false)
    func isSubrepoDiscoveryEnabled(for projectPath: String) -> Bool {
        return settings(for: projectPath).enableSubrepoDiscovery
    }

    /// Set whether sub-repository discovery is enabled for a project
    func setSubrepoDiscoveryEnabled(for projectPath: String, enabled: Bool) {
        var currentSettings = settings(for: projectPath)
        currentSettings.enableSubrepoDiscovery = enabled
        updateSettings(for: projectPath, settings: currentSettings)
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
