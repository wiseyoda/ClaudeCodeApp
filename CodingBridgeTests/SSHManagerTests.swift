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
}
