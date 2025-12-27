import Foundation
import SwiftUI

// Thinking mode - appends trigger words to prompts for extended thinking
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

    /// The suffix to append to messages (nil for normal mode)
    var promptSuffix: String? {
        switch self {
        case .normal: return nil
        case .think: return "think"
        case .thinkHard: return "think hard"
        case .thinkHarder: return "think harder"
        case .ultrathink: return "ultrathink"
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
// Note: bypassPermissions is now a separate toggle (skipPermissions) in AppSettings
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

class AppSettings: ObservableObject {
    // Server Configuration
    @AppStorage("serverURL") var serverURL: String = "http://10.0.3.2:8080"

    // Appearance Settings
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @AppStorage("fontSize") var fontSize: Int = 14

    // Claude Settings
    @AppStorage("claudeMode") private var claudeModeRaw: String = ClaudeMode.normal.rawValue
    @AppStorage("thinkingMode") private var thinkingModeRaw: String = ThinkingMode.normal.rawValue
    @AppStorage("skipPermissions") var skipPermissions: Bool = false
    @AppStorage("defaultModel") private var defaultModelRaw: String = ClaudeModel.sonnet.rawValue
    @AppStorage("customModelId") var customModelId: String = ""

    // Chat Display Settings
    @AppStorage("showThinkingBlocks") var showThinkingBlocks: Bool = true
    @AppStorage("autoScrollEnabled") var autoScrollEnabled: Bool = true

    // Project List Settings
    @AppStorage("projectSortOrder") private var projectSortOrderRaw: String = ProjectSortOrder.name.rawValue

    // Auth Settings (for claudecodeui backend)
    @AppStorage("authUsername") var authUsername: String = "admin"
    @AppStorage("authPassword") var authPassword: String = "claude123"
    @AppStorage("authToken") var authToken: String = ""
    @AppStorage("apiKey") var apiKey: String = ""  // API key for REST endpoints

    // SSH Settings
    @AppStorage("sshHost") var sshHost: String = "10.0.3.2"
    @AppStorage("sshPort") var sshPort: Int = 22
    @AppStorage("sshUsername") var sshUsername: String = ""
    @AppStorage("sshAuthMethod") private var sshAuthMethodRaw: String = SSHAuthType.password.rawValue
    @AppStorage("sshPassword") var sshPassword: String = ""

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

    /// Applies thinking mode suffix to a message if needed
    func applyThinkingMode(to message: String) -> String {
        guard let suffix = thinkingMode.promptSuffix else { return message }
        return "\(message) \(suffix)"
    }

    var defaultModel: ClaudeModel {
        get { ClaudeModel(rawValue: defaultModelRaw) ?? .sonnet }
        set { defaultModelRaw = newValue.rawValue }
    }

    var projectSortOrder: ProjectSortOrder {
        get { ProjectSortOrder(rawValue: projectSortOrderRaw) ?? .name }
        set { projectSortOrderRaw = newValue.rawValue }
    }

    var sshAuthType: SSHAuthType {
        get { SSHAuthType(rawValue: sshAuthMethodRaw) ?? .password }
        set { sshAuthMethodRaw = newValue.rawValue }
    }

    /// The effective permission mode to send to server
    /// If skipPermissions is enabled, always use bypassPermissions
    var effectivePermissionMode: String? {
        skipPermissions ? "bypassPermissions" : claudeMode.serverValue
    }

    var baseURL: URL? {
        URL(string: serverURL)
    }

    var webSocketURL: URL? {
        guard let base = baseURL else { return nil }
        let wsScheme = base.scheme == "https" ? "wss" : "ws"
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        components?.scheme = wsScheme
        components?.path = "/ws"
        if !authToken.isEmpty {
            components?.queryItems = [URLQueryItem(name: "token", value: authToken)]
        }
        return components?.url
    }

    // Derive SSH host from server URL if not set
    var effectiveSSHHost: String {
        if !sshHost.isEmpty {
            return sshHost
        }
        // Try to extract host from server URL
        if let url = URL(string: serverURL), let host = url.host {
            return host
        }
        return "10.0.3.2"
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
