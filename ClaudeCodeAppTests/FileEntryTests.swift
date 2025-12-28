import XCTest
@testable import CodingBridge

final class FileEntryTests: XCTestCase {
    func testParseFileEntry() {
        let line = "-rw-r--r--  1 user group  1234 Dec 26 12:34 file.txt"
        let entry = FileEntry.parse(from: line, basePath: "/tmp")

        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.name, "file.txt")
        XCTAssertEqual(entry?.path, "/tmp/file.txt")
        XCTAssertEqual(entry?.size, 1234)
        XCTAssertEqual(entry?.permissions, "-rw-r--r--")
        XCTAssertEqual(entry?.isDirectory, false)
        XCTAssertEqual(entry?.isSymlink, false)
    }

    func testParseDirectoryEntryWithTrailingSlash() {
        let line = "drwxr-xr-x  2 user group  4096 Dec 26 12:34 folder/"
        let entry = FileEntry.parse(from: line, basePath: "/var")

        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.name, "folder")
        XCTAssertEqual(entry?.path, "/var/folder")
        XCTAssertEqual(entry?.isDirectory, true)
        XCTAssertEqual(entry?.icon, "folder.fill")
        XCTAssertEqual(entry?.formattedSize, "")
    }

    func testParseSymlinkEntry() {
        let line = "lrwxr-xr-x  1 user group  5 Dec 26 12:34 link@ -> target"
        let entry = FileEntry.parse(from: line, basePath: "/home")

        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.name, "link")
        XCTAssertEqual(entry?.isSymlink, true)
        XCTAssertEqual(entry?.isDirectory, false)
        XCTAssertEqual(entry?.icon, "link")
    }

    func testParseSkipsDotEntries() {
        let currentLine = "drwxr-xr-x  2 user group  4096 Dec 26 12:34 ."
        let parentLine = "drwxr-xr-x  2 user group  4096 Dec 26 12:34 .."

        XCTAssertNil(FileEntry.parse(from: currentLine, basePath: "/"))
        XCTAssertNil(FileEntry.parse(from: parentLine, basePath: "/"))
    }

    func testParseRejectsShortLine() {
        XCTAssertNil(FileEntry.parse(from: "total 12", basePath: "/tmp"))
    }

    func testIconForCommonExtensions() {
        let swiftEntry = FileEntry(name: "main.swift", path: "/main.swift", isDirectory: false, isSymlink: false, size: 1, permissions: "-rw-r--r--")
        XCTAssertEqual(swiftEntry.icon, "doc.text.fill")

        let jsonEntry = FileEntry(name: "config.json", path: "/config.json", isDirectory: false, isSymlink: false, size: 1, permissions: "-rw-r--r--")
        XCTAssertEqual(jsonEntry.icon, "doc.badge.gearshape.fill")

        let markdownEntry = FileEntry(name: "README.md", path: "/README.md", isDirectory: false, isSymlink: false, size: 1, permissions: "-rw-r--r--")
        XCTAssertEqual(markdownEntry.icon, "doc.richtext.fill")

        let imageEntry = FileEntry(name: "photo.png", path: "/photo.png", isDirectory: false, isSymlink: false, size: 1, permissions: "-rw-r--r--")
        XCTAssertEqual(imageEntry.icon, "photo.fill")

        let defaultEntry = FileEntry(name: "archive.zip", path: "/archive.zip", isDirectory: false, isSymlink: false, size: 1, permissions: "-rw-r--r--")
        XCTAssertEqual(defaultEntry.icon, "doc.fill")
    }

    func testFormattedSizeUsesByteUnits() {
        let byteEntry = FileEntry(name: "file.txt", path: "/file.txt", isDirectory: false, isSymlink: false, size: 512, permissions: "-rw-r--r--")
        XCTAssertEqual(byteEntry.formattedSize, "512 B")

        let kbEntry = FileEntry(name: "file.txt", path: "/file.txt", isDirectory: false, isSymlink: false, size: 1024, permissions: "-rw-r--r--")
        XCTAssertTrue(kbEntry.formattedSize.contains("KB"))
    }

    func testPathForRootBasePath() {
        let line = "-rw-r--r--  1 user group  10 Dec 26 12:34 root.txt"
        let entry = FileEntry.parse(from: line, basePath: "/")

        XCTAssertEqual(entry?.path, "/root.txt")
    }
}
