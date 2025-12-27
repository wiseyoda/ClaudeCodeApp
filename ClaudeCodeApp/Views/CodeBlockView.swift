import SwiftUI

// MARK: - Code Block with Copy Button

struct CodeBlockView: View {
    let code: String
    let language: String?
    let settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header with language and copy button
            HStack {
                if let lang = language, !lang.isEmpty {
                    Text(lang)
                        .font(settings.scaledFont(.small))
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                }
                Spacer()
                Button {
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
