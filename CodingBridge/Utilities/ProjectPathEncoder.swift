import Foundation

/// Centralized utility for encoding and decoding project paths.
///
/// This utility provides a single source of truth for project path encoding used throughout
/// the app. The encoding scheme matches Claude CLI's `.claude/projects/` directory naming.
///
/// # Encoding Scheme
///
/// Paths are encoded by replacing `/` with `-`:
/// ```
/// /home/dev/project -> -home-dev-project
/// ```
///
/// # Known Limitation: Hyphen Ambiguity
///
/// **The encoding is lossy for paths containing hyphens.** These two paths encode identically:
/// ```
/// /home/my-project   -> -home-my-project
/// /home/my/project   -> -home-my-project  (same!)
/// ```
///
/// This is a fundamental limitation of the Claude CLI's encoding scheme. We cannot fix it
/// without breaking compatibility with existing session storage on disk.
///
/// **Recommendations:**
/// - Avoid using `decode(_:)` when you have access to the original path
/// - Store original paths alongside encoded versions when possible
/// - Accept that decode is a best-effort operation for display purposes
///
/// # Usage
///
/// ```swift
/// // Encoding for API calls and file storage
/// let encoded = ProjectPathEncoder.encode("/home/dev/project")
/// // Result: "-home-dev-project"
///
/// // Decoding (lossy - use only when original path is unavailable)
/// let decoded = ProjectPathEncoder.decode("-home-dev-project")
/// // Result: "/home/dev/project"
/// ```
///
/// - SeeAlso: cli-bridge's `src/utils/paths.ts` for the equivalent backend implementation
enum ProjectPathEncoder {

    /// Encode a project path for use in API URLs and file storage.
    ///
    /// This encoding matches the Claude CLI's directory naming convention for
    /// `~/.claude/projects/{encoded-path}/`.
    ///
    /// - Parameter path: The absolute project path (e.g., "/home/dev/project")
    /// - Returns: The encoded path (e.g., "-home-dev-project")
    ///
    /// - Note: This encoding is NOT URL-safe. Use `addingPercentEncoding()` when
    ///   embedding in URLs.
    static func encode(_ path: String) -> String {
        path.replacingOccurrences(of: "/", with: "-")
    }

    /// Decode an encoded project path back to its original form.
    ///
    /// - Warning: **This operation is lossy.** Paths containing hyphens cannot be
    ///   distinguished from paths containing slashes. For example, both `/home/my-project`
    ///   and `/home/my/project` encode to `-home-my-project`, and decoding returns
    ///   `/home/my/project`.
    ///
    /// - Parameter encoded: The encoded path (e.g., "-home-dev-project")
    /// - Returns: The decoded path (e.g., "/home/dev/project")
    ///
    /// - Important: Only use this when you don't have access to the original path.
    ///   When possible, store and pass the original path instead of decoding.
    static func decode(_ encoded: String) -> String {
        encoded.replacingOccurrences(of: "-", with: "/")
    }

    /// Check if an encoded path looks valid.
    ///
    /// Validates basic structure but cannot detect all issues due to encoding ambiguity.
    ///
    /// - Parameter encoded: The encoded path to validate
    /// - Returns: `true` if the path has valid encoded structure
    static func isValidEncoded(_ encoded: String) -> Bool {
        // Encoded paths from absolute paths should start with a dash (from leading /)
        // Empty strings and relative paths don't have this
        guard encoded.hasPrefix("-") || encoded.isEmpty else {
            return false
        }
        return true
    }
}
