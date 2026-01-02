import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import CodingBridge

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "mock.server"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
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

@MainActor
final class CLIBridgeAdapterTests: XCTestCase {
    enum MockError: LocalizedError {
        case failure

        var errorDescription: String? {
            "mock failure"
        }
    }

    private struct CustomValue: CustomStringConvertible {
        let description: String

        init(_ description: String) {
            self.description = description
        }
    }

    @MainActor
    final class MockCLIBridgeManager: CLIBridgeManager {
        var connectCalls: [(projectPath: String, sessionId: String?, model: String?, helper: Bool)] = []
        var updateServerURLCalls: [String] = []
        var sendInputCalls: [(text: String, images: [CLIImageAttachment]?, thinkingMode: String?)] = []
        var respondToPermissionCalls: [(id: String, choice: CLIPermissionChoice)] = []
        var respondToQuestionCalls: [(id: String, answers: [String: Any])] = []
        var setModelCalls: [String] = []
        var setPermissionModeCalls: [CLIPermissionMode] = []
        var cancelQueuedInputCount = 0
        var interruptCount = 0
        var disconnectCount = 0
        var clearCurrentTextCount = 0

        var connectExpectation: XCTestExpectation?
        var sendInputExpectation: XCTestExpectation?
        var respondToPermissionExpectation: XCTestExpectation?
        var respondToQuestionExpectation: XCTestExpectation?
        var setModelExpectation: XCTestExpectation?
        var setPermissionModeExpectation: XCTestExpectation?
        var cancelQueuedInputExpectation: XCTestExpectation?
        var interruptExpectation: XCTestExpectation?

        var sendInputError: Error?
        var respondToPermissionError: Error?
        var respondToQuestionError: Error?
        var setModelError: Error?
        var setPermissionModeError: Error?
        var cancelQueuedInputError: Error?
        var interruptError: Error?

        override func updateServerURL(_ url: String) {
            updateServerURLCalls.append(url)
        }

        override func connect(
            projectPath: String,
            sessionId: String? = nil,
            model: String? = nil,
            helper: Bool = false
        ) async {
            connectCalls.append((projectPath, sessionId, model, helper))
            connectExpectation?.fulfill()
        }

        override func sendInput(_ text: String, images: [CLIImageAttachment]? = nil, thinkingMode: String? = nil) async throws {
            sendInputCalls.append((text, images, thinkingMode))
            sendInputExpectation?.fulfill()
            if let error = sendInputError {
                throw error
            }
        }

        override func respondToPermission(
            id: String,
            choice: CLIPermissionChoice
        ) async throws {
            respondToPermissionCalls.append((id, choice))
            respondToPermissionExpectation?.fulfill()
            if let error = respondToPermissionError {
                throw error
            }
        }

        override func respondToQuestion(id: String, answers: [String: Any]) async throws {
            respondToQuestionCalls.append((id, answers))
            respondToQuestionExpectation?.fulfill()
            if let error = respondToQuestionError {
                throw error
            }
        }

        override func setModel(_ model: String) async throws {
            setModelCalls.append(model)
            setModelExpectation?.fulfill()
            if let error = setModelError {
                throw error
            }
        }

        override func setPermissionMode(_ mode: CLIPermissionMode) async throws {
            setPermissionModeCalls.append(mode)
            setPermissionModeExpectation?.fulfill()
            if let error = setPermissionModeError {
                throw error
            }
        }

        override func cancelQueuedInput() async throws {
            cancelQueuedInputCount += 1
            cancelQueuedInputExpectation?.fulfill()
            if let error = cancelQueuedInputError {
                throw error
            }
        }

        override func interrupt() async throws {
            interruptCount += 1
            interruptExpectation?.fulfill()
            if let error = interruptError {
                throw error
            }
        }

        override func disconnect(preserveSession: Bool = false) {
            disconnectCount += 1
            connectionState = .disconnected
            agentState = .stopped
        }

        override func clearCurrentText() {
            clearCurrentTextCount += 1
            super.clearCurrentText()
        }
    }

    private func makeAdapter(
        settings: AppSettings? = nil,
        manager: MockCLIBridgeManager? = nil
    ) async -> (CLIBridgeAdapter, MockCLIBridgeManager) {
        await MainActor.run {
            let resolvedSettings = settings ?? AppSettings()
            let resolvedManager = manager ?? MockCLIBridgeManager()
            let adapter = CLIBridgeAdapter(settings: resolvedSettings, manager: resolvedManager)
            return (adapter, resolvedManager)
        }
    }

    private func waitForMainQueue() async {
        let expectation = expectation(description: "main queue")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1)
    }

    private func tinyPNGData() -> Data {
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg=="
        return Data(base64Encoded: base64) ?? Data()
    }

    private func createLargeJPEGData(minBytes: Int = ImageAttachment.uploadThreshold + 1) -> Data {
        var dimension = 512
        var data = Data()

        for _ in 0..<5 {
            let size = CGSize(width: dimension, height: dimension)
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { context in
                for y in stride(from: 0, to: dimension, by: 8) {
                    for x in stride(from: 0, to: dimension, by: 8) {
                        let hue = CGFloat((x + y) % dimension) / CGFloat(dimension)
                        UIColor(hue: hue, saturation: 0.8, brightness: 0.9, alpha: 1.0).setFill()
                        context.fill(CGRect(x: x, y: y, width: 8, height: 8))
                    }
                }
            }
            data = image.jpegData(compressionQuality: 1.0) ?? Data()
            if data.count > minBytes { break }
            dimension += 256
        }

        return data
    }

    private func createTestHEICData() -> Data? {
        let size = CGSize(width: 32, height: 32)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        guard let cgImage = image.cgImage else { return nil }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private func withMockServer(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data),
        operation: () async throws -> Void
    ) async rethrows {
        URLProtocol.registerClass(MockURLProtocol.self)
        MockURLProtocol.requestHandler = handler
        defer {
            URLProtocol.unregisterClass(MockURLProtocol.self)
            MockURLProtocol.requestHandler = nil
        }

        try await operation()
    }

    private func captureToolInput(_ input: [String: Any]) -> String {
        let manager = MockCLIBridgeManager()
        let adapter = CLIBridgeAdapter(manager: manager)
        let toolExpectation = expectation(description: "tool use")
        var inputString = ""
        adapter.onToolUse = { _, _, input in
            inputString = input
            toolExpectation.fulfill()
        }

        manager.onEvent?(.toolStart(id: "tool-1", name: "Test", input: input))

        wait(for: [toolExpectation], timeout: 1)
        return inputString
    }

    private func decodeJSONDictionary(
        _ jsonString: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> [String: Any] {
        guard let data = jsonString.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: Any] else {
            XCTFail("Expected JSON dictionary", file: file, line: line)
            return [:]
        }
        return dict
    }

    func test_init_defaultState() async {
        let (adapter, _) = await makeAdapter()

        XCTAssertEqual(adapter.connectionState, .disconnected)
        XCTAssertFalse(adapter.isProcessing)
        XCTAssertNil(adapter.sessionId)
        XCTAssertNil(adapter.currentModel)
    }

    func test_updateSettings_propagatesServerURL() async {
        let (adapter, manager) = await makeAdapter()
        let newSettings = AppSettings()
        newSettings.serverURL = "http://example.com"

        adapter.updateSettings(newSettings)

        XCTAssertEqual(manager.updateServerURLCalls, ["http://example.com"])
    }

    func test_resolveModelId_haiku() async {
        let settings = AppSettings()
        settings.defaultModel = .haiku
        let (adapter, manager) = await makeAdapter(settings: settings)
        manager.connectExpectation = expectation(description: "connect called")

        adapter.connect(projectPath: "/tmp/project", sessionId: "session-1")

        await fulfillment(of: [manager.connectExpectation!], timeout: 1)
        XCTAssertEqual(manager.connectCalls.first?.projectPath, "/tmp/project")
        XCTAssertEqual(manager.connectCalls.first?.sessionId, "session-1")
        XCTAssertEqual(manager.connectCalls.first?.model, "haiku")
        XCTAssertEqual(manager.connectCalls.first?.helper, false)
    }

    func test_resolveModelId_opus() async {
        let settings = AppSettings()
        settings.defaultModel = .opus
        let manager = MockCLIBridgeManager()
        manager.connectExpectation = expectation(description: "connect called")
        let adapter = CLIBridgeAdapter(settings: settings, manager: manager)

        adapter.connect(projectPath: "/tmp/project")

        await fulfillment(of: [manager.connectExpectation!], timeout: 1)
        XCTAssertEqual(manager.connectCalls.first?.model, "opus")
    }

    func test_resolveModelId_sonnet() async {
        let settings = AppSettings()
        settings.defaultModel = .sonnet
        let manager = MockCLIBridgeManager()
        manager.connectExpectation = expectation(description: "connect called")
        let adapter = CLIBridgeAdapter(settings: settings, manager: manager)

        adapter.connect(projectPath: "/tmp/project")

        await fulfillment(of: [manager.connectExpectation!], timeout: 1)
        XCTAssertEqual(manager.connectCalls.first?.model, "sonnet")
    }

    func test_resolveModelId_customReturnsCustomId() async {
        let settings = AppSettings()
        settings.defaultModel = .custom
        settings.customModelId = "claude-custom"
        let manager = MockCLIBridgeManager()
        manager.connectExpectation = expectation(description: "connect called")
        let adapter = CLIBridgeAdapter(settings: settings, manager: manager)

        adapter.connect(projectPath: "/tmp/project")

        await fulfillment(of: [manager.connectExpectation!], timeout: 1)
        XCTAssertEqual(manager.connectCalls.first?.model, "claude-custom")
    }

    func test_resolveModelId_customEmptyReturnsNil() async {
        let settings = AppSettings()
        settings.defaultModel = .custom
        settings.customModelId = ""
        let manager = MockCLIBridgeManager()
        manager.connectExpectation = expectation(description: "connect called")
        let adapter = CLIBridgeAdapter(settings: settings, manager: manager)

        adapter.connect(projectPath: "/tmp/project")

        await fulfillment(of: [manager.connectExpectation!], timeout: 1)
        XCTAssertNil(manager.connectCalls.first?.model)
    }

    func test_connect_withoutProjectPath_doesNothing() async {
        let (adapter, manager) = await makeAdapter()

        adapter.connect()

        XCTAssertTrue(manager.connectCalls.isEmpty)
    }

    func test_disconnect_callsManager() async {
        let (adapter, manager) = await makeAdapter()

        adapter.disconnect()

        XCTAssertEqual(manager.disconnectCount, 1)
    }

    func test_attachToSession_togglesReattachingAndCallsCallback() async {
        let manager = MockCLIBridgeManager()
        manager.connectExpectation = expectation(description: "connect called")
        let adapter = CLIBridgeAdapter(manager: manager)
        let attachedExpectation = expectation(description: "session attached")
        adapter.onSessionAttached = {
            attachedExpectation.fulfill()
        }

        adapter.attachToSession(sessionId: "session-2", projectPath: "/tmp/project")

        XCTAssertTrue(adapter.isReattaching)
        await fulfillment(of: [manager.connectExpectation!, attachedExpectation], timeout: 1)
        XCTAssertFalse(adapter.isReattaching)
        XCTAssertEqual(manager.connectCalls.first?.sessionId, "session-2")
        XCTAssertEqual(manager.connectCalls.first?.projectPath, "/tmp/project")
    }

    func test_parsePermissionMode_acceptEdits() async {
        let settings = AppSettings()
        settings.thinkingMode = .think
        let manager = MockCLIBridgeManager()
        manager.connectionState = .connected(agentId: "agent-1")
        manager.setPermissionModeExpectation = expectation(description: "permission mode")
        manager.sendInputExpectation = expectation(description: "send input")
        let adapter = CLIBridgeAdapter(settings: settings, manager: manager)

        adapter.sendMessage(
            "Hello",
            projectPath: "/tmp/project",
            permissionMode: "acceptEdits"
        )

        await fulfillment(of: [manager.setPermissionModeExpectation!, manager.sendInputExpectation!], timeout: 1)
        XCTAssertEqual(manager.setPermissionModeCalls.last, .acceptedits)
        XCTAssertEqual(manager.sendInputCalls.last?.text, "Hello")
        XCTAssertEqual(manager.sendInputCalls.last?.thinkingMode, "think")
    }

    func test_parsePermissionMode_default() async {
        let manager = MockCLIBridgeManager()
        manager.connectionState = .connected(agentId: "agent-1")
        manager.setPermissionModeExpectation = expectation(description: "permission mode")
        manager.sendInputExpectation = expectation(description: "send input")
        let adapter = CLIBridgeAdapter(manager: manager)

        adapter.sendMessage(
            "Hello",
            projectPath: "/tmp/project",
            permissionMode: "default"
        )

        await fulfillment(of: [manager.setPermissionModeExpectation!, manager.sendInputExpectation!], timeout: 1)
        XCTAssertEqual(manager.setPermissionModeCalls.last, ._default)
    }

    func test_parsePermissionMode_bypassPermissions() async {
        let manager = MockCLIBridgeManager()
        manager.connectionState = .connected(agentId: "agent-1")
        manager.setPermissionModeExpectation = expectation(description: "permission mode")
        manager.sendInputExpectation = expectation(description: "send input")
        let adapter = CLIBridgeAdapter(manager: manager)

        adapter.sendMessage(
            "Hello",
            projectPath: "/tmp/project",
            permissionMode: "bypassPermissions"
        )

        await fulfillment(of: [manager.setPermissionModeExpectation!, manager.sendInputExpectation!], timeout: 1)
        XCTAssertEqual(manager.setPermissionModeCalls.last, .bypasspermissions)
    }

    func test_sendMessage_errorUpdatesLastError() async {
        let manager = MockCLIBridgeManager()
        manager.connectionState = .connected(agentId: "agent-1")
        manager.sendInputError = MockError.failure
        let adapter = CLIBridgeAdapter(manager: manager)
        let errorExpectation = expectation(description: "error callback")
        adapter.onError = { _ in
            errorExpectation.fulfill()
        }

        adapter.sendMessage("Hi", projectPath: "/tmp/project")

        await fulfillment(of: [errorExpectation], timeout: 1)
        XCTAssertEqual(adapter.lastError, "mock failure")
        XCTAssertFalse(adapter.isProcessing)
    }

    func test_prepareImages_smallImageInlinesBase64() async {
        let manager = MockCLIBridgeManager()
        manager.connectionState = .connected(agentId: "agent-1")
        manager.sendInputExpectation = expectation(description: "send input")
        let adapter = CLIBridgeAdapter(manager: manager)
        let attachment = ImageAttachment(data: tinyPNGData())

        adapter.sendMessage("Image", projectPath: "/tmp/project", images: [attachment])

        await fulfillment(of: [manager.sendInputExpectation!], timeout: 1)
        let images = manager.sendInputCalls.last?.images
        XCTAssertEqual(images?.count, 1)
        XCTAssertEqual(images?.first?.type, .base64)
        XCTAssertNotNil(images?.first?.data)
        XCTAssertEqual(images?.first?.mimeType, "image/png")
    }

    func test_prepareImages_detectsMimeType() async {
        let manager = MockCLIBridgeManager()
        manager.connectionState = .connected(agentId: "agent-1")
        manager.sendInputExpectation = expectation(description: "send input")
        let adapter = CLIBridgeAdapter(manager: manager)
        let invalidData = Data([0x00, 0x01])
        let attachment = ImageAttachment(data: invalidData)

        adapter.sendMessage("Bad image", projectPath: "/tmp/project", images: [attachment])

        await fulfillment(of: [manager.sendInputExpectation!], timeout: 1)
        let images = manager.sendInputCalls.last?.images
        XCTAssertEqual(images?.count, 1)
        XCTAssertEqual(images?.first?.data, invalidData.base64EncodedString())
        XCTAssertEqual(images?.first?.mimeType, "image/jpeg")
    }

    func test_prepareImages_largeImageUploads() async {
        let settings = AppSettings()
        settings.serverURL = "http://mock.server"
        let manager = MockCLIBridgeManager()
        manager.connectionState = .connected(agentId: "agent-1")
        manager.sendInputExpectation = expectation(description: "send input")
        let adapter = CLIBridgeAdapter(settings: settings, manager: manager)
        let largeData = createLargeJPEGData()
        XCTAssertGreaterThan(largeData.count, ImageAttachment.uploadThreshold)
        let attachment = ImageAttachment(data: largeData)
        let responseData = """
        {"id":"image-123","mimeType":"image/jpeg","size":\(largeData.count)}
        """.data(using: .utf8) ?? Data()

        await withMockServer(handler: { request in
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "http://mock.server")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, responseData)
        }) {
            adapter.sendMessage("Image", projectPath: "/tmp/project", images: [attachment])
            await fulfillment(of: [manager.sendInputExpectation!], timeout: 1)
        }

        let images = manager.sendInputCalls.last?.images
        XCTAssertEqual(images?.first?.type, .reference)
        XCTAssertEqual(images?.first?.id, "image-123")
        XCTAssertNil(images?.first?.data)
    }

    func test_prepareImages_fallsBackToInlineOnUploadError() async {
        let settings = AppSettings()
        settings.serverURL = "http://mock.server"
        let manager = MockCLIBridgeManager()
        manager.connectionState = .connected(agentId: "agent-1")
        manager.sendInputExpectation = expectation(description: "send input")
        let adapter = CLIBridgeAdapter(settings: settings, manager: manager)
        let largeData = createLargeJPEGData()
        XCTAssertGreaterThan(largeData.count, ImageAttachment.uploadThreshold)
        let attachment = ImageAttachment(data: largeData)

        await withMockServer(handler: { request in
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "http://mock.server")!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }) {
            adapter.sendMessage("Image", projectPath: "/tmp/project", images: [attachment])
            await fulfillment(of: [manager.sendInputExpectation!], timeout: 1)
        }

        let images = manager.sendInputCalls.last?.images
        XCTAssertEqual(images?.first?.type, .base64)
        XCTAssertNotNil(images?.first?.data)
        XCTAssertEqual(images?.first?.mimeType, "image/jpeg")
    }

    func test_prepareImages_compressesHEIC() async {
        let manager = MockCLIBridgeManager()
        manager.connectionState = .connected(agentId: "agent-1")
        manager.sendInputExpectation = expectation(description: "send input")
        let adapter = CLIBridgeAdapter(manager: manager)
        guard let heicData = createTestHEICData() else {
            XCTFail("Expected HEIC data")
            return
        }
        XCTAssertEqual(ImageUtilities.detectMediaType(from: heicData), "image/heic")
        let attachment = ImageAttachment(data: heicData)

        adapter.sendMessage("Image", projectPath: "/tmp/project", images: [attachment])

        await fulfillment(of: [manager.sendInputExpectation!], timeout: 1)
        guard let image = manager.sendInputCalls.last?.images?.first else {
            XCTFail("Expected image attachment")
            return
        }
        XCTAssertEqual(image.type, .base64)
        XCTAssertEqual(image.mimeType, "image/jpeg")
        if let base64 = image.data, let decoded = Data(base64Encoded: base64) {
            XCTAssertEqual(ImageUtilities.detectMediaType(from: decoded), "image/jpeg")
        } else {
            XCTFail("Expected base64 image data")
        }
    }

    func test_uploadImage_returnsReferenceId() async throws {
        let settings = AppSettings()
        settings.serverURL = "http://mock.server"
        let manager = MockCLIBridgeManager()
        manager.connectionState = .connected(agentId: "agent-1")
        let adapter = CLIBridgeAdapter(settings: settings, manager: manager)
        let imageData = tinyPNGData()
        let responseData = """
        {"id":"image-999","mimeType":"image/png","size":\(imageData.count)}
        """.data(using: .utf8) ?? Data()

        try await withMockServer(handler: { request in
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "http://mock.server")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, responseData)
        }) {
            let imageId = try await adapter.uploadImage(imageData)
            XCTAssertEqual(imageId, "image-999")
        }
    }

    func test_uploadImage_requiresAgentId() async {
        let manager = MockCLIBridgeManager()
        manager.connectionState = .disconnected
        let adapter = CLIBridgeAdapter(manager: manager)

        do {
            _ = try await adapter.uploadImage(tinyPNGData())
            XCTFail("Expected notConnected error")
        } catch {
            if case CLIBridgeError.notConnected = error {
                // Expected
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func test_uploadImage_propagatesError() async {
        let settings = AppSettings()
        settings.serverURL = "http://mock.server"
        let manager = MockCLIBridgeManager()
        manager.connectionState = .connected(agentId: "agent-1")
        let adapter = CLIBridgeAdapter(settings: settings, manager: manager)

        await withMockServer(handler: { request in
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "http://mock.server")!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }) {
            do {
                _ = try await adapter.uploadImage(tinyPNGData())
                XCTFail("Expected server error")
            } catch let error as CLIBridgeAPIError {
                if case .serverError(let code) = error {
                    XCTAssertEqual(code, 500)
                } else {
                    XCTFail("Unexpected API error: \(error)")
                }
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func test_sendMessageWithImageReference_usesReference() async {
        let manager = MockCLIBridgeManager()
        manager.connectionState = .connected(agentId: "agent-1")
        manager.sendInputExpectation = expectation(description: "send input")
        let adapter = CLIBridgeAdapter(manager: manager)

        adapter.sendMessageWithImageReference(
            "Image",
            imageId: "image-ref",
            projectPath: "/tmp/project"
        )

        await fulfillment(of: [manager.sendInputExpectation!], timeout: 1)
        let images = manager.sendInputCalls.last?.images
        XCTAssertEqual(images?.first?.type, .reference)
        XCTAssertEqual(images?.first?.id, "image-ref")
    }

    func test_abortSession_callsInterruptAndResetsState() async {
        let manager = MockCLIBridgeManager()
        manager.interruptExpectation = expectation(description: "interrupt")
        let adapter = CLIBridgeAdapter(manager: manager)
        adapter.isProcessing = true
        let abortedExpectation = expectation(description: "aborted callback")
        adapter.onAborted = {
            abortedExpectation.fulfill()
        }

        adapter.abortSession()

        await fulfillment(of: [manager.interruptExpectation!, abortedExpectation], timeout: 1)
        XCTAssertEqual(manager.interruptCount, 1)
        XCTAssertFalse(adapter.isAborting)
        XCTAssertFalse(adapter.isProcessing)
    }

    func test_abort_handlesErrorSetsLastError() async {
        let manager = MockCLIBridgeManager()
        manager.interruptError = MockError.failure
        manager.interruptExpectation = expectation(description: "interrupt")
        let adapter = CLIBridgeAdapter(manager: manager)

        adapter.abort()

        await fulfillment(of: [manager.interruptExpectation!], timeout: 1)
        XCTAssertEqual(adapter.lastError, "mock failure")
        XCTAssertFalse(adapter.isAborting)
    }

    func test_respondToApproval_sendsToManager() async {
        let manager = MockCLIBridgeManager()
        manager.respondToPermissionExpectation = expectation(description: "permission response")
        let adapter = CLIBridgeAdapter(manager: manager)

        adapter.respondToApproval(requestId: "perm-1", approved: true, alwaysAllow: false)

        await fulfillment(of: [manager.respondToPermissionExpectation!], timeout: 1)
        XCTAssertEqual(manager.respondToPermissionCalls.first?.choice, .allow)
    }

    func test_respondToApproval_denyUsesDenyChoice() async {
        let manager = MockCLIBridgeManager()
        manager.respondToPermissionExpectation = expectation(description: "permission response")
        let adapter = CLIBridgeAdapter(manager: manager)

        adapter.respondToApproval(requestId: "perm-2", approved: false, alwaysAllow: false)

        await fulfillment(of: [manager.respondToPermissionExpectation!], timeout: 1)
        XCTAssertEqual(manager.respondToPermissionCalls.first?.choice, .deny)
    }

    func test_respondToApproval_alwaysAllowUsesAlwaysChoice() async {
        let manager = MockCLIBridgeManager()
        manager.respondToPermissionExpectation = expectation(description: "permission response")
        let adapter = CLIBridgeAdapter(manager: manager)

        adapter.respondToApproval(requestId: "perm-3", approved: true, alwaysAllow: true)

        await fulfillment(of: [manager.respondToPermissionExpectation!], timeout: 1)
        XCTAssertEqual(manager.respondToPermissionCalls.first?.choice, .always)
    }

    func test_approvePendingRequest_allowChoice() async {
        let manager = MockCLIBridgeManager()
        manager.respondToPermissionExpectation = expectation(description: "permission response")
        let adapter = CLIBridgeAdapter(manager: manager)
        adapter.pendingApproval = ApprovalRequest(
            id: "perm-4",
            toolName: "Bash",
            input: ["command": "ls"],
            receivedAt: Date()
        )

        adapter.approvePendingRequest()

        await fulfillment(of: [manager.respondToPermissionExpectation!], timeout: 1)
        XCTAssertEqual(manager.respondToPermissionCalls.first?.choice, .allow)
    }

    func test_approvePendingRequest_alwaysAllowChoice() async {
        let manager = MockCLIBridgeManager()
        manager.respondToPermissionExpectation = expectation(description: "permission response")
        let adapter = CLIBridgeAdapter(manager: manager)
        adapter.pendingApproval = ApprovalRequest(
            id: "perm-5",
            toolName: "Bash",
            input: ["command": "ls"],
            receivedAt: Date()
        )

        adapter.approvePendingRequest(alwaysAllow: true)

        await fulfillment(of: [manager.respondToPermissionExpectation!], timeout: 1)
        XCTAssertEqual(manager.respondToPermissionCalls.first?.choice, .always)
    }

    func test_approvePendingRequest_clearsPendingApproval() async {
        let manager = MockCLIBridgeManager()
        manager.respondToPermissionExpectation = expectation(description: "permission response")
        let adapter = CLIBridgeAdapter(manager: manager)
        adapter.pendingApproval = ApprovalRequest(
            id: "perm-6",
            toolName: "Read",
            input: ["file_path": "/tmp/file"],
            receivedAt: Date()
        )

        adapter.approvePendingRequest()

        await fulfillment(of: [manager.respondToPermissionExpectation!], timeout: 1)
        XCTAssertNil(adapter.pendingApproval)
    }

    func test_denyPendingRequest_denyChoice() async {
        let manager = MockCLIBridgeManager()
        manager.respondToPermissionExpectation = expectation(description: "permission response")
        let adapter = CLIBridgeAdapter(manager: manager)
        adapter.pendingApproval = ApprovalRequest(
            id: "perm-7",
            toolName: "Write",
            input: ["file_path": "/tmp/file"],
            receivedAt: Date()
        )

        adapter.denyPendingRequest()

        await fulfillment(of: [manager.respondToPermissionExpectation!], timeout: 1)
        XCTAssertEqual(manager.respondToPermissionCalls.first?.choice, .deny)
    }

    func test_denyPendingRequest_clearsPendingApproval() async {
        let manager = MockCLIBridgeManager()
        manager.respondToPermissionExpectation = expectation(description: "permission response")
        let adapter = CLIBridgeAdapter(manager: manager)
        adapter.pendingApproval = ApprovalRequest(
            id: "perm-8",
            toolName: "Edit",
            input: ["file_path": "/tmp/file"],
            receivedAt: Date()
        )

        adapter.denyPendingRequest()

        await fulfillment(of: [manager.respondToPermissionExpectation!], timeout: 1)
        XCTAssertNil(adapter.pendingApproval)
    }

    func test_respondToQuestion_sendsAnswers() async {
        let manager = MockCLIBridgeManager()
        manager.respondToQuestionExpectation = expectation(description: "question response")
        let adapter = CLIBridgeAdapter(manager: manager)
        adapter.pendingQuestion = AskUserQuestionData(requestId: "question-1", questions: [])

        adapter.respondToQuestion(requestId: "question-1", answers: ["choice": "A"])

        await fulfillment(of: [manager.respondToQuestionExpectation!], timeout: 1)
        XCTAssertEqual(manager.respondToQuestionCalls.first?.id, "question-1")
        XCTAssertEqual(manager.respondToQuestionCalls.first?.answers["choice"] as? String, "A")
    }

    func test_respondToQuestion_clearsPendingQuestion() async {
        let manager = MockCLIBridgeManager()
        manager.respondToQuestionExpectation = expectation(description: "question response")
        let adapter = CLIBridgeAdapter(manager: manager)
        adapter.pendingQuestion = AskUserQuestionData(requestId: "question-2", questions: [])

        adapter.respondToQuestion(requestId: "question-2", answers: ["choice": "B"])

        await fulfillment(of: [manager.respondToQuestionExpectation!], timeout: 1)
        await waitForMainQueue()
        XCTAssertNil(adapter.pendingQuestion)
    }

    func test_clearPendingQuestion_clearsWithoutResponse() async {
        let manager = MockCLIBridgeManager()
        let adapter = CLIBridgeAdapter(manager: manager)
        adapter.pendingQuestion = AskUserQuestionData(requestId: "question-3", questions: [])

        adapter.clearPendingQuestion()

        XCTAssertNil(adapter.pendingQuestion)
        XCTAssertTrue(manager.respondToQuestionCalls.isEmpty)
    }

    func test_switchModel_clearsIsSwitchingOnSuccess() async {
        let manager = MockCLIBridgeManager()
        manager.setModelExpectation = expectation(description: "set model")
        let adapter = CLIBridgeAdapter(manager: manager)

        adapter.switchModel(to: .haiku)

        await fulfillment(of: [manager.setModelExpectation!], timeout: 1)
        await waitForMainQueue()
        XCTAssertEqual(manager.setModelCalls.last, "haiku")
        XCTAssertFalse(adapter.isSwitchingModel)
    }

    func test_switchModel_setsIsSwitchingFlag() async {
        let manager = MockCLIBridgeManager()
        manager.setModelExpectation = expectation(description: "set model")
        let adapter = CLIBridgeAdapter(manager: manager)

        adapter.switchModel(to: .sonnet)

        XCTAssertTrue(adapter.isSwitchingModel)
        await fulfillment(of: [manager.setModelExpectation!], timeout: 1)
    }

    func test_switchModel_clearsIsSwitchingOnError() async {
        let manager = MockCLIBridgeManager()
        manager.setModelError = MockError.failure
        manager.setModelExpectation = expectation(description: "set model")
        let adapter = CLIBridgeAdapter(manager: manager)

        adapter.switchModel(to: .opus)

        await fulfillment(of: [manager.setModelExpectation!], timeout: 1)
        await waitForMainQueue()
        XCTAssertFalse(adapter.isSwitchingModel)
        XCTAssertEqual(adapter.lastError, "mock failure")
    }

    func test_switchModel_sendsSonnetId() async {
        let manager = MockCLIBridgeManager()
        manager.setModelExpectation = expectation(description: "set model")
        let adapter = CLIBridgeAdapter(manager: manager)

        adapter.switchModel(to: .sonnet)

        await fulfillment(of: [manager.setModelExpectation!], timeout: 1)
        XCTAssertEqual(manager.setModelCalls.last, "sonnet")
    }

    func test_switchModel_sendsOpusId() async {
        let manager = MockCLIBridgeManager()
        manager.setModelExpectation = expectation(description: "set model")
        let adapter = CLIBridgeAdapter(manager: manager)

        adapter.switchModel(to: .opus)

        await fulfillment(of: [manager.setModelExpectation!], timeout: 1)
        XCTAssertEqual(manager.setModelCalls.last, "opus")
    }

    func test_switchModel_sendsHaikuId() async {
        let manager = MockCLIBridgeManager()
        manager.setModelExpectation = expectation(description: "set model")
        let adapter = CLIBridgeAdapter(manager: manager)

        adapter.switchModel(to: .haiku)

        await fulfillment(of: [manager.setModelExpectation!], timeout: 1)
        XCTAssertEqual(manager.setModelCalls.last, "haiku")
    }

    func test_switchModel_sendsCustomId() async {
        let settings = AppSettings()
        settings.customModelId = "custom-model"
        let manager = MockCLIBridgeManager()
        manager.setModelExpectation = expectation(description: "set model")
        let adapter = CLIBridgeAdapter(settings: settings, manager: manager)

        adapter.switchModel(to: .custom)

        await fulfillment(of: [manager.setModelExpectation!], timeout: 1)
        XCTAssertEqual(manager.setModelCalls.last, "custom-model")
    }

    func test_cancelQueuedInput_whenQueued() async {
        let manager = MockCLIBridgeManager()
        manager.cancelQueuedInputExpectation = expectation(description: "cancel queued")
        let adapter = CLIBridgeAdapter(manager: manager)
        adapter.isInputQueued = true

        adapter.cancelQueuedInput()

        await fulfillment(of: [manager.cancelQueuedInputExpectation!], timeout: 1)
        XCTAssertEqual(manager.cancelQueuedInputCount, 1)
    }

    func test_cancelQueuedInput_whenNotQueued() async {
        let (adapter, manager) = await makeAdapter()
        adapter.isInputQueued = false

        adapter.cancelQueuedInput()

        XCTAssertEqual(manager.cancelQueuedInputCount, 0)
    }

    func test_setSessionPermissionMode_updatesSessionMode() async {
        let manager = MockCLIBridgeManager()
        manager.setPermissionModeExpectation = expectation(description: "set permission mode")
        let adapter = CLIBridgeAdapter(manager: manager)

        adapter.setSessionPermissionMode(.bypassPermissions)

        await fulfillment(of: [manager.setPermissionModeExpectation!], timeout: 1)
        XCTAssertEqual(manager.setPermissionModeCalls.last, .bypasspermissions)
        XCTAssertEqual(adapter.sessionPermissionMode, .bypassPermissions)
    }

    func test_setSessionPermissionMode_errorSetsLastError() async {
        let manager = MockCLIBridgeManager()
        manager.setPermissionModeError = MockError.failure
        manager.setPermissionModeExpectation = expectation(description: "set permission mode")
        let adapter = CLIBridgeAdapter(manager: manager)

        adapter.setSessionPermissionMode(.acceptEdits)

        await fulfillment(of: [manager.setPermissionModeExpectation!], timeout: 1)
        XCTAssertEqual(adapter.lastError, "mock failure")
        XCTAssertNil(adapter.sessionPermissionMode)
    }

    func test_clearSessionPermissionMode_clearsMode() async {
        let (adapter, _) = await makeAdapter()
        adapter.sessionPermissionMode = .acceptEdits

        adapter.clearSessionPermissionMode()

        XCTAssertNil(adapter.sessionPermissionMode)
    }

    func test_clearCurrentText_clearsAdapterAndManager() {
        let manager = MockCLIBridgeManager()
        let adapter = CLIBridgeAdapter(manager: manager)
        adapter.currentText = "text"

        adapter.clearCurrentText()

        XCTAssertEqual(adapter.currentText, "")
        XCTAssertEqual(manager.clearCurrentTextCount, 1)
    }

    func test_callbacks_onTextCommitClearsCurrentText() {
        let manager = MockCLIBridgeManager()
        let adapter = CLIBridgeAdapter(manager: manager)
        manager.currentText = "Final"
        let commitExpectation = expectation(description: "text commit")
        var committedText: String?
        adapter.onTextCommit = { text in
            committedText = text
            commitExpectation.fulfill()
        }

        manager.onEvent?(.text("Final", isFinal: true))

        wait(for: [commitExpectation], timeout: 1)
        XCTAssertEqual(committedText, "Final")
        XCTAssertEqual(adapter.currentText, "")
        XCTAssertEqual(manager.clearCurrentTextCount, 1)
    }

    func test_sanitizeForJSON_handlesUnknownTypes() {
        let manager = MockCLIBridgeManager()
        let adapter = CLIBridgeAdapter(manager: manager)
        let toolExpectation = expectation(description: "tool use")
        var inputString: String?
        adapter.onToolUse = { _, _, input in
            inputString = input
            toolExpectation.fulfill()
        }

        manager.onEvent?(.toolStart(id: "tool-1", name: "Test", input: ["custom": CustomValue("CustomValue")]))

        wait(for: [toolExpectation], timeout: 1)
        XCTAssertNotNil(inputString)
        XCTAssertTrue(inputString?.contains("CustomValue") == true)
    }

    func test_sanitizeForJSON_handlesArrays() {
        let inputString = captureToolInput(["values": [1, "two", true]])
        let json = decodeJSONDictionary(inputString)
        guard let values = json["values"] as? [Any] else {
            XCTFail("Expected values array")
            return
        }
        XCTAssertEqual(values.count, 3)
        XCTAssertEqual(values[0] as? NSNumber, NSNumber(value: 1))
        XCTAssertEqual(values[1] as? String, "two")
        XCTAssertEqual(values[2] as? Bool, true)
    }

    func test_sanitizeForJSON_handlesDicts() {
        let inputString = captureToolInput(["meta": ["name": "test", "count": 2]])
        let json = decodeJSONDictionary(inputString)
        guard let meta = json["meta"] as? [String: Any] else {
            XCTFail("Expected meta dictionary")
            return
        }
        XCTAssertEqual(meta["name"] as? String, "test")
        XCTAssertEqual(meta["count"] as? NSNumber, NSNumber(value: 2))
    }

    func test_sanitizeForJSON_handlesStrings() {
        let inputString = captureToolInput(["name": "Claude"])
        let json = decodeJSONDictionary(inputString)
        XCTAssertEqual(json["name"] as? String, "Claude")
    }

    func test_sanitizeForJSON_handlesNumbers() {
        let inputString = captureToolInput(["count": 7, "ratio": 2.5])
        let json = decodeJSONDictionary(inputString)
        guard let countValue = json["count"] as? NSNumber else {
            XCTFail("Expected count number")
            return
        }
        guard let ratioValue = json["ratio"] as? NSNumber else {
            XCTFail("Expected ratio number")
            return
        }
        XCTAssertEqual(countValue.intValue, 7)
        XCTAssertEqual(ratioValue.doubleValue, 2.5, accuracy: 0.0001)
    }

    func test_sanitizeForJSON_handlesBooleans() {
        let inputString = captureToolInput(["enabled": true])
        let json = decodeJSONDictionary(inputString)
        XCTAssertEqual(json["enabled"] as? Bool, true)
    }

    func test_toJSONLikeString_formatsArray() {
        let inputString = captureToolInput(["values": ["one", "two"]])
        let compact = inputString.replacingOccurrences(of: " ", with: "")
        XCTAssertTrue(compact.contains("\"values\""))
        XCTAssertTrue(compact.contains("[\"one\",\"two\"]"))
    }

    func test_toJSONLikeString_formatsDict() {
        let inputString = captureToolInput(["meta": ["alpha": "beta"]])
        let compact = inputString.replacingOccurrences(of: " ", with: "")
        XCTAssertTrue(compact.contains("\"meta\""))
        XCTAssertTrue(compact.contains("\"alpha\":\"beta\""))
    }

    func test_escapeJSON_escapesBackslash() {
        let original = "C:\\temp\\file"
        let inputString = captureToolInput(["path": original])
        let json = decodeJSONDictionary(inputString)
        XCTAssertEqual(json["path"] as? String, original)
    }

    func test_escapeJSON_escapesQuotes() {
        let original = "He said \"hi\""
        let inputString = captureToolInput(["quote": original])
        let json = decodeJSONDictionary(inputString)
        XCTAssertEqual(json["quote"] as? String, original)
    }

    func test_escapeJSON_escapesTabsAndReturns() {
        let original = "Line\tTab\rReturn"
        let inputString = captureToolInput(["text": original])
        let json = decodeJSONDictionary(inputString)
        XCTAssertEqual(json["text"] as? String, original)
    }

    func test_escapeJSON_escapesNewlines() {
        let original = "Line 1\n\"Quote\""
        let inputString = captureToolInput(["text": original])
        let json = decodeJSONDictionary(inputString)
        XCTAssertEqual(json["text"] as? String, original)
    }

    func test_callbacks_onPermissionRequest_setsPendingApproval() {
        let manager = MockCLIBridgeManager()
        let adapter = CLIBridgeAdapter(manager: manager)
        let approvalExpectation = expectation(description: "approval callback")
        adapter.onApprovalRequest = { _ in
            approvalExpectation.fulfill()
        }

        let request = CLIPermissionRequest(
            type: .permission,
            id: "perm-1",
            tool: "Bash",
            input: ["command": JSONValue.string("ls -la")],
            options: [.allow, .deny]
        )
        manager.onEvent?(.permissionRequest(request))

        wait(for: [approvalExpectation], timeout: 1)
        XCTAssertEqual(adapter.pendingApproval?.id, "perm-1")
        XCTAssertEqual(adapter.pendingApproval?.toolName, "Bash")
    }

    func test_callbacks_onQuestionRequest_setsPendingQuestion() {
        let manager = MockCLIBridgeManager()
        let adapter = CLIBridgeAdapter(manager: manager)
        let questionExpectation = expectation(description: "question callback")
        adapter.onAskUserQuestion = { _ in
            questionExpectation.fulfill()
        }

        let question = QuestionItem(
            question: "Pick one",
            header: "Header",
            options: [APIQuestionOption(label: "A", description: nil)],
            multiSelect: false
        )
        let request = QuestionMessage(type: .question, id: "question-1", questions: [question])
        manager.onEvent?(.questionRequest(request))

        wait(for: [questionExpectation], timeout: 1)
        XCTAssertEqual(adapter.pendingQuestion?.requestId, "question-1")
        XCTAssertEqual(adapter.pendingQuestion?.questions.first?.question, "Pick one")
    }

    func test_callbacks_onSubagentStartAndComplete() {
        let manager = MockCLIBridgeManager()
        let adapter = CLIBridgeAdapter(manager: manager)
        let startExpectation = expectation(description: "subagent start")
        let completeExpectation = expectation(description: "subagent complete")
        adapter.onSubagentStart = { _ in startExpectation.fulfill() }
        adapter.onSubagentComplete = { _ in completeExpectation.fulfill() }

        let start = SubagentStartStreamMessage(type: .subagentStart, id: "agent-1", description: "Run")
        let complete = SubagentCompleteStreamMessage(type: .subagentComplete, id: "agent-1", summary: "Done")
        manager.onEvent?(.subagentStart(start))
        manager.onEvent?(.subagentComplete(complete))

        wait(for: [startExpectation, completeExpectation], timeout: 1)
        XCTAssertNil(adapter.activeSubagent)
    }

    func test_callbacks_onSessionEventAndHistory() {
        let manager = MockCLIBridgeManager()
        let adapter = CLIBridgeAdapter(manager: manager)
        let eventExpectation = expectation(description: "session event")
        let historyExpectation = expectation(description: "history")
        adapter.onSessionEvent = { _ in eventExpectation.fulfill() }
        adapter.onHistory = { _ in historyExpectation.fulfill() }

        let event = CLISessionEvent(
            type: .sessionEvent,
            action: .created,
            projectPath: "/tmp",
            sessionId: UUID(),
            metadata: nil
        )
        let history = CLIHistoryPayload(type: .history, messages: [], hasMore: false, cursor: nil)
        manager.onEvent?(.sessionEvent(event))
        manager.onEvent?(.history(history))

        wait(for: [eventExpectation, historyExpectation], timeout: 1)
    }

    func test_callbacks_onConnectionLifecycle() {
        let manager = MockCLIBridgeManager()
        let adapter = CLIBridgeAdapter(manager: manager)
        let replacedExpectation = expectation(description: "connection replaced")
        let reconnectExpectation = expectation(description: "reconnecting")
        let errorExpectation = expectation(description: "connection error")
        let networkExpectation = expectation(description: "network status")
        adapter.onConnectionReplaced = { replacedExpectation.fulfill() }
        adapter.onReconnecting = { _, _ in reconnectExpectation.fulfill() }
        adapter.onConnectionError = { _ in errorExpectation.fulfill() }
        adapter.onNetworkStatusChanged = { _ in networkExpectation.fulfill() }

        manager.onEvent?(.connectionReplaced)
        manager.onEvent?(.reconnecting(attempt: 2, delay: 1.5))
        manager.onEvent?(.connectionError(.networkUnavailable))
        manager.onEvent?(.networkStatusChanged(isOnline: false))

        wait(for: [replacedExpectation, reconnectExpectation, errorExpectation, networkExpectation], timeout: 1)
    }

    func test_callbacks_onPermissionModeChanged_updatesSessionPermissionMode() {
        let manager = MockCLIBridgeManager()
        let adapter = CLIBridgeAdapter(manager: manager)

        manager.onEvent?(.permissionModeChanged(mode: "acceptEdits"))

        XCTAssertEqual(adapter.sessionPermissionMode, .acceptEdits)
    }

    func test_syncState_mapsConnectionState() async {
        let manager = MockCLIBridgeManager()
        let adapter = CLIBridgeAdapter(manager: manager)

        manager.connectionState = .reconnecting(attempt: 2)
        await waitForMainQueue()

        XCTAssertEqual(adapter.connectionState, .reconnecting(attempt: 2))
    }

    func test_syncState_mapsAgentState() async {
        let manager = MockCLIBridgeManager()
        let adapter = CLIBridgeAdapter(manager: manager)

        manager.agentState = .thinking
        await waitForMainQueue()

        XCTAssertTrue(adapter.isProcessing)
    }

    func test_syncState_syncsSessionId() async {
        let manager = MockCLIBridgeManager()
        let adapter = CLIBridgeAdapter(manager: manager)

        manager.sessionId = "session-9"
        await waitForMainQueue()

        XCTAssertEqual(adapter.sessionId, "session-9")
    }

    func test_syncState_syncsModelId() async {
        let manager = MockCLIBridgeManager()
        let adapter = CLIBridgeAdapter(manager: manager)

        manager.currentModel = "claude-opus-4-5-20251101"
        await waitForMainQueue()

        XCTAssertEqual(adapter.currentModelId, "claude-opus-4-5-20251101")
        XCTAssertEqual(adapter.currentModel, .opus)
    }

    func test_syncState_syncsTokenUsage() async {
        let manager = MockCLIBridgeManager()
        let adapter = CLIBridgeAdapter(manager: manager)
        let usage = CLIUsageContent(
            type: .usage,
            inputTokens: 10,
            outputTokens: 5,
            cacheReadTokens: nil,
            cacheCreateTokens: nil,
            totalCost: nil,
            contextUsed: 150,
            contextLimit: 300
        )

        manager.tokenUsage = usage
        await waitForMainQueue()

        XCTAssertEqual(adapter.tokenUsage, TokenUsage(used: 150, total: 300))
    }

    func test_syncState_syncsLastError() async {
        let manager = MockCLIBridgeManager()
        let adapter = CLIBridgeAdapter(manager: manager)

        manager.lastError = "network error"
        await waitForMainQueue()

        XCTAssertEqual(adapter.lastError, "network error")
    }

    func test_stateSync_queueFlags() async {
        let manager = MockCLIBridgeManager()
        let adapter = CLIBridgeAdapter(manager: manager)

        manager.isInputQueued = true
        manager.queuePosition = 3
        await waitForMainQueue()

        XCTAssertTrue(adapter.isInputQueued)
        XCTAssertEqual(adapter.queuePosition, 3)
    }

    func test_stateSync_activeSubagentAndProgress() async {
        let manager = MockCLIBridgeManager()
        let adapter = CLIBridgeAdapter(manager: manager)
        let subagent = SubagentStartStreamMessage(type: .subagentStart, id: "agent-2", description: "Work")
        let progress = ProgressStreamMessage(type: .progress, id: "tool-1", tool: "Read", elapsed: 1.0)

        manager.activeSubagent = subagent
        manager.toolProgress = progress
        await waitForMainQueue()

        XCTAssertEqual(adapter.activeSubagent?.id, "agent-2")
        XCTAssertEqual(adapter.toolProgress?.tool, "Read")
    }

    func test_onSessionConnected_switchesModelWhenMismatch() async {
        let settings = AppSettings()
        settings.defaultModel = .sonnet
        let manager = MockCLIBridgeManager()
        manager.setModelExpectation = expectation(description: "set model")
        let adapter = CLIBridgeAdapter(settings: settings, manager: manager)
        manager.currentModel = "opus"
        manager.sessionId = "session-10"
        let sessionExpectation = expectation(description: "session created")
        adapter.onSessionCreated = { _ in
            sessionExpectation.fulfill()
        }

        manager.onEvent?(.connected(sessionId: "session-10", agentId: "agent-1", model: "opus"))

        await fulfillment(of: [manager.setModelExpectation!, sessionExpectation], timeout: 1)
        XCTAssertEqual(adapter.sessionId, "session-10")
        XCTAssertEqual(manager.setModelCalls.last, "sonnet")
    }

    func test_modelsMatch_directMatch() {
        let settings = AppSettings()
        settings.defaultModel = .sonnet
        let manager = MockCLIBridgeManager()
        manager.currentModel = "sonnet"
        _ = CLIBridgeAdapter(settings: settings, manager: manager)

        manager.onEvent?(.connected(sessionId: "session-11", agentId: "agent-1", model: "sonnet"))

        XCTAssertTrue(manager.setModelCalls.isEmpty)
    }

    func test_modelsMatch_aliasMatchesFullId() {
        let settings = AppSettings()
        settings.defaultModel = .sonnet
        let manager = MockCLIBridgeManager()
        manager.currentModel = "claude-sonnet-4-20250514"
        _ = CLIBridgeAdapter(settings: settings, manager: manager)

        manager.onEvent?(.connected(sessionId: "session-11", agentId: "agent-1", model: "claude-sonnet-4-20250514"))

        XCTAssertTrue(manager.setModelCalls.isEmpty)
    }

    func test_modelsMatch_caseInsensitive() {
        let settings = AppSettings()
        settings.defaultModel = .custom
        settings.customModelId = "SONNET"
        let manager = MockCLIBridgeManager()
        manager.currentModel = "claude-sonnet-4-20250514"
        _ = CLIBridgeAdapter(settings: settings, manager: manager)

        manager.onEvent?(.connected(sessionId: "session-12", agentId: "agent-1", model: "claude-sonnet-4-20250514"))

        XCTAssertTrue(manager.setModelCalls.isEmpty)
    }

    func test_parseModelFromId_containsHaiku() {
        let manager = MockCLIBridgeManager()
        let adapter = CLIBridgeAdapter(manager: manager)
        let modelExpectation = expectation(description: "model changed")
        var capturedModel: ClaudeModel?
        var capturedId: String?
        adapter.onModelChanged = { model, modelId in
            capturedModel = model
            capturedId = modelId
            modelExpectation.fulfill()
        }

        manager.onEvent?(.modelChanged(model: "claude-3-5-haiku-20241022"))

        wait(for: [modelExpectation], timeout: 1)
        XCTAssertEqual(adapter.currentModel, .haiku)
        XCTAssertEqual(capturedModel, .haiku)
        XCTAssertEqual(capturedId, "claude-3-5-haiku-20241022")
    }

    func test_parseModelFromId_containsOpus() {
        let manager = MockCLIBridgeManager()
        let adapter = CLIBridgeAdapter(manager: manager)

        manager.onEvent?(.modelChanged(model: "claude-opus-4-5-20251101"))

        XCTAssertEqual(adapter.currentModel, .opus)
    }

    func test_parseModelFromId_containsSonnet() {
        let manager = MockCLIBridgeManager()
        let adapter = CLIBridgeAdapter(manager: manager)

        manager.onEvent?(.modelChanged(model: "claude-sonnet-4-20250514"))

        XCTAssertEqual(adapter.currentModel, .sonnet)
    }

    func test_parseModelFromId_unknownReturnsCustom() {
        let manager = MockCLIBridgeManager()
        let adapter = CLIBridgeAdapter(manager: manager)

        manager.onEvent?(.modelChanged(model: "claude-unknown-1"))

        XCTAssertEqual(adapter.currentModel, .custom)
    }
}
