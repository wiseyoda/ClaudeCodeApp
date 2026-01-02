import XCTest
@testable import CodingBridge

@MainActor
private final class MockCLIBridgeAPIClient: CLIBridgeAPIClient {
    var permissionsResults: [Result<PermissionConfig, Error>] = []
    var updatePermissionsError: Error?
    var getPermissionsCallCount = 0
    var updatePermissionsCallCount = 0
    var lastUpdate: PermissionConfigUpdate?
    var onGetPermissions: (() -> Void)?
    var onUpdatePermissions: ((PermissionConfigUpdate) -> Void)?
    var shouldSuspendGetPermissions = false

    private var continuation: CheckedContinuation<PermissionConfig, Error>?

    init() {
        super.init(serverURL: "http://mock.server")
    }

    override func getPermissions() async throws -> PermissionConfig {
        getPermissionsCallCount += 1
        onGetPermissions?()

        if shouldSuspendGetPermissions {
            return try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
            }
        }

        if !permissionsResults.isEmpty {
            let result = permissionsResults.removeFirst()
            switch result {
            case .success(let config):
                return config
            case .failure(let error):
                throw error
            }
        }

        return PermissionConfig()
    }

    override func updatePermissions(_ updates: PermissionConfigUpdate) async throws {
        updatePermissionsCallCount += 1
        lastUpdate = updates
        onUpdatePermissions?(updates)

        if let updatePermissionsError {
            throw updatePermissionsError
        }
    }

    func resolveGetPermissions(with config: PermissionConfig) {
        continuation?.resume(returning: config)
        continuation = nil
        shouldSuspendGetPermissions = false
    }

    func rejectGetPermissions(with error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
        shouldSuspendGetPermissions = false
    }
}

@MainActor
final class PermissionManagerTests: XCTestCase {
    private let projectPath = "/tmp/project"
    private let otherProjectPath = "/tmp/other"

    private func makeConfig(
        globalBypass: Bool = false,
        globalDefault: PermissionMode = .default,
        projects: [String: ProjectPermissions] = [:]
    ) -> PermissionConfig {
        PermissionConfig(
            global: GlobalPermissions(bypassAll: globalBypass, defaultMode: globalDefault),
            projects: projects
        )
    }

    private func makeManager(config: PermissionConfig) async throws -> PermissionManager {
        let mock = MockCLIBridgeAPIClient()
        mock.permissionsResults = [.success(config)]
        let manager = PermissionManager.makeForTesting(apiClient: mock)
        _ = try await manager.loadConfig()
        return manager
    }

    // MARK: - Initialization

    func test_shared_returnsSingleton() {
        let first = PermissionManager.shared
        let second = PermissionManager.shared

        XCTAssertTrue(first === second)
    }

    func test_init_configIsNil() {
        let manager = PermissionManager.makeForTesting(apiClient: nil)

        XCTAssertNil(manager.config)
    }

    func test_init_isLoadingIsFalse() {
        let manager = PermissionManager.makeForTesting(apiClient: nil)

        XCTAssertFalse(manager.isLoading)
    }

    func test_init_lastErrorIsNil() {
        let manager = PermissionManager.makeForTesting(apiClient: nil)

        XCTAssertNil(manager.lastError)
    }

    func test_isConfigured_falseBeforeConfigure() {
        let manager = PermissionManager.makeForTesting(apiClient: nil)

        XCTAssertFalse(manager.isConfigured)
    }

    func test_hasConfig_falseBeforeLoad() {
        let manager = PermissionManager.makeForTesting(apiClient: nil)

        XCTAssertFalse(manager.hasConfig)
    }

    // MARK: - Configuration

    func test_configure_setsAPIClient() {
        let manager = PermissionManager.makeForTesting(apiClient: nil)

        XCTAssertFalse(manager.isConfigured)

        manager.configure(serverURL: "http://mock.server")

        XCTAssertTrue(manager.isConfigured)
    }

    func test_configure_clearsExistingConfig() async throws {
        let mock = MockCLIBridgeAPIClient()
        let config = makeConfig(globalDefault: .acceptEdits)
        mock.permissionsResults = [.success(config)]
        let manager = PermissionManager.makeForTesting(apiClient: mock)

        _ = try await manager.loadConfig()
        XCTAssertNotNil(manager.config)

        manager.configure(serverURL: "http://mock.server")

        XCTAssertNil(manager.config)
    }

    func test_configure_clearsLastError() async throws {
        let mock = MockCLIBridgeAPIClient()
        mock.permissionsResults = [.failure(CLIBridgeAPIError.badRequest)]
        let manager = PermissionManager.makeForTesting(apiClient: mock)

        do {
            _ = try await manager.loadConfig()
            XCTFail("Expected loadConfig to throw")
        } catch {
            XCTAssertNotNil(manager.lastError)
        }

        manager.configure(serverURL: "http://mock.server")

        XCTAssertNil(manager.lastError)
    }

    // MARK: - Load Config

    func test_loadConfig_success() async throws {
        let mock = MockCLIBridgeAPIClient()
        let config = makeConfig(globalDefault: .acceptEdits)
        mock.permissionsResults = [.success(config)]
        let manager = PermissionManager.makeForTesting(apiClient: mock)

        let loaded = try await manager.loadConfig()

        XCTAssertEqual(loaded, config)
        XCTAssertEqual(manager.config, config)
    }

    func test_loadConfig_setsIsLoading() async throws {
        let mock = MockCLIBridgeAPIClient()
        let config = makeConfig(globalDefault: .acceptEdits)
        mock.shouldSuspendGetPermissions = true
        let started = XCTestExpectation(description: "loadConfig started")
        mock.onGetPermissions = { started.fulfill() }
        let manager = PermissionManager.makeForTesting(apiClient: mock)

        let task = Task { @MainActor in
            try await manager.loadConfig()
        }

        await fulfillment(of: [started], timeout: 1.0)
        XCTAssertTrue(manager.isLoading)

        mock.resolveGetPermissions(with: config)
        _ = try await task.value
    }

    func test_loadConfig_clearsIsLoadingOnSuccess() async throws {
        let mock = MockCLIBridgeAPIClient()
        let config = makeConfig(globalDefault: .acceptEdits)
        mock.permissionsResults = [.success(config)]
        let manager = PermissionManager.makeForTesting(apiClient: mock)

        _ = try await manager.loadConfig()

        XCTAssertFalse(manager.isLoading)
    }

    func test_loadConfig_clearsIsLoadingOnError() async {
        let mock = MockCLIBridgeAPIClient()
        mock.permissionsResults = [.failure(CLIBridgeAPIError.badRequest)]
        let manager = PermissionManager.makeForTesting(apiClient: mock)

        do {
            _ = try await manager.loadConfig()
            XCTFail("Expected loadConfig to throw")
        } catch {
            XCTAssertFalse(manager.isLoading)
        }
    }

    func test_loadConfig_notFoundReturnsDefault() async throws {
        let mock = MockCLIBridgeAPIClient()
        mock.permissionsResults = [.failure(CLIBridgeAPIError.notFound)]
        let manager = PermissionManager.makeForTesting(apiClient: mock)

        let loaded = try await manager.loadConfig()

        XCTAssertEqual(loaded, PermissionConfig())
        XCTAssertEqual(manager.config, PermissionConfig())
    }

    func test_loadConfig_networkErrorThrows() async {
        let mock = MockCLIBridgeAPIClient()
        mock.permissionsResults = [.failure(CLIBridgeAPIError.badRequest)]
        let manager = PermissionManager.makeForTesting(apiClient: mock)

        do {
            _ = try await manager.loadConfig()
            XCTFail("Expected loadConfig to throw")
        } catch {
            if case CLIBridgeAPIError.badRequest = error {
                return
            }
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_loadConfig_setsLastErrorOnFailure() async {
        let mock = MockCLIBridgeAPIClient()
        mock.permissionsResults = [.failure(CLIBridgeAPIError.badRequest)]
        let manager = PermissionManager.makeForTesting(apiClient: mock)

        do {
            _ = try await manager.loadConfig()
            XCTFail("Expected loadConfig to throw")
        } catch {
            XCTAssertEqual(manager.lastError, CLIBridgeAPIError.badRequest.localizedDescription)
        }
    }

    func test_loadConfig_notConfiguredThrows() async {
        let manager = PermissionManager.makeForTesting(apiClient: nil)

        do {
            _ = try await manager.loadConfig()
            XCTFail("Expected loadConfig to throw")
        } catch {
            if case PermissionError.notConfigured = error {
                return
            }
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Update Config

    func test_updateConfig_callsAPI() async throws {
        let mock = MockCLIBridgeAPIClient()
        let config = makeConfig(globalDefault: .acceptEdits)
        mock.permissionsResults = [.success(config)]
        let manager = PermissionManager.makeForTesting(apiClient: mock)
        let updates = PermissionConfigUpdate(
            global: GlobalPermissionsUpdate(defaultMode: .acceptEdits)
        )

        try await manager.updateConfig(updates)

        XCTAssertEqual(mock.updatePermissionsCallCount, 1)
        XCTAssertEqual(mock.lastUpdate?.global?.defaultMode, .acceptEdits)
    }

    func test_updateConfig_invalidatesCacheAfter() async throws {
        let mock = MockCLIBridgeAPIClient()
        let initialConfig = makeConfig(globalDefault: .default)
        let updatedConfig = makeConfig(globalDefault: .acceptEdits)
        mock.permissionsResults = [.success(initialConfig), .success(updatedConfig)]
        let manager = PermissionManager.makeForTesting(apiClient: mock)
        var configWasNilDuringReload = false

        _ = try await manager.loadConfig()
        mock.onGetPermissions = {
            if mock.getPermissionsCallCount == 2 {
                configWasNilDuringReload = manager.config == nil
            }
        }

        try await manager.updateConfig(
            PermissionConfigUpdate(global: GlobalPermissionsUpdate(defaultMode: .acceptEdits))
        )

        XCTAssertTrue(configWasNilDuringReload)
    }

    func test_updateConfig_reloadsAfterUpdate() async throws {
        let mock = MockCLIBridgeAPIClient()
        let updatedConfig = makeConfig(globalDefault: .acceptEdits)
        mock.permissionsResults = [.success(updatedConfig)]
        let manager = PermissionManager.makeForTesting(apiClient: mock)

        try await manager.updateConfig(
            PermissionConfigUpdate(global: GlobalPermissionsUpdate(defaultMode: .acceptEdits))
        )

        XCTAssertEqual(mock.getPermissionsCallCount, 1)
        XCTAssertEqual(manager.config, updatedConfig)
    }

    func test_setGlobalDefaultMode_updatesMode() async throws {
        let mock = MockCLIBridgeAPIClient()
        let updatedConfig = makeConfig(globalDefault: .acceptEdits)
        mock.permissionsResults = [.success(updatedConfig)]
        let manager = PermissionManager.makeForTesting(apiClient: mock)

        try await manager.setGlobalDefaultMode(.acceptEdits)

        XCTAssertEqual(mock.lastUpdate?.global?.defaultMode, .acceptEdits)
        XCTAssertEqual(manager.config?.global.defaultMode, .acceptEdits)
    }

    func test_setGlobalBypassAll_enablesBypass() async throws {
        let mock = MockCLIBridgeAPIClient()
        let updatedConfig = makeConfig(globalBypass: true)
        mock.permissionsResults = [.success(updatedConfig)]
        let manager = PermissionManager.makeForTesting(apiClient: mock)

        try await manager.setGlobalBypassAll(true)

        XCTAssertEqual(mock.lastUpdate?.global?.bypassAll, true)
        XCTAssertEqual(manager.config?.global.bypassAll, true)
    }

    func test_setProjectMode_updatesProjectMode() async throws {
        let mock = MockCLIBridgeAPIClient()
        let updatedConfig = makeConfig(projects: [
            projectPath: ProjectPermissions(permissionMode: .acceptEdits)
        ])
        mock.permissionsResults = [.success(updatedConfig)]
        let manager = PermissionManager.makeForTesting(apiClient: mock)

        try await manager.setProjectMode(projectPath, mode: .acceptEdits)

        XCTAssertEqual(mock.lastUpdate?.projects?[projectPath]?.permissionMode, .acceptEdits)
        XCTAssertEqual(manager.config?.projects[projectPath]?.permissionMode, .acceptEdits)
    }

    // MARK: - Always Allow/Deny Lists

    func test_addAlwaysAllow_addsToList() async throws {
        let mock = MockCLIBridgeAPIClient()
        let initialConfig = makeConfig(projects: [projectPath: ProjectPermissions()])
        let updatedConfig = makeConfig(projects: [
            projectPath: ProjectPermissions(alwaysAllow: ["Read"])
        ])
        mock.permissionsResults = [.success(initialConfig), .success(updatedConfig)]
        let manager = PermissionManager.makeForTesting(apiClient: mock)

        _ = try await manager.loadConfig()
        try await manager.addAlwaysAllow("Read", for: projectPath)

        XCTAssertEqual(mock.lastUpdate?.projects?[projectPath]?.alwaysAllow, ["Read"])
        XCTAssertEqual(manager.config?.projects[projectPath]?.alwaysAllow ?? [], ["Read"])
    }

    func test_addAlwaysAllow_noDuplicates() async throws {
        let mock = MockCLIBridgeAPIClient()
        let initialConfig = makeConfig(projects: [
            projectPath: ProjectPermissions(alwaysAllow: ["Read"])
        ])
        let updatedConfig = makeConfig(projects: [
            projectPath: ProjectPermissions(alwaysAllow: ["Read"])
        ])
        mock.permissionsResults = [.success(initialConfig), .success(updatedConfig)]
        let manager = PermissionManager.makeForTesting(apiClient: mock)

        _ = try await manager.loadConfig()
        try await manager.addAlwaysAllow("Read", for: projectPath)

        XCTAssertEqual(mock.lastUpdate?.projects?[projectPath]?.alwaysAllow, ["Read"])
    }

    func test_removeAlwaysAllow_removesFromList() async throws {
        let mock = MockCLIBridgeAPIClient()
        let initialConfig = makeConfig(projects: [
            projectPath: ProjectPermissions(alwaysAllow: ["Read", "Write"])
        ])
        let updatedConfig = makeConfig(projects: [
            projectPath: ProjectPermissions(alwaysAllow: ["Write"])
        ])
        mock.permissionsResults = [.success(initialConfig), .success(updatedConfig)]
        let manager = PermissionManager.makeForTesting(apiClient: mock)

        _ = try await manager.loadConfig()
        try await manager.removeAlwaysAllow("Read", for: projectPath)

        XCTAssertEqual(mock.lastUpdate?.projects?[projectPath]?.alwaysAllow, ["Write"])
        XCTAssertEqual(manager.config?.projects[projectPath]?.alwaysAllow ?? [], ["Write"])
    }

    func test_addAlwaysDeny_addsToList() async throws {
        let mock = MockCLIBridgeAPIClient()
        let initialConfig = makeConfig(projects: [projectPath: ProjectPermissions()])
        let updatedConfig = makeConfig(projects: [
            projectPath: ProjectPermissions(alwaysDeny: ["Bash"])
        ])
        mock.permissionsResults = [.success(initialConfig), .success(updatedConfig)]
        let manager = PermissionManager.makeForTesting(apiClient: mock)

        _ = try await manager.loadConfig()
        try await manager.addAlwaysDeny("Bash", for: projectPath)

        XCTAssertEqual(mock.lastUpdate?.projects?[projectPath]?.alwaysDeny, ["Bash"])
        XCTAssertEqual(manager.config?.projects[projectPath]?.alwaysDeny ?? [], ["Bash"])
    }

    func test_addAlwaysDeny_noDuplicates() async throws {
        let mock = MockCLIBridgeAPIClient()
        let initialConfig = makeConfig(projects: [
            projectPath: ProjectPermissions(alwaysDeny: ["Bash"])
        ])
        let updatedConfig = makeConfig(projects: [
            projectPath: ProjectPermissions(alwaysDeny: ["Bash"])
        ])
        mock.permissionsResults = [.success(initialConfig), .success(updatedConfig)]
        let manager = PermissionManager.makeForTesting(apiClient: mock)

        _ = try await manager.loadConfig()
        try await manager.addAlwaysDeny("Bash", for: projectPath)

        XCTAssertEqual(mock.lastUpdate?.projects?[projectPath]?.alwaysDeny, ["Bash"])
    }

    func test_removeAlwaysDeny_removesFromList() async throws {
        let mock = MockCLIBridgeAPIClient()
        let initialConfig = makeConfig(projects: [
            projectPath: ProjectPermissions(alwaysDeny: ["Bash", "Read"])
        ])
        let updatedConfig = makeConfig(projects: [
            projectPath: ProjectPermissions(alwaysDeny: ["Read"])
        ])
        mock.permissionsResults = [.success(initialConfig), .success(updatedConfig)]
        let manager = PermissionManager.makeForTesting(apiClient: mock)

        _ = try await manager.loadConfig()
        try await manager.removeAlwaysDeny("Bash", for: projectPath)

        XCTAssertEqual(mock.lastUpdate?.projects?[projectPath]?.alwaysDeny, ["Read"])
        XCTAssertEqual(manager.config?.projects[projectPath]?.alwaysDeny ?? [], ["Read"])
    }

    func test_getAlwaysAllowList_returnsProjectList() async throws {
        let config = makeConfig(projects: [
            projectPath: ProjectPermissions(alwaysAllow: ["Read", "Write"])
        ])
        let manager = try await makeManager(config: config)

        XCTAssertEqual(manager.getAlwaysAllowList(for: projectPath), ["Read", "Write"])
    }

    func test_getAlwaysAllowList_emptyWhenNoProject() async throws {
        let config = makeConfig(projects: [
            otherProjectPath: ProjectPermissions(alwaysAllow: ["Read"])
        ])
        let manager = try await makeManager(config: config)

        XCTAssertEqual(manager.getAlwaysAllowList(for: projectPath), [])
    }

    func test_getAlwaysDenyList_returnsProjectList() async throws {
        let config = makeConfig(projects: [
            projectPath: ProjectPermissions(alwaysDeny: ["Bash", "Read"])
        ])
        let manager = try await makeManager(config: config)

        XCTAssertEqual(manager.getAlwaysDenyList(for: projectPath), ["Bash", "Read"])
    }

    func test_getAlwaysDenyList_emptyWhenNoProject() async throws {
        let config = makeConfig(projects: [
            otherProjectPath: ProjectPermissions(alwaysDeny: ["Read"])
        ])
        let manager = try await makeManager(config: config)

        XCTAssertEqual(manager.getAlwaysDenyList(for: projectPath), [])
    }

    // MARK: - Resolution Logic (resolvePermissionMode)

    func test_resolvePermissionMode_sessionOverrideTakesPriority() async throws {
        let config = makeConfig(globalDefault: .default)
        let manager = try await makeManager(config: config)

        let mode = manager.resolvePermissionMode(for: projectPath, sessionOverride: .acceptEdits)

        XCTAssertEqual(mode, .acceptEdits)
    }

    func test_resolvePermissionMode_localProjectOverrideTakesPriorityOverServer() async throws {
        let config = makeConfig(
            globalDefault: .default,
            projects: [projectPath: ProjectPermissions(permissionMode: .default)]
        )
        let manager = try await makeManager(config: config)

        let mode = manager.resolvePermissionMode(
            for: projectPath,
            localProjectOverride: .acceptEdits
        )

        XCTAssertEqual(mode, .acceptEdits)
    }

    func test_resolvePermissionMode_serverProjectConfigApplies() async throws {
        let config = makeConfig(projects: [
            projectPath: ProjectPermissions(permissionMode: .acceptEdits, bypassAll: false)
        ])
        let manager = try await makeManager(config: config)

        let mode = manager.resolvePermissionMode(for: projectPath)

        XCTAssertEqual(mode, .acceptEdits)
    }

    func test_resolvePermissionMode_serverProjectBypassOverridesProjectMode() async throws {
        let config = makeConfig(projects: [
            projectPath: ProjectPermissions(permissionMode: .acceptEdits, bypassAll: true)
        ])
        let manager = try await makeManager(config: config)

        let mode = manager.resolvePermissionMode(for: projectPath)

        XCTAssertEqual(mode, .bypassPermissions)
    }

    func test_resolvePermissionMode_globalAppSettingApplies() async throws {
        let config = makeConfig(globalDefault: .default)
        let manager = try await makeManager(config: config)

        let mode = manager.resolvePermissionMode(
            for: projectPath,
            globalAppSetting: .acceptEdits
        )

        XCTAssertEqual(mode, .acceptEdits)
    }

    func test_resolvePermissionMode_serverGlobalDefaultApplies() async throws {
        let config = makeConfig(globalDefault: .acceptEdits)
        let manager = try await makeManager(config: config)

        let mode = manager.resolvePermissionMode(for: projectPath)

        XCTAssertEqual(mode, .acceptEdits)
    }

    func test_resolvePermissionMode_serverGlobalBypassApplies() async throws {
        let config = makeConfig(globalBypass: true, globalDefault: .default)
        let manager = try await makeManager(config: config)

        let mode = manager.resolvePermissionMode(for: projectPath)

        XCTAssertEqual(mode, .bypassPermissions)
    }

    func test_resolvePermissionMode_fallsBackToGlobalAppSetting() async throws {
        // No server config
        let manager = PermissionManager.makeForTesting(apiClient: nil)

        let mode = manager.resolvePermissionMode(
            for: projectPath,
            globalAppSetting: .acceptEdits
        )

        XCTAssertEqual(mode, .acceptEdits)
    }

    func test_resolvePermissionMode_defaultWhenNoConfigOrSetting() {
        let manager = PermissionManager.makeForTesting(apiClient: nil)

        let mode = manager.resolvePermissionMode(for: projectPath)

        XCTAssertEqual(mode, .default)
    }

    func test_resolvePermissionMode_projectNotInConfig() async throws {
        let config = makeConfig(
            globalDefault: .acceptEdits,
            projects: [otherProjectPath: ProjectPermissions(permissionMode: .bypassPermissions)]
        )
        let manager = try await makeManager(config: config)

        let mode = manager.resolvePermissionMode(for: projectPath)

        XCTAssertEqual(mode, .acceptEdits)
    }

    func test_resolvePermissionMode_priorityOrder() async throws {
        // Test full priority: session > local > server project > global app > server global
        let config = makeConfig(
            globalDefault: .default,
            projects: [projectPath: ProjectPermissions(permissionMode: .default)]
        )
        let manager = try await makeManager(config: config)

        // Session override wins over everything
        let withSession = manager.resolvePermissionMode(
            for: projectPath,
            sessionOverride: .bypassPermissions,
            localProjectOverride: .acceptEdits,
            globalAppSetting: .default
        )
        XCTAssertEqual(withSession, .bypassPermissions)

        // Local project override wins over server and global
        let withLocal = manager.resolvePermissionMode(
            for: projectPath,
            localProjectOverride: .acceptEdits,
            globalAppSetting: .default
        )
        XCTAssertEqual(withLocal, .acceptEdits)
    }

    // MARK: - Tool Approval

    func test_shouldAutoApprove_denyListTakesPriority() async throws {
        let config = makeConfig(
            globalBypass: true,
            projects: [
                projectPath: ProjectPermissions(alwaysAllow: ["Bash"], alwaysDeny: ["Bash"])
            ]
        )
        let manager = try await makeManager(config: config)

        let shouldApprove = manager.shouldAutoApprove(tool: "Bash", for: projectPath)

        XCTAssertFalse(shouldApprove)
    }

    func test_shouldAutoApprove_allowListApproves() async throws {
        let config = makeConfig(projects: [
            projectPath: ProjectPermissions(alwaysAllow: ["Bash"])
        ])
        let manager = try await makeManager(config: config)

        let shouldApprove = manager.shouldAutoApprove(tool: "Bash", for: projectPath)

        XCTAssertTrue(shouldApprove)
    }

    func test_shouldAutoApprove_bypassModeApprovesAll() async throws {
        let config = makeConfig(globalBypass: true)
        let manager = try await makeManager(config: config)

        let shouldApprove = manager.shouldAutoApprove(tool: "Bash", for: projectPath)

        XCTAssertTrue(shouldApprove)
    }

    func test_shouldAutoApprove_acceptEditsApprovesFileTools() async throws {
        let config = makeConfig(globalDefault: .acceptEdits)
        let manager = try await makeManager(config: config)

        let shouldApprove = manager.shouldAutoApprove(tool: "Read", for: projectPath)

        XCTAssertTrue(shouldApprove)
    }

    func test_shouldAutoApprove_defaultModeDeniesAll() async throws {
        let config = makeConfig(globalDefault: .default)
        let manager = try await makeManager(config: config)

        let shouldApprove = manager.shouldAutoApprove(tool: "Bash", for: projectPath)

        XCTAssertFalse(shouldApprove)
    }

    func test_shouldAutoApprove_withSessionOverride() async throws {
        let config = makeConfig(globalDefault: .default)
        let manager = try await makeManager(config: config)

        let shouldApprove = manager.shouldAutoApprove(
            tool: "Bash",
            for: projectPath,
            sessionOverride: .bypassPermissions
        )

        XCTAssertTrue(shouldApprove)
    }

    func test_isToolDenied_trueWhenInDenyList() async throws {
        let config = makeConfig(projects: [
            projectPath: ProjectPermissions(alwaysDeny: ["Bash"])
        ])
        let manager = try await makeManager(config: config)

        XCTAssertTrue(manager.isToolDenied("Bash", for: projectPath))
    }

    func test_isToolDenied_falseWhenNotInDenyList() async throws {
        let config = makeConfig(projects: [
            projectPath: ProjectPermissions(alwaysDeny: ["Read"])
        ])
        let manager = try await makeManager(config: config)

        XCTAssertFalse(manager.isToolDenied("Bash", for: projectPath))
    }

    // MARK: - Cache Management

    func test_invalidateCache_clearsConfig() async throws {
        let config = makeConfig(globalDefault: .acceptEdits)
        let manager = try await makeManager(config: config)

        manager.invalidateCache()

        XCTAssertNil(manager.config)
    }

    func test_invalidateCache_forcesReloadOnNextAccess() async throws {
        let mock = MockCLIBridgeAPIClient()
        let initialConfig = makeConfig(globalDefault: .default)
        let updatedConfig = makeConfig(globalDefault: .acceptEdits)
        mock.permissionsResults = [.success(initialConfig), .success(updatedConfig)]
        let manager = PermissionManager.makeForTesting(apiClient: mock)

        _ = try await manager.loadConfig()
        manager.invalidateCache()
        _ = try await manager.loadConfig()

        XCTAssertEqual(mock.getPermissionsCallCount, 2)
        XCTAssertEqual(manager.config, updatedConfig)
    }

    // MARK: - Permission Errors

    func test_permissionError_notConfiguredDescription() {
        XCTAssertEqual(
            PermissionError.notConfigured.errorDescription,
            "Permission manager not configured with server URL"
        )
    }

    func test_permissionError_updateFailedDescription() {
        XCTAssertEqual(
            PermissionError.updateFailed.errorDescription,
            "Failed to update permission configuration"
        )
    }

    func test_permissionError_invalidResponseDescription() {
        XCTAssertEqual(
            PermissionError.invalidResponse.errorDescription,
            "Invalid response from server"
        )
    }
}
