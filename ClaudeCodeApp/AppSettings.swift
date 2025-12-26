import Foundation
import SwiftUI

// Claude Code modes
enum ClaudeMode: String, CaseIterable {
    case normal = "normal"
    case plan = "plan"
    case bypassPermissions = "bypass-permissions"

    var displayName: String {
        switch self {
        case .normal: return "normal mode"
        case .plan: return "plan mode"
        case .bypassPermissions: return "bypass permissions"
        }
    }

    var icon: String {
        switch self {
        case .normal: return "wrench"
        case .plan: return "doc.text"
        case .bypassPermissions: return "bolt"
        }
    }

    var color: Color {
        switch self {
        case .normal: return CLITheme.secondaryText
        case .plan: return CLITheme.cyan
        case .bypassPermissions: return CLITheme.orange
        }
    }

    func next() -> ClaudeMode {
        let modes = ClaudeMode.allCases
        guard let currentIndex = modes.firstIndex(of: self) else { return .normal }
        let nextIndex = (currentIndex + 1) % modes.count
        return modes[nextIndex]
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
    @AppStorage("serverURL") var serverURL: String = "http://10.0.3.2:8080"
    @AppStorage("fontSize") var fontSize: Int = 14
    @AppStorage("claudeMode") private var claudeModeRaw: String = ClaudeMode.normal.rawValue

    // SSH Settings
    @AppStorage("sshHost") var sshHost: String = "10.0.3.2"
    @AppStorage("sshPort") var sshPort: Int = 22
    @AppStorage("sshUsername") var sshUsername: String = ""
    @AppStorage("sshAuthMethod") private var sshAuthMethodRaw: String = SSHAuthType.password.rawValue

    // Note: Password is stored in Keychain in production, using UserDefaults for simplicity here
    @AppStorage("sshPassword") var sshPassword: String = ""

    var claudeMode: ClaudeMode {
        get { ClaudeMode(rawValue: claudeModeRaw) ?? .normal }
        set { claudeModeRaw = newValue.rawValue }
    }

    var sshAuthType: SSHAuthType {
        get { SSHAuthType(rawValue: sshAuthMethodRaw) ?? .password }
        set { sshAuthMethodRaw = newValue.rawValue }
    }

    var baseURL: URL? {
        URL(string: serverURL)
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
