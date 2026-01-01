import Foundation

/// Centralized access to app version information.
///
/// Version is defined in `Config/Version.xcconfig` and automatically
/// populated into Info.plist at build time.
///
/// Usage:
/// ```swift
/// Text("Version \(AppVersion.version)")
/// Text("Build \(AppVersion.build)")
/// Text(AppVersion.fullVersion)  // "0.6.6 (1)"
/// ```
enum AppVersion {
    /// Marketing version (e.g., "0.6.6")
    /// Maps to CFBundleShortVersionString / MARKETING_VERSION
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    /// Build number (e.g., "1")
    /// Maps to CFBundleVersion / CURRENT_PROJECT_VERSION
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    /// Full version string (e.g., "0.6.6 (1)")
    static var fullVersion: String {
        "\(version) (\(build))"
    }

    /// User agent string for API requests
    static var userAgent: String {
        "CodingBridge/\(version)"
    }
}
