import Foundation
import SwiftUI

// MARK: - Permission Mode Enum

/// Permission modes matching cli-bridge spec
/// Maps to CLISetPermissionModePayload.CLIPermissionMode for WebSocket communication
enum PermissionMode: String, Codable, CaseIterable, Equatable {
    case `default` = "default"
    case acceptEdits = "acceptEdits"
    case bypassPermissions = "bypassPermissions"

    var displayName: String {
        switch self {
        case .default:
            return "Ask for Everything"
        case .acceptEdits:
            return "Auto-approve File Edits"
        case .bypassPermissions:
            return "Trust Everything"
        }
    }

    /// Short name for compact UI (status bar pills)
    var shortDisplayName: String {
        switch self {
        case .default:
            return "Ask"
        case .acceptEdits:
            return "Edits OK"
        case .bypassPermissions:
            return "Bypass"
        }
    }

    var description: String {
        switch self {
        case .default:
            return "Claude will ask before using any tools"
        case .acceptEdits:
            return "Auto-approve Read, Write, Edit, Glob, Grep, LS"
        case .bypassPermissions:
            return "Never ask for permission (dangerous!)"
        }
    }

    var icon: String {
        switch self {
        case .default:
            return "lock.shield"
        case .acceptEdits:
            return "pencil.and.outline"
        case .bypassPermissions:
            return "lock.open"
        }
    }

    var color: Color {
        switch self {
        case .default:
            return .blue
        case .acceptEdits:
            return .orange
        case .bypassPermissions:
            return .red
        }
    }

    /// Whether this mode is dangerous and should show a warning
    var isDangerous: Bool {
        self == .bypassPermissions
    }

    /// Convert to CLIPermissionMode for WebSocket communication
    func toCLIPermissionMode() -> CLIPermissionMode {
        switch self {
        case .default:
            return ._default
        case .acceptEdits:
            return .acceptedits
        case .bypassPermissions:
            return .bypasspermissions
        }
    }

    /// Create from CLIPermissionMode
    init(from cliMode: CLIPermissionMode) {
        switch cliMode {
        case ._default:
            self = .default
        case .acceptedits:
            self = .acceptEdits
        case .bypasspermissions:
            self = .bypassPermissions
        }
    }
}

// MARK: - REST API Response Models

/// Full permission configuration from GET /permissions
struct PermissionConfig: Codable, Equatable {
    let global: GlobalPermissions
    let projects: [String: ProjectPermissions]

    init(global: GlobalPermissions = GlobalPermissions(), projects: [String: ProjectPermissions] = [:]) {
        self.global = global
        self.projects = projects
    }
}

/// Global permission settings
struct GlobalPermissions: Codable, Equatable {
    let bypassAll: Bool
    let defaultMode: PermissionMode

    init(bypassAll: Bool = false, defaultMode: PermissionMode = .default) {
        self.bypassAll = bypassAll
        self.defaultMode = defaultMode
    }

    enum CodingKeys: String, CodingKey {
        case bypassAll = "bypass_all"
        case defaultMode = "default_mode"
    }
}

/// Project-specific permission settings
struct ProjectPermissions: Codable, Equatable {
    let permissionMode: PermissionMode?
    let bypassAll: Bool?
    let alwaysAllow: [String]?
    let alwaysDeny: [String]?

    init(
        permissionMode: PermissionMode? = nil,
        bypassAll: Bool? = nil,
        alwaysAllow: [String]? = nil,
        alwaysDeny: [String]? = nil
    ) {
        self.permissionMode = permissionMode
        self.bypassAll = bypassAll
        self.alwaysAllow = alwaysAllow
        self.alwaysDeny = alwaysDeny
    }

    enum CodingKeys: String, CodingKey {
        case permissionMode = "permission_mode"
        case bypassAll = "bypass_all"
        case alwaysAllow = "always_allow"
        case alwaysDeny = "always_deny"
    }
}

// MARK: - REST API Request Models (for PUT)

/// Update payload for PUT /permissions
struct PermissionConfigUpdate: Codable {
    var global: GlobalPermissionsUpdate?
    var projects: [String: ProjectPermissionsUpdate]?

    init(global: GlobalPermissionsUpdate? = nil, projects: [String: ProjectPermissionsUpdate]? = nil) {
        self.global = global
        self.projects = projects
    }
}

/// Global permissions update payload
struct GlobalPermissionsUpdate: Codable {
    var bypassAll: Bool?
    var defaultMode: PermissionMode?

    init(bypassAll: Bool? = nil, defaultMode: PermissionMode? = nil) {
        self.bypassAll = bypassAll
        self.defaultMode = defaultMode
    }

    enum CodingKeys: String, CodingKey {
        case bypassAll = "bypass_all"
        case defaultMode = "default_mode"
    }
}

/// Project permissions update payload
struct ProjectPermissionsUpdate: Codable {
    var permissionMode: PermissionMode?
    var bypassAll: Bool?
    var alwaysAllow: [String]?
    var alwaysDeny: [String]?

    init(
        permissionMode: PermissionMode? = nil,
        bypassAll: Bool? = nil,
        alwaysAllow: [String]? = nil,
        alwaysDeny: [String]? = nil
    ) {
        self.permissionMode = permissionMode
        self.bypassAll = bypassAll
        self.alwaysAllow = alwaysAllow
        self.alwaysDeny = alwaysDeny
    }

    enum CodingKeys: String, CodingKey {
        case permissionMode = "permission_mode"
        case bypassAll = "bypass_all"
        case alwaysAllow = "always_allow"
        case alwaysDeny = "always_deny"
    }
}

// MARK: - Permission Choice

/// User's response to a permission request
enum PermissionChoice: String, Codable {
    case allow
    case deny
    case always

    /// Convert to CLI choice for WebSocket response
    func toCLIChoice() -> CLIPermissionChoice {
        switch self {
        case .allow:
            return .allow
        case .deny:
            return .deny
        case .always:
            return .always
        }
    }
}

// MARK: - Tool Types for Permissions

/// Tools that are auto-approved in acceptEdits mode
let acceptEditsAutoApprovedTools: Set<String> = [
    "Read", "Write", "Edit", "Glob", "Grep", "LS"
]

/// Check if a tool is auto-approved for the given mode
func isToolAutoApproved(_ tool: String, mode: PermissionMode, alwaysAllow: [String]? = nil, alwaysDeny: [String]? = nil) -> Bool {
    // Check always_deny first (takes precedence)
    if let denyList = alwaysDeny, denyList.contains(tool) {
        return false
    }

    // Check always_allow
    if let allowList = alwaysAllow, allowList.contains(tool) {
        return true
    }

    // Check mode
    switch mode {
    case .bypassPermissions:
        return true
    case .acceptEdits:
        return acceptEditsAutoApprovedTools.contains(tool)
    case .default:
        return false
    }
}
