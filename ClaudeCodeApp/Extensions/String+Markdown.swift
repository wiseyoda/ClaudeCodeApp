import Foundation

// MARK: - Escape Sequence Protection

extension String {
    /// Normalize inline code fences - convert ```code``` to `code` when on single line
    var normalizedCodeFences: String {
        // Match triple backticks that don't span multiple lines (inline code)
        // Pattern: ```something``` where "something" has no newlines
        var result = self
        let pattern = "```([^`\\n]+?)```"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "`$1`")
        }
        return result
    }

    /// Parse and format usage limit messages with local timezone
    /// Format: "Claude AI usage limit reached|<epoch>"
    var formattedUsageLimit: String {
        // Check for usage limit message pattern
        if self.contains("usage limit") && self.contains("|") {
            let parts = self.split(separator: "|")
            if parts.count == 2, let epoch = Double(parts[1]) {
                let date = Date(timeIntervalSince1970: epoch)
                let formatter = DateFormatter()
                formatter.dateStyle = .none
                formatter.timeStyle = .short
                formatter.timeZone = .current
                let timeString = formatter.string(from: date)
                return "\(parts[0]) (resets at \(timeString))"
            }
        }
        return self
    }

    /// Decode common HTML entities
    var htmlDecoded: String {
        var result = self
        let entities: [(String, String)] = [
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&amp;", "&"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&apos;", "'"),
            ("&nbsp;", " "),
            ("&#x27;", "'"),
            ("&#x2F;", "/"),
            ("&#60;", "<"),
            ("&#62;", ">"),
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        return result
    }

    /// Protect escape sequences in math content by replacing them with placeholders
    func protectMathEscapes() -> (String, [(String, String)]) {
        var result = self
        var replacements: [(String, String)] = []

        // Common LaTeX escape sequences to protect
        let escapePatterns = [
            "\\\\",  // Double backslash
            "\\{", "\\}",  // Braces
            "\\[", "\\]",  // Brackets
            "\\(", "\\)",  // Parentheses
            "\\_",  // Underscore
            "\\^",  // Caret
            "\\$",  // Dollar
            "\\%",  // Percent
            "\\&",  // Ampersand
            "\\#",  // Hash
        ]

        for (index, pattern) in escapePatterns.enumerated() {
            let placeholder = "§ESCAPE\(index)§"
            if result.contains(pattern) {
                replacements.append((placeholder, pattern))
                result = result.replacingOccurrences(of: pattern, with: placeholder)
            }
        }

        return (result, replacements)
    }

    /// Restore protected escape sequences
    func restoreMathEscapes(_ replacements: [(String, String)]) -> String {
        var result = self
        for (placeholder, original) in replacements.reversed() {
            result = result.replacingOccurrences(of: placeholder, with: original)
        }
        return result
    }

    /// Full escape processing: decode HTML entities, normalize code fences, handle backslash escapes
    var processedForDisplay: String {
        return self.htmlDecoded.normalizedCodeFences
    }
}
