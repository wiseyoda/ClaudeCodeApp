import SwiftUI

// MARK: - Diff View for Edit Tool

struct DiffView: View {
    let oldString: String
    let newString: String
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Removed section
            if !oldString.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("- Removed:")
                        .font(settings.scaledFont(.small))
                        .foregroundColor(CLITheme.red(for: colorScheme))
                    Text(oldString)
                        .font(settings.scaledFont(.small))
                        .foregroundColor(CLITheme.diffRemovedText(for: colorScheme))
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(CLITheme.diffRemoved(for: colorScheme))
                        .cornerRadius(4)
                }
            }

            // Added section
            if !newString.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("+ Added:")
                        .font(settings.scaledFont(.small))
                        .foregroundColor(CLITheme.green(for: colorScheme))
                    Text(newString)
                        .font(settings.scaledFont(.small))
                        .foregroundColor(CLITheme.diffAddedText(for: colorScheme))
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(CLITheme.diffAdded(for: colorScheme))
                        .cornerRadius(4)
                }
            }
        }
    }

    /// Parse old_string and new_string from Edit tool content
    static func parseEditContent(_ content: String) -> (old: String, new: String)? {
        // Content format: "Edit(file_path: /path, old_string: ..., new_string: ...)"
        // We need to extract old_string and new_string

        // Simple parsing - look for old_string: and new_string:
        guard content.hasPrefix("Edit") else { return nil }

        var oldString = ""
        var newString = ""

        // Extract old_string value
        if let oldRange = content.range(of: "old_string: ") {
            let afterOld = content[oldRange.upperBound...]
            // Find the end - either ", new_string:" or end of content
            if let endRange = afterOld.range(of: ", new_string: ") {
                oldString = String(afterOld[..<endRange.lowerBound])
            }
        }

        // Extract new_string value
        if let newRange = content.range(of: "new_string: ") {
            let afterNew = content[newRange.upperBound...]
            // Find the end - either ")" or ", replace_all:"
            if let endRange = afterNew.range(of: ", replace_all:") {
                newString = String(afterNew[..<endRange.lowerBound])
            } else if let endRange = afterNew.range(of: ")") {
                newString = String(afterNew[..<endRange.lowerBound])
            } else {
                newString = String(afterNew)
            }
        }

        if oldString.isEmpty && newString.isEmpty {
            return nil
        }

        return (oldString, newString)
    }
}
