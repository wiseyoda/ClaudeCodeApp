import SwiftUI

// CLI-inspired dark theme colors matching Claude Code
enum CLITheme {
    // Background colors
    static let background = Color(red: 0.08, green: 0.08, blue: 0.08)  // Near black
    static let secondaryBackground = Color(red: 0.12, green: 0.12, blue: 0.12)

    // Text colors
    static let primaryText = Color.white
    static let secondaryText = Color(white: 0.6)
    static let mutedText = Color(white: 0.4)

    // Accent colors (matching CLI)
    static let green = Color(red: 0.4, green: 0.8, blue: 0.4)      // Tool bullets, success
    static let yellow = Color(red: 0.9, green: 0.8, blue: 0.4)     // Paths, values
    static let orange = Color(red: 0.9, green: 0.6, blue: 0.3)     // Warnings
    static let red = Color(red: 0.9, green: 0.4, blue: 0.4)        // Errors, removed
    static let cyan = Color(red: 0.4, green: 0.8, blue: 0.9)       // Links, package names
    static let purple = Color(red: 0.7, green: 0.5, blue: 0.9)     // Special highlights
    static let blue = Color(red: 0.4, green: 0.6, blue: 0.9)       // User messages

    // Diff colors
    static let diffAdded = Color(red: 0.2, green: 0.3, blue: 0.2)
    static let diffRemoved = Color(red: 0.3, green: 0.2, blue: 0.2)
    static let diffAddedText = Color(red: 0.5, green: 0.9, blue: 0.5)
    static let diffRemovedText = Color(red: 0.9, green: 0.5, blue: 0.5)

    // Fonts
    static let monoFont = Font.system(.body, design: .monospaced)
    static let monoSmall = Font.system(.caption, design: .monospaced)
    static let monoLarge = Font.system(.title3, design: .monospaced)
}
