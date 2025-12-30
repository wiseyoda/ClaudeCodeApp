import Foundation
import SwiftUI

// MARK: - Permission Manager

/// Manages permission configuration with caching and resolution logic
/// Provides REST API integration for persistent permissions
@MainActor
class PermissionManager: ObservableObject {
    static let shared = PermissionManager()

    /// Cached permission configuration from server
    @Published private(set) var config: PermissionConfig?

    /// Whether we're currently loading config
    @Published private(set) var isLoading = false

    /// Last error that occurred
    @Published private(set) var lastError: String?

    /// API client for server communication
    private var apiClient: CLIBridgeAPIClient?

    private init(apiClient: CLIBridgeAPIClient? = nil) {
        self.apiClient = apiClient
    }

#if DEBUG
    static func makeForTesting(apiClient: CLIBridgeAPIClient? = nil) -> PermissionManager {
        PermissionManager(apiClient: apiClient)
    }
#endif

    // MARK: - Configuration

    /// Configure the manager with server settings
    func configure(serverURL: String) {
        self.apiClient = CLIBridgeAPIClient(serverURL: serverURL)
        self.config = nil
        self.lastError = nil
    }

    // MARK: - REST API Methods

    /// Load current permission configuration from server
    @discardableResult
    func loadConfig() async throws -> PermissionConfig {
        guard let apiClient = apiClient else {
            throw PermissionError.notConfigured
        }

        isLoading = true
        lastError = nil

        do {
            let config = try await apiClient.getPermissions()
            self.config = config
            isLoading = false
            return config
        } catch {
            isLoading = false
            // If server doesn't support permissions endpoint, use default config
            if case CLIBridgeAPIError.notFound = error {
                let defaultConfig = PermissionConfig()
                self.config = defaultConfig
                return defaultConfig
            }
            lastError = error.localizedDescription
            throw error
        }
    }

    /// Update permission configuration (merges with existing)
    func updateConfig(_ updates: PermissionConfigUpdate) async throws {
        guard let apiClient = apiClient else {
            throw PermissionError.notConfigured
        }

        try await apiClient.updatePermissions(updates)

        // Invalidate cache and reload
        self.config = nil
        try await loadConfig()
    }

    /// Set global default mode
    func setGlobalDefaultMode(_ mode: PermissionMode) async throws {
        try await updateConfig(PermissionConfigUpdate(
            global: GlobalPermissionsUpdate(defaultMode: mode)
        ))
    }

    /// Set global bypass all
    func setGlobalBypassAll(_ bypass: Bool) async throws {
        try await updateConfig(PermissionConfigUpdate(
            global: GlobalPermissionsUpdate(bypassAll: bypass)
        ))
    }

    /// Set project permission mode
    func setProjectMode(_ projectPath: String, mode: PermissionMode) async throws {
        try await updateConfig(PermissionConfigUpdate(
            projects: [projectPath: ProjectPermissionsUpdate(permissionMode: mode)]
        ))
    }

    /// Enable bypass for a project
    func enableBypass(for projectPath: String) async throws {
        try await updateConfig(PermissionConfigUpdate(
            projects: [projectPath: ProjectPermissionsUpdate(bypassAll: true)]
        ))
    }

    /// Disable bypass for a project
    func disableBypass(for projectPath: String) async throws {
        try await updateConfig(PermissionConfigUpdate(
            projects: [projectPath: ProjectPermissionsUpdate(bypassAll: false)]
        ))
    }

    /// Add tool to always-allow list
    func addAlwaysAllow(_ tool: String, for projectPath: String) async throws {
        var currentList = getAlwaysAllowList(for: projectPath)
        if !currentList.contains(tool) {
            currentList.append(tool)
        }

        try await updateConfig(PermissionConfigUpdate(
            projects: [projectPath: ProjectPermissionsUpdate(alwaysAllow: currentList)]
        ))
    }

    /// Remove tool from always-allow list
    func removeAlwaysAllow(_ tool: String, for projectPath: String) async throws {
        var currentList = getAlwaysAllowList(for: projectPath)
        currentList.removeAll { $0 == tool }

        try await updateConfig(PermissionConfigUpdate(
            projects: [projectPath: ProjectPermissionsUpdate(alwaysAllow: currentList)]
        ))
    }

    /// Add tool to always-deny list
    func addAlwaysDeny(_ tool: String, for projectPath: String) async throws {
        var currentList = getAlwaysDenyList(for: projectPath)
        if !currentList.contains(tool) {
            currentList.append(tool)
        }

        try await updateConfig(PermissionConfigUpdate(
            projects: [projectPath: ProjectPermissionsUpdate(alwaysDeny: currentList)]
        ))
    }

    /// Remove tool from always-deny list
    func removeAlwaysDeny(_ tool: String, for projectPath: String) async throws {
        var currentList = getAlwaysDenyList(for: projectPath)
        currentList.removeAll { $0 == tool }

        try await updateConfig(PermissionConfigUpdate(
            projects: [projectPath: ProjectPermissionsUpdate(alwaysDeny: currentList)]
        ))
    }

    // MARK: - Resolution Logic

    /// Get effective permission mode for a project
    /// Resolution order: session override > project bypass > project mode > global bypass > global default
    func getEffectiveMode(
        for projectPath: String,
        sessionOverride: PermissionMode? = nil
    ) -> PermissionMode {
        // Session override takes highest priority
        if let sessionMode = sessionOverride {
            return sessionMode
        }

        guard let config = config else {
            return .default
        }

        // Check global bypass
        if config.global.bypassAll {
            return .bypassPermissions
        }

        // Check project config
        if let projectConfig = config.projects[projectPath] {
            // Project-level bypass
            if projectConfig.bypassAll == true {
                return .bypassPermissions
            }
            // Project-level mode
            if let mode = projectConfig.permissionMode {
                return mode
            }
        }

        // Fall back to global default
        return config.global.defaultMode
    }

    /// Get always-allow list for a project
    func getAlwaysAllowList(for projectPath: String) -> [String] {
        return config?.projects[projectPath]?.alwaysAllow ?? []
    }

    /// Get always-deny list for a project
    func getAlwaysDenyList(for projectPath: String) -> [String] {
        return config?.projects[projectPath]?.alwaysDeny ?? []
    }

    /// Check if a tool should be auto-approved for the given project
    func shouldAutoApprove(
        tool: String,
        for projectPath: String,
        sessionOverride: PermissionMode? = nil
    ) -> Bool {
        let alwaysDeny = getAlwaysDenyList(for: projectPath)
        let alwaysAllow = getAlwaysAllowList(for: projectPath)
        let effectiveMode = getEffectiveMode(for: projectPath, sessionOverride: sessionOverride)

        return isToolAutoApproved(tool, mode: effectiveMode, alwaysAllow: alwaysAllow, alwaysDeny: alwaysDeny)
    }

    /// Check if a tool is in the always-deny list
    func isToolDenied(_ tool: String, for projectPath: String) -> Bool {
        let alwaysDeny = getAlwaysDenyList(for: projectPath)
        return alwaysDeny.contains(tool)
    }

    /// Check if config has been loaded
    var isConfigured: Bool {
        return apiClient != nil
    }

    /// Check if config is available
    var hasConfig: Bool {
        return config != nil
    }

    /// Clear cached config (forces reload on next access)
    func invalidateCache() {
        config = nil
    }
}

// MARK: - Permission Errors

enum PermissionError: LocalizedError {
    case notConfigured
    case updateFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Permission manager not configured with server URL"
        case .updateFailed:
            return "Failed to update permission configuration"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}
