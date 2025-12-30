import Foundation
import SwiftUI

// Thinking mode - sent to server via thinkingMode field in input messages
enum ThinkingMode: String, CaseIterable {
    case normal = "normal"
    case think = "think"
    case thinkHard = "think_hard"
    case thinkHarder = "think_harder"
    case ultrathink = "ultrathink"

    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .think: return "Think"
        case .thinkHard: return "Think Hard"
        case .thinkHarder: return "Think Harder"
        case .ultrathink: return "Ultrathink"
        }
    }

    /// Short name for compact UI (status bar pills)
    var shortDisplayName: String {
        switch self {
        case .normal: return "Normal"
        case .think: return "Think"
        case .thinkHard: return "Hard"
        case .thinkHarder: return "Harder"
        case .ultrathink: return "Ultra"
        }
    }

    var icon: String {
        switch self {
        case .normal: return "bolt"
        case .think: return "brain"
        case .thinkHard: return "brain.head.profile"
        case .thinkHarder: return "brain.head.profile.fill"
        case .ultrathink: return "sparkles"
        }
    }

    var color: Color {
        switch self {
        case .normal: return Color(white: 0.6)
        case .think: return Color(red: 0.6, green: 0.4, blue: 0.8)  // Light purple
        case .thinkHard: return Color(red: 0.7, green: 0.3, blue: 0.9)  // Purple
        case .thinkHarder: return Color(red: 0.8, green: 0.2, blue: 1.0)  // Bright purple
        case .ultrathink: return Color(red: 1.0, green: 0.4, blue: 0.8)  // Pink/magenta
        }
    }

    func next() -> ThinkingMode {
        let all = ThinkingMode.allCases
        guard let idx = all.firstIndex(of: self) else { return .normal }
        let nextIdx = (idx + 1) % all.count
        return all[nextIdx]
    }
}

// Claude Code modes - values must match server expectations
enum ClaudeMode: String, CaseIterable {
    case normal = "default"
    case plan = "plan"

    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .plan: return "Plan"
        }
    }

    var description: String {
        switch self {
        case .normal: return "Execute tasks directly"
        case .plan: return "Plan before executing"
        }
    }

    /// The value to send to the server (nil for default mode)
    var serverValue: String? {
        switch self {
        case .normal: return nil  // Server treats nil/default as normal
        case .plan: return "plan"
        }
    }

    var icon: String {
        switch self {
        case .normal: return "wrench"
        case .plan: return "doc.text"
        }
    }

    var color: Color {
        switch self {
        case .normal: return Color(white: 0.6)  // Secondary text color
        case .plan: return Color(red: 0.4, green: 0.8, blue: 0.9)  // Cyan
        }
    }

    func next() -> ClaudeMode {
        self == .normal ? .plan : .normal
    }
}

// Theme preference
enum AppTheme: String, CaseIterable {
    case system = "system"
    case dark = "dark"
    case light = "light"

    var displayName: String {
        switch self {
        case .system: return "System"
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil  // Follow system
        case .dark: return .dark
        case .light: return .light
        }
    }
}

// Project sort order
enum ProjectSortOrder: String, CaseIterable {
    case name = "name"
    case date = "date"

    var displayName: String {
        switch self {
        case .name: return "Name (A-Z)"
        case .date: return "Recent Activity"
        }
    }
}

// Note: PermissionMode enum is defined in PermissionTypes.swift

// Font size preset
enum FontSizePreset: Int, CaseIterable {
    case extraSmall = 10
    case small = 12
    case medium = 14
    case large = 16
    case extraLarge = 18

    var displayName: String {
        switch self {
        case .extraSmall: return "XS"
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        case .extraLarge: return "XL"
        }
    }
}

// History limit (messages per project)
enum HistoryLimit: Int, CaseIterable {
    case small = 25
    case medium = 50
    case large = 100
    case extraLarge = 200

    var displayName: String {
        switch self {
        case .small: return "25"
        case .medium: return "50"
        case .large: return "100"
        case .extraLarge: return "200"
        }
    }
}

@MainActor
class AppSettings: ObservableObject {
    // Server Configuration
    @AppStorage("serverURL") var serverURL: String = "http://localhost:3100"

    // Appearance Settings
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @AppStorage("fontSize") var fontSize: Int = 14

    // Claude Settings
    @AppStorage("claudeMode") private var claudeModeRaw: String = ClaudeMode.normal.rawValue
    @AppStorage("thinkingMode") private var thinkingModeRaw: String = ThinkingMode.normal.rawValue
    @AppStorage("defaultModel") private var defaultModelRaw: String = ClaudeModel.sonnet.rawValue

    // Permission Settings
    @AppStorage("globalPermissionMode") private var globalPermissionModeRaw: String = PermissionMode.default.rawValue
    @AppStorage("customModelId") var customModelId: String = ""

    // Chat Display Settings
    @AppStorage("showThinkingBlocks") var showThinkingBlocks: Bool = true
    @AppStorage("autoScrollEnabled") var autoScrollEnabled: Bool = true
    @AppStorage("historyLimit") private var historyLimitRaw: Int = HistoryLimit.medium.rawValue
    @AppStorage("lockToPortrait") var lockToPortrait: Bool = true  // Lock to portrait mode by default

    // Debug Settings
    @AppStorage("debugLoggingEnabled") var debugLoggingEnabled: Bool = false

    // Processing timeout in seconds (how long to wait for Claude response)
    // Default 5 minutes - long-running operations like code review can take time
    @AppStorage("processingTimeout") var processingTimeout: Int = 300

    // MARK: - Background & Notifications

    /// Master toggle for push notifications feature (default: false - experimental)
    /// When disabled, all push notification functionality is inactive
    @AppStorage("enablePushNotifications") var enablePushNotifications: Bool = false

    /// Enable background notifications when app not in foreground (default: true)
    @AppStorage("enableBackgroundNotifications") var enableBackgroundNotifications: Bool = true

    /// Show detailed content in notifications visible on Lock Screen (default: false)
    /// When false, shows generic "Claude needs attention" instead of command details
    @AppStorage("showNotificationDetails") var showNotificationDetails: Bool = false

    /// Continue background processing in Low Power Mode (default: false)
    @AppStorage("backgroundInLowPowerMode") var backgroundInLowPowerMode: Bool = false

    /// Enable time-sensitive notifications that break through Focus modes (default: true)
    @AppStorage("enableTimeSensitiveNotifications") var enableTimeSensitiveNotifications: Bool = true

    /// Enable Live Activities for task progress (default: true, Phase 2)
    @AppStorage("enableLiveActivities") var enableLiveActivities: Bool = true

    // Project List Settings
    @AppStorage("projectSortOrder") private var projectSortOrderRaw: String = ProjectSortOrder.name.rawValue

    // Auth Settings (for cli-bridge server)
    @AppStorage("authUsername") var authUsername: String = ""
    // Auth credentials are stored in Keychain for security - see computed properties below
    @Published private var _authPasswordCache: String?
    @Published private var _authTokenCache: String?
    @Published private var _apiKeyCache: String?

    // SSH Settings
    // Default to empty - SSH is optional when using cli-bridge locally
    @AppStorage("sshHost") var sshHost: String = ""
    @AppStorage("sshPort") var sshPort: Int = 22
    @AppStorage("sshUsername") var sshUsername: String = "dev"
    @AppStorage("sshAuthMethod") private var sshAuthMethodRaw: String = SSHAuthType.password.rawValue
    // SSH password is stored in Keychain for security - see sshPassword computed property below
    @Published private var _sshPasswordCache: String?

    // MARK: - Initialization

    init() {
        // Migrate credentials from UserDefaults to Keychain on first launch after update
        migrateSSHPasswordIfNeeded()
        migrateAuthCredentialsIfNeeded()
    }

    // MARK: - Computed Properties

    var appTheme: AppTheme {
        get { AppTheme(rawValue: appThemeRaw) ?? .system }
        set { appThemeRaw = newValue.rawValue }
    }

    var claudeMode: ClaudeMode {
        get { ClaudeMode(rawValue: claudeModeRaw) ?? .normal }
        set { claudeModeRaw = newValue.rawValue }
    }

    var thinkingMode: ThinkingMode {
        get { ThinkingMode(rawValue: thinkingModeRaw) ?? .normal }
        set { thinkingModeRaw = newValue.rawValue }
    }

    var defaultModel: ClaudeModel {
        get { ClaudeModel(rawValue: defaultModelRaw) ?? .sonnet }
        set { defaultModelRaw = newValue.rawValue }
    }

    var projectSortOrder: ProjectSortOrder {
        get { ProjectSortOrder(rawValue: projectSortOrderRaw) ?? .name }
        set { projectSortOrderRaw = newValue.rawValue }
    }

    var historyLimit: HistoryLimit {
        get { HistoryLimit(rawValue: historyLimitRaw) ?? .medium }
        set { historyLimitRaw = newValue.rawValue }
    }

    /// Global permission mode
    var globalPermissionMode: PermissionMode {
        get { PermissionMode(rawValue: globalPermissionModeRaw) ?? .default }
        set { globalPermissionModeRaw = newValue.rawValue }
    }

    var sshAuthType: SSHAuthType {
        get { SSHAuthType(rawValue: sshAuthMethodRaw) ?? .password }
        set { sshAuthMethodRaw = newValue.rawValue }
    }

    /// SSH password stored securely in Keychain
    var sshPassword: String {
        get {
            // Use cache if available
            if let cached = _sshPasswordCache {
                return cached
            }
            // Otherwise retrieve from Keychain
            let password = KeychainHelper.shared.retrieveSSHPassword() ?? ""
            _sshPasswordCache = password
            return password
        }
        set {
            _sshPasswordCache = newValue
            KeychainHelper.shared.storeSSHPassword(newValue)
        }
    }

    /// Migrate SSH password from UserDefaults to Keychain if needed
    func migrateSSHPasswordIfNeeded() {
        // Check if there's a password in old UserDefaults location
        let oldKey = "sshPassword"
        if let oldPassword = UserDefaults.standard.string(forKey: oldKey), !oldPassword.isEmpty {
            // Migrate to Keychain
            if KeychainHelper.shared.storeSSHPassword(oldPassword) {
                // Remove from UserDefaults after successful migration
                UserDefaults.standard.removeObject(forKey: oldKey)
                _sshPasswordCache = oldPassword
            }
        }
    }

    // MARK: - Auth Credentials (Keychain-backed)

    /// Auth password stored securely in Keychain
    var authPassword: String {
        get {
            if let cached = _authPasswordCache {
                return cached
            }
            let password = KeychainHelper.shared.retrieveAuthPassword() ?? ""
            _authPasswordCache = password
            return password
        }
        set {
            _authPasswordCache = newValue
            KeychainHelper.shared.storeAuthPassword(newValue)
        }
    }

    /// Auth token (JWT) stored securely in Keychain
    var authToken: String {
        get {
            if let cached = _authTokenCache {
                return cached
            }
            let token = KeychainHelper.shared.retrieveAuthToken() ?? ""
            _authTokenCache = token
            return token
        }
        set {
            _authTokenCache = newValue
            KeychainHelper.shared.storeAuthToken(newValue)
        }
    }

    /// API key stored securely in Keychain
    var apiKey: String {
        get {
            if let cached = _apiKeyCache {
                return cached
            }
            let key = KeychainHelper.shared.retrieveAPIKey() ?? ""
            _apiKeyCache = key
            return key
        }
        set {
            _apiKeyCache = newValue
            KeychainHelper.shared.storeAPIKey(newValue)
        }
    }

    /// Migrate auth credentials from UserDefaults to Keychain if needed
    func migrateAuthCredentialsIfNeeded() {
        // Migrate authPassword
        let passwordKey = "authPassword"
        if let oldPassword = UserDefaults.standard.string(forKey: passwordKey), !oldPassword.isEmpty {
            if KeychainHelper.shared.storeAuthPassword(oldPassword) {
                UserDefaults.standard.removeObject(forKey: passwordKey)
                _authPasswordCache = oldPassword
            }
        }

        // Migrate authToken
        let tokenKey = "authToken"
        if let oldToken = UserDefaults.standard.string(forKey: tokenKey), !oldToken.isEmpty {
            if KeychainHelper.shared.storeAuthToken(oldToken) {
                UserDefaults.standard.removeObject(forKey: tokenKey)
                _authTokenCache = oldToken
            }
        }

        // Migrate apiKey
        let apiKeyKey = "apiKey"
        if let oldKey = UserDefaults.standard.string(forKey: apiKeyKey), !oldKey.isEmpty {
            if KeychainHelper.shared.storeAPIKey(oldKey) {
                UserDefaults.standard.removeObject(forKey: apiKeyKey)
                _apiKeyCache = oldKey
            }
        }
    }

    /// The effective permission mode to send to server
    /// Returns the global permission mode as a string for server communication
    var effectivePermissionMode: String {
        globalPermissionMode.rawValue
    }

    var baseURL: URL? {
        URL(string: serverURL)
    }

    // Derive SSH host from server URL if not set
    // Returns empty string if SSH is not configured (disables SSH features)
    var effectiveSSHHost: String {
        if !sshHost.isEmpty {
            return sshHost
        }
        // When SSH host is empty, SSH features are disabled
        // cli-bridge provides git status and file browsing via REST API
        return ""
    }

    /// True if SSH is configured and can be used
    var isSSHConfigured: Bool {
        !effectiveSSHHost.isEmpty && effectiveSSHHost != "localhost" && effectiveSSHHost != "127.0.0.1"
    }

    // Font size scaling
    enum FontStyle {
        case small
        case body
        case large
    }

    func scaledFont(_ style: FontStyle) -> Font {
        let baseSize = CGFloat(fontSize)
        switch style {
        case .small:
            return .system(size: baseSize - 2, design: .monospaced)
        case .body:
            return .system(size: baseSize, design: .monospaced)
        case .large:
            return .system(size: baseSize + 2, design: .monospaced)
        }
    }
}

// SSH Authentication type
enum SSHAuthType: String, CaseIterable {
    case password = "password"
    case publicKey = "publicKey"

    var displayName: String {
        switch self {
        case .password: return "Password"
        case .publicKey: return "SSH Key"
        }
    }
}
