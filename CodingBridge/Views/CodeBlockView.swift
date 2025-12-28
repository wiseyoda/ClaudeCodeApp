import SwiftUI

// MARK: - Code Block with Copy Button

struct CodeBlockView: View {
    let code: String
    let language: String?
    let settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    @State private var showCopied = false

    /// Get display-friendly language name from markdown fence language
    private var displayLanguage: String? {
        guard let lang = language, !lang.isEmpty else { return nil }
        return Self.languageDisplayName(for: lang)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header with language badge and copy button
            HStack {
                if let displayLang = displayLanguage {
                    HStack(spacing: 4) {
                        Image(systemName: Self.languageIcon(for: language ?? ""))
                            .font(.system(size: 10))
                        Text(displayLang)
                    }
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.cyan(for: colorScheme))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(CLITheme.cyan(for: colorScheme).opacity(0.15))
                    )
                }
                Spacer()
                Button {
                    HapticManager.light()
                    UIPasteboard.general.string = code
                    showCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showCopied = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        Text(showCopied ? "Copied!" : "Copy")
                    }
                    .font(settings.scaledFont(.small))
                    .foregroundColor(showCopied ? CLITheme.green(for: colorScheme) : CLITheme.mutedText(for: colorScheme))
                }
                .buttonStyle(.plain)
            }

            // Code content
            Text(code)
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.cyan(for: colorScheme))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CLITheme.secondaryBackground(for: colorScheme))
                .cornerRadius(6)
        }
    }

    // MARK: - Language Display Helpers

    /// Convert markdown fence language to display name
    static func languageDisplayName(for lang: String) -> String {
        let lower = lang.lowercased()
        switch lower {
        // Common languages
        case "swift": return "Swift"
        case "ts", "typescript", "tsx": return "TypeScript"
        case "js", "javascript", "jsx", "mjs", "cjs": return "JavaScript"
        case "py", "python": return "Python"
        case "rs", "rust": return "Rust"
        case "go", "golang": return "Go"
        case "java": return "Java"
        case "kt", "kotlin": return "Kotlin"
        case "rb", "ruby": return "Ruby"
        case "php": return "PHP"
        case "cs", "csharp", "c#": return "C#"
        case "cpp", "c++", "cc", "cxx": return "C++"
        case "c", "h": return "C"
        case "objc", "objective-c", "m", "mm": return "Obj-C"
        case "scala": return "Scala"
        case "r": return "R"
        case "dart": return "Dart"
        case "ex", "elixir": return "Elixir"
        case "clj", "clojure": return "Clojure"
        case "hs", "haskell": return "Haskell"
        case "lua": return "Lua"
        case "pl", "perl": return "Perl"
        case "sh", "bash", "zsh", "shell": return "Shell"
        case "ps1", "powershell": return "PowerShell"

        // Markup/data
        case "md", "markdown": return "Markdown"
        case "json", "jsonc": return "JSON"
        case "yaml", "yml": return "YAML"
        case "xml": return "XML"
        case "html", "htm": return "HTML"
        case "css", "scss", "sass", "less": return "CSS"
        case "sql": return "SQL"
        case "graphql", "gql": return "GraphQL"
        case "toml": return "TOML"
        case "dockerfile": return "Docker"
        case "makefile", "make": return "Makefile"

        // Text
        case "txt", "text", "plaintext": return "Text"
        case "diff", "patch": return "Diff"
        case "log": return "Log"

        default:
            // Capitalize first letter for unknown languages
            return lang.prefix(1).uppercased() + lang.dropFirst()
        }
    }

    /// Get SF Symbol icon for language
    static func languageIcon(for lang: String) -> String {
        let lower = lang.lowercased()
        switch lower {
        case "swift": return "swift"
        case "shell", "sh", "bash", "zsh": return "terminal"
        case "json", "yaml", "yml", "toml", "xml": return "doc.text"
        case "html", "htm", "css", "scss": return "globe"
        case "sql": return "cylinder"
        case "dockerfile", "docker": return "shippingbox"
        case "markdown", "md": return "text.document"
        case "diff", "patch": return "plus.forwardslash.minus"
        default: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

// MARK: - Math Block View

struct MathBlockView: View {
    let content: String
    let settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header with LaTeX label and copy button
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "function")
                        .font(.caption)
                    Text("LaTeX")
                }
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.purple(for: colorScheme))

                Spacer()

                Button {
                    HapticManager.light()
                    UIPasteboard.general.string = content
                    showCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showCopied = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        Text(showCopied ? "Copied!" : "Copy")
                    }
                    .font(settings.scaledFont(.small))
                    .foregroundColor(showCopied ? CLITheme.green(for: colorScheme) : CLITheme.mutedText(for: colorScheme))
                }
                .buttonStyle(.plain)
            }

            // Math content with distinctive styling
            Text(content)
                .font(.system(size: CGFloat(settings.fontSize), design: .monospaced))
                .italic()
                .foregroundColor(CLITheme.purple(for: colorScheme))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(CLITheme.purple(for: colorScheme).opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(CLITheme.purple(for: colorScheme).opacity(0.3), lineWidth: 1)
                        )
                )
        }
    }
}
