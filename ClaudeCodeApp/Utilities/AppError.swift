import Foundation

// MARK: - App Errors

enum AppError: LocalizedError {
    case networkUnavailable
    case serverUnreachable(String)
    case connectionFailed(String)
    case authenticationFailed
    case sessionExpired
    case messageFailed(String)
    case imageUploadFailed(String)
    case sshConnectionFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "No internet connection"
        case .serverUnreachable(let url):
            return "Cannot reach server at \(url)"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .authenticationFailed:
            return "Authentication failed"
        case .sessionExpired:
            return "Session expired"
        case .messageFailed(let reason):
            return "Message failed: \(reason)"
        case .imageUploadFailed(let reason):
            return "Image upload failed: \(reason)"
        case .sshConnectionFailed(let reason):
            return "SSH connection failed: \(reason)"
        case .invalidResponse:
            return "Invalid server response"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Check your internet connection and try again."
        case .serverUnreachable:
            return "Check that Tailscale is connected and the server is running."
        case .connectionFailed:
            return "The server may be temporarily unavailable. Try again in a moment."
        case .authenticationFailed:
            return "Check your credentials in Settings."
        case .sessionExpired:
            return "Please reconnect to continue."
        case .messageFailed:
            return "Your message could not be sent. It will be retried automatically."
        case .imageUploadFailed:
            return "The image could not be uploaded. Try a smaller image or check your connection."
        case .sshConnectionFailed:
            return "Check SSH credentials in Settings and ensure the server is reachable."
        case .invalidResponse:
            return "The server returned an unexpected response. Try again."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .serverUnreachable, .connectionFailed, .messageFailed:
            return true
        case .authenticationFailed, .sessionExpired, .invalidResponse, .imageUploadFailed, .sshConnectionFailed:
            return false
        }
    }

    /// SF Symbol icon name for this error type
    var icon: String {
        switch self {
        case .networkUnavailable:
            return "wifi.slash"
        case .serverUnreachable, .connectionFailed:
            return "network.slash"
        case .authenticationFailed:
            return "lock.slash"
        case .sessionExpired:
            return "clock.badge.exclamationmark"
        case .messageFailed:
            return "bubble.left.and.exclamationmark.bubble.right"
        case .imageUploadFailed:
            return "photo.badge.exclamationmark"
        case .sshConnectionFailed:
            return "terminal"
        case .invalidResponse:
            return "exclamationmark.triangle"
        }
    }
}

// MARK: - Error Alert Helper

struct ErrorAlert: Identifiable {
    let id = UUID()
    let error: AppError
    let dismissAction: (() -> Void)?

    init(_ error: AppError, dismissAction: (() -> Void)? = nil) {
        self.error = error
        self.dismissAction = dismissAction
    }

    var title: String {
        switch error {
        case .networkUnavailable:
            return "Network Error"
        case .serverUnreachable, .connectionFailed:
            return "Connection Error"
        case .authenticationFailed:
            return "Authentication Error"
        case .sessionExpired:
            return "Session Expired"
        case .messageFailed:
            return "Message Error"
        case .imageUploadFailed:
            return "Upload Error"
        case .sshConnectionFailed:
            return "SSH Error"
        case .invalidResponse:
            return "Server Error"
        }
    }
}
