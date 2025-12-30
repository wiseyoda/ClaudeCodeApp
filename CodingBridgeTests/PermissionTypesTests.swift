import SwiftUI
import UIKit
import XCTest
@testable import CodingBridge

final class PermissionTypesTests: XCTestCase {
    private enum TestError: Error {
        case invalidJSONObject
    }

    private func decodeJSON<T: Decodable>(_ json: String, as type: T.Type = T.self) throws -> T {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func encodeJSONObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dict = object as? [String: Any] else {
            throw TestError.invalidJSONObject
        }
        return dict
    }

    private func rgbaComponents(for color: UIColor) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return nil
        }
        return (r, g, b, a)
    }

    private func assertColor(_ color: Color, matches expected: Color, file: StaticString = #file, line: UInt = #line) {
        let trait = UITraitCollection(userInterfaceStyle: .light)
        let actualColor = UIColor(color).resolvedColor(with: trait)
        let expectedColor = UIColor(expected).resolvedColor(with: trait)

        guard let actual = rgbaComponents(for: actualColor),
              let expectedComponents = rgbaComponents(for: expectedColor) else {
            XCTFail("Unable to extract RGBA components", file: file, line: line)
            return
        }

        XCTAssertEqual(actual.r, expectedComponents.r, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actual.g, expectedComponents.g, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actual.b, expectedComponents.b, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actual.a, expectedComponents.a, accuracy: 0.001, file: file, line: line)
    }

    // MARK: - PermissionMode

    func test_permissionMode_allCases_containsExpectedCases() {
        XCTAssertEqual(PermissionMode.allCases, [.default, .acceptEdits, .bypassPermissions])
    }

    func test_permissionMode_displayName_returnsExpectedValues() {
        let cases: [(PermissionMode, String)] = [
            (.default, "Ask for Everything"),
            (.acceptEdits, "Auto-approve File Edits"),
            (.bypassPermissions, "Trust Everything")
        ]

        for (mode, expected) in cases {
            XCTAssertEqual(mode.displayName, expected)
        }
    }

    func test_permissionMode_shortDisplayName_returnsExpectedValues() {
        let cases: [(PermissionMode, String)] = [
            (.default, "Ask"),
            (.acceptEdits, "Edits OK"),
            (.bypassPermissions, "Bypass")
        ]

        for (mode, expected) in cases {
            XCTAssertEqual(mode.shortDisplayName, expected)
        }
    }

    func test_permissionMode_description_returnsExpectedValues() {
        let cases: [(PermissionMode, String)] = [
            (.default, "Claude will ask before using any tools"),
            (.acceptEdits, "Auto-approve Read, Write, Edit, Glob, Grep, LS"),
            (.bypassPermissions, "Never ask for permission (dangerous!)")
        ]

        for (mode, expected) in cases {
            XCTAssertEqual(mode.description, expected)
        }
    }

    func test_permissionMode_icon_returnsExpectedValues() {
        let cases: [(PermissionMode, String)] = [
            (.default, "lock.shield"),
            (.acceptEdits, "pencil.and.outline"),
            (.bypassPermissions, "lock.open")
        ]

        for (mode, expected) in cases {
            XCTAssertEqual(mode.icon, expected)
        }
    }

    func test_permissionMode_color_returnsExpectedValues() {
        let cases: [(PermissionMode, Color)] = [
            (.default, .blue),
            (.acceptEdits, .orange),
            (.bypassPermissions, .red)
        ]

        for (mode, expected) in cases {
            assertColor(mode.color, matches: expected)
        }
    }

    func test_permissionMode_isDangerous_flagsBypassOnly() {
        XCTAssertFalse(PermissionMode.default.isDangerous)
        XCTAssertFalse(PermissionMode.acceptEdits.isDangerous)
        XCTAssertTrue(PermissionMode.bypassPermissions.isDangerous)
    }

    func test_permissionMode_toCLIPermissionMode_matchesRawValues() {
        for mode in PermissionMode.allCases {
            XCTAssertEqual(mode.toCLIPermissionMode().rawValue, mode.rawValue)
        }
    }

    func test_permissionMode_initFromCLIPermissionMode_mapsCases() {
        let cases: [(CLISetPermissionModePayload.CLIPermissionMode, PermissionMode)] = [
            (.default, .default),
            (.acceptEdits, .acceptEdits),
            (.bypassPermissions, .bypassPermissions)
        ]

        for (cliMode, expected) in cases {
            XCTAssertEqual(PermissionMode(from: cliMode), expected)
        }
    }

    func test_permissionMode_codableRoundTrip_preservesValue() throws {
        for mode in PermissionMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(PermissionMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }

    // MARK: - PermissionConfig

    func test_permissionConfig_defaultInit_usesDefaults() {
        let config = PermissionConfig()

        XCTAssertEqual(config.global, GlobalPermissions())
        XCTAssertTrue(config.projects.isEmpty)
    }

    func test_permissionConfig_customInit_assignsValues() {
        let project = ProjectPermissions(permissionMode: .acceptEdits, bypassAll: true, alwaysAllow: ["Read"])
        let config = PermissionConfig(global: GlobalPermissions(bypassAll: true, defaultMode: .acceptEdits),
                                      projects: ["/tmp": project])

        XCTAssertEqual(config.global.bypassAll, true)
        XCTAssertEqual(config.global.defaultMode, .acceptEdits)
        XCTAssertEqual(config.projects["/tmp"], project)
    }

    func test_permissionConfig_codingKeys_encodesSnakeCase() throws {
        let project = ProjectPermissions(permissionMode: .bypassPermissions,
                                         bypassAll: false,
                                         alwaysAllow: ["Read"],
                                         alwaysDeny: ["Bash"])
        let config = PermissionConfig(global: GlobalPermissions(bypassAll: true, defaultMode: .acceptEdits),
                                      projects: ["/tmp": project])
        let encoded = try encodeJSONObject(config)

        let global = encoded["global"] as? [String: Any]
        XCTAssertEqual(global?["bypass_all"] as? Bool, true)
        XCTAssertEqual(global?["default_mode"] as? String, "acceptEdits")

        let projects = encoded["projects"] as? [String: Any]
        let projectDict = projects?["/tmp"] as? [String: Any]
        XCTAssertEqual(projectDict?["permission_mode"] as? String, "bypassPermissions")
        XCTAssertEqual(projectDict?["bypass_all"] as? Bool, false)
        XCTAssertEqual(projectDict?["always_allow"] as? [String], ["Read"])
        XCTAssertEqual(projectDict?["always_deny"] as? [String], ["Bash"])
    }

    func test_permissionConfig_decodingKeys_decodesSnakeCase() throws {
        let json = """
        {
          "global": {
            "bypass_all": true,
            "default_mode": "acceptEdits"
          },
          "projects": {
            "/tmp": {
              "permission_mode": "bypassPermissions",
              "bypass_all": false,
              "always_allow": ["Read"],
              "always_deny": ["Bash"]
            }
          }
        }
        """

        let config = try decodeJSON(json, as: PermissionConfig.self)

        XCTAssertEqual(config.global.bypassAll, true)
        XCTAssertEqual(config.global.defaultMode, .acceptEdits)
        XCTAssertEqual(config.projects["/tmp"]?.permissionMode, .bypassPermissions)
        XCTAssertEqual(config.projects["/tmp"]?.bypassAll, false)
        XCTAssertEqual(config.projects["/tmp"]?.alwaysAllow, ["Read"])
        XCTAssertEqual(config.projects["/tmp"]?.alwaysDeny, ["Bash"])
    }

    // MARK: - GlobalPermissions

    func test_globalPermissions_defaultInit_usesDefaults() {
        let permissions = GlobalPermissions()

        XCTAssertEqual(permissions.bypassAll, false)
        XCTAssertEqual(permissions.defaultMode, .default)
    }

    func test_globalPermissions_customInit_assignsValues() {
        let permissions = GlobalPermissions(bypassAll: true, defaultMode: .acceptEdits)

        XCTAssertEqual(permissions.bypassAll, true)
        XCTAssertEqual(permissions.defaultMode, .acceptEdits)
    }

    func test_globalPermissions_codingKeys_encodesSnakeCase() throws {
        let permissions = GlobalPermissions(bypassAll: true, defaultMode: .acceptEdits)
        let encoded = try encodeJSONObject(permissions)

        XCTAssertEqual(encoded["bypass_all"] as? Bool, true)
        XCTAssertEqual(encoded["default_mode"] as? String, "acceptEdits")
    }

    func test_globalPermissions_codingKeys_decodesSnakeCase() throws {
        let json = """
        {
          "bypass_all": true,
          "default_mode": "bypassPermissions"
        }
        """

        let permissions = try decodeJSON(json, as: GlobalPermissions.self)

        XCTAssertEqual(permissions.bypassAll, true)
        XCTAssertEqual(permissions.defaultMode, .bypassPermissions)
    }

    // MARK: - ProjectPermissions

    func test_projectPermissions_defaultInit_usesNilFields() {
        let permissions = ProjectPermissions()

        XCTAssertNil(permissions.permissionMode)
        XCTAssertNil(permissions.bypassAll)
        XCTAssertNil(permissions.alwaysAllow)
        XCTAssertNil(permissions.alwaysDeny)
    }

    func test_projectPermissions_customInit_assignsValues() {
        let permissions = ProjectPermissions(permissionMode: .acceptEdits,
                                            bypassAll: true,
                                            alwaysAllow: ["Read", "Edit"],
                                            alwaysDeny: ["Bash"])

        XCTAssertEqual(permissions.permissionMode, .acceptEdits)
        XCTAssertEqual(permissions.bypassAll, true)
        XCTAssertEqual(permissions.alwaysAllow, ["Read", "Edit"])
        XCTAssertEqual(permissions.alwaysDeny, ["Bash"])
    }

    func test_projectPermissions_decodesAllFields() throws {
        let json = """
        {
          "permission_mode": "acceptEdits",
          "bypass_all": true,
          "always_allow": ["Read", "Edit"],
          "always_deny": ["Bash"]
        }
        """

        let permissions = try decodeJSON(json, as: ProjectPermissions.self)

        XCTAssertEqual(permissions.permissionMode, .acceptEdits)
        XCTAssertEqual(permissions.bypassAll, true)
        XCTAssertEqual(permissions.alwaysAllow, ["Read", "Edit"])
        XCTAssertEqual(permissions.alwaysDeny, ["Bash"])
    }

    func test_projectPermissions_decodesMissingOptionalFields() throws {
        let json = """
        {
          "permission_mode": "default"
        }
        """

        let permissions = try decodeJSON(json, as: ProjectPermissions.self)

        XCTAssertEqual(permissions.permissionMode, .default)
        XCTAssertNil(permissions.bypassAll)
        XCTAssertNil(permissions.alwaysAllow)
        XCTAssertNil(permissions.alwaysDeny)
    }

    func test_projectPermissions_encodesSnakeCaseKeys() throws {
        let permissions = ProjectPermissions(permissionMode: .bypassPermissions,
                                             bypassAll: false,
                                             alwaysAllow: ["Read"],
                                             alwaysDeny: ["Bash"])
        let encoded = try encodeJSONObject(permissions)

        XCTAssertEqual(encoded["permission_mode"] as? String, "bypassPermissions")
        XCTAssertEqual(encoded["bypass_all"] as? Bool, false)
        XCTAssertEqual(encoded["always_allow"] as? [String], ["Read"])
        XCTAssertEqual(encoded["always_deny"] as? [String], ["Bash"])
    }

    // MARK: - PermissionConfigUpdate

    func test_permissionConfigUpdate_defaultInit_isEmpty() throws {
        let update = PermissionConfigUpdate()
        let encoded = try encodeJSONObject(update)

        XCTAssertTrue(encoded.isEmpty)
    }

    func test_permissionConfigUpdate_encodesGlobalOnly() throws {
        let update = PermissionConfigUpdate(global: GlobalPermissionsUpdate(bypassAll: true, defaultMode: .acceptEdits))
        let encoded = try encodeJSONObject(update)

        XCTAssertNotNil(encoded["global"])
        XCTAssertNil(encoded["projects"])

        let global = encoded["global"] as? [String: Any]
        XCTAssertEqual(global?["bypass_all"] as? Bool, true)
        XCTAssertEqual(global?["default_mode"] as? String, "acceptEdits")
    }

    func test_permissionConfigUpdate_encodesProjectsOnly() throws {
        let projectUpdate = ProjectPermissionsUpdate(permissionMode: .acceptEdits, alwaysAllow: ["Read"])
        let update = PermissionConfigUpdate(projects: ["/tmp": projectUpdate])
        let encoded = try encodeJSONObject(update)

        XCTAssertNil(encoded["global"])
        let projects = encoded["projects"] as? [String: Any]
        let project = projects?["/tmp"] as? [String: Any]
        XCTAssertEqual(project?["permission_mode"] as? String, "acceptEdits")
        XCTAssertEqual(project?["always_allow"] as? [String], ["Read"])
    }

    func test_permissionConfigUpdate_encodesGlobalAndProjects() throws {
        let globalUpdate = GlobalPermissionsUpdate(bypassAll: true, defaultMode: .bypassPermissions)
        let projectUpdate = ProjectPermissionsUpdate(bypassAll: false, alwaysDeny: ["Bash"])
        let update = PermissionConfigUpdate(global: globalUpdate, projects: ["/tmp": projectUpdate])
        let encoded = try encodeJSONObject(update)

        XCTAssertNotNil(encoded["global"])
        XCTAssertNotNil(encoded["projects"])
        let global = encoded["global"] as? [String: Any]
        XCTAssertEqual(global?["default_mode"] as? String, "bypassPermissions")
        let projects = encoded["projects"] as? [String: Any]
        let project = projects?["/tmp"] as? [String: Any]
        XCTAssertEqual(project?["always_deny"] as? [String], ["Bash"])
    }

    // MARK: - GlobalPermissionsUpdate

    func test_globalPermissionsUpdate_defaultInit_isEmpty() throws {
        let update = GlobalPermissionsUpdate()
        let encoded = try encodeJSONObject(update)

        XCTAssertTrue(encoded.isEmpty)
    }

    func test_globalPermissionsUpdate_encodesSnakeCaseKeys() throws {
        let update = GlobalPermissionsUpdate(bypassAll: true, defaultMode: .acceptEdits)
        let encoded = try encodeJSONObject(update)

        XCTAssertEqual(encoded["bypass_all"] as? Bool, true)
        XCTAssertEqual(encoded["default_mode"] as? String, "acceptEdits")
    }

    func test_globalPermissionsUpdate_decodesSnakeCaseKeys() throws {
        let json = """
        {
          "bypass_all": true,
          "default_mode": "default"
        }
        """

        let update = try decodeJSON(json, as: GlobalPermissionsUpdate.self)

        XCTAssertEqual(update.bypassAll, true)
        XCTAssertEqual(update.defaultMode, .default)
    }

    // MARK: - ProjectPermissionsUpdate

    func test_projectPermissionsUpdate_defaultInit_isEmpty() throws {
        let update = ProjectPermissionsUpdate()
        let encoded = try encodeJSONObject(update)

        XCTAssertTrue(encoded.isEmpty)
    }

    func test_projectPermissionsUpdate_encodesSnakeCaseKeys() throws {
        let update = ProjectPermissionsUpdate(permissionMode: .acceptEdits,
                                             bypassAll: true,
                                             alwaysAllow: ["Read"],
                                             alwaysDeny: ["Bash"])
        let encoded = try encodeJSONObject(update)

        XCTAssertEqual(encoded["permission_mode"] as? String, "acceptEdits")
        XCTAssertEqual(encoded["bypass_all"] as? Bool, true)
        XCTAssertEqual(encoded["always_allow"] as? [String], ["Read"])
        XCTAssertEqual(encoded["always_deny"] as? [String], ["Bash"])
    }

    func test_projectPermissionsUpdate_decodesSnakeCaseKeys() throws {
        let json = """
        {
          "permission_mode": "bypassPermissions",
          "bypass_all": false,
          "always_allow": ["Read"],
          "always_deny": ["Bash"]
        }
        """

        let update = try decodeJSON(json, as: ProjectPermissionsUpdate.self)

        XCTAssertEqual(update.permissionMode, .bypassPermissions)
        XCTAssertEqual(update.bypassAll, false)
        XCTAssertEqual(update.alwaysAllow, ["Read"])
        XCTAssertEqual(update.alwaysDeny, ["Bash"])
    }

    // MARK: - PermissionChoice

    func test_permissionChoice_toCLIChoice_mapsCases() {
        let cases: [(PermissionChoice, String)] = [
            (.allow, "allow"),
            (.deny, "deny"),
            (.always, "always")
        ]

        for (choice, expected) in cases {
            XCTAssertEqual(choice.toCLIChoice().rawValue, expected)
        }
    }

    func test_permissionChoice_codableRoundTrip_preservesRawValue() throws {
        let choices: [PermissionChoice] = [.allow, .deny, .always]

        for choice in choices {
            let data = try JSONEncoder().encode(choice)
            let decoded = try JSONDecoder().decode(PermissionChoice.self, from: data)
            XCTAssertEqual(decoded.rawValue, choice.rawValue)
        }
    }

    // MARK: - Auto Approval Tools

    func test_acceptEditsAutoApprovedTools_containsExpectedTools() {
        let expected: Set<String> = ["Read", "Write", "Edit", "Glob", "Grep", "LS"]
        XCTAssertEqual(acceptEditsAutoApprovedTools, expected)
    }

    // MARK: - isToolAutoApproved

    func test_isToolAutoApproved_defaultMode_deniesTool() {
        XCTAssertFalse(isToolAutoApproved("Read", mode: .default))
    }

    func test_isToolAutoApproved_acceptEdits_allowsAutoApprovedTool() {
        XCTAssertTrue(isToolAutoApproved("Read", mode: .acceptEdits))
    }

    func test_isToolAutoApproved_acceptEdits_deniesUnknownTool() {
        XCTAssertFalse(isToolAutoApproved("Bash", mode: .acceptEdits))
    }

    func test_isToolAutoApproved_bypassPermissions_allowsAnyTool() {
        XCTAssertTrue(isToolAutoApproved("Bash", mode: .bypassPermissions))
    }

    func test_isToolAutoApproved_alwaysAllow_overridesDefault() {
        XCTAssertTrue(isToolAutoApproved("Bash", mode: .default, alwaysAllow: ["Bash"]))
    }

    func test_isToolAutoApproved_alwaysAllow_overridesAcceptEdits() {
        XCTAssertTrue(isToolAutoApproved("Bash", mode: .acceptEdits, alwaysAllow: ["Bash"]))
    }

    func test_isToolAutoApproved_alwaysDeny_overridesAlwaysAllow() {
        XCTAssertFalse(isToolAutoApproved("Read", mode: .acceptEdits, alwaysAllow: ["Read"], alwaysDeny: ["Read"]))
    }

    func test_isToolAutoApproved_alwaysDeny_overridesBypassPermissions() {
        XCTAssertFalse(isToolAutoApproved("Bash", mode: .bypassPermissions, alwaysDeny: ["Bash"]))
    }

    func test_isToolAutoApproved_alwaysDeny_overridesAcceptEdits() {
        XCTAssertFalse(isToolAutoApproved("Read", mode: .acceptEdits, alwaysDeny: ["Read"]))
    }

    func test_isToolAutoApproved_alwaysAllow_requiresMatchingTool() {
        XCTAssertFalse(isToolAutoApproved("Read", mode: .default, alwaysAllow: ["Bash"]))
    }
}
