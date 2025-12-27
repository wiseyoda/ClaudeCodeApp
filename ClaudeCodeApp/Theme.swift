import SwiftUI

// CLI-inspired theme colors supporting dark and light modes
enum CLITheme {
    // MARK: - Background Colors

    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.08, green: 0.08, blue: 0.08)  // Near black
            : Color(red: 0.96, green: 0.96, blue: 0.96)  // Light gray
    }

    static func secondaryBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.12, green: 0.12, blue: 0.12)
            : Color.white
    }

    // MARK: - Text Colors

    static func primaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white : Color(red: 0.1, green: 0.1, blue: 0.1)
    }

    static func secondaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.6) : Color(white: 0.4)
    }

    static func mutedText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.4) : Color(white: 0.55)
    }

    // MARK: - Accent Colors
    // These are adjusted for better contrast in each mode

    static func green(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.4, green: 0.8, blue: 0.4)
            : Color(red: 0.2, green: 0.6, blue: 0.2)
    }

    static func yellow(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.9, green: 0.8, blue: 0.4)
            : Color(red: 0.7, green: 0.55, blue: 0.0)
    }

    static func orange(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.9, green: 0.6, blue: 0.3)
            : Color(red: 0.85, green: 0.45, blue: 0.1)
    }

    static func red(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.9, green: 0.4, blue: 0.4)
            : Color(red: 0.8, green: 0.25, blue: 0.25)
    }

    static func cyan(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.4, green: 0.8, blue: 0.9)
            : Color(red: 0.0, green: 0.55, blue: 0.7)
    }

    static func purple(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.7, green: 0.5, blue: 0.9)
            : Color(red: 0.5, green: 0.3, blue: 0.7)
    }

    static func blue(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.4, green: 0.6, blue: 0.9)
            : Color(red: 0.2, green: 0.4, blue: 0.8)
    }

    // MARK: - Diff Colors

    static func diffAdded(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.2, green: 0.3, blue: 0.2)
            : Color(red: 0.85, green: 0.95, blue: 0.85)
    }

    static func diffRemoved(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.3, green: 0.2, blue: 0.2)
            : Color(red: 0.95, green: 0.85, blue: 0.85)
    }

    static func diffAddedText(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.5, green: 0.9, blue: 0.5)
            : Color(red: 0.15, green: 0.5, blue: 0.15)
    }

    static func diffRemovedText(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.9, green: 0.5, blue: 0.5)
            : Color(red: 0.6, green: 0.15, blue: 0.15)
    }

    // MARK: - Fonts

    static let monoFont = Font.system(.body, design: .monospaced)
    static let monoSmall = Font.system(.caption, design: .monospaced)
    static let monoLarge = Font.system(.title3, design: .monospaced)

    // MARK: - Legacy Static Properties (for backward compatibility during migration)
    // These use dark mode colors as defaults

    static let background = Color(red: 0.08, green: 0.08, blue: 0.08)
    static let secondaryBackground = Color(red: 0.12, green: 0.12, blue: 0.12)
    static let primaryText = Color.white
    static let secondaryText = Color(white: 0.6)
    static let mutedText = Color(white: 0.4)
    static let green = Color(red: 0.4, green: 0.8, blue: 0.4)
    static let yellow = Color(red: 0.9, green: 0.8, blue: 0.4)
    static let orange = Color(red: 0.9, green: 0.6, blue: 0.3)
    static let red = Color(red: 0.9, green: 0.4, blue: 0.4)
    static let cyan = Color(red: 0.4, green: 0.8, blue: 0.9)
    static let purple = Color(red: 0.7, green: 0.5, blue: 0.9)
    static let blue = Color(red: 0.4, green: 0.6, blue: 0.9)
    static let diffAdded = Color(red: 0.2, green: 0.3, blue: 0.2)
    static let diffRemoved = Color(red: 0.3, green: 0.2, blue: 0.2)
    static let diffAddedText = Color(red: 0.5, green: 0.9, blue: 0.5)
    static let diffRemovedText = Color(red: 0.9, green: 0.5, blue: 0.5)
}
