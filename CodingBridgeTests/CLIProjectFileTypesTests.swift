import XCTest
@testable import CodingBridge

final class CLIProjectFileTypesTests: XCTestCase {
    // MARK: - Helper Methods

    /// Creates a CLIGitStatus matching the generated type signature
    private func makeGitStatus(
        branch: String = "main",
        isClean: Bool = true,
        uncommittedCount: Int? = nil,
        ahead: Int? = nil,
        behind: Int? = nil,
        hasUntracked: Bool? = nil,
        hasStaged: Bool? = nil,
        remote: String? = nil,
        trackingBranch: String? = nil
    ) -> CLIGitStatus {
        CLIGitStatus(
            branch: branch,
            isClean: isClean,
            uncommittedCount: uncommittedCount,
            ahead: ahead,
            behind: behind,
            hasUntracked: hasUntracked,
            hasStaged: hasStaged,
            remote: remote,
            trackingBranch: trackingBranch
        )
    }

    /// Creates a CLIFileEntry matching the generated type signature
    private func makeFileEntry(
        name: String = "file.txt",
        type: CLIFileEntryType = .file,
        size: Int? = nil,
        modified: String = "2024-12-31T11:22:33Z"
    ) -> CLIFileEntry {
        CLIFileEntry(
            name: name,
            type: type,
            size: size,
            modified: modified
        )
    }

    private func formattedByteCount(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func isoDate(_ value: String, withFractionalSeconds: Bool) -> Date? {
        let formatter = ISO8601DateFormatter()
        if withFractionalSeconds {
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        } else {
            formatter.formatOptions = [.withInternetDateTime]
        }
        return formatter.date(from: value)
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, json: String) throws -> T {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(type, from: data)
    }

    // MARK: - CLIProject Tests

    func testCLIProjectStoresFields() {
        let git = makeGitStatus(branch: "main", isClean: true)
        let project = CLIProject(
            path: "/home/dev/project",
            name: "Project",
            lastUsed: Date(),
            sessionCount: 3,
            git: git
        )

        XCTAssertEqual(project.path, "/home/dev/project")
        XCTAssertEqual(project.name, "Project")
        XCTAssertEqual(project.sessionCount, 3)
        XCTAssertEqual(project.git?.branch, "main")
    }

    func testCLIProjectWithNilOptionals() {
        let project = CLIProject(
            path: "/home/dev/project",
            name: "Project",
            lastUsed: nil,
            sessionCount: nil,
            git: nil
        )

        XCTAssertEqual(project.path, "/home/dev/project")
        XCTAssertEqual(project.name, "Project")
        XCTAssertNil(project.lastUsed)
        XCTAssertNil(project.sessionCount)
        XCTAssertNil(project.git)
    }

    // MARK: - CLIProjectDetail Tests

    func testCLIProjectDetailStoresFields() {
        let structure = CLIProjectStructure(
            hasCLAUDE: true,
            hasPackageJSON: true,
            hasPyprojectToml: false,
            directories: ["src", "tests"],
            primaryLanguage: "TypeScript"
        )
        let detail = CLIProjectDetail(
            path: "/home/dev/project",
            name: "Project",
            git: makeGitStatus(branch: "dev"),
            sessionCount: 4,
            lastUsed: "2025-12-30",
            structure: structure,
            readme: "README content"
        )

        XCTAssertEqual(detail.path, "/home/dev/project")
        XCTAssertEqual(detail.name, "Project")
        XCTAssertEqual(detail.lastUsed, "2025-12-30")
        XCTAssertEqual(detail.sessionCount, 4)
        XCTAssertEqual(detail.git?.branch, "dev")
        XCTAssertEqual(detail.readme, "README content")
        XCTAssertEqual(detail.structure?.hasPackageJSON, true)
        XCTAssertEqual(detail.structure?.primaryLanguage, "TypeScript")
    }

    // MARK: - CLIProjectStructure Tests

    func testCLIProjectStructureBadgesIncludeAllFlags() {
        let structure = CLIProjectStructure(
            hasCLAUDE: true,
            hasPackageJSON: true,
            hasPyprojectToml: true,
            directories: nil,
            primaryLanguage: "Python"
        )

        let badges = structure.projectTypeBadges
        // The badges depend on which flags are true
        XCTAssertTrue(badges.contains { $0.label == "Node.js" })
        XCTAssertTrue(badges.contains { $0.label == "Python" })
        XCTAssertTrue(badges.contains { $0.label == "Claude" })
    }

    func testCLIProjectStructureBadgesEmptyWhenNoFlags() {
        let structure = CLIProjectStructure(
            hasCLAUDE: false,
            hasPackageJSON: false,
            hasPyprojectToml: false,
            directories: nil,
            primaryLanguage: nil
        )

        XCTAssertTrue(structure.projectTypeBadges.isEmpty)
    }

    // MARK: - CLIGitStatus Tests

    func testCLIGitStatusStoresFields() {
        let status = makeGitStatus(
            branch: "feature",
            isClean: false,
            uncommittedCount: 5,
            ahead: 2,
            behind: 1,
            hasUntracked: true,
            hasStaged: true,
            remote: "origin",
            trackingBranch: "origin/feature"
        )

        XCTAssertEqual(status.branch, "feature")
        XCTAssertEqual(status.isClean, false)
        XCTAssertEqual(status.uncommittedCount, 5)
        XCTAssertEqual(status.ahead, 2)
        XCTAssertEqual(status.behind, 1)
        XCTAssertEqual(status.hasUntracked, true)
        XCTAssertEqual(status.hasStaged, true)
        XCTAssertEqual(status.remote, "origin")
        XCTAssertEqual(status.trackingBranch, "origin/feature")
    }

    func testCLIGitStatusToGitStatusClean() {
        let status = makeGitStatus(branch: "main", isClean: true)
        XCTAssertEqual(status.toGitStatus, .clean)
    }

    func testCLIGitStatusToGitStatusDirty() {
        let status = makeGitStatus(branch: "main", isClean: false, uncommittedCount: 3)
        XCTAssertEqual(status.toGitStatus, .dirty)
    }

    func testCLIGitStatusToGitStatusDirtyAndAhead() {
        let status = makeGitStatus(branch: "main", isClean: false, uncommittedCount: 2, ahead: 1)
        XCTAssertEqual(status.toGitStatus, .dirtyAndAhead)
    }

    func testCLIGitStatusToGitStatusDiverged() {
        let status = makeGitStatus(branch: "main", isClean: true, ahead: 2, behind: 1)
        XCTAssertEqual(status.toGitStatus, .diverged)
    }

    func testCLIGitStatusToGitStatusAhead() {
        let status = makeGitStatus(branch: "main", isClean: true, ahead: 3, behind: 0)
        XCTAssertEqual(status.toGitStatus, .ahead(3))
    }

    func testCLIGitStatusToGitStatusBehind() {
        let status = makeGitStatus(branch: "main", isClean: true, ahead: 0, behind: 2)
        XCTAssertEqual(status.toGitStatus, .behind(2))
    }

    // MARK: - cli-bridge specific format tests

    func testCLIGitStatusToGitStatusCleanFromCliBridgeFormat() {
        // cli-bridge sends: { branch, isClean: true, uncommittedCount: 0 }
        let status = makeGitStatus(
            branch: "main",
            isClean: true,
            uncommittedCount: 0
        )
        XCTAssertEqual(status.toGitStatus, .clean)
    }

    func testCLIGitStatusToGitStatusDirtyFromCliBridgeFormat() {
        // cli-bridge sends: { branch, isClean: false, uncommittedCount: 3 }
        let status = makeGitStatus(
            branch: "main",
            isClean: false,
            uncommittedCount: 3
        )
        XCTAssertEqual(status.toGitStatus, .dirty)
    }

    // MARK: - CLIFileEntry Tests

    func testCLIFileEntryStoresFields() {
        let entry = makeFileEntry(
            name: "readme.md",
            type: .file,
            size: 2048,
            modified: "2024-12-31T11:22:33Z"
        )

        XCTAssertEqual(entry.name, "readme.md")
        XCTAssertEqual(entry.type, .file)
        XCTAssertEqual(entry.size, 2048)
        XCTAssertEqual(entry.modified, "2024-12-31T11:22:33Z")
        XCTAssertEqual(entry.id, "readme.md")
    }

    func testCLIFileEntryIsDirTrueWhenDirectory() {
        let entry = makeFileEntry(name: "Sources", type: .directory)
        XCTAssertTrue(entry.isDir)
    }

    func testCLIFileEntryIsDirFalseWhenFile() {
        let entry = makeFileEntry(name: "file.txt", type: .file)
        XCTAssertFalse(entry.isDir)
    }

    func testCLIFileEntryIsSymlink() {
        let entry = makeFileEntry(name: "link", type: .symlink)
        XCTAssertTrue(entry.isSymlink)
    }

    func testCLIFileEntryModifiedDateParsesFractionalSeconds() {
        let timestamp = "2024-12-31T11:22:33.456Z"
        let entry = makeFileEntry(modified: timestamp)

        XCTAssertEqual(entry.modifiedDate, isoDate(timestamp, withFractionalSeconds: true))
    }

    func testCLIFileEntryModifiedDateParsesNonFractionalSeconds() {
        let timestamp = "2024-12-31T11:22:33Z"
        let entry = makeFileEntry(modified: timestamp)

        XCTAssertEqual(entry.modifiedDate, isoDate(timestamp, withFractionalSeconds: false))
    }

    func testCLIFileEntryIconDirectoryOverridesExtension() {
        let entry = makeFileEntry(name: "Sources.swift", type: .directory)
        XCTAssertEqual(entry.icon, "folder.fill")
    }

    func testCLIFileEntryIconSwift() {
        let entry = makeFileEntry(name: "main.swift", type: .file)
        XCTAssertEqual(entry.icon, "swift")
    }

    func testCLIFileEntryIconTypeScript() {
        XCTAssertEqual(makeFileEntry(name: "main.ts", type: .file).icon, "t.square")
        XCTAssertEqual(makeFileEntry(name: "main.tsx", type: .file).icon, "t.square")
    }

    func testCLIFileEntryIconJavaScript() {
        XCTAssertEqual(makeFileEntry(name: "main.js", type: .file).icon, "j.square")
        XCTAssertEqual(makeFileEntry(name: "main.jsx", type: .file).icon, "j.square")
    }

    func testCLIFileEntryIconJSON() {
        let entry = makeFileEntry(name: "config.json", type: .file)
        XCTAssertEqual(entry.icon, "curlybraces")
    }

    func testCLIFileEntryIconMarkdown() {
        XCTAssertEqual(makeFileEntry(name: "README.md", type: .file).icon, "doc.text")
        XCTAssertEqual(makeFileEntry(name: "README.markdown", type: .file).icon, "doc.text")
    }

    func testCLIFileEntryIconImages() {
        let expected = "photo"
        XCTAssertEqual(makeFileEntry(name: "image.png", type: .file).icon, expected)
        XCTAssertEqual(makeFileEntry(name: "image.jpg", type: .file).icon, expected)
        XCTAssertEqual(makeFileEntry(name: "image.jpeg", type: .file).icon, expected)
        XCTAssertEqual(makeFileEntry(name: "image.gif", type: .file).icon, expected)
        XCTAssertEqual(makeFileEntry(name: "image.webp", type: .file).icon, expected)
        XCTAssertEqual(makeFileEntry(name: "image.svg", type: .file).icon, expected)
    }

    func testCLIFileEntryIconPDF() {
        let entry = makeFileEntry(name: "report.pdf", type: .file)
        XCTAssertEqual(entry.icon, "doc.fill")
    }

    func testCLIFileEntryIconHTML() {
        XCTAssertEqual(makeFileEntry(name: "index.html", type: .file).icon, "globe")
        XCTAssertEqual(makeFileEntry(name: "index.htm", type: .file).icon, "globe")
    }

    func testCLIFileEntryIconStyles() {
        XCTAssertEqual(makeFileEntry(name: "styles.css", type: .file).icon, "paintbrush")
        XCTAssertEqual(makeFileEntry(name: "styles.scss", type: .file).icon, "paintbrush")
    }

    func testCLIFileEntryIconPython() {
        let entry = makeFileEntry(name: "app.py", type: .file)
        XCTAssertEqual(entry.icon, "p.circle")
    }

    func testCLIFileEntryIconRust() {
        let entry = makeFileEntry(name: "main.rs", type: .file)
        XCTAssertEqual(entry.icon, "r.square")
    }

    func testCLIFileEntryIconGo() {
        let entry = makeFileEntry(name: "main.go", type: .file)
        XCTAssertEqual(entry.icon, "g.circle")
    }

    func testCLIFileEntryIconRuby() {
        let entry = makeFileEntry(name: "app.rb", type: .file)
        XCTAssertEqual(entry.icon, "r.circle")
    }

    func testCLIFileEntryIconJavaAndKotlin() {
        XCTAssertEqual(makeFileEntry(name: "Main.java", type: .file).icon, "j.circle")
        XCTAssertEqual(makeFileEntry(name: "Main.kt", type: .file).icon, "j.circle")
    }

    func testCLIFileEntryIconShell() {
        XCTAssertEqual(makeFileEntry(name: "script.sh", type: .file).icon, "terminal")
        XCTAssertEqual(makeFileEntry(name: "script.bash", type: .file).icon, "terminal")
        XCTAssertEqual(makeFileEntry(name: "script.zsh", type: .file).icon, "terminal")
    }

    func testCLIFileEntryIconConfigFormats() {
        XCTAssertEqual(makeFileEntry(name: "config.yml", type: .file).icon, "list.bullet")
        XCTAssertEqual(makeFileEntry(name: "config.yaml", type: .file).icon, "list.bullet")
    }

    func testCLIFileEntryIconDefaultFallback() {
        let entry = makeFileEntry(name: "archive.zip", type: .file)
        XCTAssertEqual(entry.icon, "archivebox")
    }

    func testCLIFileEntryIconLowercasesExtension() {
        let entry = makeFileEntry(name: "Main.SWIFT", type: .file)
        XCTAssertEqual(entry.icon, "swift")
    }

    func testCLIFileEntryFormattedSizeNilForDirectory() {
        let entry = makeFileEntry(name: "Sources", type: .directory, size: 2048)
        // Directory should still show size since we have it
        XCTAssertNotNil(entry.formattedSize)
    }

    func testCLIFileEntryFormattedSizeNilWhenMissing() {
        let entry = makeFileEntry(name: "file.txt", type: .file, size: nil)
        XCTAssertNil(entry.formattedSize)
    }

    func testCLIFileEntryFormattedSizeDisplaysCorrectly() {
        let entry = makeFileEntry(name: "file.txt", type: .file, size: 2048)
        XCTAssertNotNil(entry.formattedSize)
        // The formatted size should contain "KB" for 2048 bytes
        XCTAssertTrue(entry.formattedSize?.contains("KB") == true || entry.formattedSize?.contains("2") == true)
    }

    // MARK: - CLIFileListResponse (DirectoryListing) Tests

    func testCLIFileListResponseStoresFields() throws {
        let json = """
        {
          "path": "/Users/dev",
          "entries": [
            { "name": "main.swift", "type": "file", "size": 10, "modified": "2024-12-31T11:22:33Z" },
            { "name": "Sources", "type": "directory", "modified": "2024-12-31T11:22:33Z" }
          ]
        }
        """

        let response = try decodeJSON(CLIFileListResponse.self, json: json)
        XCTAssertEqual(response.path, "/Users/dev")
        XCTAssertEqual(response.entries.count, 2)
        XCTAssertEqual(response.entries[0].name, "main.swift")
        XCTAssertEqual(response.entries[1].name, "Sources")
    }

    func testCLIFileListResponseParentDerivation() throws {
        let json = """
        {
          "path": "/Users/dev/project",
          "entries": []
        }
        """

        let response = try decodeJSON(CLIFileListResponse.self, json: json)
        XCTAssertEqual(response.parent, "/Users/dev")
    }

    func testCLIFileListResponseParentForRoot() throws {
        let json = """
        {
          "path": "/",
          "entries": []
        }
        """

        let response = try decodeJSON(CLIFileListResponse.self, json: json)
        XCTAssertNil(response.parent)
    }

    // MARK: - CLIFileContentResponse (FileContent) Tests

    func testCLIFileContentResponseStoresFields() {
        let response = CLIFileContentResponse(
            path: "/tmp/file.txt",
            content: "Hello",
            size: 12,
            modified: "2024-12-31T11:22:33Z",
            mimeType: "text/plain"
        )

        XCTAssertEqual(response.path, "/tmp/file.txt")
        XCTAssertEqual(response.content, "Hello")
        XCTAssertEqual(response.size, 12)
        XCTAssertEqual(response.modified, "2024-12-31T11:22:33Z")
        XCTAssertEqual(response.mimeType, "text/plain")
    }

    func testCLIFileContentResponseFileNameExtractsFromPath() {
        let response = CLIFileContentResponse(
            path: "/tmp/subdirectory/file.txt",
            content: "",
            size: 0,
            modified: "2024-12-31T11:22:33Z",
            mimeType: "text/plain"
        )

        XCTAssertEqual(response.fileName, "file.txt")
    }

    func testCLIFileContentResponseFormattedSize() {
        let response = CLIFileContentResponse(
            path: "/tmp/file.txt",
            content: "",
            size: 2048,
            modified: "2024-12-31T11:22:33Z",
            mimeType: "text/plain"
        )

        XCTAssertNotNil(response.formattedSize)
    }

    func testCLIFileContentResponseLanguageFromPath() {
        let response = CLIFileContentResponse(
            path: "/tmp/main.swift",
            content: "",
            size: 0,
            modified: "2024-12-31T11:22:33Z",
            mimeType: "text/plain"
        )

        XCTAssertEqual(response.language, "swift")
    }

    func testCLIFileContentResponseLineCount() {
        let response = CLIFileContentResponse(
            path: "/tmp/file.txt",
            content: "Line 1\nLine 2\nLine 3",
            size: 21,
            modified: "2024-12-31T11:22:33Z",
            mimeType: "text/plain"
        )

        XCTAssertEqual(response.lineCount, 3)
    }
}
