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


// MARK: - SSH Error

enum SSHError: LocalizedError {
    case connectionFailed(String)
    case authenticationFailed
    case notConnected
    case keyNotFound(String)
    case unsupportedKeyType(String)
    case keyParseError(String)
    case timeout
    case connectionReset

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let reason): return "Connection failed: \(reason)"
        case .authenticationFailed: return "Authentication failed"
        case .notConnected: return "Not connected"
        case .keyNotFound(let path): return "SSH key not found: \(path)"
        case .unsupportedKeyType(let type): return "Unsupported key type: \(type)"
        case .keyParseError(let reason): return "Failed to parse key: \(reason)"
        case .timeout: return "Connection timed out"
        case .connectionReset: return "Connection was reset"
        }
    }

    /// Whether this error is transient and the operation can be retried
    var isTransient: Bool {
        switch self {
        case .connectionFailed(let reason):
            // Check for transient connection issues
            let transientPatterns = ["reset", "timed out", "timeout", "temporarily", "try again", "ECONNRESET"]
            return transientPatterns.contains { reason.lowercased().contains($0.lowercased()) }
        case .notConnected, .timeout, .connectionReset:
            return true
        case .authenticationFailed, .keyNotFound, .unsupportedKeyType, .keyParseError:
            return false
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

        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            log.warning("Could not read SSH config")
            return
        }

        let hosts = Self.parseSSHConfig(content, homeDirectory: homeDir)
        availableHosts = hosts
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
                return keyPath
            }
        }
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
            let client = try await SSHClient.connect(
                host: host,
                port: port,
                authenticationMethod: authMethod,
                hostKeyValidator: tofuValidator.validator(),
                reconnect: .never
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

        // Escape paths for safe shell command execution
        let escapedRemoteDir = shellEscape(remoteDir)
        let escapedRemotePath = shellEscape(remotePath)
        let escapedRemotePathB64 = shellEscape("\(remotePath).b64")

        // Ensure the directory exists
        _ = try? await client.executeCommand("mkdir -p \(escapedRemoteDir)")

        // Convert image to base64 (no line wrapping)
        let base64String = imageData.base64EncodedString()

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
        _ = try await client.executeCommand(verifyCmd)

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

    /// Execute a command with automatic retry for transient failures
    /// - Parameters:
    ///   - command: The command to execute
    ///   - settings: App settings for auto-connect
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - retryDelay: Delay between retries in seconds (default: 1.0)
    /// - Returns: The command output as a string
    func executeCommandWithRetry(
        _ command: String,
        settings: AppSettings,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0
    ) async throws -> String {
        var lastError: Error?
        var attemptCount = 0

        while attemptCount < maxRetries {
            attemptCount += 1

            do {
                // Ensure connected before each attempt
                if !isConnected {
                    try await autoConnect(settings: settings)
                }

                return try await executeCommand(command)
            } catch let error as SSHError where error.isTransient {
                lastError = error
                log.warning("SSH transient error (attempt \(attemptCount)/\(maxRetries)): \(error.localizedDescription)")

                // Disconnect and wait before retry
                disconnect()

                if attemptCount < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                }
            } catch let error as NIOSSHError {
                // Check if NIO SSH error is transient
                let errorStr = String(describing: error)
                let isTransient = errorStr.contains("reset") ||
                                  errorStr.contains("closed") ||
                                  errorStr.contains("timeout")

                if isTransient && attemptCount < maxRetries {
                    lastError = error
                    log.warning("NIO SSH transient error (attempt \(attemptCount)/\(maxRetries)): \(errorStr.prefix(100))")
                    disconnect()
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                } else {
                    throw error
                }
            } catch {
                // Non-transient error, don't retry
                throw error
            }
        }

        // All retries exhausted
        log.error("SSH command failed after \(maxRetries) attempts")
        throw lastError ?? SSHError.connectionFailed("Max retries exceeded")
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

    // Session loading via SSH has been removed.
    // Sessions are now loaded via API using SessionStore and SessionRepository.
    // See: SessionRepository.swift, SessionStore.swift
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
        }

        // Get file extension
        let ext = (name as NSString).pathExtension.lowercased()

        switch ext {
        case "swift": return "swift"
        case "ts", "tsx": return "t.square"
        case "js", "jsx", "mjs": return "j.square"
        case "json": return "curlybraces"
        case "md", "markdown": return "doc.text"
        case "png", "jpg", "jpeg", "gif", "webp", "svg": return "photo"
        case "pdf": return "doc.richtext"
        case "html", "htm": return "globe"
        case "css", "scss", "less": return "paintbrush"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "rs": return "gearshape.2"
        case "go": return "bolt"
        case "rb": return "diamond"
        case "java", "kt": return "cup.and.saucer"
        case "sh", "bash", "zsh": return "terminal"
        case "yml", "yaml", "toml": return "gearshape"
        case "lock": return "lock"
        case "env": return "key"
        case "gitignore", "dockerignore": return "eye.slash"
        case "txt", "rst": return "doc.text"
        case "xml": return "chevron.left.forwardslash.chevron.right"
        default: return "doc"
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
