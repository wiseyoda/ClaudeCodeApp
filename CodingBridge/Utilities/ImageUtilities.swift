import Foundation
import UIKit

/// Shared utilities for image processing
enum ImageUtilities {
    // MARK: - Constants

    /// Default JPEG compression quality
    static let defaultJPEGQuality: CGFloat = 0.85

    /// Maximum image dimension (pixels) before resizing
    static let maxDimension: CGFloat = 4096

    /// Maximum image size in bytes (20MB server limit)
    static let maxSizeBytes = 20_000_000

    /// Minimum compression quality to try
    static let minCompressionQuality: CGFloat = 0.1

    // MARK: - MIME Type Detection

    /// Detect MIME type from image data magic bytes
    /// - Parameter data: Raw image data
    /// - Returns: MIME type string (e.g., "image/png", "image/jpeg")
    static func detectMediaType(from data: Data) -> String {
        guard data.count >= 4 else { return "image/jpeg" }

        let bytes = [UInt8](data.prefix(4))

        // PNG: 89 50 4E 47
        if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "image/png"
        }
        // GIF: 47 49 46 38
        if bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38 {
            return "image/gif"
        }
        // WebP: 52 49 46 46 ... 57 45 42 50
        if bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 {
            if data.count >= 12 {
                let webpBytes = [UInt8](data[8..<12])
                if webpBytes[0] == 0x57 && webpBytes[1] == 0x45 && webpBytes[2] == 0x42 && webpBytes[3] == 0x50 {
                    return "image/webp"
                }
            }
        }
        // HEIC/HEIF: Check for ftyp box with heic/heix/hevc/hevx brand
        if isHEIC(data) {
            return "image/heic"
        }
        // Default to JPEG
        return "image/jpeg"
    }

    // MARK: - HEIC Detection

    /// Check if data is HEIC/HEIF format
    /// HEIC files have an ftyp box with brands like heic, heix, mif1, etc.
    /// - Parameter data: Raw image data
    /// - Returns: true if HEIC format
    static func isHEIC(_ data: Data) -> Bool {
        guard data.count >= 12 else { return false }

        let bytes = [UInt8](data.prefix(12))

        // Check for ftyp box (bytes 4-7 should be "ftyp")
        guard bytes[4] == 0x66 && bytes[5] == 0x74 &&
              bytes[6] == 0x79 && bytes[7] == 0x70 else {
            return false
        }

        // Check major brand (bytes 8-11)
        // Common HEIC brands: heic, heix, mif1, msf1
        let brand = String(bytes: bytes[8..<12], encoding: .ascii) ?? ""
        let heicBrands = ["heic", "heix", "mif1", "msf1", "hevc", "hevx"]
        return heicBrands.contains(brand)
    }

    // MARK: - Image Conversion

    /// Convert image data to JPEG format
    /// Handles HEIC and other formats by decoding and re-encoding
    /// - Parameters:
    ///   - data: Source image data
    ///   - quality: JPEG compression quality (0.0-1.0)
    /// - Returns: JPEG data or nil if conversion fails
    static func convertToJPEG(_ data: Data, quality: CGFloat = defaultJPEGQuality) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return image.jpegData(compressionQuality: quality)
    }

    /// Resize image to fit within maximum dimensions while preserving aspect ratio
    /// - Parameters:
    ///   - image: Source image
    ///   - maxDimension: Maximum width or height
    /// - Returns: Resized image or original if already within bounds
    static func resize(_ image: UIImage, maxDimension: CGFloat = maxDimension) -> UIImage {
        let size = image.size
        let maxCurrent = max(size.width, size.height)

        guard maxCurrent > maxDimension else { return image }

        let scale = maxDimension / maxCurrent
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - Compression

    /// Compress image data to fit within size limit
    /// Iteratively reduces quality until size requirement is met
    /// - Parameters:
    ///   - data: Source image data
    ///   - maxSizeBytes: Maximum allowed size in bytes
    ///   - maxDimension: Maximum dimension for resizing
    /// - Returns: Compressed JPEG data or nil if compression fails
    static func compress(
        _ data: Data,
        maxSizeBytes: Int = maxSizeBytes,
        maxDimension: CGFloat = maxDimension
    ) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        // First resize if needed
        let resizedImage = resize(image, maxDimension: maxDimension)

        // Try progressively lower quality until under size limit
        var quality = defaultJPEGQuality
        var result = resizedImage.jpegData(compressionQuality: quality)

        while let currentData = result, currentData.count > maxSizeBytes && quality > minCompressionQuality {
            quality -= 0.1
            result = resizedImage.jpegData(compressionQuality: quality)
        }

        return result
    }

    // MARK: - Unified Processing

    /// Processing result containing processed data and metadata
    struct ProcessingResult {
        let data: Data
        let mimeType: String
        let wasConverted: Bool
        let wasCompressed: Bool
        let originalSize: Int
        let finalSize: Int
    }

    /// Validation error for image processing
    enum ValidationError: LocalizedError {
        case tooLarge(sizeBytes: Int, maxBytes: Int)
        case unsupportedFormat(mimeType: String)
        case corruptedData
        case conversionFailed

        var errorDescription: String? {
            switch self {
            case .tooLarge(let size, let max):
                let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
                let maxStr = ByteCountFormatter.string(fromByteCount: Int64(max), countStyle: .file)
                return "Image is too large (\(sizeStr)). Maximum size is \(maxStr)."
            case .unsupportedFormat(let mimeType):
                return "Unsupported image format: \(mimeType)"
            case .corruptedData:
                return "Image data appears to be corrupted"
            case .conversionFailed:
                return "Failed to convert image to JPEG"
            }
        }
    }

    /// Prepare image data for upload
    /// Handles HEIC conversion, resizing, and compression
    /// - Parameters:
    ///   - data: Raw image data
    ///   - maxSizeBytes: Maximum allowed size
    /// - Returns: ProcessingResult with processed data and metadata
    /// - Throws: ValidationError if image cannot be processed
    static func prepareForUpload(
        _ data: Data,
        maxSizeBytes: Int = maxSizeBytes
    ) throws -> ProcessingResult {
        let originalSize = data.count
        let originalMimeType = detectMediaType(from: data)

        // Validate we can process this format
        guard UIImage(data: data) != nil else {
            throw ValidationError.corruptedData
        }

        // Check if we need to convert (HEIC or unsupported format)
        let needsConversion = isHEIC(data) || !isSupportedForUpload(originalMimeType)

        // If small enough and supported format, return as-is
        if !needsConversion && originalSize <= maxSizeBytes {
            return ProcessingResult(
                data: data,
                mimeType: originalMimeType,
                wasConverted: false,
                wasCompressed: false,
                originalSize: originalSize,
                finalSize: originalSize
            )
        }

        // Convert/compress to JPEG
        guard let compressedData = compress(data, maxSizeBytes: maxSizeBytes) else {
            throw ValidationError.conversionFailed
        }

        // Final size check
        guard compressedData.count <= maxSizeBytes else {
            throw ValidationError.tooLarge(sizeBytes: compressedData.count, maxBytes: maxSizeBytes)
        }

        return ProcessingResult(
            data: compressedData,
            mimeType: "image/jpeg",
            wasConverted: needsConversion,
            wasCompressed: compressedData.count < originalSize,
            originalSize: originalSize,
            finalSize: compressedData.count
        )
    }

    /// Check if MIME type is supported for upload
    /// - Parameter mimeType: MIME type string
    /// - Returns: true if format is supported by server
    static func isSupportedForUpload(_ mimeType: String) -> Bool {
        let supported = ["image/jpeg", "image/png", "image/gif", "image/webp"]
        return supported.contains(mimeType)
    }
}
