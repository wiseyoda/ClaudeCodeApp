import Foundation
import Security
import NIOCore
import NIOSSH
import CryptoKit
import Citadel

// MARK: - Keychain Helper

/// Helper for secure SSH key storage in iOS Keychain
class KeychainHelper {
    static let shared = KeychainHelper()

    // Keychain service identifier
    private let service = "com.codingbridge.sshkeys"

    // Account keys for different stored items
    private enum Account: String {
        case privateKey = "ssh_private_key"
        case passphrase = "ssh_key_passphrase"
        case sshPassword = "ssh_password"
        // Auth credentials for cli-bridge server
        case authPassword = "auth_password"
        case authToken = "auth_token"
        case apiKey = "api_key"
        // Push notification credentials
        case userId = "user_id"
        case fcmToken = "fcm_token"
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

    // MARK: - Auth Password (cli-bridge server)

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

    // MARK: - Auth Token (JWT for cli-bridge server)

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

    // MARK: - API Key (for cli-bridge REST endpoints)

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

    // MARK: - User ID (for push notification registration)

    /// Get or create a unique user ID for push notification registration
    /// The ID is generated once and persisted in Keychain
    func getOrCreateUserId() -> String {
        // Try to retrieve existing user ID
        if let existingId = retrieveUserId() {
            return existingId
        }

        // Generate new UUID and store it
        let newId = UUID().uuidString
        storeUserId(newId)
        log.info("Generated new user ID for push notifications")
        return newId
    }

    /// Store the user ID securely
    @discardableResult
    private func storeUserId(_ userId: String) -> Bool {
        guard !userId.isEmpty, let data = userId.data(using: .utf8) else {
            return false
        }
        deleteUserId()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Account.userId.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieve the stored user ID
    func retrieveUserId() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Account.userId.rawValue,
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

    /// Delete the stored user ID
    @discardableResult
    func deleteUserId() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Account.userId.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - FCM Token (Firebase Cloud Messaging)

    /// Store the FCM token securely
    @discardableResult
    func storeFCMToken(_ token: String) -> Bool {
        guard !token.isEmpty, let data = token.data(using: .utf8) else {
            deleteFCMToken()
            return true
        }
        deleteFCMToken()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Account.fcmToken.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            log.info("FCM token stored in Keychain")
            return true
        } else {
            log.error("Failed to store FCM token: \(status)")
            return false
        }
    }

    /// Retrieve the stored FCM token
    func retrieveFCMToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Account.fcmToken.rawValue,
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

    /// Delete the stored FCM token
    @discardableResult
    func deleteFCMToken() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Account.fcmToken.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Check if an FCM token is stored
    var hasFCMToken: Bool {
        retrieveFCMToken() != nil
    }

    /// Remove all stored SSH credentials
    func clearAll() {
        deleteSSHKey()
        deletePassphrase()
        deleteSSHPassword()
        log.info("All SSH credentials cleared from Keychain")
    }

    /// Remove all stored credentials (SSH, auth, and push)
    func clearAllCredentials() {
        deleteSSHKey()
        deletePassphrase()
        deleteSSHPassword()
        deleteAuthPassword()
        deleteAuthToken()
        deleteAPIKey()
        deleteUserId()
        deleteFCMToken()
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
final class TOFUHostKeyValidator: NIOSSHClientServerAuthenticationDelegate, @unchecked Sendable {
    let host: String
    let port: Int

    /// Create a TOFU validator for a specific host and port
    init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    /// Create an SSHHostKeyValidator using TOFU strategy
    func validator() -> SSHHostKeyValidator {
        return .custom(self)
    }

    /// Validate host key using TOFU strategy (NIOSSHClientServerAuthenticationDelegate)
    func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        // Compute fingerprint from the public key
        let fingerprint = computeFingerprint(from: hostKey)

        // Check if we have a stored fingerprint for this host
        if let storedFingerprint = KeychainHelper.shared.retrieveHostKeyFingerprint(host: host, port: port) {
            // Verify the fingerprint matches
            if storedFingerprint == fingerprint {
                validationCompletePromise.succeed(())  // Success - fingerprint matches
            } else {
                // CRITICAL: Fingerprint mismatch - possible MITM attack
                log.error("SSH host key mismatch for \(host):\(port)!")
                log.error("Expected: \(storedFingerprint)")
                log.error("Received: \(fingerprint)")
                validationCompletePromise.fail(SSHHostKeyError.mismatch(expected: storedFingerprint, received: fingerprint))
            }
        } else {
            // First connection - trust and store the fingerprint
            log.info("First SSH connection to \(host):\(port) - storing host key fingerprint")
            KeychainHelper.shared.storeHostKeyFingerprint(fingerprint, host: host, port: port)
            validationCompletePromise.succeed(())  // Success - trusted on first use
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
