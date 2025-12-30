import Foundation

// MARK: - SSH Key Detection

/// Detects the type of an SSH private key from its content
enum SSHKeyType: String {
    case rsa = "RSA"
    case ed25519 = "Ed25519"
    case ecdsa256 = "ECDSA-256"
    case ecdsa384 = "ECDSA-384"
    case ecdsa521 = "ECDSA-521"
    case unknown = "Unknown"

    var description: String { rawValue }

    var isSupported: Bool {
        switch self {
        case .rsa, .ed25519:
            return true
        default:
            return false
        }
    }
}

/// Helper for detecting SSH key types
enum SSHKeyDetection {

    /// Normalize Unicode dashes and remove invisible characters
    /// iOS Smart Punctuation can convert ASCII hyphens to em/en dashes
    private static func normalizeKeyContent(_ content: String) -> String {
        var result = content

        // Replace all dash-like Unicode characters with ASCII hyphen-minus
        let dashReplacements: [(String, String)] = [
            ("\u{2010}", "-"), // HYPHEN
            ("\u{2011}", "-"), // NON-BREAKING HYPHEN
            ("\u{2012}", "-"), // FIGURE DASH
            ("\u{2013}", "-"), // EN DASH
            ("\u{2014}", "-"), // EM DASH
            ("\u{2015}", "-"), // HORIZONTAL BAR
            ("\u{2212}", "-"), // MINUS SIGN
            ("\u{FE58}", "-"), // SMALL EM DASH
            ("\u{FE63}", "-"), // SMALL HYPHEN-MINUS
            ("\u{FF0D}", "-"), // FULLWIDTH HYPHEN-MINUS
        ]
        for (unicode, ascii) in dashReplacements {
            result = result.replacingOccurrences(of: unicode, with: ascii)
        }

        // Remove invisible/zero-width characters that can corrupt pasted text
        let invisibleChars = [
            "\u{200B}", // ZERO WIDTH SPACE
            "\u{200C}", // ZERO WIDTH NON-JOINER
            "\u{200D}", // ZERO WIDTH JOINER
            "\u{FEFF}", // BOM / ZERO WIDTH NO-BREAK SPACE
            "\u{2060}", // WORD JOINER
            "\u{00A0}", // NON-BREAKING SPACE (replace with regular space)
        ]
        for char in invisibleChars {
            result = result.replacingOccurrences(of: char, with: char == "\u{00A0}" ? " " : "")
        }

        return result
    }

    /// Detect the type of a private key from its string content
    static func detectPrivateKeyType(from content: String) throws -> SSHKeyType {
        print("[KeyDetect] Input content length: \(content.count)")
        let normalized = normalizeKeyContent(content)
        print("[KeyDetect] Normalized content length: \(normalized.count)")
        let trimmed = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[KeyDetect] Trimmed content length: \(trimmed.count)")

        // OpenSSH format (newer)
        if trimmed.hasPrefix("-----BEGIN OPENSSH PRIVATE KEY-----") {
            return try detectOpenSSHKeyType(from: trimmed)
        }

        // PEM RSA format
        if trimmed.hasPrefix("-----BEGIN RSA PRIVATE KEY-----") {
            return .rsa
        }

        // PEM EC format
        if trimmed.hasPrefix("-----BEGIN EC PRIVATE KEY-----") {
            return .ecdsa256
        }

        // PEM generic private key (PKCS#8)
        if trimmed.hasPrefix("-----BEGIN PRIVATE KEY-----") {
            return .unknown
        }

        // PEM encrypted private key
        if trimmed.hasPrefix("-----BEGIN ENCRYPTED PRIVATE KEY-----") {
            return .unknown
        }

        throw SSHError.keyParseError("Unrecognized key format")
    }

    /// Detect key type from OpenSSH format by parsing the key data
    private static func detectOpenSSHKeyType(from content: String) throws -> SSHKeyType {
        print("[KeyDetect] Content length: \(content.count)")

        // Extract base64 content between header and footer
        guard let headerRange = content.range(of: "-----BEGIN OPENSSH PRIVATE KEY-----") else {
            print("[KeyDetect] ERROR: Header '-----BEGIN OPENSSH PRIVATE KEY-----' not found!")
            print("[KeyDetect] First 200 chars: \(content.prefix(200))")
            throw SSHError.keyParseError("Missing key header")
        }

        guard let footerRange = content.range(of: "-----END OPENSSH PRIVATE KEY-----") else {
            print("[KeyDetect] ERROR: Footer '-----END OPENSSH PRIVATE KEY-----' not found!")
            print("[KeyDetect] Last 200 chars: \(content.suffix(200))")
            throw SSHError.keyParseError("Missing key footer")
        }

        let base64Section = String(content[headerRange.upperBound..<footerRange.lowerBound])
        print("[KeyDetect] Base64 section length: \(base64Section.count)")

        // Strip ALL non-base64 characters (handles iOS hyphenation, whitespace, line breaks, etc.)
        let validBase64Chars = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
        let base64String = String(base64Section.unicodeScalars.filter { validBase64Chars.contains($0) })
        print("[KeyDetect] Filtered base64 length: \(base64String.count), mod4=\(base64String.count % 4)")

        // Try to decode, adding padding if needed (base64 must be multiple of 4)
        var paddedBase64 = base64String
        let remainder = paddedBase64.count % 4
        if remainder != 0 {
            print("[KeyDetect] Adding \(4 - remainder) padding chars to fix mod4")
            paddedBase64 += String(repeating: "=", count: 4 - remainder)
        }

        guard var data = Data(base64Encoded: paddedBase64) else {
            print("[KeyDetect] ERROR: Base64 decode failed even with padding!")
            print("[KeyDetect] First 100 of base64: \(base64String.prefix(100))")
            print("[KeyDetect] Last 100 of base64: \(base64String.suffix(100))")
            throw SSHError.keyParseError("Invalid base64 encoding")
        }
        print("[KeyDetect] Decoded \(data.count) bytes successfully")

        // OpenSSH keys should start with "openssh-key-v1\0" magic bytes
        // If magic bytes are wrong and base64 was mod4=3, the first char may have been truncated
        // (This happens when iOS TextEditor drops the first character during paste)
        let magicBytes = "openssh-key-v1"
        let dataPrefix = String(data: data.prefix(14), encoding: .utf8) ?? ""
        print("[KeyDetect] Data prefix: '\(dataPrefix)'")

        if dataPrefix != magicBytes && remainder == 3 {
            print("[KeyDetect] Magic bytes mismatch with mod4=3, trying truncation recovery...")

            // Try prepending 'b' - OpenSSH keys start with "b3Bl..." which is "openssh..."
            let recoveredBase64 = "b" + base64String
            print("[KeyDetect] Trying with prepended 'b': length=\(recoveredBase64.count), mod4=\(recoveredBase64.count % 4)")

            if let recoveredData = Data(base64Encoded: recoveredBase64) {
                let recoveredPrefix = String(data: recoveredData.prefix(14), encoding: .utf8) ?? ""
                print("[KeyDetect] Recovered data prefix: '\(recoveredPrefix)'")

                if recoveredPrefix == magicBytes {
                    print("[KeyDetect] SUCCESS: Truncation recovery worked!")
                    data = recoveredData
                }
                // If recovery didn't work, continue with original data - might still find key type
            }
        }

        // Look for key type strings in the binary data
        let dataString = data.map { String(format: "%c", isprint(Int32($0)) != 0 ? $0 : 46) }.joined()

        if dataString.contains("ssh-ed25519") {
            return .ed25519
        }
        if dataString.contains("ssh-rsa") {
            return .rsa
        }
        if dataString.contains("ecdsa-sha2-nistp256") {
            return .ecdsa256
        }
        if dataString.contains("ecdsa-sha2-nistp384") {
            return .ecdsa384
        }
        if dataString.contains("ecdsa-sha2-nistp521") {
            return .ecdsa521
        }

        return .unknown
    }

    /// Validate that a key string looks like a valid SSH private key
    static func isValidKeyFormat(_ content: String) -> Bool {
        let normalized = normalizeKeyContent(content)
        let trimmed = normalized.trimmingCharacters(in: .whitespacesAndNewlines)

        let validPrefixes = [
            "-----BEGIN OPENSSH PRIVATE KEY-----",
            "-----BEGIN RSA PRIVATE KEY-----",
            "-----BEGIN EC PRIVATE KEY-----",
            "-----BEGIN PRIVATE KEY-----",
            "-----BEGIN ENCRYPTED PRIVATE KEY-----"
        ]

        return validPrefixes.contains { trimmed.hasPrefix($0) }
    }

    /// Normalize and fix SSH key content, including truncation recovery
    /// Returns the fixed key content ready for storage
    static func normalizeSSHKey(_ content: String) -> String {
        let normalized = normalizeKeyContent(content)

        // For OpenSSH keys, check if truncation recovery is needed
        guard normalized.contains("-----BEGIN OPENSSH PRIVATE KEY-----"),
              normalized.contains("-----END OPENSSH PRIVATE KEY-----") else {
            // Not OpenSSH format - just return normalized content
            return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Extract the base64 section
        guard let headerRange = normalized.range(of: "-----BEGIN OPENSSH PRIVATE KEY-----"),
              let footerRange = normalized.range(of: "-----END OPENSSH PRIVATE KEY-----") else {
            return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let base64Section = String(normalized[headerRange.upperBound..<footerRange.lowerBound])
        let validBase64Chars = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
        let base64String = String(base64Section.unicodeScalars.filter { validBase64Chars.contains($0) })

        // Check if truncation recovery is needed
        let remainder = base64String.count % 4
        if remainder == 3 {
            // Try with padding first
            let paddedBase64 = base64String + "="
            if let data = Data(base64Encoded: paddedBase64) {
                let dataPrefix = String(data: data.prefix(14), encoding: .utf8) ?? ""
                if dataPrefix != "openssh-key-v1" {
                    // Magic bytes wrong - try prepending 'b'
                    let recoveredBase64 = "b" + base64String
                    if let recoveredData = Data(base64Encoded: recoveredBase64) {
                        let recoveredPrefix = String(data: recoveredData.prefix(14), encoding: .utf8) ?? ""
                        if recoveredPrefix == "openssh-key-v1" {
                            // Truncation detected! Rebuild the key with the fixed base64
                            print("[KeyNormalize] Truncation recovery applied - prepending missing 'b'")
                            let formattedBase64 = formatBase64(recoveredBase64)
                            return "-----BEGIN OPENSSH PRIVATE KEY-----\n\(formattedBase64)\n-----END OPENSSH PRIVATE KEY-----"
                        }
                    }
                }
            }
        }

        // No truncation detected, just return cleaned up version
        let formattedBase64 = formatBase64(base64String)
        return "-----BEGIN OPENSSH PRIVATE KEY-----\n\(formattedBase64)\n-----END OPENSSH PRIVATE KEY-----"
    }

    /// Format base64 string with proper line breaks (70 chars per line)
    private static func formatBase64(_ base64: String) -> String {
        var result = ""
        var index = base64.startIndex
        while index < base64.endIndex {
            let endIndex = base64.index(index, offsetBy: 70, limitedBy: base64.endIndex) ?? base64.endIndex
            result += base64[index..<endIndex]
            if endIndex < base64.endIndex {
                result += "\n"
            }
            index = endIndex
        }
        return result
    }
}
