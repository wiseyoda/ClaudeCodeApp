import Foundation
import Citadel
import NIOCore
import Crypto

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
    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var output: String = ""
    @Published var lastError: String?
    @Published var availableHosts: [SSHConfigEntry] = []

    private var client: SSHClient?

    var host: String = ""
    var port: Int = 22
    var username: String = ""
    var currentDirectory: String = "~"  // Track working directory

    init() {
        loadSSHConfig()
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

    // Parse ~/.ssh/config to get available hosts
    func loadSSHConfig() {
        let homeDir = getRealHomeDirectory()
        let configPath = homeDir + "/.ssh/config"

        print("[SSH] Looking for config at: \(configPath)")

        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            print("[SSH] Could not read SSH config")
            return
        }

        print("[SSH] Found SSH config, parsing...")

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
                // Save previous entry if exists
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
                // Expand ~ to real home directory
                let expandedPath = value.replacingOccurrences(of: "~", with: homeDir)
                currentEntry?.identityFile = expandedPath
            default:
                break
            }
        }

        // Don't forget the last entry
        if let entry = currentEntry, !entry.host.contains("*") {
            hosts.append(entry)
        }

        availableHosts = hosts
        print("[SSH] Found \(hosts.count) hosts: \(hosts.map { $0.host })")
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
                print("[SSH] Found default key: \(keyPath)")
                return keyPath
            }
        }
        print("[SSH] No default key found in \(sshDir)")
        return nil
    }

    // Connect with SSH key
    func connectWithKey(host: String, port: Int, username: String, privateKeyPath: String, passphrase: String? = nil) async throws {
        self.host = host
        self.port = port
        self.username = username

        isConnecting = true
        lastError = nil
        output = "Connecting to \(username)@\(host):\(port) with key...\n"

        do {
            // Read the private key
            guard let keyData = FileManager.default.contents(atPath: privateKeyPath),
                  let privateKeyString = String(data: keyData, encoding: .utf8) else {
                throw SSHError.keyNotFound(privateKeyPath)
            }

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

            // Connect with key authentication
            let client = try await SSHClient.connect(
                host: host,
                port: port,
                authenticationMethod: authMethod,
                hostKeyValidator: .acceptAnything(),
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
            // Connect with password authentication
            let client = try await SSHClient.connect(
                host: host,
                port: port,
                authenticationMethod: .passwordBased(username: username, password: password),
                hostKeyValidator: .acceptAnything(),
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
        Task {
            try? await client?.close()
        }
        client = nil
        isConnected = false
        output += "\n[Disconnected]\n"
    }

    func send(_ command: String) {
        guard let client = client, isConnected else { return }

        output += "$ \(command)\n"

        let trimmedCommand = command.trimmingCharacters(in: .whitespaces)
        var actualCommand: String

        // Handle cd commands specially
        if trimmedCommand == "cd" {
            // cd with no args goes home
            currentDirectory = "~"
            actualCommand = "cd ~ && pwd"
        } else if trimmedCommand.hasPrefix("cd ") {
            let newDir = String(trimmedCommand.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            // Build the full cd command from current directory
            actualCommand = "cd \(currentDirectory) && cd \(newDir) && pwd"
            // Update our tracked directory after successful cd
            if newDir.hasPrefix("/") {
                currentDirectory = newDir
            } else if newDir == "~" || newDir.hasPrefix("~/") {
                currentDirectory = newDir
            } else if newDir == ".." {
                if currentDirectory != "~" && currentDirectory != "/" {
                    currentDirectory = (currentDirectory as NSString).deletingLastPathComponent
                    if currentDirectory.isEmpty { currentDirectory = "/" }
                }
            } else if newDir == "-" {
                // cd - is complex, just let it run
                currentDirectory = "~"  // Reset, not perfect but safe
            } else {
                // Relative path
                if currentDirectory == "~" {
                    currentDirectory = "~/\(newDir)"
                } else {
                    currentDirectory = "\(currentDirectory)/\(newDir)"
                }
            }
        } else {
            // Regular command - run from current directory
            actualCommand = "cd \(currentDirectory) && \(command)"
        }

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
        var result = text
        // Remove color codes
        result = result.replacingOccurrences(of: "\u{1B}\\[[0-9;]*m", with: "", options: .regularExpression)
        // Remove cursor movement
        result = result.replacingOccurrences(of: "\u{1B}\\[[0-9;]*[ABCDJKH]", with: "", options: .regularExpression)
        // Remove title setting
        result = result.replacingOccurrences(of: "\u{1B}\\][0-9];[^\u{07}]*\u{07}", with: "", options: .regularExpression)
        // Remove other escape sequences
        result = result.replacingOccurrences(of: "\u{1B}\\[[?0-9;]*[hl]", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "\u{1B}[=>]", with: "", options: .regularExpression)
        return result
    }

    func clearOutput() {
        output = ""
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
