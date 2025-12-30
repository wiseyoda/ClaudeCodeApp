import UIKit

/// Centralized haptic feedback manager for consistent tactile feedback across the app
enum HapticManager {
    // MARK: - Impact Feedback

    /// Light impact - for subtle confirmations (copy, toggle)
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Medium impact - for primary actions (send, select)
    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Heavy impact - for strong confirmations (commit, publish)
    static func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    /// Rigid impact - for definitive actions (abort, delete)
    static func rigid() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }

    /// Soft impact - for gentle confirmations (hover, subtle toggle)
    static func soft() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
    }

    // MARK: - Notification Feedback

    /// Success notification - for completed actions
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Warning notification - for important alerts
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    /// Error notification - for failures
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    // MARK: - Selection Feedback

    /// Selection changed - for picker/list selection
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
