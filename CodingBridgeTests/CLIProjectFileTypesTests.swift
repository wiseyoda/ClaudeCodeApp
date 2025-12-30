import XCTest
@testable import CodingBridge

final class CLIProjectFileTypesTests: XCTestCase {
    private func makeGitStatus(
        branch: String? = "main",
        status: String? = "clean",
        remote: String? = "origin",
        remoteUrl: String? = "git@example.com:repo.git",
        ahead: Int? = nil,
        behind: Int? = nil,
        hasUncommitted: Bool? = nil,
        hasUntracked: Bool? = nil,
        isClean: Bool? = nil,
        uncommittedCount: Int? = nil
    ) -> CLIGitStatus {
        CLIGitStatus(
            branch: branch,
            status: status,
            remote: remote,
            remoteUrl: remoteUrl,
            ahead: ahead,
            behind: behind,
            hasUncommitted: hasUncommitted,
            hasUntracked: hasUntracked,
            isClean: isClean,
            uncommittedCount: uncommittedCount
        )
    }

    private func makeFileEntry(
        name: String = "file.txt",
        path: String = "/tmp/file.txt",
        type: String? = "file",
        size: Int? = 1,
        modified: String? = nil,
        fileExtension: String? = "txt",
        childCount: Int? = nil
    ) -> CLIFileEntry {
        CLIFileEntry(
            name: name,
            path: path,
            type: type,
            size: size,
            modified: modified,
            extension: fileExtension,
            childCount: childCount
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

    func testCLIProjectStoresFields() {
        let git = makeGitStatus(branch: "main", status: "clean")
        let project = CLIProject(
            path: "/home/dev/project",
            name: "Project",
            lastUsed: "2025-12-30",
            sessionCount: 3,
            git: git
        )

        XCTAssertEqual(project.path, "/home/dev/project")
        XCTAssertEqual(project.name, "Project")
        XCTAssertEqual(project.lastUsed, "2025-12-30")
        XCTAssertEqual(project.sessionCount, 3)
        XCTAssertEqual(project.git?.branch, "main")
    }

    func testCLIProjectEncodedPathReplacesSlashes() {
        let project = CLIProject(
            path: "/home/dev/project",
            name: "Project",
            lastUsed: nil,
            sessionCount: nil,
            git: nil
        )

        XCTAssertEqual(project.encodedPath, "-home-dev-project")
    }

    func testCLIProjectDetailStoresFields() {
        let structure = CLIProjectStructure(
            hasPackageJson: true,
            hasCargoToml: false,
            hasGoMod: true,
            hasPyproject: nil,
            hasDenoJson: nil,
            primaryLanguage: "Go"
        )
        let detail = CLIProjectDetail(
            path: "/home/dev/project",
            name: "Project",
            lastUsed: "2025-12-30",
            sessionCount: 4,
            git: makeGitStatus(branch: "dev"),
            readme: "README content",
            structure: structure
        )

        XCTAssertEqual(detail.path, "/home/dev/project")
        XCTAssertEqual(detail.name, "Project")
        XCTAssertEqual(detail.lastUsed, "2025-12-30")
        XCTAssertEqual(detail.sessionCount, 4)
        XCTAssertEqual(detail.git?.branch, "dev")
        XCTAssertEqual(detail.readme, "README content")
        XCTAssertEqual(detail.structure?.hasPackageJson, true)
        XCTAssertEqual(detail.structure?.hasGoMod, true)
        XCTAssertEqual(detail.structure?.primaryLanguage, "Go")
    }

    func testCLIProjectDetailEncodedPathReplacesSlashes() {
        let detail = CLIProjectDetail(
            path: "/home/dev/project",
            name: "Project",
            lastUsed: nil,
            sessionCount: nil,
            git: nil,
            readme: nil,
            structure: nil
        )

        XCTAssertEqual(detail.encodedPath, "-home-dev-project")
    }

    func testCLIProjectStructureBadgesIncludeAllFlags() {
        let structure = CLIProjectStructure(
            hasPackageJson: true,
            hasCargoToml: true,
            hasGoMod: true,
            hasPyproject: true,
            hasDenoJson: true,
            primaryLanguage: "Rust"
        )

        let badges = structure.projectTypeBadges
        XCTAssertEqual(badges.map { $0.icon }, ["cube.box", "gearshape.2", "bolt", "snake", "dinosaur"])
        XCTAssertEqual(badges.map { $0.label }, ["Node.js", "Rust", "Go", "Python", "Deno"])
        XCTAssertEqual(badges.map { $0.color }, ["green", "orange", "cyan", "yellow", "purple"])
    }

    func testCLIProjectStructureBadgesEmptyWhenNoFlags() {
        let structure = CLIProjectStructure(
            hasPackageJson: nil,
            hasCargoToml: nil,
            hasGoMod: nil,
            hasPyproject: nil,
            hasDenoJson: nil,
            primaryLanguage: nil
        )

        XCTAssertTrue(structure.projectTypeBadges.isEmpty)
    }

    func testCLIGitStatusStoresFields() {
        let status = makeGitStatus(
            branch: "feature",
            status: "modified",
            remote: "origin",
            remoteUrl: "git@example.com:repo.git",
            ahead: 2,
            behind: 1,
            hasUncommitted: true,
            hasUntracked: true,
            isClean: false,
            uncommittedCount: 5
        )

        XCTAssertEqual(status.branch, "feature")
        XCTAssertEqual(status.status, "modified")
        XCTAssertEqual(status.remote, "origin")
        XCTAssertEqual(status.remoteUrl, "git@example.com:repo.git")
        XCTAssertEqual(status.ahead, 2)
        XCTAssertEqual(status.behind, 1)
        XCTAssertEqual(status.hasUncommitted, true)
        XCTAssertEqual(status.hasUntracked, true)
        XCTAssertEqual(status.isClean, false)
        XCTAssertEqual(status.uncommittedCount, 5)
    }

    func testCLIGitStatusRepoIsCleanPrefersServerTrue() {
        let status = makeGitStatus(status: "modified", isClean: true)
        XCTAssertTrue(status.repoIsClean)
    }

    func testCLIGitStatusRepoIsCleanPrefersServerFalse() {
        let status = makeGitStatus(status: "clean", isClean: false)
        XCTAssertFalse(status.repoIsClean)
    }

    func testCLIGitStatusRepoIsCleanFallsBackToStatusClean() {
        let status = makeGitStatus(status: "clean", isClean: nil)
        XCTAssertTrue(status.repoIsClean)
    }

    func testCLIGitStatusRepoIsCleanFallsBackToStatusNotClean() {
        let status = makeGitStatus(status: "modified", isClean: nil)
        XCTAssertFalse(status.repoIsClean)
    }

    func testCLIGitStatusToGitStatusNotGitRepoWhenBranchNil() {
        let status = makeGitStatus(branch: nil, status: "clean")
        XCTAssertEqual(status.toGitStatus, .notGitRepo)
    }

    func testCLIGitStatusToGitStatusConflictReturnsDiverged() {
        let status = makeGitStatus(status: "conflict", ahead: 2, behind: 1, isClean: false)
        XCTAssertEqual(status.toGitStatus, .diverged)
    }

    func testCLIGitStatusToGitStatusDirtyAndAheadFromUncommittedCount() {
        let status = makeGitStatus(status: "clean", ahead: 1, isClean: nil, uncommittedCount: 2)
        XCTAssertEqual(status.toGitStatus, .dirtyAndAhead)
    }

    func testCLIGitStatusToGitStatusDirtyAndAheadOverridesDiverged() {
        let status = makeGitStatus(status: "clean", ahead: 1, behind: 1, isClean: nil, uncommittedCount: 2)
        XCTAssertEqual(status.toGitStatus, .dirtyAndAhead)
    }

    func testCLIGitStatusToGitStatusDivergedWhenAheadAndBehindAndClean() {
        let status = makeGitStatus(status: "clean", ahead: 1, behind: 2, isClean: true)
        XCTAssertEqual(status.toGitStatus, .diverged)
    }

    func testCLIGitStatusToGitStatusAheadWhenOnlyAhead() {
        let status = makeGitStatus(status: "clean", ahead: 3, behind: 0, isClean: true)
        XCTAssertEqual(status.toGitStatus, .ahead(3))
    }

    func testCLIGitStatusToGitStatusBehindWhenOnlyBehind() {
        let status = makeGitStatus(status: "clean", ahead: 0, behind: 2, isClean: true)
        XCTAssertEqual(status.toGitStatus, .behind(2))
    }

    func testCLIGitStatusToGitStatusDirtyFromHasUncommitted() {
        let status = makeGitStatus(status: "clean", hasUncommitted: true, isClean: nil)
        XCTAssertEqual(status.toGitStatus, .dirty)
    }

    func testCLIGitStatusToGitStatusDirtyFromStatusFallback() {
        let status = makeGitStatus(status: "modified", isClean: nil)
        XCTAssertEqual(status.toGitStatus, .dirty)
    }

    func testCLIGitStatusToGitStatusCleanWhenNoChanges() {
        let status = makeGitStatus(status: "clean", isClean: true)
        XCTAssertEqual(status.toGitStatus, .clean)
    }

    func testCLIFileEntryStoresFields() {
        let entry = makeFileEntry(
            name: "readme.md",
            path: "/tmp/readme.md",
            type: "file",
            size: 2048,
            modified: "2024-12-31T11:22:33Z",
            fileExtension: "md",
            childCount: 4
        )

        XCTAssertEqual(entry.name, "readme.md")
        XCTAssertEqual(entry.path, "/tmp/readme.md")
        XCTAssertEqual(entry.type, "file")
        XCTAssertEqual(entry.size, 2048)
        XCTAssertEqual(entry.modified, "2024-12-31T11:22:33Z")
        XCTAssertEqual(entry.childCount, 4)
        XCTAssertEqual(entry.id, "/tmp/readme.md")
    }

    func testCLIFileEntryIsDirTrueWhenDirectory() {
        let entry = makeFileEntry(type: "directory", fileExtension: nil)
        XCTAssertTrue(entry.isDir)
    }

    func testCLIFileEntryIsDirFalseWhenTypeNil() {
        let entry = makeFileEntry(type: nil)
        XCTAssertFalse(entry.isDir)
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

    func testCLIFileEntryModifiedDateNilWhenMissing() {
        let entry = makeFileEntry(modified: nil)
        XCTAssertNil(entry.modifiedDate)
    }

    func testCLIFileEntryIconDirectoryOverridesExtension() {
        let entry = makeFileEntry(type: "directory", fileExtension: "swift")
        XCTAssertEqual(entry.icon, "folder.fill")
    }

    func testCLIFileEntryIconSwift() {
        let entry = makeFileEntry(name: "main.swift", fileExtension: "swift")
        XCTAssertEqual(entry.icon, "swift")
    }

    func testCLIFileEntryIconTypeScript() {
        XCTAssertEqual(makeFileEntry(name: "main.ts", fileExtension: "ts").icon, "t.square")
        XCTAssertEqual(makeFileEntry(name: "main.tsx", fileExtension: "tsx").icon, "t.square")
    }

    func testCLIFileEntryIconJavaScript() {
        XCTAssertEqual(makeFileEntry(name: "main.js", fileExtension: "js").icon, "j.square")
        XCTAssertEqual(makeFileEntry(name: "main.jsx", fileExtension: "jsx").icon, "j.square")
    }

    func testCLIFileEntryIconJSON() {
        let entry = makeFileEntry(name: "config.json", fileExtension: "json")
        XCTAssertEqual(entry.icon, "curlybraces")
    }

    func testCLIFileEntryIconMarkdown() {
        XCTAssertEqual(makeFileEntry(name: "README.md", fileExtension: "md").icon, "doc.text")
        XCTAssertEqual(makeFileEntry(name: "README.markdown", fileExtension: "markdown").icon, "doc.text")
    }

    func testCLIFileEntryIconImages() {
        let expected = "photo"
        XCTAssertEqual(makeFileEntry(name: "image.png", fileExtension: "png").icon, expected)
        XCTAssertEqual(makeFileEntry(name: "image.jpg", fileExtension: "jpg").icon, expected)
        XCTAssertEqual(makeFileEntry(name: "image.jpeg", fileExtension: "jpeg").icon, expected)
        XCTAssertEqual(makeFileEntry(name: "image.gif", fileExtension: "gif").icon, expected)
        XCTAssertEqual(makeFileEntry(name: "image.webp", fileExtension: "webp").icon, expected)
        XCTAssertEqual(makeFileEntry(name: "image.svg", fileExtension: "svg").icon, expected)
    }

    func testCLIFileEntryIconPDF() {
        let entry = makeFileEntry(name: "report.pdf", fileExtension: "pdf")
        XCTAssertEqual(entry.icon, "doc.richtext")
    }

    func testCLIFileEntryIconHTML() {
        XCTAssertEqual(makeFileEntry(name: "index.html", fileExtension: "html").icon, "globe")
        XCTAssertEqual(makeFileEntry(name: "index.htm", fileExtension: "htm").icon, "globe")
    }

    func testCLIFileEntryIconStyles() {
        XCTAssertEqual(makeFileEntry(name: "styles.css", fileExtension: "css").icon, "paintbrush")
        XCTAssertEqual(makeFileEntry(name: "styles.scss", fileExtension: "scss").icon, "paintbrush")
        XCTAssertEqual(makeFileEntry(name: "styles.less", fileExtension: "less").icon, "paintbrush")
    }

    func testCLIFileEntryIconPython() {
        let entry = makeFileEntry(name: "app.py", fileExtension: "py")
        XCTAssertEqual(entry.icon, "chevron.left.forwardslash.chevron.right")
    }

    func testCLIFileEntryIconRust() {
        let entry = makeFileEntry(name: "main.rs", fileExtension: "rs")
        XCTAssertEqual(entry.icon, "gearshape.2")
    }

    func testCLIFileEntryIconGo() {
        let entry = makeFileEntry(name: "main.go", fileExtension: "go")
        XCTAssertEqual(entry.icon, "bolt")
    }

    func testCLIFileEntryIconRuby() {
        let entry = makeFileEntry(name: "app.rb", fileExtension: "rb")
        XCTAssertEqual(entry.icon, "diamond")
    }

    func testCLIFileEntryIconJavaAndKotlin() {
        XCTAssertEqual(makeFileEntry(name: "Main.java", fileExtension: "java").icon, "cup.and.saucer")
        XCTAssertEqual(makeFileEntry(name: "Main.kt", fileExtension: "kt").icon, "cup.and.saucer")
    }

    func testCLIFileEntryIconShell() {
        XCTAssertEqual(makeFileEntry(name: "script.sh", fileExtension: "sh").icon, "terminal")
        XCTAssertEqual(makeFileEntry(name: "script.bash", fileExtension: "bash").icon, "terminal")
        XCTAssertEqual(makeFileEntry(name: "script.zsh", fileExtension: "zsh").icon, "terminal")
    }

    func testCLIFileEntryIconConfigFormats() {
        XCTAssertEqual(makeFileEntry(name: "config.yml", fileExtension: "yml").icon, "gearshape")
        XCTAssertEqual(makeFileEntry(name: "config.yaml", fileExtension: "yaml").icon, "gearshape")
        XCTAssertEqual(makeFileEntry(name: "config.toml", fileExtension: "toml").icon, "gearshape")
    }

    func testCLIFileEntryIconLockFiles() {
        let entry = makeFileEntry(name: "package.lock", fileExtension: "lock")
        XCTAssertEqual(entry.icon, "lock")
    }

    func testCLIFileEntryIconEnvFiles() {
        let entry = makeFileEntry(name: ".env", fileExtension: "env")
        XCTAssertEqual(entry.icon, "key")
    }

    func testCLIFileEntryIconGitIgnoreFiles() {
        XCTAssertEqual(makeFileEntry(name: ".gitignore", fileExtension: "gitignore").icon, "eye.slash")
        XCTAssertEqual(makeFileEntry(name: ".dockerignore", fileExtension: "dockerignore").icon, "eye.slash")
    }

    func testCLIFileEntryIconDefaultFallback() {
        let entry = makeFileEntry(name: "archive.zip", fileExtension: "zip")
        XCTAssertEqual(entry.icon, "doc")
    }

    func testCLIFileEntryIconLowercasesExtension() {
        let entry = makeFileEntry(name: "Main.SWIFT", fileExtension: "SWIFT")
        XCTAssertEqual(entry.icon, "swift")
    }

    func testCLIFileEntryFormattedSizeNilForDirectory() {
        let entry = makeFileEntry(type: "directory", size: 2048, fileExtension: nil)
        XCTAssertNil(entry.formattedSize)
    }

    func testCLIFileEntryFormattedSizeNilWhenMissing() {
        let entry = makeFileEntry(size: nil)
        XCTAssertNil(entry.formattedSize)
    }

    func testCLIFileEntryFormattedSizeUsesByteCountFormatter() {
        let entry = makeFileEntry(size: 2048)
        XCTAssertEqual(entry.formattedSize, formattedByteCount(2048))
    }

    func testCLIFileEntryToFileEntryConversion() {
        let entry = makeFileEntry(name: "file.txt", path: "/tmp/file.txt", type: "file", size: 42, fileExtension: "txt")
        let converted = entry.toFileEntry()

        XCTAssertEqual(converted.name, "file.txt")
        XCTAssertEqual(converted.path, "/tmp/file.txt")
        XCTAssertFalse(converted.isDirectory)
        XCTAssertFalse(converted.isSymlink)
        XCTAssertEqual(converted.size, 42)
        XCTAssertEqual(converted.permissions, "")
    }

    func testCLIFileEntryToFileEntryDefaultsSizeToZero() {
        let entry = makeFileEntry(size: nil)
        XCTAssertEqual(entry.toFileEntry().size, 0)
    }

    func testCLIFileListResponseBuildsPathsFromDirectory() throws {
        let json = """
        {
          "path": "/Users/dev",
          "entries": [
            { "name": "main.swift", "type": "file", "size": 10, "extension": "swift" },
            { "name": "Sources", "type": "directory", "childCount": 2 }
          ],
          "parent": "/Users"
        }
        """

        let response = try decodeJSON(CLIFileListResponse.self, json: json)
        XCTAssertEqual(response.path, "/Users/dev")
        XCTAssertEqual(response.parent, "/Users")
        XCTAssertEqual(response.entries[0].path, "/Users/dev/main.swift")
        XCTAssertEqual(response.entries[1].path, "/Users/dev/Sources")
    }

    func testCLIFileListResponseBuildsPathsForRoot() throws {
        let json = """
        {
          "path": "/",
          "entries": [
            { "name": "file.txt", "type": "file", "size": 10, "extension": "txt" }
          ],
          "parent": null
        }
        """

        let response = try decodeJSON(CLIFileListResponse.self, json: json)
        XCTAssertEqual(response.entries.first?.path, "/file.txt")
    }

    func testCLIFileListResponseBuildsPathsForTrailingSlash() throws {
        let json = """
        {
          "path": "/Users/dev/",
          "entries": [
            { "name": "file.txt", "type": "file", "size": 10, "extension": "txt" }
          ],
          "parent": "/Users"
        }
        """

        let response = try decodeJSON(CLIFileListResponse.self, json: json)
        XCTAssertEqual(response.entries.first?.path, "/Users/dev/file.txt")
    }

    func testCLIFileListResponseBuildsPathsForEmptyPath() throws {
        let json = """
        {
          "path": "",
          "entries": [
            { "name": "file.txt", "type": "file", "size": 10, "extension": "txt" }
          ],
          "parent": null
        }
        """

        let response = try decodeJSON(CLIFileListResponse.self, json: json)
        XCTAssertEqual(response.entries.first?.path, "/file.txt")
    }

    func testCLIFileContentResponseStoresFields() {
        let response = CLIFileContentResponse(
            path: "/tmp/file.txt",
            name: "file.txt",
            content: "Hello",
            size: 12,
            modified: "2024-12-31T11:22:33Z",
            mimeType: "text/plain",
            language: "text",
            lineCount: 1
        )

        XCTAssertEqual(response.path, "/tmp/file.txt")
        XCTAssertEqual(response.name, "file.txt")
        XCTAssertEqual(response.content, "Hello")
        XCTAssertEqual(response.size, 12)
        XCTAssertEqual(response.modified, "2024-12-31T11:22:33Z")
        XCTAssertEqual(response.mimeType, "text/plain")
        XCTAssertEqual(response.language, "text")
        XCTAssertEqual(response.lineCount, 1)
    }

    func testCLIFileContentResponseFileNameUsesNameWhenPresent() {
        let response = CLIFileContentResponse(
            path: "/tmp/file.txt",
            name: "override.txt",
            content: "",
            size: nil,
            modified: nil,
            mimeType: nil,
            language: nil,
            lineCount: nil
        )

        XCTAssertEqual(response.fileName, "override.txt")
    }

    func testCLIFileContentResponseFileNameUsesPathComponentWhenNameNil() {
        let response = CLIFileContentResponse(
            path: "/tmp/another.txt",
            name: nil,
            content: "",
            size: nil,
            modified: nil,
            mimeType: nil,
            language: nil,
            lineCount: nil
        )

        XCTAssertEqual(response.fileName, "another.txt")
    }

    func testCLIFileContentResponseFormattedSizeUsesByteCountFormatter() {
        let response = CLIFileContentResponse(
            path: "/tmp/file.txt",
            name: nil,
            content: "",
            size: 2048,
            modified: nil,
            mimeType: nil,
            language: nil,
            lineCount: nil
        )

        XCTAssertEqual(response.formattedSize, formattedByteCount(2048))
    }

    func testCLIFileContentResponseFormattedSizeNilWhenMissing() {
        let response = CLIFileContentResponse(
            path: "/tmp/file.txt",
            name: nil,
            content: "",
            size: nil,
            modified: nil,
            mimeType: nil,
            language: nil,
            lineCount: nil
        )

        XCTAssertNil(response.formattedSize)
    }

    func testCLIFileContentResponseModifiedDateParsesFractionalSeconds() {
        let timestamp = "2024-12-31T11:22:33.789Z"
        let response = CLIFileContentResponse(
            path: "/tmp/file.txt",
            name: nil,
            content: "",
            size: nil,
            modified: timestamp,
            mimeType: nil,
            language: nil,
            lineCount: nil
        )

        XCTAssertEqual(response.modifiedDate, isoDate(timestamp, withFractionalSeconds: true))
    }

    func testCLIFileContentResponseModifiedDateParsesNonFractionalSeconds() {
        let timestamp = "2024-12-31T11:22:33Z"
        let response = CLIFileContentResponse(
            path: "/tmp/file.txt",
            name: nil,
            content: "",
            size: nil,
            modified: timestamp,
            mimeType: nil,
            language: nil,
            lineCount: nil
        )

        XCTAssertEqual(response.modifiedDate, isoDate(timestamp, withFractionalSeconds: false))
    }

    func testCLIFileContentResponseModifiedDateNilWhenMissing() {
        let response = CLIFileContentResponse(
            path: "/tmp/file.txt",
            name: nil,
            content: "",
            size: nil,
            modified: nil,
            mimeType: nil,
            language: nil,
            lineCount: nil
        )

        XCTAssertNil(response.modifiedDate)
    }
}
