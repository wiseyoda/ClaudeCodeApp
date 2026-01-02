import XCTest
import SwiftUI
@testable import CodingBridge

@MainActor
final class AppSettingsTests: XCTestCase {

    // MARK: - ThinkingMode Tests

    func test_thinkingMode_displayName_returnsCorrectNames() {
        XCTAssertEqual(ThinkingMode.normal.displayName, "Normal")
        XCTAssertEqual(ThinkingMode.think.displayName, "Think")
        XCTAssertEqual(ThinkingMode.thinkHard.displayName, "Think Hard")
        XCTAssertEqual(ThinkingMode.thinkHarder.displayName, "Think Harder")
        XCTAssertEqual(ThinkingMode.ultrathink.displayName, "Ultrathink")
    }

    func test_thinkingMode_shortDisplayName_returnsCompactNames() {
        XCTAssertEqual(ThinkingMode.normal.shortDisplayName, "Normal")
        XCTAssertEqual(ThinkingMode.think.shortDisplayName, "Think")
        XCTAssertEqual(ThinkingMode.thinkHard.shortDisplayName, "Hard")
        XCTAssertEqual(ThinkingMode.thinkHarder.shortDisplayName, "Harder")
        XCTAssertEqual(ThinkingMode.ultrathink.shortDisplayName, "Ultra")
    }

    func test_thinkingMode_icon_returnsValidSFSymbols() {
        XCTAssertEqual(ThinkingMode.normal.icon, "bolt")
        XCTAssertEqual(ThinkingMode.think.icon, "brain")
        XCTAssertEqual(ThinkingMode.thinkHard.icon, "brain.head.profile")
        XCTAssertEqual(ThinkingMode.thinkHarder.icon, "brain.head.profile.fill")
        XCTAssertEqual(ThinkingMode.ultrathink.icon, "sparkles")
    }

    func test_thinkingMode_next_cyclesThroughAllModes() {
        var mode = ThinkingMode.normal
        let expectedSequence: [ThinkingMode] = [.think, .thinkHard, .thinkHarder, .ultrathink, .normal]

        for expected in expectedSequence {
            mode = mode.next()
            XCTAssertEqual(mode, expected)
        }
    }

    // MARK: - ClaudeMode Tests

    func test_claudeMode_displayName_returnsCorrectNames() {
        XCTAssertEqual(ClaudeMode.normal.displayName, "Normal")
        XCTAssertEqual(ClaudeMode.plan.displayName, "Plan")
    }

    func test_claudeMode_description_returnsCorrectDescriptions() {
        XCTAssertEqual(ClaudeMode.normal.description, "Execute tasks directly")
        XCTAssertEqual(ClaudeMode.plan.description, "Plan before executing")
    }

    func test_claudeMode_serverValue_returnsNilForNormal() {
        XCTAssertNil(ClaudeMode.normal.serverValue)
    }

    func test_claudeMode_serverValue_returnsPlanForPlanMode() {
        XCTAssertEqual(ClaudeMode.plan.serverValue, "plan")
    }

    func test_claudeMode_icon_returnsValidSFSymbols() {
        XCTAssertEqual(ClaudeMode.normal.icon, "wrench")
        XCTAssertEqual(ClaudeMode.plan.icon, "doc.text")
    }

    func test_claudeMode_next_togglesBetweenModes() {
        XCTAssertEqual(ClaudeMode.normal.next(), .plan)
        XCTAssertEqual(ClaudeMode.plan.next(), .normal)
    }

    // MARK: - AppTheme Tests

    func test_appTheme_displayName_returnsCorrectNames() {
        XCTAssertEqual(AppTheme.system.displayName, "System")
        XCTAssertEqual(AppTheme.dark.displayName, "Dark")
        XCTAssertEqual(AppTheme.light.displayName, "Light")
    }

    func test_appTheme_colorScheme_returnsNilForSystem() {
        XCTAssertNil(AppTheme.system.colorScheme)
    }

    func test_appTheme_colorScheme_returnsDarkForDark() {
        XCTAssertEqual(AppTheme.dark.colorScheme, .dark)
    }

    func test_appTheme_colorScheme_returnsLightForLight() {
        XCTAssertEqual(AppTheme.light.colorScheme, .light)
    }

    // MARK: - ProjectSortOrder Tests

    func test_projectSortOrder_displayName_returnsCorrectNames() {
        XCTAssertEqual(ProjectSortOrder.name.displayName, "Name (A-Z)")
        XCTAssertEqual(ProjectSortOrder.date.displayName, "Recent Activity")
    }

    // MARK: - FontSizePreset Tests

    func test_fontSizePreset_rawValues_areCorrect() {
        XCTAssertEqual(FontSizePreset.extraSmall.rawValue, 10)
        XCTAssertEqual(FontSizePreset.small.rawValue, 12)
        XCTAssertEqual(FontSizePreset.medium.rawValue, 14)
        XCTAssertEqual(FontSizePreset.large.rawValue, 16)
        XCTAssertEqual(FontSizePreset.extraLarge.rawValue, 18)
    }

    func test_fontSizePreset_displayName_returnsShortNames() {
        XCTAssertEqual(FontSizePreset.extraSmall.displayName, "XS")
        XCTAssertEqual(FontSizePreset.small.displayName, "S")
        XCTAssertEqual(FontSizePreset.medium.displayName, "M")
        XCTAssertEqual(FontSizePreset.large.displayName, "L")
        XCTAssertEqual(FontSizePreset.extraLarge.displayName, "XL")
    }

    // MARK: - SSHAuthType Tests

    func test_sshAuthType_displayName_returnsCorrectNames() {
        XCTAssertEqual(SSHAuthType.password.displayName, "Password")
        XCTAssertEqual(SSHAuthType.publicKey.displayName, "SSH Key")
    }

    func test_sshAuthType_rawValues_areCorrect() {
        XCTAssertEqual(SSHAuthType.password.rawValue, "password")
        XCTAssertEqual(SSHAuthType.publicKey.rawValue, "publicKey")
    }

    // MARK: - AppSettings URL Construction Tests

    func test_baseURL_parsesValidHTTPURL() {
        let settings = AppSettings()
        settings.serverURL = "http://localhost:8080"

        XCTAssertNotNil(settings.baseURL)
        XCTAssertEqual(settings.baseURL?.scheme, "http")
        XCTAssertEqual(settings.baseURL?.host, "localhost")
        XCTAssertEqual(settings.baseURL?.port, 8080)
    }

    func test_baseURL_parsesValidHTTPSURL() {
        let settings = AppSettings()
        settings.serverURL = "https://example.com"

        XCTAssertNotNil(settings.baseURL)
        XCTAssertEqual(settings.baseURL?.scheme, "https")
        XCTAssertEqual(settings.baseURL?.host, "example.com")
    }

    // MARK: - Effective SSH Host Tests

    func test_effectiveSSHHost_returnsConfiguredHostWhenSet() {
        let settings = AppSettings()
        settings.sshHost = "192.168.1.100"

        XCTAssertEqual(settings.effectiveSSHHost, "192.168.1.100")
    }

    func test_effectiveSSHHost_returnsEmptyWhenSSHHostEmpty() {
        let settings = AppSettings()
        settings.sshHost = ""
        settings.serverURL = "http://example.com:8080"

        // SSH features disabled when sshHost is empty (cli-bridge provides git/file ops via REST)
        XCTAssertEqual(settings.effectiveSSHHost, "")
    }

    func test_effectiveSSHHost_returnsEmptyWhenBothEmpty() {
        let settings = AppSettings()
        settings.sshHost = ""
        settings.serverURL = ""

        // SSH features disabled when not configured
        XCTAssertEqual(settings.effectiveSSHHost, "")
    }

    // MARK: - Global Permission Mode Tests

    func test_globalPermissionMode_bypassSerializesCorrectly() {
        let settings = AppSettings()
        settings.globalPermissionMode = .bypassPermissions

        XCTAssertEqual(settings.globalPermissionMode.rawValue, "bypassPermissions")
    }

    func test_globalPermissionMode_defaultSerializesCorrectly() {
        let settings = AppSettings()
        settings.globalPermissionMode = .default

        XCTAssertEqual(settings.globalPermissionMode.rawValue, "default")
    }

    func test_globalPermissionMode_acceptEditsSerializesCorrectly() {
        let settings = AppSettings()
        settings.globalPermissionMode = .acceptEdits

        XCTAssertEqual(settings.globalPermissionMode.rawValue, "acceptEdits")
    }

    // MARK: - Push Notification Settings Tests

    func test_enablePushNotifications_defaultsToFalse() {
        let settings = AppSettings()
        // Push notifications should be OFF by default (experimental feature)
        XCTAssertFalse(settings.enablePushNotifications)
    }

    func test_enableBackgroundNotifications_defaultsToTrue() {
        let settings = AppSettings()
        XCTAssertTrue(settings.enableBackgroundNotifications)
    }

    func test_enableLiveActivities_defaultsToTrue() {
        let settings = AppSettings()
        XCTAssertTrue(settings.enableLiveActivities)
    }

    func test_enableTimeSensitiveNotifications_defaultsToTrue() {
        let settings = AppSettings()
        XCTAssertTrue(settings.enableTimeSensitiveNotifications)
    }

    func test_showNotificationDetails_defaultsToFalse() {
        let settings = AppSettings()
        // Notification details are hidden by default for privacy
        XCTAssertFalse(settings.showNotificationDetails)
    }
}
