import Foundation
import Citadel
import NIOSSH
import Crypto
import CryptoKit

// MARK: - SSHManager Connection Extensions

extension SSHManager {
    // MARK: - SSH Config Host Connection

    /// Connect using SSH config host alias (e.g., "claude-dev")
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

    // MARK: - Key-Based Connection

    /// Connect with SSH key from file path
    func connectWithKey(host: String, port: Int, username: String, privateKeyPath: String, passphrase: String? = nil) async throws {
        // Read the private key from file
        guard let keyData = FileManager.default.contents(atPath: privateKeyPath),
              let privateKeyString = String(data: keyData, encoding: .utf8) else {
            throw SSHError.keyNotFound(privateKeyPath)
        }

        try await connectWithKeyString(host: host, port: port, username: username, privateKeyString: privateKeyString, passphrase: passphrase)
    }

    /// Connect with SSH key from Keychain
    func connectWithKeychainKey(host: String, port: Int, username: String) async throws {
        guard let privateKeyString = KeychainHelper.shared.retrieveSSHKey() else {
            throw SSHError.keyNotFound("No SSH key stored in Keychain")
        }

        let passphrase = KeychainHelper.shared.retrievePassphrase()
        try await connectWithKeyString(host: host, port: port, username: username, privateKeyString: privateKeyString, passphrase: passphrase)
    }

    /// Connect with SSH key string (shared implementation)
    func connectWithKeyString(host: String, port: Int, username: String, privateKeyString: String, passphrase: String? = nil) async throws {
        self.host = host
        self.port = port
        self.username = username

        isConnecting = true
        lastError = nil
        output = "Connecting to \(username)@\(host):\(port) with key...\n"

        let connectionStart = CFAbsoluteTimeGetCurrent()
        log.info("[SSH] Starting connection to \(host):\(port)")

        do {
            // Detect key type and create appropriate authentication method
            let detectStart = CFAbsoluteTimeGetCurrent()
            let keyType = try SSHKeyDetection.detectPrivateKeyType(from: privateKeyString)
            log.info("[SSH] Key detection took \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - detectStart) * 1000))ms - type: \(keyType)")

            let authMethod: SSHAuthenticationMethod

            let parseStart = CFAbsoluteTimeGetCurrent()
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
            log.info("[SSH] Key parsing took \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - parseStart) * 1000))ms")

            // Connect with key authentication using TOFU host key validation
            let tofuValidator = TOFUHostKeyValidator(host: host, port: port)
            let connectStart = CFAbsoluteTimeGetCurrent()
            log.info("[SSH] Starting SSHClient.connect()...")
            let client = try await clientFactory.connect(
                host: host,
                port: port,
                authenticationMethod: authMethod,
                hostKeyValidator: tofuValidator
            )
            log.info("[SSH] SSHClient.connect() took \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - connectStart) * 1000))ms")

            self.client = client
            isConnected = true
            isConnecting = false
            currentDirectory = "~"  // Reset to home on new connection
            output += "Connected! Type commands below.\n\n"
            log.info("[SSH] Total connection time: \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - connectionStart) * 1000))ms")

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

    // MARK: - Password Connection

    /// Connect with password (fallback)
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
            let client = try await clientFactory.connect(
                host: host,
                port: port,
                authenticationMethod: .passwordBased(username: username, password: password),
                hostKeyValidator: tofuValidator
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

    // MARK: - Auto Connect

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

    // MARK: - Internal Helpers

    /// Find default SSH key
    internal func findDefaultKey() -> String? {
        let homeDir = getRealHomeDirectory()
        let sshDir = homeDir + "/.ssh"
        let defaultKeys = ["id_ed25519", "id_rsa", "id_ecdsa", "id_dsa"]

        for keyName in defaultKeys {
            let keyPath = sshDir + "/" + keyName
            if FileManager.default.fileExists(atPath: keyPath) {
                return keyPath
            }
        }
        return nil
    }
}
