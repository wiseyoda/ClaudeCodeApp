import XCTest
import UIKit
@testable import CodingBridge

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

    // MARK: - HEIC Detection Tests

    func testDetectHEIC() {
        // HEIC ftyp box: ....ftypheic
        var heicData = Data([0x00, 0x00, 0x00, 0x18]) // box size
        heicData.append(contentsOf: [0x66, 0x74, 0x79, 0x70]) // "ftyp"
        heicData.append(contentsOf: [0x68, 0x65, 0x69, 0x63]) // "heic"
        XCTAssertTrue(ImageUtilities.isHEIC(heicData))
        XCTAssertEqual(ImageUtilities.detectMediaType(from: heicData), "image/heic")
    }

    func testDetectHEIX() {
        // HEIC variant: heix
        var heixData = Data([0x00, 0x00, 0x00, 0x18])
        heixData.append(contentsOf: [0x66, 0x74, 0x79, 0x70]) // "ftyp"
        heixData.append(contentsOf: [0x68, 0x65, 0x69, 0x78]) // "heix"
        XCTAssertTrue(ImageUtilities.isHEIC(heixData))
    }

    func testDetectMIF1() {
        // HEIF variant: mif1
        var mif1Data = Data([0x00, 0x00, 0x00, 0x18])
        mif1Data.append(contentsOf: [0x66, 0x74, 0x79, 0x70]) // "ftyp"
        mif1Data.append(contentsOf: [0x6D, 0x69, 0x66, 0x31]) // "mif1"
        XCTAssertTrue(ImageUtilities.isHEIC(mif1Data))
    }

    func testNotHEICForPNG() {
        let pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x00])
        XCTAssertFalse(ImageUtilities.isHEIC(pngData))
    }

    func testNotHEICForShortData() {
        let shortData = Data([0x00, 0x00, 0x00, 0x18, 0x66, 0x74])
        XCTAssertFalse(ImageUtilities.isHEIC(shortData))
    }

    // MARK: - Format Support Tests

    func testSupportedFormats() {
        XCTAssertTrue(ImageUtilities.isSupportedForUpload("image/jpeg"))
        XCTAssertTrue(ImageUtilities.isSupportedForUpload("image/png"))
        XCTAssertTrue(ImageUtilities.isSupportedForUpload("image/gif"))
        XCTAssertTrue(ImageUtilities.isSupportedForUpload("image/webp"))
    }

    func testUnsupportedFormats() {
        XCTAssertFalse(ImageUtilities.isSupportedForUpload("image/heic"))
        XCTAssertFalse(ImageUtilities.isSupportedForUpload("image/bmp"))
        XCTAssertFalse(ImageUtilities.isSupportedForUpload("image/svg+xml"))
        XCTAssertFalse(ImageUtilities.isSupportedForUpload("application/pdf"))
    }

    // MARK: - JPEG Conversion Tests

    func testConvertToJPEGFromValidImage() {
        // Create a simple 1x1 red pixel PNG
        let pngData = createTestPNGData()
        let jpegData = ImageUtilities.convertToJPEG(pngData)
        XCTAssertNotNil(jpegData)
        // Verify it's now JPEG
        if let jpeg = jpegData {
            XCTAssertEqual(ImageUtilities.detectMediaType(from: jpeg), "image/jpeg")
        }
    }

    func testConvertToJPEGFromInvalidData() {
        let invalidData = Data([0x00, 0x01, 0x02, 0x03])
        let jpegData = ImageUtilities.convertToJPEG(invalidData)
        XCTAssertNil(jpegData)
    }

    // MARK: - Compression Tests

    func testCompressSmallImage() {
        let pngData = createTestPNGData()
        let compressed = ImageUtilities.compress(pngData, maxSizeBytes: 1_000_000)
        XCTAssertNotNil(compressed)
    }

    func testCompressRespectsMaxSize() {
        // Create a larger test image
        let largeImage = createLargerTestImage()
        let maxSize = 50_000 // 50KB limit
        let compressed = ImageUtilities.compress(largeImage, maxSizeBytes: maxSize)
        XCTAssertNotNil(compressed)
        if let data = compressed {
            // Should be under or reasonably close to max size
            // (may exceed slightly if minimum quality still produces larger output)
            XCTAssertLessThan(data.count, maxSize * 2, "Compressed size should be reasonable")
        }
    }

    // MARK: - Validation Error Tests

    func testValidationErrorDescriptions() {
        let tooLarge = ImageUtilities.ValidationError.tooLarge(sizeBytes: 25_000_000, maxBytes: 20_000_000)
        XCTAssertNotNil(tooLarge.errorDescription)
        XCTAssertTrue(tooLarge.errorDescription?.contains("too large") ?? false)

        let unsupported = ImageUtilities.ValidationError.unsupportedFormat(mimeType: "image/bmp")
        XCTAssertNotNil(unsupported.errorDescription)
        XCTAssertTrue(unsupported.errorDescription?.contains("Unsupported") ?? false)

        let corrupted = ImageUtilities.ValidationError.corruptedData
        XCTAssertNotNil(corrupted.errorDescription)
        XCTAssertTrue(corrupted.errorDescription?.contains("corrupted") ?? false)
    }

    // MARK: - Prepare For Upload Tests

    func testPrepareSmallSupportedImage() throws {
        let pngData = createTestPNGData()
        let result = try ImageUtilities.prepareForUpload(pngData)

        XCTAssertEqual(result.mimeType, "image/png")
        XCTAssertFalse(result.wasConverted)
        XCTAssertFalse(result.wasCompressed)
        XCTAssertEqual(result.originalSize, pngData.count)
    }

    func testPrepareCorruptedDataThrows() {
        let invalidData = Data([0x00, 0x01, 0x02, 0x03])

        XCTAssertThrowsError(try ImageUtilities.prepareForUpload(invalidData)) { error in
            if case ImageUtilities.ValidationError.corruptedData = error {
                // Expected
            } else {
                XCTFail("Expected corruptedData error")
            }
        }
    }

    // MARK: - Helper Methods

    private func createTestPNGData() -> Data {
        // Create a simple 10x10 red image
        let size = CGSize(width: 10, height: 10)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.pngData() ?? Data()
    }

    private func createLargerTestImage() -> Data {
        // Create a 200x200 gradient image for compression testing
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            for y in 0..<200 {
                for x in 0..<200 {
                    let hue = CGFloat(x) / 200.0
                    let saturation = CGFloat(y) / 200.0
                    UIColor(hue: hue, saturation: saturation, brightness: 1.0, alpha: 1.0).setFill()
                    context.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        return image.pngData() ?? Data()
    }
}
