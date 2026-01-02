import Foundation
import SwiftUI

// MARK: - Claude Model Selection

/// Available Claude models for the app
enum ClaudeModel: String, CaseIterable, Identifiable, Codable {
    case opus = "opus"
    case sonnet = "sonnet"
    case haiku = "haiku"
    case custom = "custom"

    var id: String { rawValue }

    /// Display name shown in UI
    var displayName: String {
        switch self {
        case .opus: return "Opus 4.5"
        case .sonnet: return "Sonnet 4.5"
        case .haiku: return "Haiku 4.5"
        case .custom: return "Custom"
        }
    }

    /// Short label for nav bar pill
    var shortName: String {
        switch self {
        case .opus: return "Opus"
        case .sonnet: return "Sonnet"
        case .haiku: return "Haiku"
        case .custom: return "Custom"
        }
    }

    /// Description of the model's characteristics
    var description: String {
        switch self {
        case .opus: return "Most capable for complex work"
        case .sonnet: return "Best for everyday tasks"
        case .haiku: return "Fastest for quick answers"
        case .custom: return "Custom model ID"
        }
    }

    /// Icon for the model
    var icon: String {
        switch self {
        case .opus: return "brain.head.profile"
        case .sonnet: return "sparkles"
        case .haiku: return "bolt.fill"
        case .custom: return "gearshape"
        }
    }

    /// Color for the model indicator
    func color(for scheme: ColorScheme) -> Color {
        switch self {
        case .opus:
            return scheme == .dark
                ? Color(red: 0.7, green: 0.5, blue: 0.9)  // Purple
                : Color(red: 0.5, green: 0.3, blue: 0.7)
        case .sonnet:
            return scheme == .dark
                ? Color(red: 0.4, green: 0.8, blue: 0.9)  // Cyan
                : Color(red: 0.0, green: 0.55, blue: 0.7)
        case .haiku:
            return scheme == .dark
                ? Color(red: 0.9, green: 0.8, blue: 0.4)  // Yellow
                : Color(red: 0.7, green: 0.55, blue: 0.0)
        case .custom:
            return scheme == .dark
                ? Color(white: 0.6)
                : Color(white: 0.4)
        }
    }

    /// The model identifier to send to cli-bridge
    /// Standard models use aliases ("opus", "sonnet", "haiku") - server resolves to full SDK model IDs
    /// Custom model requires user to enter full model ID via settings
    var modelId: String? {
        switch self {
        case .opus: return "opus"
        case .sonnet: return "sonnet"
        case .haiku: return "haiku"
        case .custom: return nil  // User provides full model ID via settings
        }
    }
}
