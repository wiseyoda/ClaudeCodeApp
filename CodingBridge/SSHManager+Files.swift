import Foundation

// MARK: - SSHManager File Operations Extension

extension SSHManager {
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
        let cmd = "ls -laF \(shellEscapePath(path)) 2>/dev/null | tail -n +2"
        let result = try await client.execute(cmd)
        let output = result.output

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
        let cmd = "cat \(shellEscapePath(path))"
        let result = try await client.execute(cmd)
        return result.output
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

    // MARK: - File Writing

    /// Write content to a remote file
    func writeFile(_ path: String, contents: String) async throws {
        guard let client = client, isConnected else {
            throw SSHError.notConnected
        }

        let escapedPath = shellEscapePath(path)
        let escapedContents = shellEscape(contents)
        let cmd = "printf %s \(escapedContents) > \(escapedPath)"
        _ = try await client.execute(cmd)
    }

    /// Delete a remote file
    func deleteFile(_ path: String) async throws {
        guard let client = client, isConnected else {
            throw SSHError.notConnected
        }

        let escapedPath = shellEscapePath(path)
        let cmd = "rm -f \(escapedPath)"
        _ = try await client.execute(cmd)
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
        _ = try? await client.execute("mkdir -p \(escapedRemoteDir)")

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

            _ = try await client.execute(cmd)
            offset = endOffset
            isFirst = false
        }

        // Decode the base64 file to the actual image
        // Use -d for standard base64 decode
        let decodeCmd = "base64 -d \(escapedRemotePathB64) > \(escapedRemotePath) && rm \(escapedRemotePathB64)"
        _ = try await client.execute(decodeCmd)

        // Verify the file was created and has content
        let verifyCmd = "stat -c '%s' \(escapedRemotePath) 2>/dev/null || stat -f '%z' \(escapedRemotePath) 2>/dev/null"
        _ = try await client.execute(verifyCmd)

        return remotePath
    }
}
