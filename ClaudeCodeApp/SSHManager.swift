import Foundation
import Citadel
import NIOCore
import NIOSSH
import Crypto
import Security
import CryptoKit

// MARK: - Shell Escaping

/// Escape a string for safe use in shell commands as a literal argument
/// Uses single-quote escaping: wrap in single quotes and escape any internal single quotes
func shellEscape(_ string: String) -> String {
    // Replace ' with '\'' (end quote, escaped quote, start quote)
    let escaped = string.replacingOccurrences(of: "'", with: "'\\''")
    return "'\(escaped)'"
}

/// Escape a command string for safe execution within bash -c
/// This is more restrictive than shellEscape since it prevents shell interpretation
private func escapeCommandForBash(_ command: String) -> String {
    // For commands executed with bash -c, we need to prevent injection
    // Single quote escaping is the safest approach
    return command.replacingOccurrences(of: "'", with: "'\\''")
}

// MARK: - Keychain Helper

/// Helper for secure SSH key storage in iOS Keychain
class KeychainHelper {
    static let shared = KeychainHelper()

    // Keychain service identifier
    private let service = "com.claudecodeapp.sshkeys"

    // Account keys for different stored items
    private enum Account: String {
        case privateKey = "ssh_private_key"
        case passphrase = "ssh_key_passphrase"
        case sshPassword = "ssh_password"
        // Auth credentials for claudecodeui backend
        case authPassword = "auth_password"
        case authToken = "auth_token"
        case apiKey = "api_key"
        // SSH host key fingerprints for TOFU (Trust On First Use) validation
        // Format: "host:port" -> fingerprint
        case hostKeyPrefix = "ssh_hostkey_"
    }

    private init() {}

    // MARK: - SSH Private Key

    /// Store an SSH private key securely
    @discardableResult
    func storeSSHKey(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }
        deleteSSHKey()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Account.privateKey.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            log.info("SSH key stored in Keychain")
            return true
        } else {
            log.error("Failed to store SSH key in Keychain: \(status)")
            return false
        }
    }

    /// Retrieve the stored SSH private key
    func retrieveSSHKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Account.privateKey.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    /// Delete the stored SSH private key
    @discardableResult
    func deleteSSHKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Account.privateKey.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Check if an SSH key is stored
    var hasSSHKey: Bool {
        retrieveSSHKey() != nil
    }

    // MARK: - Passphrase

    /// Store the passphrase for an encrypted SSH key
    @discardableResult
    func storePassphrase(_ passphrase: String) -> Bool {
        guard let data = passphrase.data(using: .utf8) else { return false }
        deletePassphrase()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Account.passphrase.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieve the stored passphrase
    func retrievePassphrase() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Account.passphrase.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    /// Delete the stored passphrase
    @discardableResult
    func deletePassphrase() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Account.passphrase.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - SSH Password (fallback authentication)

    /// Store the SSH password securely
    @discardableResult
    func storeSSHPassword(_ password: String) -> Bool {
        guard !password.isEmpty, let data = password.data(using: .utf8) else {
            deleteSSHPassword()
            return true
        }
        deleteSSHPassword()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Account.sshPassword.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieve the stored SSH password
    func retrieveSSHPassword() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Account.sshPassword.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    /// Delete the stored SSH password
    @discardableResult
    func deleteSSHPassword() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Account.sshPassword.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Check if an SSH password is stored
    var hasSSHPassword: Bool {
        retrieveSSHPassword() != nil
    }

    // MARK: - Auth Password (claudecodeui backend)

    /// Store the auth password securely
    @discardableResult
    func storeAuthPassword(_ password: String) -> Bool {
        guard !password.isEmpty, let data = password.data(using: .utf8) else {
            deleteAuthPassword()
            return true
        }
        deleteAuthPassword()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Account.authPassword.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieve the stored auth password
    func retrieveAuthPassword() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Account.authPassword.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    /// Delete the stored auth password
    @discardableResult
    func deleteAuthPassword() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Account.authPassword.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Auth Token (JWT for claudecodeui backend)

    /// Store the auth token securely
    @discardableResult
    func storeAuthToken(_ token: String) -> Bool {
        guard !token.isEmpty, let data = token.data(using: .utf8) else {
            deleteAuthToken()
            return true
        }
        deleteAuthToken()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Account.authToken.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieve the stored auth token
    func retrieveAuthToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Account.authToken.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    /// Delete the stored auth token
    @discardableResult
    func deleteAuthToken() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Account.authToken.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - API Key (for claudecodeui REST endpoints)

    /// Store the API key securely
    @discardableResult
    func storeAPIKey(_ key: String) -> Bool {
        guard !key.isEmpty, let data = key.data(using: .utf8) else {
            deleteAPIKey()
            return true
        }
        deleteAPIKey()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Account.apiKey.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieve the stored API key
    func retrieveAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Account.apiKey.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    /// Delete the stored API key
    @discardableResult
    func deleteAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Account.apiKey.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Remove all stored SSH credentials
    func clearAll() {
        deleteSSHKey()
        deletePassphrase()
        deleteSSHPassword()
        log.info("All SSH credentials cleared from Keychain")
    }

    /// Remove all stored credentials (SSH and auth)
    func clearAllCredentials() {
        deleteSSHKey()
        deletePassphrase()
        deleteSSHPassword()
        deleteAuthPassword()
        deleteAuthToken()
        deleteAPIKey()
        log.info("All credentials cleared from Keychain")
    }

    // MARK: - SSH Host Key Fingerprints (TOFU)

    /// Generate Keychain account name for a host:port pair
    private func hostKeyAccount(for host: String, port: Int) -> String {
        return "\(Account.hostKeyPrefix.rawValue)\(host):\(port)"
    }

    /// Store a host key fingerprint for TOFU validation
    @discardableResult
    func storeHostKeyFingerprint(_ fingerprint: String, host: String, port: Int) -> Bool {
        guard !fingerprint.isEmpty, let data = fingerprint.data(using: .utf8) else {
            return false
        }

        let account = hostKeyAccount(for: host, port: port)

        // Delete any existing fingerprint first
        deleteHostKeyFingerprint(host: host, port: port)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            log.info("Stored host key fingerprint for \(host):\(port)")
            return true
        } else {
            log.error("Failed to store host key fingerprint: \(status)")
            return false
        }
    }

    /// Retrieve the stored host key fingerprint
    func retrieveHostKeyFingerprint(host: String, port: Int) -> String? {
        let account = hostKeyAccount(for: host, port: port)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    /// Delete a stored host key fingerprint
    @discardableResult
    func deleteHostKeyFingerprint(host: String, port: Int) -> Bool {
        let account = hostKeyAccount(for: host, port: port)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Check if we have a stored fingerprint for this host
    func hasHostKeyFingerprint(host: String, port: Int) -> Bool {
        retrieveHostKeyFingerprint(host: host, port: port) != nil
    }
}

// MARK: - TOFU Host Key Validator

/// SSH host key validation error
enum SSHHostKeyError: Error, LocalizedError {
    case mismatch(expected: String, received: String)

    var errorDescription: String? {
        switch self {
        case .mismatch(let expected, let received):
            return "SSH host key mismatch! Expected: \(expected.prefix(16))..., Received: \(received.prefix(16))... This could indicate a man-in-the-middle attack."
        }
    }
}

/// Trust On First Use (TOFU) host key validator
/// On first connection: stores the host's key fingerprint
/// On subsequent connections: verifies the fingerprint matches
struct TOFUHostKeyValidator {
    let host: String
    let port: Int

    /// Create a TOFU validator for a specific host and port
    init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    /// Create an SSHHostKeyValidator using TOFU strategy
    func validator() -> SSHHostKeyValidator {
        return .custom { publicKey in
            // Compute fingerprint from the public key
            let fingerprint = computeFingerprint(from: publicKey)

            // Check if we have a stored fingerprint for this host
            if let storedFingerprint = KeychainHelper.shared.retrieveHostKeyFingerprint(host: host, port: port) {
                // Verify the fingerprint matches
                if storedFingerprint == fingerprint {
                    log.debug("SSH host key verified for \(host):\(port)")
                    return  // Success - fingerprint matches
                } else {
                    // CRITICAL: Fingerprint mismatch - possible MITM attack
                    log.error("SSH host key mismatch for \(host):\(port)!")
                    log.error("Expected: \(storedFingerprint)")
                    log.error("Received: \(fingerprint)")
                    throw SSHHostKeyError.mismatch(expected: storedFingerprint, received: fingerprint)
                }
            } else {
                // First connection - trust and store the fingerprint
                log.info("First SSH connection to \(host):\(port) - storing host key fingerprint")
                KeychainHelper.shared.storeHostKeyFingerprint(fingerprint, host: host, port: port)
                return  // Success - trusted on first use
            }
        }
    }

    /// Compute a SHA-256 fingerprint from public key data
    private func computeFingerprint(from publicKey: NIOSSHPublicKey) -> String {
        // Get the raw public key bytes and compute SHA-256 hash
        var hasher = SHA256()

        // Use the public key's raw representation
        // NIOSSHPublicKey doesn't expose raw bytes directly, so we use its description
        // which includes the key type and base64-encoded key data
        let keyDescription = String(describing: publicKey)
        hasher.update(data: Data(keyDescription.utf8))

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined(separator: ":")
    }
}

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

// MARK: - SSH Error

enum SSHError: LocalizedError {
    case connectionFailed(String)
    case authenticationFailed
    case notConnected
    case keyNotFound(String)
    case unsupportedKeyType(String)
    case keyParseError(String)

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let reason): return "Connection failed: \(reason)"
        case .authenticationFailed: return "Authentication failed"
        case .notConnected: return "Not connected"
        case .keyNotFound(let path): return "SSH key not found: \(path)"
        case .unsupportedKeyType(let type): return "Unsupported key type: \(type)"
        case .keyParseError(let reason): return "Failed to parse key: \(reason)"
        }
    }
}

// SSH Config entry parsed from ~/.ssh/config
struct SSHConfigEntry {
    var host: String
    var hostName: String?
    var user: String?
    var port: Int?
    var identityFile: String?
}

@MainActor
class SSHManager: ObservableObject {
    /// Shared singleton instance - use this instead of creating new instances
    static let shared = SSHManager()

    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var output: String = ""
    @Published var lastError: String?
    @Published var availableHosts: [SSHConfigEntry] = []

    private var client: SSHClient?
    private var disconnectTask: Task<Void, Never>?

    var host: String = ""
    var port: Int = 22
    var username: String = ""
    var currentDirectory: String = "~"  // Track working directory

    init() {
        loadSSHConfig()
    }

    deinit {
        // Cancel any pending disconnect task
        disconnectTask?.cancel()

        // Synchronously close the SSH connection to prevent orphaned server processes
        // We need to capture client before it's deallocated and close it in a detached task
        if let clientToClose = client {
            Task.detached {
                try? await clientToClose.close()
            }
        }
    }

    // Get the real home directory (works around iOS Simulator sandboxing)
    private func getRealHomeDirectory() -> String {
        #if targetEnvironment(simulator)
        // In Simulator, get the actual Mac home directory
        if let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] {
            return home
        }
        // Fallback: parse from sandbox path
        let sandboxPath = NSHomeDirectory()
        if let range = sandboxPath.range(of: "/Library/Developer") {
            return String(sandboxPath[..<range.lowerBound])
        }
        #endif
        return NSHomeDirectory()
    }

    static func parseSSHConfig(_ content: String, homeDirectory: String) -> [SSHConfigEntry] {
        var hosts: [SSHConfigEntry] = []
        var currentEntry: SSHConfigEntry?

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            let parts = trimmed.split(separator: " ", maxSplits: 1).map { String($0) }
            guard parts.count >= 2 else { continue }

            let key = parts[0].lowercased()
            let value = parts[1].trimmingCharacters(in: .whitespaces)

            switch key {
            case "host":
                if let entry = currentEntry, !entry.host.contains("*") {
                    hosts.append(entry)
                }
                currentEntry = SSHConfigEntry(host: value)
            case "hostname":
                currentEntry?.hostName = value
            case "user":
                currentEntry?.user = value
            case "port":
                currentEntry?.port = Int(value)
            case "identityfile":
                let expandedPath = value.replacingOccurrences(of: "~", with: homeDirectory)
                currentEntry?.identityFile = expandedPath
            default:
                break
            }
        }

        if let entry = currentEntry, !entry.host.contains("*") {
            hosts.append(entry)
        }

        return hosts
    }

    static func buildCommand(for command: String, currentDirectory: String) -> (command: String, updatedDirectory: String) {
        let trimmedCommand = command.trimmingCharacters(in: .whitespaces)
        var updatedDirectory = currentDirectory

        if trimmedCommand == "cd" {
            updatedDirectory = "~"
            return ("cd ~ && pwd", updatedDirectory)
        }

        if trimmedCommand.hasPrefix("cd ") {
            let newDir = String(trimmedCommand.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            let baseDirectory = currentDirectory
            // Validate newDir to prevent directory traversal attacks
            let validatedDir = validateDirectoryPath(newDir)
            let actualCommand = "cd \(baseDirectory) && cd \(validatedDir) && pwd"

            if newDir.hasPrefix("/") {
                updatedDirectory = newDir
            } else if newDir == "~" || newDir.hasPrefix("~/") {
                updatedDirectory = newDir
            } else if newDir == ".." {
                if updatedDirectory != "~" && updatedDirectory != "/" {
                    updatedDirectory = (updatedDirectory as NSString).deletingLastPathComponent
                    if updatedDirectory.isEmpty { updatedDirectory = "/" }
                }
            } else if newDir == "-" {
                updatedDirectory = "~"
            } else {
                if updatedDirectory == "~" {
                    updatedDirectory = "~/\(newDir)"
                } else {
                    updatedDirectory = "\(updatedDirectory)/\(newDir)"
                }
            }

            return (actualCommand, updatedDirectory)
        }

        return ("cd \(currentDirectory) && \(command)", updatedDirectory)
    }

    /// Validate a directory path to prevent command injection and directory traversal attacks
    private static func validateDirectoryPath(_ path: String) -> String {
        // Reject paths with dangerous shell metacharacters that could lead to command injection
        let dangerousChars = CharacterSet(charactersIn: ";|&`$\n\r\t")
        guard path.rangeOfCharacter(from: dangerousChars) == nil else {
            // For security, replace dangerous paths with a safe default
            return "."
        }

        // Prevent directory traversal attacks by limiting .. sequences
        let components = path.components(separatedBy: "/")
        var validatedComponents: [String] = []

        for component in components {
            if component == ".." {
                // Allow reasonable directory traversal (max 5 levels up)
                if validatedComponents.count > 5 {
                    return "."
                }
                validatedComponents.append(component)
            } else if component.isEmpty || component == "." {
                // Allow empty or current directory components
                continue
            } else {
                // Basic validation for directory names
                guard component.range(of: #"^[a-zA-Z0-9._-]+$"#, options: .regularExpression) != nil ||
                      component == "~" else {
                    return "."
                }
                validatedComponents.append(component)
            }
        }

        return validatedComponents.joined(separator: "/").isEmpty ? "." : validatedComponents.joined(separator: "/")
    }

    static func stripAnsiCodes(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "\u{1B}\\[[0-9;]*m", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "\u{1B}\\[[0-9;]*[ABCDJKH]", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "\u{1B}\\][0-9];[^\u{07}]*\u{07}", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "\u{1B}\\[[?0-9;]*[hl]", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "\u{1B}[=>]", with: "", options: .regularExpression)
        return result
    }

    // Parse ~/.ssh/config to get available hosts
    func loadSSHConfig() {
        let homeDir = getRealHomeDirectory()
        let configPath = homeDir + "/.ssh/config"

        log.debug("Looking for config at: \(configPath)")

        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            log.warning("Could not read SSH config")
            return
        }

        log.debug("Found SSH config, parsing...")
        let hosts = Self.parseSSHConfig(content, homeDirectory: homeDir)
        availableHosts = hosts
        log.debug("Found \(hosts.count) hosts: \(hosts.map { $0.host })")
    }

    // Connect using SSH config host alias (e.g., "claude-dev")
    func connectWithConfigHost(_ hostAlias: String) async throws {
        guard let entry = availableHosts.first(where: { $0.host == hostAlias }) else {
            throw SSHError.connectionFailed("Host '\(hostAlias)' not found in SSH config")
        }

        let actualHost = entry.hostName ?? hostAlias
        let actualPort = entry.port ?? 22
        let actualUser = entry.user ?? NSUserName()

        // Try key-based auth first
        if let keyPath = entry.identityFile ?? findDefaultKey() {
            try await connectWithKey(
                host: actualHost,
                port: actualPort,
                username: actualUser,
                privateKeyPath: keyPath
            )
        } else {
            throw SSHError.keyNotFound("No identity file configured and no default key found")
        }
    }

    // Find default SSH key
    private func findDefaultKey() -> String? {
        let homeDir = getRealHomeDirectory()
        let sshDir = homeDir + "/.ssh"
        let defaultKeys = ["id_ed25519", "id_rsa", "id_ecdsa", "id_dsa"]

        for keyName in defaultKeys {
            let keyPath = sshDir + "/" + keyName
            if FileManager.default.fileExists(atPath: keyPath) {
                log.debug("Found default key: \(keyPath)")
                return keyPath
            }
        }
        log.debug("No default key found in \(sshDir)")
        return nil
    }

    // Connect with SSH key from file path
    func connectWithKey(host: String, port: Int, username: String, privateKeyPath: String, passphrase: String? = nil) async throws {
        // Read the private key from file
        guard let keyData = FileManager.default.contents(atPath: privateKeyPath),
              let privateKeyString = String(data: keyData, encoding: .utf8) else {
            throw SSHError.keyNotFound(privateKeyPath)
        }

        try await connectWithKeyString(host: host, port: port, username: username, privateKeyString: privateKeyString, passphrase: passphrase)
    }

    // Connect with SSH key from Keychain
    func connectWithKeychainKey(host: String, port: Int, username: String) async throws {
        guard let privateKeyString = KeychainHelper.shared.retrieveSSHKey() else {
            throw SSHError.keyNotFound("No SSH key stored in Keychain")
        }

        let passphrase = KeychainHelper.shared.retrievePassphrase()
        try await connectWithKeyString(host: host, port: port, username: username, privateKeyString: privateKeyString, passphrase: passphrase)
    }

    // Connect with SSH key string (shared implementation)
    func connectWithKeyString(host: String, port: Int, username: String, privateKeyString: String, passphrase: String? = nil) async throws {
        self.host = host
        self.port = port
        self.username = username

        isConnecting = true
        lastError = nil
        output = "Connecting to \(username)@\(host):\(port) with key...\n"

        do {
            // Detect key type and create appropriate authentication method
            let keyType = try SSHKeyDetection.detectPrivateKeyType(from: privateKeyString)
            let authMethod: SSHAuthenticationMethod

            switch keyType {
            case .ed25519:
                let decryptKey = passphrase.flatMap { $0.data(using: .utf8) }
                let privateKey = try Curve25519.Signing.PrivateKey(sshEd25519: privateKeyString, decryptionKey: decryptKey)
                authMethod = .ed25519(username: username, privateKey: privateKey)
                output += "Using Ed25519 key...\n"

            case .rsa:
                let decryptKey = passphrase.flatMap { $0.data(using: .utf8) }
                let privateKey = try Insecure.RSA.PrivateKey(sshRsa: privateKeyString, decryptionKey: decryptKey)
                authMethod = .rsa(username: username, privateKey: privateKey)
                output += "Using RSA key...\n"

            default:
                // ECDSA keys (P-256, P-384, P-521) are detected but SSH key parsing may not be available
                throw SSHError.unsupportedKeyType("\(keyType.description) - only Ed25519 and RSA are supported")
            }

            // Connect with key authentication using TOFU host key validation
            let tofuValidator = TOFUHostKeyValidator(host: host, port: port)
            let client = try await SSHClient.connect(
                host: host,
                port: port,
                authenticationMethod: authMethod,
                hostKeyValidator: tofuValidator.validator(),
                reconnect: .never
            )

            self.client = client
            isConnected = true
            isConnecting = false
            currentDirectory = "~"  // Reset to home on new connection
            output += "Connected! Type commands below.\n\n"

        } catch let error as SSHError {
            isConnecting = false
            isConnected = false
            lastError = error.localizedDescription
            output += "Error: \(error.localizedDescription)\n"
            throw error
        } catch {
            isConnecting = false
            isConnected = false
            lastError = error.localizedDescription
            output += "Error: \(error.localizedDescription)\n"
            throw SSHError.connectionFailed(error.localizedDescription)
        }
    }

    // Connect with password (fallback)
    func connect(host: String, port: Int, username: String, password: String) async throws {
        self.host = host
        self.port = port
        self.username = username

        isConnecting = true
        lastError = nil
        output = "Connecting to \(username)@\(host):\(port)...\n"

        do {
            // Connect with password authentication using TOFU host key validation
            let tofuValidator = TOFUHostKeyValidator(host: host, port: port)
            let client = try await SSHClient.connect(
                host: host,
                port: port,
                authenticationMethod: .passwordBased(username: username, password: password),
                hostKeyValidator: tofuValidator.validator(),
                reconnect: .never
            )

            self.client = client
            isConnected = true
            isConnecting = false
            currentDirectory = "~"  // Reset to home on new connection
            output += "Connected! Type commands below.\n\n"

        } catch {
            isConnecting = false
            isConnected = false
            lastError = error.localizedDescription
            output += "Error: \(error.localizedDescription)\n"
            throw SSHError.connectionFailed(error.localizedDescription)
        }
    }

    func disconnect() {
        // Cancel any previous disconnect task
        disconnectTask?.cancel()

        // Store the task to prevent it from becoming dangling
        let clientToClose = client
        disconnectTask = Task {
            try? await clientToClose?.close()
        }

        client = nil
        isConnected = false
        output += "\n[Disconnected]\n"
    }

    func send(_ command: String) {
        guard let client = client, isConnected else { return }

        output += "$ \(command)\n"
        let commandResult = Self.buildCommand(for: command, currentDirectory: currentDirectory)
        let actualCommand = commandResult.command
        currentDirectory = commandResult.updatedDirectory

        Task {
            do {
                // Execute command and get streaming output
                let stream = try await client.executeCommandStream(actualCommand)

                // Process the stream - ExecCommandOutput has stdout/stderr ByteBuffers
                for try await output in stream {
                    let text: String
                    switch output {
                    case .stdout(let buffer):
                        text = String(buffer: buffer)
                    case .stderr(let buffer):
                        text = String(buffer: buffer)
                    }

                    let processedText = self.processAnsiCodes(text)
                    await MainActor.run {
                        self.output += processedText
                    }
                }

            } catch {
                await MainActor.run {
                    self.output += "Error: \(error.localizedDescription)\n"
                    self.lastError = error.localizedDescription
                }
            }

            await MainActor.run {
                self.output += "\n"
            }
        }
    }

    func sendSpecialKey(_ key: SpecialKey) {
        // Special keys don't work well with command execution mode
        // Just show a message
        switch key {
        case .ctrlC:
            output += "^C (use disconnect to end session)\n"
        case .ctrlD:
            disconnect()
        default:
            break
        }
    }

    // Basic ANSI code processing - strip most codes
    private func processAnsiCodes(_ text: String) -> String {
        Self.stripAnsiCodes(text)
    }

    func clearOutput() {
        output = ""
    }

    // MARK: - Image Upload via Base64

    /// Upload image data via SSH command and return the remote file path
    /// Uses base64 encoding to transfer the image reliably
    /// - Parameters:
    ///   - imageData: The image data to upload
    ///   - filename: Optional filename (defaults to timestamped name)
    /// - Returns: The remote file path where the image was saved
    func uploadImage(_ imageData: Data, filename: String? = nil) async throws -> String {
        guard let client = client, isConnected else {
            throw SSHError.notConnected
        }

        // Generate filename with UUID for uniqueness
        let uuid = UUID().uuidString.prefix(8)
        let timestamp = Int(Date().timeIntervalSince1970)
        let actualFilename = filename ?? "img_\(timestamp)_\(uuid).jpg"

        // Remote directory for uploaded images
        let remoteDir = "/tmp/claude-images"
        let remotePath = "\(remoteDir)/\(actualFilename)"

        log.debug("Starting upload of \(imageData.count) bytes to \(remotePath)")

        // Escape paths for safe shell command execution
        let escapedRemoteDir = shellEscape(remoteDir)
        let escapedRemotePath = shellEscape(remotePath)
        let escapedRemotePathB64 = shellEscape("\(remotePath).b64")

        // Ensure the directory exists
        _ = try? await client.executeCommand("mkdir -p \(escapedRemoteDir)")

        // Convert image to base64 (no line wrapping)
        let base64String = imageData.base64EncodedString()
        log.debug("Base64 length: \(base64String.count) chars")

        // Use printf with chunks to avoid command line limits
        // printf '%s' doesn't add newlines and handles base64 chars safely
        // Note: base64 output only contains [A-Za-z0-9+/=] so chunk doesn't need escaping
        let chunkSize = 30000  // Conservative chunk size
        var offset = 0
        var isFirst = true

        while offset < base64String.count {
            let startIndex = base64String.index(base64String.startIndex, offsetBy: offset)
            let endOffset = min(offset + chunkSize, base64String.count)
            let endIndex = base64String.index(base64String.startIndex, offsetBy: endOffset)
            let chunk = String(base64String[startIndex..<endIndex])

            // Use printf '%s' to avoid newline issues
            // Redirect: > for first chunk, >> for subsequent
            let redirect = isFirst ? ">" : ">>"
            let cmd = "printf '%s' '\(chunk)' \(redirect) \(escapedRemotePathB64)"

            _ = try await client.executeCommand(cmd)
            offset = endOffset
            isFirst = false
        }

        // Decode the base64 file to the actual image
        // Use -d for standard base64 decode
        let decodeCmd = "base64 -d \(escapedRemotePathB64) > \(escapedRemotePath) && rm \(escapedRemotePathB64)"
        _ = try await client.executeCommand(decodeCmd)

        // Verify the file was created and has content
        let verifyCmd = "stat -c '%s' \(escapedRemotePath) 2>/dev/null || stat -f '%z' \(escapedRemotePath) 2>/dev/null"
        let verifyResult = try await client.executeCommand(verifyCmd)
        let fileSize = String(buffer: verifyResult).trimmingCharacters(in: .whitespacesAndNewlines)
        log.debug("Uploaded image to: \(remotePath) (\(fileSize) bytes)")

        return remotePath
    }

    // MARK: - Command Execution

    /// Execute a command and return the output
    /// - Parameter command: The command to execute
    /// - Returns: The command output as a string
    func executeCommand(_ command: String) async throws -> String {
        guard let client = client, isConnected else {
            throw SSHError.notConnected
        }

        let result = try await client.executeCommand(command)
        return String(buffer: result)
    }

    /// Execute a command with a timeout
    /// - Parameters:
    ///   - command: The command to execute
    ///   - timeoutSeconds: Maximum time to wait for completion
    /// - Returns: The command output as a string, or nil if timed out
    func executeCommandWithTimeout(_ command: String, timeoutSeconds: Int) async -> String? {
        guard let client = client, isConnected else {
            return nil
        }

        // Escape the command for safe execution within bash -c
        let escapedCommand = escapeCommandForBash(command)
        // Wrap the command with timeout utility
        // Use 'timeout' command if available, otherwise use shell background trick
        let wrappedCommand = "timeout \(timeoutSeconds)s bash -c '\(escapedCommand)' 2>&1 || echo '[TIMEOUT]'"

        do {
            let result = try await client.executeCommand(wrappedCommand)
            let output = String(buffer: result)
            if output.contains("[TIMEOUT]") {
                return nil
            }
            return output
        } catch {
            return nil
        }
    }

    /// Execute a command with auto-connect
    func executeCommandWithAutoConnect(_ command: String, settings: AppSettings) async throws -> String {
        if !isConnected {
            try await autoConnect(settings: settings)
        }
        return try await executeCommand(command)
    }

    /// Auto-connect using the best available authentication method
    /// Priority: 1) SSH Config hosts, 2) Keychain key, 3) Filesystem key, 4) Password
    func autoConnect(settings: AppSettings) async throws {
        let username = settings.sshUsername.isEmpty ? NSUserName() : settings.sshUsername

        // 1. Try SSH config hosts first (Mac only - has access to ~/.ssh/config)
        if let configHost = availableHosts.first(where: {
            $0.hostName == settings.effectiveSSHHost || $0.host.contains("claude")
        }) {
            try await connectWithConfigHost(configHost.host)
            return
        }

        // 2. Try Keychain key (works on iPhone)
        if KeychainHelper.shared.hasSSHKey {
            try await connectWithKeychainKey(
                host: settings.effectiveSSHHost,
                port: settings.sshPort,
                username: username
            )
            return
        }

        // 3. Try filesystem key (Mac only)
        if settings.sshAuthType == .publicKey {
            let keyPath = getRealHomeDirectory() + "/.ssh/id_ed25519"
            if FileManager.default.fileExists(atPath: keyPath) {
                try await connectWithKey(
                    host: settings.effectiveSSHHost,
                    port: settings.sshPort,
                    username: username,
                    privateKeyPath: keyPath
                )
                return
            }
        }

        // 4. Fall back to password auth
        try await connect(
            host: settings.effectiveSSHHost,
            port: settings.sshPort,
            username: username,
            password: settings.sshPassword
        )
    }

    // MARK: - File Listing

    /// List files in a remote directory
    /// - Parameter path: The remote directory path (can include ~)
    /// - Returns: Array of FileEntry objects
    func listFiles(_ path: String) async throws -> [FileEntry] {
        guard let client = client, isConnected else {
            throw SSHError.notConnected
        }

        // Use ls -la with specific format for parsing
        // -A shows hidden files except . and ..
        let cmd = "ls -laF \(shellEscape(path)) 2>/dev/null | tail -n +2"
        let result = try await client.executeCommand(cmd)
        let output = String(buffer: result)

        var entries: [FileEntry] = []
        for line in output.components(separatedBy: "\n") {
            guard !line.isEmpty else { continue }
            if let entry = FileEntry.parse(from: line, basePath: path) {
                entries.append(entry)
            }
        }

        // Sort: directories first, then alphabetically
        return entries.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    // MARK: - Git Operations

    /// Check if a path is a git repository
    func isGitRepo(_ path: String) async throws -> Bool {
        guard let client = client, isConnected else {
            throw SSHError.notConnected
        }

        let cmd = "cd \(shellEscape(path)) && git rev-parse --is-inside-work-tree 2>/dev/null"
        let result = try await client.executeCommand(cmd)
        let output = String(buffer: result).trimmingCharacters(in: .whitespacesAndNewlines)
        return output == "true"
    }

    /// Check git status for a project path
    /// Returns a GitStatus enum indicating the sync state
    func checkGitStatus(_ path: String) async throws -> GitStatus {
        guard let client = client, isConnected else {
            throw SSHError.notConnected
        }

        // First check if it's a git repo
        // Use `|| echo "false"` to ensure command succeeds even if not a git repo
        let escapedPath = shellEscape(path)
        let isGitCmd = "cd \(escapedPath) && git rev-parse --is-inside-work-tree 2>/dev/null || echo 'false'"
        let isGitResult = try await client.executeCommand(isGitCmd)
        let isGit = String(buffer: isGitResult).trimmingCharacters(in: .whitespacesAndNewlines)

        if isGit != "true" {
            return .notGitRepo
        }

        // Check for uncommitted changes (including untracked files)
        // Use `|| true` to ensure command succeeds even on git errors
        let statusCmd = "cd \(escapedPath) && git status --porcelain 2>/dev/null || true"
        let statusResult = try await client.executeCommand(statusCmd)
        let statusOutput = String(buffer: statusResult).trimmingCharacters(in: .whitespacesAndNewlines)
        let hasUncommittedChanges = !statusOutput.isEmpty

        // Fetch remote to get accurate ahead/behind (non-blocking, with timeout)
        _ = try? await client.executeCommand("cd \(escapedPath) && timeout 5s git fetch --quiet 2>/dev/null || true")

        // Check ahead/behind status relative to upstream
        // Use `|| echo ""` to handle repos without upstream configured (returns empty string)
        let revListCmd = "cd \(escapedPath) && git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null || echo ''"
        let revListResult = try await client.executeCommand(revListCmd)
        let revListOutput = String(buffer: revListResult).trimmingCharacters(in: .whitespacesAndNewlines)

        var aheadCount = 0
        var behindCount = 0

        // Parse "ahead\tbehind" format
        let parts = revListOutput.split(separator: "\t")
        if parts.count == 2 {
            aheadCount = Int(parts[0]) ?? 0
            behindCount = Int(parts[1]) ?? 0
        }

        // Determine status based on combinations
        if hasUncommittedChanges {
            if aheadCount > 0 {
                return .dirtyAndAhead
            }
            return .dirty
        }

        if aheadCount > 0 && behindCount > 0 {
            return .diverged
        }

        if aheadCount > 0 {
            return .ahead(aheadCount)
        }

        if behindCount > 0 {
            return .behind(behindCount)
        }

        return .clean
    }

    /// Check git status with auto-connect
    /// Returns .unknown for connection failures (SSH not configured) to avoid showing errors
    /// Returns .error only for actual git command failures after successful connection
    func checkGitStatusWithAutoConnect(_ path: String, settings: AppSettings) async -> GitStatus {
        // Try to connect if not already connected
        if !isConnected {
            do {
                try await autoConnect(settings: settings)
            } catch {
                // Connection failure is expected when SSH is not configured (e.g., iOS Simulator)
                // Silently return .unknown instead of showing an error
                log.debug("SSH connection not available for git status check: \(error.localizedDescription)")
                return .unknown
            }
        }

        // Now try to check git status (we have a connection)
        do {
            return try await checkGitStatus(path)
        } catch {
            // This is an actual git command failure, report it
            log.error("Failed to check git status for \(path): \(error)")
            return .error(error.localizedDescription)
        }
    }

    /// Pull latest changes from remote (fast-forward only)
    /// Returns true if successful, false otherwise
    func gitPull(_ path: String) async throws -> Bool {
        guard let client = client, isConnected else {
            throw SSHError.notConnected
        }

        let cmd = "cd \(shellEscape(path)) && git pull --ff-only 2>&1"
        let result = try await client.executeCommand(cmd)
        let output = String(buffer: result).trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for success indicators
        if output.contains("Already up to date") || output.contains("Fast-forward") {
            log.info("Git pull successful for \(path)")
            return true
        }

        // Check for failure indicators
        if output.contains("fatal:") || output.contains("error:") {
            log.warning("Git pull failed for \(path): \(output)")
            return false
        }

        return true
    }

    /// Pull with auto-connect
    func gitPullWithAutoConnect(_ path: String, settings: AppSettings) async -> Bool {
        do {
            if !isConnected {
                try await autoConnect(settings: settings)
            }
            return try await gitPull(path)
        } catch {
            log.error("Failed to git pull for \(path): \(error)")
            return false
        }
    }

    /// Get git diff summary for dirty repos
    func getGitDiffSummary(_ path: String) async throws -> String {
        guard let client = client, isConnected else {
            throw SSHError.notConnected
        }

        // Get a summary of changes: modified files, untracked files, staged changes
        let escapedPath = shellEscape(path)
        let cmd = """
        cd \(escapedPath) && echo "=== Git Status ===" && git status --short && \
        echo "" && echo "=== Recent Commits (unpushed) ===" && \
        git log --oneline @{upstream}..HEAD 2>/dev/null || echo "(no upstream)" && \
        echo "" && echo "=== Diff Stats ===" && git diff --stat 2>/dev/null
        """

        let result = try await client.executeCommand(cmd)
        return String(buffer: result)
    }

    // MARK: - Multi-Repo Discovery

    /// Discover nested git repositories within a project directory
    /// Scans up to maxDepth levels deep for subdirectories containing .git folders
    /// - Parameters:
    ///   - basePath: The root project path to scan
    ///   - maxDepth: Maximum depth to scan (default 2)
    /// - Returns: Array of relative paths to directories containing .git
    func discoverSubRepos(_ basePath: String, maxDepth: Int = 2) async throws -> [String] {
        guard let client = client, isConnected else {
            throw SSHError.notConnected
        }

        let escapedPath = shellEscape(basePath)

        // Use find to locate .git entries, then extract parent paths
        // -mindepth 2 excludes the root .git folder (depth 1 would be ./.git)
        // Git submodules use a .git FILE (not directory) that points to the actual repo,
        // so we need to find both -type d (regular repos) and -type f (submodules)
        // Output format: ./packages/api (relative paths)
        let cmd = """
        cd \(escapedPath) && find . -mindepth 2 -maxdepth \(maxDepth + 1) -name '.git' \\( -type d -o -type f \\) 2>/dev/null | \
        sed 's|/\\.git$||' | \
        sed 's|^\\./||' | \
        sort
        """

        let result = try await client.executeCommand(cmd)
        let output = String(buffer: result).trimmingCharacters(in: .whitespacesAndNewlines)

        guard !output.isEmpty else {
            return []
        }

        // Parse output: one relative path per line
        return output
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Discover nested git repositories with auto-connect
    func discoverSubReposWithAutoConnect(_ basePath: String, maxDepth: Int = 2, settings: AppSettings) async -> [String] {
        do {
            if !isConnected {
                try await autoConnect(settings: settings)
            }
            return try await discoverSubRepos(basePath, maxDepth: maxDepth)
        } catch {
            log.error("Failed to discover sub-repos in \(basePath): \(error)")
            return []
        }
    }

    /// Check git status for multiple sub-repositories sequentially
    /// Note: Sequential execution is used because the Citadel SSH library doesn't handle
    /// concurrent executeCommand calls reliably - running multiple git status checks
    /// in parallel causes channel/connection errors for most of the requests.
    /// - Parameters:
    ///   - basePath: The root project path
    ///   - subRepoPaths: Array of relative paths to sub-repos
    /// - Returns: Dictionary mapping relative path to GitStatus
    func checkMultiRepoStatus(_ basePath: String, subRepoPaths: [String]) async -> [String: GitStatus] {
        guard isConnected else {
            return Dictionary(uniqueKeysWithValues: subRepoPaths.map { ($0, GitStatus.unknown) })
        }

        // Check sub-repos sequentially to avoid SSH channel conflicts
        // Each checkGitStatus runs multiple SSH commands, and concurrent execution
        // causes most checks to fail with connection errors
        var results: [String: GitStatus] = [:]
        for relativePath in subRepoPaths {
            let fullPath = (basePath as NSString).appendingPathComponent(relativePath)
            do {
                let status = try await self.checkGitStatus(fullPath)
                results[relativePath] = status
            } catch {
                results[relativePath] = .error(error.localizedDescription)
            }
        }
        return results
    }

    /// Check git status for multiple sub-repositories with auto-connect
    func checkMultiRepoStatusWithAutoConnect(
        _ basePath: String,
        subRepoPaths: [String],
        settings: AppSettings
    ) async -> [String: GitStatus] {
        do {
            if !isConnected {
                try await autoConnect(settings: settings)
            }
            return await checkMultiRepoStatus(basePath, subRepoPaths: subRepoPaths)
        } catch {
            log.error("Failed to check multi-repo status for \(basePath): \(error)")
            return Dictionary(uniqueKeysWithValues: subRepoPaths.map { ($0, GitStatus.unknown) })
        }
    }

    /// Pull a specific sub-repository
    func pullSubRepo(_ basePath: String, relativePath: String, settings: AppSettings) async -> Bool {
        let fullPath = (basePath as NSString).appendingPathComponent(relativePath)
        return await gitPullWithAutoConnect(fullPath, settings: settings)
    }

    /// Pull all sub-repositories that are behind
    /// Note: Sequential execution to avoid SSH channel conflicts (see checkMultiRepoStatus)
    /// - Returns: Dictionary of relativePath -> success/failure
    func pullAllBehindSubRepos(
        _ basePath: String,
        subRepos: [SubRepo],
        settings: AppSettings
    ) async -> [String: Bool] {
        let behindRepos = subRepos.filter { $0.status.canAutoPull }

        // Pull repos sequentially to avoid SSH channel conflicts
        var results: [String: Bool] = [:]
        for subRepo in behindRepos {
            let success = await self.pullSubRepo(basePath, relativePath: subRepo.relativePath, settings: settings)
            results[subRepo.relativePath] = success
        }
        return results
    }

    /// List files with auto-connect
    func listFilesWithAutoConnect(_ path: String, settings: AppSettings) async throws -> [FileEntry] {
        if !isConnected {
            try await autoConnect(settings: settings)
        }
        return try await listFiles(path)
    }

    // MARK: - File Reading

    /// Read a remote file and return its contents as a string
    /// - Parameter path: The remote file path (can include ~)
    /// - Returns: The file contents as a string
    func readFile(_ path: String) async throws -> String {
        guard let client = client, isConnected else {
            throw SSHError.notConnected
        }

        // Use cat to read the file
        let cmd = "cat \(shellEscape(path))"
        let result = try await client.executeCommand(cmd)
        return String(buffer: result)
    }

    /// Read a remote file and return its contents, connecting first if needed
    /// - Parameters:
    ///   - path: The remote file path
    ///   - settings: AppSettings to use for connection if not connected
    /// - Returns: The file contents as a string
    func readFileWithAutoConnect(_ path: String, settings: AppSettings) async throws -> String {
        if !isConnected {
            try await autoConnect(settings: settings)
        }
        return try await readFile(path)
    }

    // MARK: - Session Loading via SSH

    /// Load all sessions for a project via SSH
    /// Returns ProjectSession objects with metadata extracted from session files
    /// - Parameters:
    ///   - projectPath: The project's absolute path (e.g., /home/dev/workspace/ClaudeCodeApp)
    ///   - settings: AppSettings for auto-connect if needed
    /// - Returns: Array of ProjectSession objects sorted by last activity
    func loadAllSessions(for projectPath: String, settings: AppSettings) async throws -> [ProjectSession] {
        if !isConnected {
            try await autoConnect(settings: settings)
        }

        // Encode project path for Claude session directory
        // /home/dev/workspace/ClaudeCodeApp → -home-dev-workspace-ClaudeCodeApp
        let encodedPath = projectPath.replacingOccurrences(of: "/", with: "-")
        // Use $HOME for consistent shell expansion (~ doesn't expand in all contexts)
        // Shell-escape the encoded path to prevent command injection
        let escapedEncodedPath = shellEscape(encodedPath)

        // Get session files with metadata and first REAL user message for summary
        // Uses jq for proper JSON parsing (handles both array and string content formats)
        // Filters: meta messages, ClaudeHelper prompts, system error messages
        // Extracts: session_id|line_count|mtime|first_user_message_text
        let command = """
            cd "$HOME/.claude/projects"/\(escapedEncodedPath) && ls -1 *.jsonl 2>/dev/null | grep -v '^agent-' | while read f; do
                name=$(basename "$f" .jsonl)
                lines=$(wc -l < "$f" | tr -d ' ')
                mtime=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null)
                # Extract first real user message using jq (handles both content formats)
                summary=$(grep '"type":"user"' "$f" 2>/dev/null | jq -r 'select(.isMeta != true) | (if .message.content | type == "array" then .message.content[0].text elif .message.content | type == "string" then .message.content else empty end) // empty' 2>/dev/null | grep -v '^Based on this conversation' | grep -v 'which files would be most relevant' | grep -v '^Caveat:' | grep -v '^Unknown slash command' | head -1 | head -c 80 || echo "")
                echo "$name|$lines|$mtime|$summary"
            done
            """

        let output = try await executeCommand(command)
        var sessions: [ProjectSession] = []

        for line in output.components(separatedBy: .newlines) {
            guard !line.isEmpty else { continue }
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 3 else { continue }

            let sessionId = parts[0]
            let lineCount = Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
            let mtime = Double(parts[2].trimmingCharacters(in: .whitespaces)) ?? 0

            // Skip empty sessions (0 lines)
            guard lineCount >= 1 else { continue }

            // Convert mtime to ISO8601 string
            let date = Date(timeIntervalSince1970: mtime)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            let lastActivity = formatter.string(from: date)

            // Extract summary from 4th field if available
            var summary: String? = nil
            if parts.count >= 4 {
                let rawSummary = parts[3...].joined(separator: "|").trimmingCharacters(in: .whitespacesAndNewlines)
                if !rawSummary.isEmpty {
                    // Clean up the summary - take first 50 chars
                    summary = String(rawSummary.prefix(50))
                }
            }

            // Skip ClaudeHelper sessions (generated for AI suggestions)
            // These have deterministic IDs based on project path hash
            let helperSessionId = ClaudeHelper.createHelperSessionId(for: projectPath)
            if sessionId == helperSessionId {
                continue
            }

            sessions.append(ProjectSession(
                id: sessionId,
                summary: summary,
                messageCount: lineCount,
                lastActivity: lastActivity,
                lastUserMessage: summary,  // Use summary as last user message too
                lastAssistantMessage: nil
            ))
        }

        // Sort by last activity (most recent first)
        return sessions.sorted { s1, s2 in
            (s1.lastActivity ?? "") > (s2.lastActivity ?? "")
        }
    }

    /// Count sessions for a project (fast - just counts files)
    /// Returns count of non-empty, non-agent, non-helper sessions
    func countSessions(for projectPath: String, settings: AppSettings) async throws -> Int {
        if !isConnected {
            try await autoConnect(settings: settings)
        }

        let encodedPath = projectPath.replacingOccurrences(of: "/", with: "-")
        // Shell-escape the encoded path to prevent command injection
        let escapedEncodedPath = shellEscape(encodedPath)

        // Get the helper session ID to exclude it (already a safe UUID format)
        let helperSessionId = ClaudeHelper.createHelperSessionId(for: projectPath)

        // Count non-agent session files that have content (at least 1 line)
        // Also exclude helper sessions used for AI suggestions
        let command = """
            cd "$HOME/.claude/projects"/\(escapedEncodedPath) 2>/dev/null && ls -1 *.jsonl 2>/dev/null | grep -v '^agent-' | grep -v '^\(helperSessionId).jsonl$' | while read f; do
                [ -s "$f" ] && echo "$f"
            done | wc -l | tr -d ' '
            """

        let output = try await executeCommand(command)
        return Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    /// Count sessions for multiple projects efficiently (single SSH connection)
    /// Excludes agent sessions and helper sessions used for AI suggestions
    func countSessionsForProjects(_ projectPaths: [String], settings: AppSettings) async throws -> [String: Int] {
        if !isConnected {
            try await autoConnect(settings: settings)
        }

        var results: [String: Int] = [:]

        // Process in batches to avoid command line length limits
        for path in projectPaths {
            let encodedPath = path.replacingOccurrences(of: "/", with: "-")
            // Shell-escape the encoded path to prevent command injection
            let escapedEncodedPath = shellEscape(encodedPath)

            // Get the helper session ID to exclude it (already a safe UUID format)
            let helperSessionId = ClaudeHelper.createHelperSessionId(for: path)

            let command = """
                cd "$HOME/.claude/projects"/\(escapedEncodedPath) 2>/dev/null && ls -1 *.jsonl 2>/dev/null | grep -v '^agent-' | grep -v '^\(helperSessionId).jsonl$' | while read f; do
                    [ -s "$f" ] && echo "$f"
                done | wc -l | tr -d ' '
                """

            do {
                let output = try await executeCommand(command)
                let count = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                results[path] = count
            } catch {
                // If we can't get count for a project, just skip it
                print("[SSHManager] Failed to count sessions for \(path): \(error)")
            }
        }

        return results
    }
}

// MARK: - File Entry

struct FileEntry: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let isSymlink: Bool
    let size: Int64
    let permissions: String

    var icon: String {
        if isSymlink {
            return "link"
        } else if isDirectory {
            return "folder.fill"
        } else if name.hasSuffix(".swift") || name.hasSuffix(".ts") || name.hasSuffix(".js") ||
                  name.hasSuffix(".py") || name.hasSuffix(".go") || name.hasSuffix(".rs") {
            return "doc.text.fill"
        } else if name.hasSuffix(".json") || name.hasSuffix(".yaml") || name.hasSuffix(".yml") ||
                  name.hasSuffix(".toml") || name.hasSuffix(".xml") {
            return "doc.badge.gearshape.fill"
        } else if name.hasSuffix(".md") || name.hasSuffix(".txt") || name.hasSuffix(".rst") {
            return "doc.richtext.fill"
        } else if name.hasSuffix(".png") || name.hasSuffix(".jpg") || name.hasSuffix(".gif") ||
                  name.hasSuffix(".svg") || name.hasSuffix(".webp") {
            return "photo.fill"
        } else {
            return "doc.fill"
        }
    }

    var formattedSize: String {
        if isDirectory { return "" }
        if size < 1024 { return "\(size) B" }
        if size < 1024 * 1024 { return String(format: "%.1f KB", Double(size) / 1024) }
        if size < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(size) / (1024 * 1024)) }
        return String(format: "%.1f GB", Double(size) / (1024 * 1024 * 1024))
    }

    /// Parse ls -laF output line into FileEntry
    static func parse(from line: String, basePath: String) -> FileEntry? {
        // Format: -rw-r--r--  1 user group  1234 Dec 26 12:34 filename
        // With -F: directories have /, symlinks have @, executables have *
        let components = line.split(separator: " ", omittingEmptySubsequences: true)
        guard components.count >= 9 else { return nil }

        let permissions = String(components[0])
        let sizeStr = String(components[4])
        // Filename is everything after the date/time (columns 5-8)
        let nameStartIndex = components.dropFirst(8).first.map { line.range(of: String($0))?.lowerBound } ?? nil
        guard let startIndex = nameStartIndex else { return nil }

        var name = String(line[startIndex...]).trimmingCharacters(in: .whitespaces)

        // Handle symlinks: name -> target
        var isSymlink = false
        if permissions.hasPrefix("l") {
            isSymlink = true
            if let arrowRange = name.range(of: " -> ") {
                name = String(name[..<arrowRange.lowerBound])
            }
        }

        // Remove trailing type indicators from -F flag
        let isDirectory = name.hasSuffix("/") || permissions.hasPrefix("d")
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: "/*@"))

        // Skip . and ..
        if name == "." || name == ".." { return nil }

        let size = Int64(sizeStr) ?? 0
        let path = basePath == "/" ? "/\(name)" :
                   basePath.hasSuffix("/") ? "\(basePath)\(name)" : "\(basePath)/\(name)"

        return FileEntry(
            name: name,
            path: path,
            isDirectory: isDirectory,
            isSymlink: isSymlink,
            size: size,
            permissions: permissions
        )
    }
}

// Special keys for terminal
enum SpecialKey {
    case ctrlC
    case ctrlD
    case ctrlZ
    case ctrlL
    case tab
    case escape
    case up
    case down
    case left
    case right

    var sequence: String {
        switch self {
        case .ctrlC: return "\u{03}"
        case .ctrlD: return "\u{04}"
        case .ctrlZ: return "\u{1A}"
        case .ctrlL: return "\u{0C}"
        case .tab: return "\t"
        case .escape: return "\u{1B}"
        case .up: return "\u{1B}[A"
        case .down: return "\u{1B}[B"
        case .right: return "\u{1B}[C"
        case .left: return "\u{1B}[D"
        }
    }
}
