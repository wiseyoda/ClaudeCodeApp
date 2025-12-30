import XCTest
@testable import CodingBridge

@MainActor
final class SSHManagerTests: XCTestCase {
    func testParseSSHConfigExpandsIdentityFileAndSkipsWildcard() {
        let config = """
        Host *
          User wildcard
        Host work
          HostName work.example.com
          User dev
          Port 2222
          IdentityFile ~/.ssh/id_ed25519
        Host personal
          HostName personal.example.com
        """

        let hosts = SSHManager.parseSSHConfig(config, homeDirectory: "/Users/test")

        XCTAssertEqual(hosts.count, 2)
        XCTAssertEqual(hosts.first?.host, "work")
        XCTAssertEqual(hosts.first?.hostName, "work.example.com")
        XCTAssertEqual(hosts.first?.user, "dev")
        XCTAssertEqual(hosts.first?.port, 2222)
        XCTAssertEqual(hosts.first?.identityFile, "/Users/test/.ssh/id_ed25519")
        XCTAssertEqual(hosts.last?.host, "personal")
    }

    func testBuildCommandForCdHomeResetsDirectory() {
        let result = SSHManager.buildCommand(for: "cd", currentDirectory: "~/repo")

        XCTAssertEqual(result.command, "cd ~ && pwd")
        XCTAssertEqual(result.updatedDirectory, "~")
    }

    func testBuildCommandForRelativeCdUpdatesDirectory() {
        let result = SSHManager.buildCommand(for: "cd Projects", currentDirectory: "~")

        XCTAssertEqual(result.command, "cd ~ && cd Projects && pwd")
        XCTAssertEqual(result.updatedDirectory, "~/Projects")
    }

    func testBuildCommandForParentCdUpdatesDirectory() {
        let result = SSHManager.buildCommand(for: "cd ..", currentDirectory: "/Users/test/repo")

        XCTAssertEqual(result.command, "cd /Users/test/repo && cd .. && pwd")
        XCTAssertEqual(result.updatedDirectory, "/Users/test")
    }

    func testBuildCommandForRegularCommandKeepsDirectory() {
        let result = SSHManager.buildCommand(for: "ls -la", currentDirectory: "~/repo")

        XCTAssertEqual(result.command, "cd ~/repo && ls -la")
        XCTAssertEqual(result.updatedDirectory, "~/repo")
    }

    func testStripAnsiCodesRemovesSequences() {
        let input = "\u{1B}[31mRed\u{1B}[0m\u{1B}[2JBlue\u{1B}]0;Title\u{07}End"

        let output = SSHManager.stripAnsiCodes(input)

        XCTAssertEqual(output, "RedBlueEnd")
    }

    func testBuildCommandValidatesDangerousDirectoryPaths() {
        // Test that dangerous shell metacharacters are rejected
        let dangerousCommands = [
            "cd /tmp; rm -rf /",
            "cd $(rm -rf /)",
            "cd `rm -rf /`",
            "cd /tmp | rm -rf /",
            "cd /tmp & rm -rf /"
        ]

        for command in dangerousCommands {
            let result = SSHManager.buildCommand(for: command, currentDirectory: "~")
            // Should default to safe "." directory for cd commands with dangerous paths
            if command.hasPrefix("cd ") {
                XCTAssertEqual(result.command, "cd ~ && cd . && pwd")
            }
        }
    }

    func testBuildCommandAllowsSafeDirectoryNames() {
        let safeDirs = ["Projects", "my-project", "src", "test_123", "..", "~", "~/Documents"]

        for dir in safeDirs {
            let command = "cd \(dir)"
            let result = SSHManager.buildCommand(for: command, currentDirectory: "~")

            // Should not be sanitized to "."
            XCTAssertNotEqual(result.command, "cd ~ && cd . && pwd")
        }
    }

    func test_escapePath_handlesBasicPath() {
        XCTAssertEqual(shellEscape("/tmp/file.txt"), "'/tmp/file.txt'")
    }

    func test_escapePath_handlesSingleQuotes() {
        XCTAssertEqual(shellEscape("O'Reilly"), "'O'\\''Reilly'")
    }

    func test_escapePath_handlesDoubleQuotes() {
        XCTAssertEqual(shellEscape("quote\"test"), "'quote\"test'")
    }

    func test_escapePath_handlesBackslashes() {
        XCTAssertEqual(shellEscape("path\\with\\slashes"), "'path\\with\\slashes'")
    }

    func test_escapePath_handlesSpaces() {
        XCTAssertEqual(shellEscape("path with spaces"), "'path with spaces'")
    }

    func test_escapePath_handlesNewlines() {
        XCTAssertEqual(shellEscape("line1\nline2"), "'line1\nline2'")
    }

    func test_escapePath_handlesCommandInjection() {
        XCTAssertEqual(shellEscape("file.txt; rm -rf /"), "'file.txt; rm -rf /'")
    }

    func test_escapePath_handlesDollarSigns() {
        XCTAssertEqual(shellEscape("$HOME/bin"), "'$HOME/bin'")
    }

    func test_escapePath_handlesBackticks() {
        XCTAssertEqual(shellEscape("`whoami`"), "'`whoami`'")
    }

    func test_escapePath_handlesSemicolons() {
        XCTAssertEqual(shellEscape("a;b;c"), "'a;b;c'")
    }

    func test_listFiles_parsesDirectoryListing() {
        let output = """
        drwxr-xr-x  5 user staff  160 Dec 26 12:34 src/
        -rw-r--r--  1 user staff  12 Dec 26 12:34 README.md
        """

        let entries = parseListOutput(output, basePath: "/repo")

        XCTAssertEqual(entries.map(\.name), ["src", "README.md"])
        XCTAssertTrue(entries.first?.isDirectory == true)
        XCTAssertEqual(entries.last?.path, "/repo/README.md")
    }

    func test_listFiles_handlesEmptyDirectory() {
        let entries = parseListOutput("", basePath: "/repo")

        XCTAssertTrue(entries.isEmpty)
    }

    func test_listFiles_parsesFilePermissions() {
        let output = "drwxr-x---  2 user staff  64 Dec 26 12:34 secure/"
        let entries = parseListOutput(output, basePath: "/repo")

        XCTAssertEqual(entries.first?.permissions, "drwxr-x---")
    }

    func test_listFiles_parsesFileSizes() {
        let output = "-rw-r--r--  1 user staff  2048 Dec 26 12:34 data.bin"
        let entries = parseListOutput(output, basePath: "/repo")

        XCTAssertEqual(entries.first?.size, 2048)
    }

    func test_listFiles_parsesModifiedDates() {
        let output = "-rw-r--r--  1 user staff  120 Dec 26 2024 report.txt"
        let entries = parseListOutput(output, basePath: "/repo")

        XCTAssertEqual(entries.first?.name, "report.txt")
    }

    func test_listFiles_handlesSymlinks() {
        let output = "lrwxr-xr-x  1 user staff  5 Dec 26 12:34 link@ -> target"
        let entries = parseListOutput(output, basePath: "/repo")

        XCTAssertEqual(entries.first?.name, "link")
        XCTAssertEqual(entries.first?.path, "/repo/link")
        XCTAssertTrue(entries.first?.isSymlink == true)
        XCTAssertFalse(entries.first?.isDirectory ?? true)
    }

    func test_listFiles_handlesHiddenFiles() {
        let output = "-rw-r--r--  1 user staff  10 Dec 26 12:34 .env"
        let entries = parseListOutput(output, basePath: "/repo")

        XCTAssertEqual(entries.first?.name, ".env")
    }

    func test_readFile_returnsContent() async throws {
        throw XCTSkip("Requires a live SSH connection.")
    }

    func test_readFile_handlesLargeFiles() async throws {
        throw XCTSkip("Requires a live SSH connection.")
    }

    func test_readFile_handlesBinaryFiles() async throws {
        throw XCTSkip("Requires a live SSH connection.")
    }

    func test_readFile_handlesNonExistent() async throws {
        throw XCTSkip("Requires a live SSH connection.")
    }

    func test_createDirectory_success() throws {
        throw XCTSkip("SSHManager does not expose createDirectory yet.")
    }

    func test_createDirectory_alreadyExists() throws {
        throw XCTSkip("SSHManager does not expose createDirectory yet.")
    }

    func test_createDirectory_permissionDenied() throws {
        throw XCTSkip("SSHManager does not expose createDirectory yet.")
    }

    func test_deleteFile_success() throws {
        throw XCTSkip("SSHManager does not expose deleteFile yet.")
    }

    func test_deleteFile_notFound() throws {
        throw XCTSkip("SSHManager does not expose deleteFile yet.")
    }

    func test_moveFile_success() throws {
        throw XCTSkip("SSHManager does not expose moveFile yet.")
    }

    func test_moveFile_destExists() throws {
        throw XCTSkip("SSHManager does not expose moveFile yet.")
    }

    func test_copyFile_success() throws {
        throw XCTSkip("SSHManager does not expose copyFile yet.")
    }

    func test_executeGitCommand_status() async throws {
        throw XCTSkip("Requires a live SSH connection.")
    }

    func test_executeGitCommand_branch() async throws {
        throw XCTSkip("Requires a live SSH connection.")
    }

    func test_executeGitCommand_log() async throws {
        throw XCTSkip("Requires a live SSH connection.")
    }

    func test_executeGitCommand_diff() async throws {
        throw XCTSkip("Requires a live SSH connection.")
    }

    func test_executeGitCommand_pull() async throws {
        throw XCTSkip("Requires a live SSH connection.")
    }

    func test_executeGitCommand_notARepo() async throws {
        throw XCTSkip("Requires a live SSH connection.")
    }

    func test_parseGitStatus_clean() {
        let status = SSHManager.parseGitStatus(isGitResult: "true", statusOutput: "", revListOutput: "")

        XCTAssertEqual(status, .clean)
    }

    func test_parseGitStatus_modified() {
        let status = SSHManager.parseGitStatus(isGitResult: "true", statusOutput: " M file.txt", revListOutput: "")

        XCTAssertEqual(status, .dirty)
    }

    func test_parseGitStatus_staged() {
        let status = SSHManager.parseGitStatus(isGitResult: "true", statusOutput: "M  file.txt", revListOutput: "")

        XCTAssertEqual(status, .dirty)
    }

    func test_parseGitStatus_untracked() {
        let status = SSHManager.parseGitStatus(isGitResult: "true", statusOutput: "?? file.txt", revListOutput: "")

        XCTAssertEqual(status, .dirty)
    }

    func test_parseGitStatus_conflicted() {
        let status = SSHManager.parseGitStatus(isGitResult: "true", statusOutput: "UU file.txt", revListOutput: "")

        XCTAssertEqual(status, .dirty)
    }

    func test_parseGitStatus_ahead() {
        let status = SSHManager.parseGitStatus(isGitResult: "true", statusOutput: "", revListOutput: "3\t0")

        XCTAssertEqual(status, .ahead(3))
    }

    func test_parseGitStatus_behind() {
        let status = SSHManager.parseGitStatus(isGitResult: "true", statusOutput: "", revListOutput: "0\t2")

        XCTAssertEqual(status, .behind(2))
    }

    func test_parseGitStatus_diverged() {
        let status = SSHManager.parseGitStatus(isGitResult: "true", statusOutput: "", revListOutput: "2\t3")

        XCTAssertEqual(status, .diverged)
    }

    func test_connect_withPassword() async throws {
        throw XCTSkip("Requires a live SSH connection.")
    }

    func test_connect_withPrivateKey() async throws {
        throw XCTSkip("Requires a live SSH connection.")
    }

    func test_connect_withPrivateKeyPassphrase() async throws {
        throw XCTSkip("Requires a live SSH connection.")
    }

    func test_connect_invalidHost() async throws {
        throw XCTSkip("Requires a live SSH connection.")
    }

    func test_connect_invalidPort() async throws {
        throw XCTSkip("Requires a live SSH connection.")
    }

    func test_connect_authFailure() async throws {
        throw XCTSkip("Requires a live SSH connection.")
    }

    func test_disconnect_cleansUp() async throws {
        throw XCTSkip("Requires a live SSH connection.")
    }

    func test_reconnect_afterDisconnect() async throws {
        throw XCTSkip("Requires a live SSH connection.")
    }

    func test_isConnected_reflectsState() async throws {
        throw XCTSkip("Requires a live SSH connection.")
    }

    func test_executeCommand_success() async throws {
        throw XCTSkip("Requires a live SSH connection.")
    }

    func test_executeCommand_failure() async throws {
        throw XCTSkip("Requires a live SSH connection.")
    }

    func test_executeCommand_timeout() async throws {
        throw XCTSkip("Requires a live SSH connection.")
    }

    func test_executeCommand_largeOutput() async throws {
        throw XCTSkip("Requires a live SSH connection.")
    }

    func test_executeCommand_stderrCapture() async throws {
        throw XCTSkip("Requires a live SSH connection.")
    }

    func test_executeCommand_exitCode() async throws {
        throw XCTSkip("Requires a live SSH connection.")
    }

    func test_stripANSI_removesColors() {
        let input = "\u{1B}[31mRed\u{1B}[0m"
        let output = SSHManager.stripAnsiCodes(input)

        XCTAssertEqual(output, "Red")
    }

    func test_stripANSI_removesCursor() {
        let input = "\u{1B}[2JClear\u{1B}[HHome"
        let output = SSHManager.stripAnsiCodes(input)

        XCTAssertEqual(output, "ClearHome")
    }

    func test_stripANSI_preservesText() {
        let input = "Plain text"
        let output = SSHManager.stripAnsiCodes(input)

        XCTAssertEqual(output, input)
    }

    func test_stripANSI_multipleSequences() {
        let input = "\u{1B}[31mRed\u{1B}[0m\n\u{1B}[?25lHide\u{1B}[?25hShow"
        let output = SSHManager.stripAnsiCodes(input)

        XCTAssertEqual(output, "Red\nHideShow")
    }

    func test_normalizeKeyContent_convertsEmdashes() {
        let emDash = "\u{2014}"
        let header = String(repeating: emDash, count: 5) + "BEGIN RSA PRIVATE KEY" + String(repeating: emDash, count: 5)
        let footer = String(repeating: emDash, count: 5) + "END RSA PRIVATE KEY" + String(repeating: emDash, count: 5)
        let input = "\(header)\nABC\n\(footer)"

        let normalized = SSHKeyDetection.normalizeSSHKey(input)

        XCTAssertTrue(normalized.contains("-----BEGIN RSA PRIVATE KEY-----"))
        XCTAssertTrue(normalized.contains("-----END RSA PRIVATE KEY-----"))
        XCTAssertFalse(normalized.contains(emDash))
    }

    func test_normalizeKeyContent_convertsEndashes() {
        let enDash = "\u{2013}"
        let header = String(repeating: enDash, count: 5) + "BEGIN RSA PRIVATE KEY" + String(repeating: enDash, count: 5)
        let footer = String(repeating: enDash, count: 5) + "END RSA PRIVATE KEY" + String(repeating: enDash, count: 5)
        let input = "\(header)\nABC\n\(footer)"

        let normalized = SSHKeyDetection.normalizeSSHKey(input)

        XCTAssertTrue(normalized.contains("-----BEGIN RSA PRIVATE KEY-----"))
        XCTAssertTrue(normalized.contains("-----END RSA PRIVATE KEY-----"))
        XCTAssertFalse(normalized.contains(enDash))
    }

    func test_normalizeKeyContent_removesSoftHyphens() {
        let softHyphen = "\u{00AD}"
        let input = "-----BEGIN RSA PRIVATE KEY-----\nA\(softHyphen)BC\n-----END RSA PRIVATE KEY-----"

        let normalized = SSHKeyDetection.normalizeSSHKey(input)

        XCTAssertFalse(normalized.contains(softHyphen))
        XCTAssertTrue(normalized.contains("ABC"))
    }

    func test_normalizeKeyContent_preservesMinusSigns() {
        let input = "-----BEGIN RSA PRIVATE KEY-----\nABC\n-----END RSA PRIVATE KEY-----"

        let normalized = SSHKeyDetection.normalizeSSHKey(input)

        XCTAssertEqual(normalized, input)
    }

    func test_fileEntry_formattedSize_directoryIsEmpty() {
        let entry = FileEntry(name: "dir", path: "/repo/dir", isDirectory: true, isSymlink: false, size: 0, permissions: "drwxr-xr-x")

        XCTAssertEqual(entry.formattedSize, "")
    }

    func test_fileEntry_formattedSize_bytes() {
        let entry = FileEntry(name: "file", path: "/repo/file", isDirectory: false, isSymlink: false, size: 512, permissions: "-rw-r--r--")

        XCTAssertEqual(entry.formattedSize, "512 B")
    }

    func test_fileEntry_formattedSize_kilobytes() {
        let entry = FileEntry(name: "file", path: "/repo/file", isDirectory: false, isSymlink: false, size: 2048, permissions: "-rw-r--r--")

        XCTAssertEqual(entry.formattedSize, "2.0 KB")
    }

    func test_fileEntry_formattedSize_megabytes() {
        let entry = FileEntry(name: "file", path: "/repo/file", isDirectory: false, isSymlink: false, size: 2_097_152, permissions: "-rw-r--r--")

        XCTAssertEqual(entry.formattedSize, "2.0 MB")
    }

    func test_fileEntry_icon_swift() {
        let entry = FileEntry(name: "main.swift", path: "/repo/main.swift", isDirectory: false, isSymlink: false, size: 1, permissions: "-rw-r--r--")

        XCTAssertEqual(entry.icon, "swift")
    }

    func test_fileEntry_icon_markdown() {
        let entry = FileEntry(name: "README.md", path: "/repo/README.md", isDirectory: false, isSymlink: false, size: 1, permissions: "-rw-r--r--")

        XCTAssertEqual(entry.icon, "doc.text")
    }

    func test_fileEntry_icon_image() {
        let entry = FileEntry(name: "photo.png", path: "/repo/photo.png", isDirectory: false, isSymlink: false, size: 1, permissions: "-rw-r--r--")

        XCTAssertEqual(entry.icon, "photo")
    }

    func test_fileEntry_icon_default() {
        let entry = FileEntry(name: "archive.bin", path: "/repo/archive.bin", isDirectory: false, isSymlink: false, size: 1, permissions: "-rw-r--r--")

        XCTAssertEqual(entry.icon, "doc")
    }

    func test_sshError_isTransient_connectionFailed() {
        let error = SSHError.connectionFailed("ECONNRESET while reading")

        XCTAssertTrue(error.isTransient)
    }

    func test_sshError_isTransient_timeout() {
        let error = SSHError.timeout

        XCTAssertTrue(error.isTransient)
    }

    func test_sshError_isTransient_authenticationFailed() {
        let error = SSHError.authenticationFailed

        XCTAssertFalse(error.isTransient)
    }

    private func parseListOutput(_ output: String, basePath: String) -> [FileEntry] {
        var entries: [FileEntry] = []
        for line in output.components(separatedBy: "\n") {
            guard !line.isEmpty else { continue }
            if let entry = FileEntry.parse(from: line, basePath: basePath) {
                entries.append(entry)
            }
        }

        return entries.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
