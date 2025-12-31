import Foundation
import ActivityKit
import UIKit

protocol LiveActivityProviding {
    var areActivitiesEnabled: Bool { get }
    func request(
        attributes: CodingBridgeAttributes,
        contentState: CodingBridgeAttributes.ContentState,
        pushType: PushType?
    ) throws -> String
    func update(activityId: String, contentState: CodingBridgeAttributes.ContentState) async throws
    func end(
        activityId: String,
        contentState: CodingBridgeAttributes.ContentState?,
        dismissalPolicy: ActivityUIDismissalPolicy
    ) async throws
    func pushTokenUpdates(activityId: String) -> AsyncStream<Data>?
    func activityReference(activityId: String) -> Activity<CodingBridgeAttributes>?
}

protocol LiveActivityAPIClient {
    func registerLiveActivityToken(
        pushToken: String,
        pushToStartToken: String?,
        activityId: String,
        sessionId: String,
        environment: String
    ) async throws -> CLILiveActivityRegisterResponse
    func invalidatePushToken(
        tokenType: CLIPushInvalidateRequest.TokenType,
        token: String
    ) async throws
}

extension CLIBridgeAPIClient: LiveActivityAPIClient {}

enum LiveActivityProviderError: Error {
    case activityNotFound
    case unsupported
}

final class RealLiveActivityProvider: LiveActivityProviding {
    private var activities: [String: Activity<CodingBridgeAttributes>] = [:]

    var areActivitiesEnabled: Bool {
        if #available(iOS 16.1, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        return false
    }

    func request(
        attributes: CodingBridgeAttributes,
        contentState: CodingBridgeAttributes.ContentState,
        pushType: PushType?
    ) throws -> String {
        guard #available(iOS 16.1, *) else {
            throw LiveActivityProviderError.unsupported
        }

        let activity = try Activity.request(
            attributes: attributes,
            content: .init(state: contentState, staleDate: nil),
            pushType: pushType
        )
        activities[activity.id] = activity
        return activity.id
    }

    func update(activityId: String, contentState: CodingBridgeAttributes.ContentState) async throws {
        guard #available(iOS 16.1, *) else {
            throw LiveActivityProviderError.unsupported
        }
        guard let activity = activityReference(activityId: activityId) else {
            throw LiveActivityProviderError.activityNotFound
        }

        await activity.update(ActivityContent(state: contentState, staleDate: nil))
    }

    func end(
        activityId: String,
        contentState: CodingBridgeAttributes.ContentState?,
        dismissalPolicy: ActivityUIDismissalPolicy
    ) async throws {
        guard #available(iOS 16.1, *) else {
            throw LiveActivityProviderError.unsupported
        }
        guard let activity = activityReference(activityId: activityId) else {
            throw LiveActivityProviderError.activityNotFound
        }

        if let contentState {
            await activity.end(
                ActivityContent(state: contentState, staleDate: nil),
                dismissalPolicy: dismissalPolicy
            )
        } else {
            await activity.end(dismissalPolicy: dismissalPolicy)
        }

        activities[activityId] = nil
    }

    func pushTokenUpdates(activityId: String) -> AsyncStream<Data>? {
        guard #available(iOS 16.1, *) else { return nil }
        guard let activity = activityReference(activityId: activityId) else { return nil }
        return AsyncStream { continuation in
            let task = Task {
                for await token in activity.pushTokenUpdates {
                    continuation.yield(token)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func activityReference(activityId: String) -> Activity<CodingBridgeAttributes>? {
        if let cached = activities[activityId] {
            return cached
        }

        guard #available(iOS 16.1, *) else { return nil }
        return Activity<CodingBridgeAttributes>.activities.first { $0.id == activityId }
    }
}

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

    private var activityProvider: LiveActivityProviding
    private var apiClient: LiveActivityAPIClient?
    private var elapsedTimer: Timer?
    private var elapsedSeconds: Int = 0
    private var currentSessionId: String?
    private var currentActivityId: String?
    private var liveActivityPushToken: String?
    private var lastRegisteredPushToken: String?
    private var lastRegisteredActivityId: String?
    private var pushTokenTask: Task<Void, Never>?
    private var isSupportOverrideEnabled: Bool = false
    private var activeActivityId: String? {
        currentActivityId ?? currentActivity?.id
    }

    // MARK: - Initialization

    private init(activityProvider: LiveActivityProviding = RealLiveActivityProvider()) {
        self.activityProvider = activityProvider
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
                        guard !self.isSupportOverrideEnabled else { return }
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

        if activeActivityId != nil, currentSessionId == sessionId {
            await updateActivity(
                status: .processing,
                operation: "Resuming..."
            )
            return
        }

        if activeActivityId != nil {
            await endActivity()
        }

        let attributes = CodingBridgeAttributes(
            sessionId: sessionId,
            projectName: projectName,
            modelName: modelName,
            startedAt: Date()
        )

        let initialState = CodingBridgeAttributes.ContentState.processing()

        do {
            let activityId = try activityProvider.request(
                attributes: attributes,
                contentState: initialState,
                pushType: .token
            )
            currentActivityId = activityId
            currentActivity = activityProvider.activityReference(activityId: activityId)
            currentSessionId = sessionId
            startElapsedTimer()

            log.info("[LiveActivity] Started activity for session: \(sessionId)")

            // Register push token with backend
            registerPushToken(activityId: activityId, sessionId: sessionId)

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
        guard let activityId = activeActivityId else {
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

        do {
            try await activityProvider.update(activityId: activityId, contentState: state)
            log.debug("[LiveActivity] Updated: \(status.displayText)")
        } catch {
            log.error("[LiveActivity] Failed to update activity: \(error)")
        }
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
        guard let activityId = activeActivityId else { return }

        stopElapsedTimer()

        let finalState = CodingBridgeAttributes.ContentState.complete(elapsedSeconds: elapsedSeconds)
        let dismissalPolicy: ActivityUIDismissalPolicy = immediately ? .immediate : .after(.now + 30)

        do {
            try await activityProvider.end(
                activityId: activityId,
                contentState: finalState,
                dismissalPolicy: dismissalPolicy
            )
        } catch {
            log.error("[LiveActivity] Failed to end activity: \(error)")
        }

        log.info("[LiveActivity] Ended activity after \(elapsedSeconds) seconds")

        currentActivity = nil
        currentActivityId = nil
        currentSessionId = nil
        elapsedSeconds = 0
        lastRegisteredPushToken = nil
        lastRegisteredActivityId = nil
        liveActivityPushToken = nil
        pushTokenTask?.cancel()
        pushTokenTask = nil
    }

    /// End activity with error
    func endWithError(_ message: String) async {
        guard let activityId = activeActivityId else { return }

        stopElapsedTimer()

        let error = LAErrorInfo(message: message, recoverable: false)
        let finalState = CodingBridgeAttributes.ContentState.error(error)

        do {
            try await activityProvider.end(
                activityId: activityId,
                contentState: finalState,
                dismissalPolicy: .after(.now + 60)
            )
        } catch {
            log.error("[LiveActivity] Failed to end activity with error: \(error)")
        }

        log.info("[LiveActivity] Ended with error: \(message)")

        currentActivity = nil
        currentActivityId = nil
        currentSessionId = nil
        lastRegisteredPushToken = nil
        lastRegisteredActivityId = nil
        liveActivityPushToken = nil
        pushTokenTask?.cancel()
        pushTokenTask = nil
    }

    // MARK: - Push Token Registration

    private func registerPushToken(activityId: String, sessionId: String) {
        pushTokenTask?.cancel()
        pushTokenTask = Task { [weak self] in
            guard let self else { return }
            await self.listenForPushTokens(activityId: activityId, sessionId: sessionId)
        }
    }

    private func listenForPushTokens(activityId: String, sessionId: String) async {
        guard let tokenUpdates = activityProvider.pushTokenUpdates(activityId: activityId) else { return }

        for await tokenData in tokenUpdates {
            if Task.isCancelled { break }
            await handlePushTokenUpdate(tokenData, activityId: activityId, sessionId: sessionId)
        }
    }

    private func handlePushTokenUpdate(_ tokenData: Data, activityId: String, sessionId: String) async {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        log.info("[LiveActivity] Received push token: \(token.prefix(20))...")

        liveActivityPushToken = token

        if lastRegisteredPushToken == token, lastRegisteredActivityId == activityId {
            return
        }

        guard let client = apiClient else { return }

        do {
            let environment = isProductionEnvironment ? "production" : "sandbox"
            _ = try await client.registerLiveActivityToken(
                pushToken: token,
                pushToStartToken: nil,
                activityId: activityId,
                sessionId: sessionId,
                environment: environment
            )
            lastRegisteredPushToken = token
            lastRegisteredActivityId = activityId
            log.info("[LiveActivity] Registered push token with backend")
        } catch {
            log.error("[LiveActivity] Failed to register push token: \(error)")
        }
    }

    func invalidatePushToken() async {
        guard let token = liveActivityPushToken else { return }
        guard let client = apiClient else {
            liveActivityPushToken = nil
            lastRegisteredPushToken = nil
            lastRegisteredActivityId = nil
            return
        }

        do {
            try await client.invalidatePushToken(tokenType: .liveActivity, token: token)
            log.info("[LiveActivity] Invalidated push token")
        } catch {
            log.error("[LiveActivity] Failed to invalidate push token: \(error)")
        }

        liveActivityPushToken = nil
        lastRegisteredPushToken = nil
        lastRegisteredActivityId = nil
    }

    // MARK: - Push Update Handling

    /// Handle incoming push update for Live Activity
    func handlePushUpdate(_ userInfo: [AnyHashable: Any]) async {
        guard activeActivityId != nil else {
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
        activeActivityId != nil
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

#if DEBUG
extension LiveActivityManager {
    static func makeForTesting(
        provider: LiveActivityProviding = RealLiveActivityProvider(),
        apiClient: LiveActivityAPIClient? = nil
    ) -> LiveActivityManager {
        let manager = LiveActivityManager(activityProvider: provider)
        manager.apiClient = apiClient
        return manager
    }

    func setSupportForTesting(isSupported: Bool, isEnabled: Bool) {
        isSupportOverrideEnabled = true
        self.isSupported = isSupported
        self.isEnabled = isEnabled
    }

    func setElapsedSecondsForTesting(_ seconds: Int) {
        elapsedSeconds = seconds
    }

    func setCurrentSessionIdForTesting(_ sessionId: String?) {
        currentSessionId = sessionId
    }

    func liveActivityPushTokenForTesting() -> String? {
        liveActivityPushToken
    }

    func resetForTesting() {
        currentActivity = nil
        currentActivityId = nil
        currentSessionId = nil
        elapsedSeconds = 0
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        liveActivityPushToken = nil
        lastRegisteredPushToken = nil
        lastRegisteredActivityId = nil
        pushTokenTask?.cancel()
        pushTokenTask = nil
        isSupportOverrideEnabled = false
    }
}
#endif
