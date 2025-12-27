import XCTest
@testable import ClaudeCodeApp

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

        XCTAssertNil(settings.skipPermissionsOverride)
    }

    func test_skipPermissionsOverride_returnsNilByDefault() {
        let store = makeStore()

        XCTAssertNil(store.skipPermissionsOverride(for: "/path/to/project"))
    }

    func test_updateSettings_persistsAndLoads() throws {
        let store = makeStore()
        let projectPath = "/path/to/project"

        store.updateSettings(for: projectPath, settings: ProjectSettings(skipPermissionsOverride: true))

        let reloaded = ProjectSettingsStore(baseDirectory: tempDirectory)
        XCTAssertEqual(reloaded.settings(for: projectPath).skipPermissionsOverride, true)
    }

    func test_setSkipPermissionsOverride_updatesInMemory() {
        let store = makeStore()
        let projectPath = "/path/to/project"

        store.setSkipPermissionsOverride(for: projectPath, override: false)

        XCTAssertEqual(store.skipPermissionsOverride(for: projectPath), false)
    }

    func test_effectiveSkipPermissions_prefersOverrideTrue() {
        let store = makeStore()
        let projectPath = "/path/to/project"

        store.setSkipPermissionsOverride(for: projectPath, override: true)

        XCTAssertTrue(store.effectiveSkipPermissions(for: projectPath, globalSetting: false))
    }

    func test_effectiveSkipPermissions_prefersOverrideFalse() {
        let store = makeStore()
        let projectPath = "/path/to/project"

        store.setSkipPermissionsOverride(for: projectPath, override: false)

        XCTAssertFalse(store.effectiveSkipPermissions(for: projectPath, globalSetting: true))
    }

    func test_effectiveSkipPermissions_fallsBackToGlobalSetting() {
        let store = makeStore()
        let projectPath = "/path/to/project"

        store.setSkipPermissionsOverride(for: projectPath, override: nil)

        XCTAssertTrue(store.effectiveSkipPermissions(for: projectPath, globalSetting: true))
        XCTAssertFalse(store.effectiveSkipPermissions(for: projectPath, globalSetting: false))
    }

    func test_clearSettings_removesPersistedOverride() {
        let store = makeStore()
        let projectPath = "/path/to/project"

        store.setSkipPermissionsOverride(for: projectPath, override: true)
        store.clearSettings(for: projectPath)

        let reloaded = ProjectSettingsStore(baseDirectory: tempDirectory)
        XCTAssertNil(reloaded.skipPermissionsOverride(for: projectPath))
    }

    func test_encodedPath_usesHyphensInStorageKey() throws {
        let store = makeStore()
        let projectPath = "/home/user/my-project"

        store.setSkipPermissionsOverride(for: projectPath, override: true)

        let data = try Data(contentsOf: settingsFileURL())
        let decoded = try JSONDecoder().decode([String: ProjectSettings].self, from: data)

        XCTAssertTrue(decoded.keys.contains("-home-user-my-project"))
    }
}
