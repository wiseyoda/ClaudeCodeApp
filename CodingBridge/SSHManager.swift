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

private func normalizeHomePath(_ path: String) -> String {
    if path == "~" {
        return "$HOME"
    }
    if path.hasPrefix("~/") {
        return "$HOME" + String(path.dropFirst())
    }
    return path
}

private func escapeForDoubleQuotes(_ value: String) -> String {
    let placeholder = "__HOME_PLACEHOLDER__"
    var escaped = value.replacingOccurrences(of: "$HOME", with: placeholder)
    escaped = escaped.replacingOccurrences(of: "\\", with: "\\\\")
    escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
    escaped = escaped.replacingOccurrences(of: "`", with: "\\`")
    escaped = escaped.replacingOccurrences(of: "$", with: "\\$")
    escaped = escaped.replacingOccurrences(of: placeholder, with: "$HOME")
    return escaped
}

/// Escape a path for safe use in shell commands, expanding ~ to $HOME with double quotes.
func shellEscapePath(_ path: String) -> String {
    let normalized = normalizeHomePath(path)
    if normalized.contains("$HOME") {
        return "\"\(escapeForDoubleQuotes(normalized))\""
    }
    return shellEscape(normalized)
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

struct SSHCommandResult: Equatable {
    let output: String
    let exitCode: Int32
}

enum SSHCommandStreamOutput {
    case stdout(ByteBuffer)
    case stderr(ByteBuffer)
}

protocol SSHClientProtocol: AnyObject {
    func execute(_ command: String) async throws -> SSHCommandResult
    func executeCommandStream(_ command: String) async throws -> AsyncThrowingStream<SSHCommandStreamOutput, Error>
    func disconnect() async throws
}

protocol SSHClientFactory {
    func connect(
        host: String,
        port: Int,
        authenticationMethod: SSHAuthenticationMethod,
        hostKeyValidator: NIOSSHClientServerAuthenticationDelegate
    ) async throws -> SSHClientProtocol
}

final class CitadelSSHClientAdapter: SSHClientProtocol {
    private let client: SSHClient

    init(client: SSHClient) {
        self.client = client
    }

    func execute(_ command: String) async throws -> SSHCommandResult {
        let result = try await client.executeCommand(command)
        return SSHCommandResult(output: String(buffer: result), exitCode: 0)
    }

    func executeCommandStream(_ command: String) async throws -> AsyncThrowingStream<SSHCommandStreamOutput, Error> {
        let stream = try await client.executeCommandStream(command)
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await output in stream {
                        switch output {
                        case .stdout(let buffer):
                            continuation.yield(.stdout(buffer))
                        case .stderr(let buffer):
                            continuation.yield(.stderr(buffer))
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func disconnect() async throws {
        try await client.close()
    }
}

struct CitadelSSHClientFactory: SSHClientFactory {
    func connect(
        host: String,
        port: Int,
        authenticationMethod: SSHAuthenticationMethod,
        hostKeyValidator: NIOSSHClientServerAuthenticationDelegate
    ) async throws -> SSHClientProtocol {
        let client = try await SSHClient.connect(
            host: host,
            port: port,
            authenticationMethod: authenticationMethod,
            hostKeyValidator: SSHHostKeyValidator.custom(hostKeyValidator),
            reconnect: .never
        )
        return CitadelSSHClientAdapter(client: client)
    }
}

@MainActor
class SSHManager: ObservableObject {
    // SSHManager is used per-view (not as singleton) because each TerminalView
    // needs its own connection state (host, username, output buffer, currentDirectory).
    // All file/git operations have been migrated to CLIBridgeAPIClient.

    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var output: String = ""
    @Published var lastError: String?
    @Published var availableHosts: [SSHConfigEntry] = []

    // Internal properties accessible to extensions
    internal let clientFactory: SSHClientFactory
    internal var client: SSHClientProtocol?
    private var disconnectTask: Task<Void, Never>?

    var host: String = ""
    var port: Int = 22
    var username: String = ""
    var currentDirectory: String = "~"  // Track working directory

    init(clientFactory: SSHClientFactory = CitadelSSHClientFactory(), loadConfig: Bool = true) {
        self.clientFactory = clientFactory
        if loadConfig {
            loadSSHConfig()
        }
    }

#if DEBUG
    static func makeForTesting(client: SSHClientProtocol, isConnected: Bool = true) -> SSHManager {
        let manager = SSHManager(clientFactory: CitadelSSHClientFactory(), loadConfig: false)
        manager.client = client
        manager.isConnected = isConnected
        return manager
    }
#endif

    deinit {
        // Cancel any pending disconnect task
        disconnectTask?.cancel()

        // Synchronously close the SSH connection to prevent orphaned server processes
        // We need to capture client before it's deallocated and close it in a detached task
        if let clientToClose = client {
            Task.detached {
                try? await clientToClose.disconnect()
            }
        }
    }

    // Get the real home directory (works around iOS Simulator sandboxing)
    // Internal for extension access
    internal func getRealHomeDirectory() -> String {
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

    // MARK: - Disconnect

    func disconnect() {
        // Cancel any previous disconnect task
        disconnectTask?.cancel()

        // Store the task to prevent it from becoming dangling
        let clientToClose = client
        disconnectTask = Task {
            try? await clientToClose?.disconnect()
        }

        client = nil
        isConnected = false
        output += "\n[Disconnected]\n"
    }

    // MARK: - Terminal Commands

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

                // Process the stream output - stdout/stderr ByteBuffers
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

    // MARK: - Command Execution

    /// Execute a command and return the output
    /// - Parameter command: The command to execute
    /// - Returns: The command output as a string
    func executeCommand(_ command: String) async throws -> String {
        let result = try await executeCommandWithExitCode(command)
        return result.output
    }

    /// Execute a command and return output plus exit code
    func executeCommandWithExitCode(_ command: String) async throws -> SSHCommandResult {
        guard let client = client, isConnected else {
            throw SSHError.notConnected
        }

        return try await client.execute(command)
    }

    /// Execute a command with a timeout
    /// - Parameters:
    ///   - command: The command to execute
    ///   - timeoutSeconds: Maximum time to wait for completion
    /// - Returns: The command output as a string
    func executeCommandWithTimeout(_ command: String, timeoutSeconds: Int) async throws -> String {
        guard let client = client, isConnected else {
            throw SSHError.notConnected
        }

        // Escape the command for safe execution within bash -c
        let escapedCommand = escapeCommandForBash(command)
        // Wrap the command with timeout utility
        // Use 'timeout' command if available, otherwise use shell background trick
        let wrappedCommand = "timeout \(timeoutSeconds)s bash -c '\(escapedCommand)' 2>&1 || echo '[TIMEOUT]'"

        let result = try await client.execute(wrappedCommand)
        if result.output.contains("[TIMEOUT]") {
            throw SSHError.timeout
        }
        return result.output
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
