import XCTest
import Foundation
@testable import CodingBridge

private final class PushNotificationMockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var requestObserver: ((URLRequest) -> Void)?

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "mock.server"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        if let observer = Self.requestObserver {
            observer(request)
        }

        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class RequestRecorder {
    private let lock = NSLock()
    private var stored: [URLRequest] = []

    func record(_ request: URLRequest) {
        lock.lock()
        stored.append(request)
        lock.unlock()
    }

    func reset() {
        lock.lock()
        stored.removeAll()
        lock.unlock()
    }

    var requests: [URLRequest] {
        lock.lock()
        let copy = stored
        lock.unlock()
        return copy
    }
}

private final class ResponseSequencer {
    private let lock = NSLock()
    private var index = 0

    func nextIndex() -> Int {
        lock.lock()
        let value = index
        index += 1
        lock.unlock()
        return value
    }
}

private func makeJSONResponse(for request: URLRequest, statusCode: Int = 200, json: String) -> (HTTPURLResponse, Data) {
    let url = request.url ?? URL(string: "https://mock.server")!
    let response = HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
    )!
    return (response, Data(json.utf8))
}

private func decodeJSONBody(_ request: URLRequest) -> [String: Any]? {
    let bodyData: Data?
    if let body = request.httpBody {
        bodyData = body
    } else if let stream = request.httpBodyStream {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        bodyData = data
    } else {
        bodyData = nil
    }

    guard let payload = bodyData, !payload.isEmpty else { return nil }
    return (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any]
}

@MainActor
final class PushNotificationManagerTests: XCTestCase {
    private var manager: PushNotificationManager!
    private var recorder: RequestRecorder!
    private var mockSession: URLSession!

    override func setUp() {
        super.setUp()
        KeychainHelper.shared.deleteFCMToken()
        recorder = RequestRecorder()
        PushNotificationMockURLProtocol.requestObserver = { [weak recorder] request in
            recorder?.record(request)
        }
        PushNotificationMockURLProtocol.requestHandler = nil
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PushNotificationMockURLProtocol.self]
        mockSession = URLSession(configuration: config)
        manager = PushNotificationManager.makeForTesting()
    }

    override func tearDown() {
        manager.resetForTesting()
        PushNotificationMockURLProtocol.requestHandler = nil
        PushNotificationMockURLProtocol.requestObserver = nil
        mockSession = nil
        recorder = nil
        manager = nil
        super.tearDown()
    }

    private func configure(serverURL: String = "https://mock.server") {
        manager.configure(serverURL: serverURL, session: mockSession)
    }

    private func setDeviceToken(_ bytes: [UInt8]) {
        manager.didRegisterForRemoteNotifications(deviceToken: Data(bytes))
    }

    private func captureNotifications(for names: [Notification.Name], userInfo: [AnyHashable: Any]) -> [Notification.Name] {
        var receivedNames: [Notification.Name] = []
        var observers: [NSObjectProtocol] = []

        for name in names {
            let observer = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { _ in
                receivedNames.append(name)
            }
            observers.append(observer)
        }

        manager.handleNotification(userInfo: userInfo)
        observers.forEach { NotificationCenter.default.removeObserver($0) }

        return receivedNames
    }

    private func assertNotificationPosted(name: Notification.Name, type: String) {
        var received: Notification?
        let observer = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { notification in
            received = notification
        }

        manager.handleNotification(userInfo: ["type": type, "payload": "value"])
        NotificationCenter.default.removeObserver(observer)

        XCTAssertEqual(received?.name, name)
        XCTAssertEqual(received?.userInfo?["payload"] as? String, "value")
    }

    func test_shared_returnsSingleton() {
        let first = PushNotificationManager.shared
        let second = PushNotificationManager.shared
        XCTAssertTrue(first === second)
    }

    func test_init_tokenIsNil() {
        XCTAssertNil(manager.fcmToken)
    }

    func test_init_isRegisteredIsFalse() {
        XCTAssertFalse(manager.isRegistered)
    }

    func test_init_lastErrorIsNil() {
        XCTAssertNil(manager.registrationError)
    }

    func test_setDeviceToken_storesToken() {
        setDeviceToken([0x12, 0x34, 0xab, 0xcd])
        XCTAssertEqual(manager.fcmToken, "1234abcd")
    }

    func test_setDeviceToken_convertsDataToString() {
        setDeviceToken([0x00, 0x0f, 0xa0])
        XCTAssertEqual(manager.fcmToken, "000fa0")
    }

    func test_setDeviceToken_persistsToKeychain() {
        setDeviceToken([0xde, 0xad, 0xbe, 0xef])
        XCTAssertEqual(KeychainHelper.shared.retrieveFCMToken(), "deadbeef")
    }

    func test_clearDeviceToken_clearsToken() async {
        configure()
        setDeviceToken([0xaa, 0xbb, 0xcc])

        PushNotificationMockURLProtocol.requestHandler = { request in
            makeJSONResponse(for: request, json: "{\"success\":true,\"tokenId\":\"token-1\"}")
        }

        await manager.invalidateToken()

        XCTAssertNil(manager.fcmToken)
        XCTAssertNil(KeychainHelper.shared.retrieveFCMToken())
    }

    func test_clearDeviceToken_setsIsRegisteredFalse() async {
        configure()
        setDeviceToken([0x01, 0x02, 0x03])

        PushNotificationMockURLProtocol.requestHandler = { request in
            switch request.url?.path {
            case "/api/push/register":
                return makeJSONResponse(for: request, json: "{\"success\":true,\"tokenId\":\"token-1\"}")
            case "/api/push/invalidate":
                return makeJSONResponse(for: request, json: "{\"success\":true,\"tokenId\":\"token-1\"}")
            default:
                return makeJSONResponse(for: request, json: "{\"success\":true,\"tokenId\":\"token-1\"}")
            }
        }

        await manager.registerWithBackend()
        XCTAssertTrue(manager.isRegistered)

        await manager.invalidateToken()
        XCTAssertFalse(manager.isRegistered)
    }

    func test_registerToken_success() async {
        configure()
        setDeviceToken([0x10, 0x20, 0x30])

        PushNotificationMockURLProtocol.requestHandler = { request in
            makeJSONResponse(for: request, json: "{\"success\":true,\"tokenId\":\"token-1\"}")
        }

        await manager.registerWithBackend()

        XCTAssertTrue(manager.isRegistered)
        XCTAssertNil(manager.registrationError)

        guard let request = recorder.requests.first else {
            XCTFail("Expected register request")
            return
        }
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/push/register")

        let body = decodeJSONBody(request)
        XCTAssertEqual(body?["fcmToken"] as? String, "102030")
        #if DEBUG
        let expectedEnvironment = "sandbox"
        #else
        let expectedEnvironment = "production"
        #endif
        XCTAssertEqual(body?["environment"] as? String, expectedEnvironment)
        XCTAssertEqual(body?["platform"] as? String, "ios")
    }

    func test_registerToken_setsIsRegistered() async {
        configure()
        setDeviceToken([0x11, 0x22, 0x33])

        let sequencer = ResponseSequencer()
        PushNotificationMockURLProtocol.requestHandler = { request in
            let index = sequencer.nextIndex()
            let json = index == 0 ? "{\"success\":true,\"tokenId\":\"token-1\"}" : "{\"success\":false,\"tokenId\":\"token-2\"}"
            return makeJSONResponse(for: request, json: json)
        }

        await manager.registerWithBackend()
        XCTAssertTrue(manager.isRegistered)

        await manager.registerWithBackend()
        XCTAssertFalse(manager.isRegistered)
    }

    func test_registerToken_noTokenDoesNothing() async {
        configure()
        PushNotificationMockURLProtocol.requestHandler = { request in
            makeJSONResponse(for: request, json: "{\"success\":true,\"tokenId\":\"token-1\"}")
        }

        await manager.registerWithBackend()

        XCTAssertTrue(recorder.requests.isEmpty)
        XCTAssertFalse(manager.isRegistered)
    }

    func test_registerToken_networkErrorSetsLastError() async {
        configure()
        setDeviceToken([0x09, 0x09, 0x09])

        PushNotificationMockURLProtocol.requestHandler = { request in
            makeJSONResponse(for: request, statusCode: 500, json: "{}")
        }

        await manager.registerWithBackend()

        XCTAssertEqual(manager.registrationError, "Server error (500)")
        XCTAssertFalse(manager.isRegistered)
    }

    func test_registerToken_retriesOnFailure() async {
        configure()
        setDeviceToken([0xaa, 0xbb, 0xcc])

        let sequencer = ResponseSequencer()
        PushNotificationMockURLProtocol.requestHandler = { request in
            let index = sequencer.nextIndex()
            if index == 0 {
                return makeJSONResponse(for: request, statusCode: 404, json: "{}")
            }
            return makeJSONResponse(for: request, json: "{\"success\":true,\"tokenId\":\"token-1\"}")
        }

        await manager.registerWithBackend()
        XCTAssertEqual(manager.registrationError, "Push endpoints not available on server")
        XCTAssertFalse(manager.isRegistered)

        await manager.retryPendingRegistration()
        XCTAssertTrue(manager.isRegistered)
        XCTAssertNil(manager.registrationError)
        XCTAssertEqual(recorder.requests.count, 2)
    }

    func test_invalidateToken_success() async {
        configure()
        setDeviceToken([0xca, 0xfe])

        PushNotificationMockURLProtocol.requestHandler = { request in
            makeJSONResponse(for: request, json: "{\"success\":true,\"tokenId\":\"token-1\"}")
        }

        await manager.invalidateToken()

        XCTAssertEqual(recorder.requests.count, 1)
        guard let request = recorder.requests.first else {
            XCTFail("Expected invalidate request")
            return
        }
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertEqual(request.url?.path, "/api/push/invalidate")

        let body = decodeJSONBody(request)
        XCTAssertEqual(body?["tokenType"] as? String, "fcm")
        XCTAssertEqual(body?["token"] as? String, "cafe")
    }

    func test_invalidateToken_clearsIsRegistered() async {
        configure()
        setDeviceToken([0x01, 0x02, 0x03])

        PushNotificationMockURLProtocol.requestHandler = { request in
            switch request.url?.path {
            case "/api/push/register":
                return makeJSONResponse(for: request, json: "{\"success\":true,\"tokenId\":\"token-1\"}")
            case "/api/push/invalidate":
                return makeJSONResponse(for: request, json: "{\"success\":true,\"tokenId\":\"token-1\"}")
            default:
                return makeJSONResponse(for: request, json: "{\"success\":true,\"tokenId\":\"token-1\"}")
            }
        }

        await manager.registerWithBackend()
        XCTAssertTrue(manager.isRegistered)

        await manager.invalidateToken()
        XCTAssertFalse(manager.isRegistered)
    }

    func test_invalidateToken_noTokenDoesNothing() async {
        configure()
        PushNotificationMockURLProtocol.requestHandler = { request in
            makeJSONResponse(for: request, json: "{\"success\":true,\"tokenId\":\"token-1\"}")
        }

        await manager.invalidateToken()

        XCTAssertTrue(recorder.requests.isEmpty)
    }

    func test_invalidateToken_networkErrorStillClearsToken() async {
        configure()
        setDeviceToken([0xde, 0xad])

        PushNotificationMockURLProtocol.requestHandler = { request in
            makeJSONResponse(for: request, statusCode: 500, json: "{}")
        }

        await manager.invalidateToken()

        XCTAssertNil(manager.fcmToken)
        XCTAssertFalse(manager.isRegistered)
        XCTAssertEqual(recorder.requests.count, 1)
    }

    func test_checkStatus_returnsServerStatus() async {
        configure()

        PushNotificationMockURLProtocol.requestHandler = { request in
            let json = """
            {"provider":"fcm","providerEnabled":true,"fcmTokenRegistered":true,"fcmTokenLastUpdated":"2025-01-01T00:00:00Z","liveActivityTokens":[{"activityId":"act-1","sessionId":"sess-1","registeredAt":"2025-01-01T00:00:00Z","hasUpdateToken":true,"hasPushToStartToken":false}],"recentDeliveries":[]}
            """
            return makeJSONResponse(for: request, json: json)
        }

        let status = await manager.checkStatus()

        XCTAssertEqual(status?.provider, "fcm")
        XCTAssertEqual(status?.fcmTokenRegistered, true)
        XCTAssertEqual(status?.liveActivityTokens.first?.activityId, "act-1")
        XCTAssertTrue(manager.isRegistered)
    }

    func test_checkStatus_handlesNoTokens() async {
        configure()

        PushNotificationMockURLProtocol.requestHandler = { request in
            let json = """
            {"provider":"fcm","providerEnabled":true,"fcmTokenRegistered":false,"fcmTokenLastUpdated":null,"liveActivityTokens":[],"recentDeliveries":[]}
            """
            return makeJSONResponse(for: request, json: json)
        }

        let status = await manager.checkStatus()

        XCTAssertNotNil(status)
        XCTAssertEqual(status?.fcmTokenRegistered, false)
        XCTAssertFalse(manager.isRegistered)
    }

    func test_checkStatus_networkError() async {
        configure()

        PushNotificationMockURLProtocol.requestHandler = { request in
            makeJSONResponse(for: request, statusCode: 500, json: "{}")
        }

        let status = await manager.checkStatus()

        XCTAssertNil(status)
    }

    func test_configure_setsServerURL() async {
        configure(serverURL: "https://mock.server/")
        setDeviceToken([0xab, 0xcd])

        PushNotificationMockURLProtocol.requestHandler = { request in
            makeJSONResponse(for: request, json: "{\"success\":true,\"tokenId\":\"token-1\"}")
        }

        await manager.registerWithBackend()

        guard let request = recorder.requests.first else {
            XCTFail("Expected register request")
            return
        }
        XCTAssertEqual(request.url?.absoluteString, "https://mock.server/api/push/register")
    }

    func test_configure_createsAPIClient() async {
        configure()

        PushNotificationMockURLProtocol.requestHandler = { request in
            let json = """
            {"provider":"fcm","providerEnabled":true,"fcmTokenRegistered":false,"fcmTokenLastUpdated":null,"liveActivityTokens":[],"recentDeliveries":[]}
            """
            return makeJSONResponse(for: request, json: json)
        }

        let status = await manager.checkStatus()
        XCTAssertNotNil(status)
    }

    func test_isConfigured_trueAfterConfigure() async {
        configure()
        setDeviceToken([0x01, 0x02])

        PushNotificationMockURLProtocol.requestHandler = { request in
            makeJSONResponse(for: request, json: "{\"success\":true,\"tokenId\":\"token-1\"}")
        }

        await manager.registerWithBackend()
        XCTAssertEqual(recorder.requests.count, 1)
    }

    func test_isConfigured_falseBeforeConfigure() async {
        setDeviceToken([0x01, 0x02])
        PushNotificationMockURLProtocol.requestHandler = { request in
            makeJSONResponse(for: request, json: "{\"success\":true,\"tokenId\":\"token-1\"}")
        }

        await manager.registerWithBackend()

        XCTAssertTrue(recorder.requests.isEmpty)
    }

    func test_handleNotification_taskComplete_postsNotification() {
        assertNotificationPosted(name: .pushTaskComplete, type: "task_complete")
    }

    func test_handleNotification_taskError_postsNotification() {
        assertNotificationPosted(name: .pushTaskError, type: "task_error")
    }

    func test_handleNotification_approvalRequest_postsNotification() {
        assertNotificationPosted(name: .pushApprovalRequest, type: "approval_request")
    }

    func test_handleNotification_question_postsNotification() {
        assertNotificationPosted(name: .pushQuestion, type: "question")
    }

    func test_handleNotification_sessionWarning_postsNotification() {
        assertNotificationPosted(name: .pushSessionWarning, type: "session_warning")
    }

    func test_handleNotification_unknownType_doesNotPost() {
        let names: [Notification.Name] = [
            .pushTaskComplete,
            .pushTaskError,
            .pushApprovalRequest,
            .pushQuestion,
            .pushSessionWarning
        ]

        let received = captureNotifications(for: names, userInfo: ["type": "unknown"])
        XCTAssertTrue(received.isEmpty)
    }

    func test_handleNotification_missingType_doesNotPost() {
        let names: [Notification.Name] = [
            .pushTaskComplete,
            .pushTaskError,
            .pushApprovalRequest,
            .pushQuestion,
            .pushSessionWarning
        ]

        let received = captureNotifications(for: names, userInfo: ["message": "hi"])
        XCTAssertTrue(received.isEmpty)
    }

    func test_didFailToRegisterForRemoteNotifications_setsError() {
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"])
        manager.didFailToRegisterForRemoteNotifications(error: error)
        XCTAssertEqual(manager.registrationError, "boom")
    }
}
