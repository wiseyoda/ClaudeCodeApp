import XCTest
@testable import CodingBridge

@MainActor
final class ProjectSettingsStoreTests: XCTestCase {

    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        super.tearDown()
    }

    private func makeStore() -> ProjectSettingsStore {
        ProjectSettingsStore(baseDirectory: tempDirectory)
    }

    private func settingsFileURL() -> URL {
        tempDirectory
            .appendingPathComponent("project-settings", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    func test_settings_returnsDefaultWhenMissing() {
        let store = makeStore()

        let settings = store.settings(for: "/path/to/project")

        XCTAssertNil(settings.permissionModeOverride)
    }

    func test_permissionModeOverride_returnsNilByDefault() {
        let store = makeStore()

        XCTAssertNil(store.settings(for: "/path/to/project").permissionModeOverride)
    }

    func test_updateSettings_persistsAndLoads() throws {
        let store = makeStore()
        let projectPath = "/path/to/project"

        store.updateSettings(for: projectPath, settings: ProjectSettings(permissionModeOverride: .bypassPermissions))

        let reloaded = ProjectSettingsStore(baseDirectory: tempDirectory)
        XCTAssertEqual(reloaded.settings(for: projectPath).permissionModeOverride, .bypassPermissions)
    }

    func test_updateSettings_setsPermissionMode() {
        let store = makeStore()
        let projectPath = "/path/to/project"

        store.updateSettings(for: projectPath, settings: ProjectSettings(permissionModeOverride: .acceptEdits))

        XCTAssertEqual(store.settings(for: projectPath).permissionModeOverride, .acceptEdits)
    }

    func test_updateSettings_canSetBypassPermissions() {
        let store = makeStore()
        let projectPath = "/path/to/project"

        store.updateSettings(for: projectPath, settings: ProjectSettings(permissionModeOverride: .bypassPermissions))

        XCTAssertEqual(store.settings(for: projectPath).permissionModeOverride, .bypassPermissions)
    }

    func test_updateSettings_canSetDefault() {
        let store = makeStore()
        let projectPath = "/path/to/project"

        store.updateSettings(for: projectPath, settings: ProjectSettings(permissionModeOverride: .default))

        XCTAssertEqual(store.settings(for: projectPath).permissionModeOverride, .default)
    }

    func test_updateSettings_canClearOverride() {
        let store = makeStore()
        let projectPath = "/path/to/project"

        store.updateSettings(for: projectPath, settings: ProjectSettings(permissionModeOverride: .bypassPermissions))
        store.updateSettings(for: projectPath, settings: ProjectSettings(permissionModeOverride: nil))

        XCTAssertNil(store.settings(for: projectPath).permissionModeOverride)
    }

    func test_clearSettings_removesPersistedOverride() {
        let store = makeStore()
        let projectPath = "/path/to/project"

        store.updateSettings(for: projectPath, settings: ProjectSettings(permissionModeOverride: .bypassPermissions))
        store.clearSettings(for: projectPath)

        let reloaded = ProjectSettingsStore(baseDirectory: tempDirectory)
        XCTAssertNil(reloaded.settings(for: projectPath).permissionModeOverride)
    }

    func test_encodedPath_usesHyphensInStorageKey() throws {
        let store = makeStore()
        let projectPath = "/home/user/my-project"

        store.updateSettings(for: projectPath, settings: ProjectSettings(permissionModeOverride: .bypassPermissions))

        let data = try Data(contentsOf: settingsFileURL())
        let decoded = try JSONDecoder().decode([String: ProjectSettings].self, from: data)

        XCTAssertTrue(decoded.keys.contains("-home-user-my-project"))
    }
}
