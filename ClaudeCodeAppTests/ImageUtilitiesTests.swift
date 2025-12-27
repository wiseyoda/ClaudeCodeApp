import XCTest
@testable import ClaudeCodeApp

final class ImageUtilitiesTests: XCTestCase {

    func testDetectPNG() {
        // PNG magic bytes: 89 50 4E 47
        let pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        XCTAssertEqual(ImageUtilities.detectMediaType(from: pngData), "image/png")
    }

    func testDetectJPEG() {
        // JPEG magic bytes: FF D8 FF
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
        XCTAssertEqual(ImageUtilities.detectMediaType(from: jpegData), "image/jpeg")
    }

    func testDetectGIF() {
        // GIF magic bytes: 47 49 46 38
        let gifData = Data([0x47, 0x49, 0x46, 0x38, 0x39, 0x61])
        XCTAssertEqual(ImageUtilities.detectMediaType(from: gifData), "image/gif")
    }

    func testDetectWebP() {
        // WebP magic bytes: RIFF....WEBP
        var webpData = Data([0x52, 0x49, 0x46, 0x46]) // RIFF
        webpData.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // size placeholder
        webpData.append(contentsOf: [0x57, 0x45, 0x42, 0x50]) // WEBP
        XCTAssertEqual(ImageUtilities.detectMediaType(from: webpData), "image/webp")
    }

    func testUnknownDefaultsToJPEG() {
        // Random bytes should default to JPEG
        let unknownData = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05])
        XCTAssertEqual(ImageUtilities.detectMediaType(from: unknownData), "image/jpeg")
    }

    func testEmptyDataDefaultsToJPEG() {
        let emptyData = Data()
        XCTAssertEqual(ImageUtilities.detectMediaType(from: emptyData), "image/jpeg")
    }

    func testShortDataDefaultsToJPEG() {
        // Less than 4 bytes
        let shortData = Data([0x89, 0x50])
        XCTAssertEqual(ImageUtilities.detectMediaType(from: shortData), "image/jpeg")
    }
}
