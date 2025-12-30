import Foundation
import ActivityKit
import UIKit

// MARK: - Live Activity Manager
// Manages Live Activities for displaying task progress on Lock Screen and Dynamic Island
// Requires iOS 16.1+ and iPhone 14 Pro+ for Dynamic Island

@MainActor
final class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    // MARK: - Published State

    @Published private(set) var currentActivity: Activity<CodingBridgeAttributes>?
    @Published private(set) var isSupported: Bool = false
    @Published private(set) var isEnabled: Bool = false

    // MARK: - Private State

    private var apiClient: CLIBridgeAPIClient?
    private var elapsedTimer: Timer?
    private var elapsedSeconds: Int = 0
    private var currentSessionId: String?

    // MARK: - Initialization

    private init() {
        checkSupport()
    }

    // MARK: - Configuration

    /// Configure the Live Activity manager with the server URL
    func configure(serverURL: String) {
        apiClient = CLIBridgeAPIClient(serverURL: serverURL)
        checkSupport()
    }

    /// Check if Live Activities are supported and enabled
    private func checkSupport() {
        if #available(iOS 16.1, *) {
            let authInfo = ActivityAuthorizationInfo()
            isSupported = true
            isEnabled = authInfo.areActivitiesEnabled

            // Observe authorization changes
            Task {
                for await enabled in authInfo.activityEnablementUpdates {
                    await MainActor.run {
                        self.isEnabled = enabled
                    }
                }
            }
        } else {
            isSupported = false
            isEnabled = false
        }
    }

    // MARK: - Activity Lifecycle

    /// Start a new Live Activity for a session
    func startActivity(projectName: String, sessionId: String, modelName: String? = nil) async throws {
        guard isSupported && isEnabled else {
            log.warning("[LiveActivity] Not supported or not enabled")
            return
        }

        // End any existing activity
        await endActivity()

        let attributes = CodingBridgeAttributes(
            sessionId: sessionId,
            projectName: projectName,
            modelName: modelName,
            startedAt: Date()
        )

        let initialState = CodingBridgeAttributes.ContentState.processing()

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: .token
            )

            currentActivity = activity
            currentSessionId = sessionId
            startElapsedTimer()

            log.info("[LiveActivity] Started activity for session: \(sessionId)")

            // Register push token with backend
            await registerPushToken(for: activity, sessionId: sessionId)

        } catch {
            log.error("[LiveActivity] Failed to start activity: \(error)")
            throw error
        }
    }

    /// Update the current Live Activity with new state
    func updateActivity(
        status: LiveActivityStatus,
        operation: String?,
        progress: LAProgress? = nil,
        approval: LAApprovalInfo? = nil,
        question: LAQuestionInfo? = nil,
        error: LAErrorInfo? = nil
    ) async {
        guard let activity = currentActivity else {
            log.warning("[LiveActivity] No active activity to update")
            return
        }

        var state = CodingBridgeAttributes.ContentState(
            status: status,
            currentOperation: operation,
            elapsedSeconds: elapsedSeconds,
            todoProgress: progress,
            approvalRequest: approval,
            question: question,
            error: error
        )

        // Include elapsed time
        state.elapsedSeconds = elapsedSeconds

        await activity.update(ActivityContent(state: state, staleDate: nil))
        log.debug("[LiveActivity] Updated: \(status.displayText)")
    }

    /// Update activity to show approval request
    func showApprovalRequest(_ request: CLIPermissionRequest) async {
        let approval = LAApprovalInfo(
            id: request.id,
            toolName: request.tool,
            summary: request.description
        )
        await updateActivity(
            status: .awaitingApproval,
            operation: "Approve \(request.tool)?",
            approval: approval
        )
    }

    /// Update activity to show question
    func showQuestion(_ request: CLIQuestionRequest) async {
        let preview = request.questions.first?.question ?? "Claude has a question"
        let question = LAQuestionInfo(
            id: request.id,
            preview: String(preview.prefix(100))
        )
        await updateActivity(
            status: .awaitingAnswer,
            operation: preview,
            question: question
        )
    }

    /// Update activity to show error
    func showError(_ message: String, recoverable: Bool = true) async {
        let error = LAErrorInfo(message: message, recoverable: recoverable)
        await updateActivity(
            status: .error,
            operation: message,
            error: error
        )
    }

    /// Update activity with todo progress
    func updateProgress(completed: Int, total: Int, currentTask: String?) async {
        let progress = LAProgress(
            completed: completed,
            total: total,
            currentTask: currentTask
        )
        await updateActivity(
            status: .processing,
            operation: currentTask ?? "Working...",
            progress: progress
        )
    }

    /// End the current Live Activity
    func endActivity(immediately: Bool = false) async {
        guard let activity = currentActivity else { return }

        stopElapsedTimer()

        let finalState = CodingBridgeAttributes.ContentState.complete(elapsedSeconds: elapsedSeconds)
        let dismissalPolicy: ActivityUIDismissalPolicy = immediately ? .immediate : .after(.now + 30)

        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: dismissalPolicy
        )

        log.info("[LiveActivity] Ended activity after \(elapsedSeconds) seconds")

        currentActivity = nil
        currentSessionId = nil
        elapsedSeconds = 0
    }

    /// End activity with error
    func endWithError(_ message: String) async {
        guard let activity = currentActivity else { return }

        stopElapsedTimer()

        let error = LAErrorInfo(message: message, recoverable: false)
        let finalState = CodingBridgeAttributes.ContentState.error(error)

        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .after(.now + 60)  // Keep error visible longer
        )

        log.info("[LiveActivity] Ended with error: \(message)")

        currentActivity = nil
        currentSessionId = nil
    }

    // MARK: - Push Token Registration

    private func registerPushToken(for activity: Activity<CodingBridgeAttributes>, sessionId: String) async {
        guard let client = apiClient else { return }

        // Get push token from the activity
        for await tokenData in activity.pushTokenUpdates {
            let token = tokenData.map { String(format: "%02x", $0) }.joined()
            log.info("[LiveActivity] Received push token: \(token.prefix(20))...")

            do {
                let environment = isProductionEnvironment ? "production" : "sandbox"
                _ = try await client.registerLiveActivityToken(
                    pushToken: token,
                    activityId: activity.id,
                    sessionId: sessionId,
                    environment: environment
                )
                log.info("[LiveActivity] Registered push token with backend")
            } catch {
                log.error("[LiveActivity] Failed to register push token: \(error)")
            }

            // Only need the first token
            break
        }
    }

    // MARK: - Push Update Handling

    /// Handle incoming push update for Live Activity
    func handlePushUpdate(_ userInfo: [AnyHashable: Any]) async {
        guard currentActivity != nil else {
            log.warning("[LiveActivity] Received push update but no active activity")
            return
        }

        // Parse the content-state from push payload
        guard let aps = userInfo["aps"] as? [String: Any],
              let contentState = aps["content-state"] as? [String: Any] else {
            log.warning("[LiveActivity] Invalid push payload structure")
            return
        }

        // Parse status
        guard let statusRaw = contentState["status"] as? String,
              let status = LiveActivityStatus(rawValue: statusRaw) else {
            log.warning("[LiveActivity] Missing or invalid status in push")
            return
        }

        let operation = contentState["currentOperation"] as? String
        let elapsedSecondsFromPush = contentState["elapsedSeconds"] as? Int

        // Update elapsed seconds from push if available
        if let elapsed = elapsedSecondsFromPush {
            elapsedSeconds = elapsed
        }

        // Parse optional fields
        var progress: LAProgress?
        if let progressData = contentState["todoProgress"] as? [String: Any],
           let completed = progressData["completed"] as? Int,
           let total = progressData["total"] as? Int {
            progress = LAProgress(
                completed: completed,
                total: total,
                currentTask: progressData["currentTask"] as? String
            )
        }

        await updateActivity(
            status: status,
            operation: operation,
            progress: progress
        )
    }

    // MARK: - Timer Management

    private func startElapsedTimer() {
        elapsedSeconds = 0
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsedSeconds += 1
            }
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    // MARK: - Helpers

    /// Determine if we're in production or sandbox environment
    private var isProductionEnvironment: Bool {
        #if DEBUG
        return false
        #else
        // Check for TestFlight
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return false
        }
        return true
        #endif
    }

    /// Clean up any stale activities from previous app launches
    func cleanupStaleActivities() async {
        guard #available(iOS 16.1, *) else { return }

        for activity in Activity<CodingBridgeAttributes>.activities {
            await activity.end(
                ActivityContent(
                    state: .complete(elapsedSeconds: 0),
                    staleDate: nil
                ),
                dismissalPolicy: .immediate
            )
        }
        log.info("[LiveActivity] Cleaned up stale activities")
    }
}

// MARK: - Convenience Extensions

extension LiveActivityManager {
    /// Check if we have an active Live Activity
    var hasActiveActivity: Bool {
        currentActivity != nil
    }

    /// Get the session ID of the current activity
    var activeSessionId: String? {
        currentSessionId
    }

    /// Formatted elapsed time string
    var formattedElapsedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return "\(seconds)s"
        }
    }
}
