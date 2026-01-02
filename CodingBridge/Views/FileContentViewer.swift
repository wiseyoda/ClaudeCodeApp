import SwiftUI
import Highlightr

// MARK: - File Content Viewer

struct FileContentViewer: View {
    let fileContent: CLIFileContentResponse
    let projectPath: String
    var onAskClaude: ((String, Bool) -> Void)?  // (content, isNewSession)

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var settings: AppSettings

    @State private var showAskClaudeSheet = false
    @State private var showShareSheet = false
    @State private var copiedToClipboard = false

    private let highlightr: Highlightr? = Highlightr()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // File metadata header
                    fileHeader

                    Divider()

                    // Syntax highlighted content with line numbers
                    codeContent
                }
            }
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle(fileContent.fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(CLITheme.blue(for: colorScheme))
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Copy button
                    Button {
                        copyToClipboard()
                    } label: {
                        Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc")
                    }
                    .foregroundColor(copiedToClipboard ? CLITheme.green(for: colorScheme) : CLITheme.blue(for: colorScheme))

                    // Share button
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .foregroundColor(CLITheme.blue(for: colorScheme))

                    // Ask Claude button
                    if onAskClaude != nil {
                        Button {
                            showAskClaudeSheet = true
                        } label: {
                            Image(systemName: "bubble.left.and.bubble.right")
                        }
                        .foregroundColor(CLITheme.blue(for: colorScheme))
                    }
                }
            }
            .confirmationDialog("Ask Claude about this file", isPresented: $showAskClaudeSheet) {
                Button("Start New Session") {
                    onAskClaude?(fileContent.content, true)
                    dismiss()
                }
                Button("Add to Current Session") {
                    onAskClaude?(fileContent.content, false)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("How would you like to discuss \(fileContent.fileName)?")
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [fileContent.content])
            }
        }
    }

    // MARK: - File Header

    private var fileHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            // File path
            Text(fileContent.path)
                .font(CLITheme.monoSmall)
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
                .lineLimit(2)

            // Metadata row
            HStack(spacing: 16) {
                // Language badge
                if let language = fileContent.language {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 10))
                        Text(language)
                            .font(settings.scaledFont(.small))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(CLITheme.blue(for: colorScheme).opacity(0.2))
                    .foregroundColor(CLITheme.blue(for: colorScheme))
                    .cornerRadius(4)
                }

                // File size
                if let size = fileContent.formattedSize {
                    HStack(spacing: 4) {
                        Image(systemName: "doc")
                            .font(.system(size: 10))
                        Text(size)
                            .font(settings.scaledFont(.small))
                    }
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                }

                // Line count
                if let lineCount = fileContent.lineCount {
                    HStack(spacing: 4) {
                        Image(systemName: "list.number")
                            .font(.system(size: 10))
                        Text("\(lineCount) lines")
                            .font(settings.scaledFont(.small))
                    }
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                }

                Spacer()
            }
        }
        .padding()
        .background(CLITheme.secondaryBackground(for: colorScheme))
    }

    // MARK: - Code Content

    private var codeContent: some View {
        let lines = fileContent.content.components(separatedBy: "\n")
        let lineNumberWidth = "\(lines.count)".count * 10 + 20

        return HStack(alignment: .top, spacing: 0) {
            // Line numbers
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, _ in
                    Text("\(index + 1)")
                        .font(CLITheme.monoSmall)
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                        .frame(height: 18)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .frame(minWidth: CGFloat(lineNumberWidth))
            .background(CLITheme.secondaryBackground(for: colorScheme).opacity(0.5))

            // Syntax highlighted code
            ScrollView(.horizontal, showsIndicators: true) {
                highlightedCode
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
            }
        }
    }

    private var highlightedCode: some View {
        let language = detectLanguage()

        if let highlightr = highlightr {
            // Configure theme based on color scheme
            highlightr.setTheme(to: colorScheme == .dark ? "atom-one-dark" : "atom-one-light")

            if let highlighted = highlightr.highlight(fileContent.content, as: language) {
                return AnyView(
                    Text(AttributedString(highlighted))
                        .font(CLITheme.monoSmall)
                        .textSelection(.enabled)
                )
            }
        }

        // Fallback to plain text
        return AnyView(
            Text(fileContent.content)
                .font(CLITheme.monoSmall)
                .foregroundColor(CLITheme.primaryText(for: colorScheme))
                .textSelection(.enabled)
        )
    }

    // MARK: - Helpers

    private func detectLanguage() -> String {
        // Use server-provided language if available
        if let lang = fileContent.language?.lowercased() {
            return mapToHighlightrLanguage(lang)
        }

        // Fallback to extension-based detection
        let ext = (fileContent.path as NSString).pathExtension.lowercased()
        return extensionToLanguage(ext)
    }

    private func mapToHighlightrLanguage(_ lang: String) -> String {
        switch lang {
        case "typescript": return "typescript"
        case "javascript": return "javascript"
        case "python": return "python"
        case "swift": return "swift"
        case "rust": return "rust"
        case "go": return "go"
        case "ruby": return "ruby"
        case "java": return "java"
        case "kotlin": return "kotlin"
        case "c": return "c"
        case "cpp", "c++": return "cpp"
        case "csharp", "c#": return "csharp"
        case "php": return "php"
        case "html": return "xml"
        case "css": return "css"
        case "scss": return "scss"
        case "json": return "json"
        case "yaml": return "yaml"
        case "markdown": return "markdown"
        case "shell", "bash": return "bash"
        case "sql": return "sql"
        default: return lang
        }
    }

    private func extensionToLanguage(_ ext: String) -> String {
        switch ext {
        case "swift": return "swift"
        case "ts", "tsx": return "typescript"
        case "js", "jsx", "mjs": return "javascript"
        case "py": return "python"
        case "rs": return "rust"
        case "go": return "go"
        case "rb": return "ruby"
        case "java": return "java"
        case "kt", "kts": return "kotlin"
        case "c", "h": return "c"
        case "cpp", "cc", "cxx", "hpp": return "cpp"
        case "cs": return "csharp"
        case "php": return "php"
        case "html", "htm": return "xml"
        case "css": return "css"
        case "scss", "sass": return "scss"
        case "json": return "json"
        case "yml", "yaml": return "yaml"
        case "md", "markdown": return "markdown"
        case "sh", "bash", "zsh": return "bash"
        case "sql": return "sql"
        case "xml": return "xml"
        case "toml": return "ini"
        default: return "plaintext"
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = fileContent.content
        copiedToClipboard = true

        // Reset after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedToClipboard = false
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    FileContentViewer(
        fileContent: CLIFileContentResponse(
            path: "/src/utils/auth.ts",
            content: """
            import { jwt } from 'jsonwebtoken';

            export function validateToken(token: string): boolean {
                try {
                    const decoded = jwt.verify(token, process.env.SECRET);
                    return !!decoded;
                } catch {
                    return false;
                }
            }
            """,
            size: 256,
            modified: "2024-12-29T09:00:00Z",
            mimeType: "text/typescript"
        ),
        projectPath: "/Users/dev/myapp"
    )
    .environmentObject(AppSettings())
}
