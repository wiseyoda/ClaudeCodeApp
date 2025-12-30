import Foundation
import UIKit

/// Represents an image attachment for sending with messages
/// Tracks the full lifecycle from selection through upload/inline encoding
struct ImageAttachment: Identifiable, Equatable {
    let id: UUID
    let originalData: Data
    var processedData: Data?
    var mimeType: String
    var uploadState: UploadState = .pending
    var referenceId: String?

    /// Upload state for tracking progress
    enum UploadState: Equatable {
        case pending              // Not yet processed
        case processing           // Converting/compressing
        case uploading(Double)    // Upload in progress (0.0-1.0)
        case uploaded(String)     // Uploaded, has reference ID
        case inline               // Will be sent as base64
        case failed(String)       // Upload failed with error

        var isComplete: Bool {
            switch self {
            case .uploaded, .inline:
                return true
            default:
                return false
            }
        }

        var isInProgress: Bool {
            switch self {
            case .processing, .uploading:
                return true
            default:
                return false
            }
        }
    }

    /// Size threshold for deciding upload vs inline (500KB)
    static let uploadThreshold = 500_000

    /// Maximum allowed image size (20MB server limit)
    static let maxImageSize = 20_000_000

    /// Maximum number of images per message
    static let maxImagesPerMessage = 5

    // MARK: - Initialization

    init(id: UUID = UUID(), data: Data) {
        self.id = id
        self.originalData = data
        self.mimeType = ImageUtilities.detectMediaType(from: data)
    }

    // MARK: - Computed Properties

    /// The data to use for sending (processed if available, otherwise original)
    var dataForSending: Data {
        processedData ?? originalData
    }

    /// Size of data that will be sent
    var sizeBytes: Int {
        dataForSending.count
    }

    /// Whether this image should be uploaded vs sent inline
    var shouldUpload: Bool {
        sizeBytes > Self.uploadThreshold
    }

    /// UIImage for display (uses original for better quality thumbnails)
    var displayImage: UIImage? {
        UIImage(data: originalData)
    }

    /// Thumbnail UIImage for compact display
    var thumbnailImage: UIImage? {
        guard let image = displayImage else { return nil }
        let targetSize = CGSize(width: 120, height: 120)
        return image.preparingThumbnail(of: targetSize)
    }

    /// Human-readable size string
    var sizeString: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(sizeBytes))
    }

    // MARK: - Equatable

    static func == (lhs: ImageAttachment, rhs: ImageAttachment) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Array Extension

extension Array where Element == ImageAttachment {
    /// Whether all images are ready to send
    var allReady: Bool {
        allSatisfy { $0.uploadState.isComplete }
    }

    /// Whether any image is currently processing/uploading
    var hasInProgress: Bool {
        contains { $0.uploadState.isInProgress }
    }

    /// Total size of all images
    var totalSize: Int {
        reduce(0) { $0 + $1.sizeBytes }
    }

    /// Number of images that will be uploaded
    var uploadCount: Int {
        filter { $0.shouldUpload }.count
    }

    /// Number of images that will be inlined
    var inlineCount: Int {
        filter { !$0.shouldUpload }.count
    }
}
