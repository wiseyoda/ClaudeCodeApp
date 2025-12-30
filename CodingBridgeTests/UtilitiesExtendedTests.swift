import XCTest
import Foundation
import UIKit
import Combine
import Security
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

private typealias NetworkState = (
    isConnected: Bool,
    connectionType: NetworkMonitor.ConnectionType,
    isExpensive: Bool,
    isConstrained: Bool
)

@MainActor
private func snapshotNetworkState(_ monitor: NetworkMonitor = .shared) -> NetworkState {
    (
        isConnected: monitor.isConnected,
        connectionType: monitor.connectionType,
        isExpensive: monitor.isExpensive,
        isConstrained: monitor.isConstrained
    )
}

@MainActor
private func restoreNetworkState(_ state: NetworkState, monitor: NetworkMonitor = .shared) {
    monitor.updateStateForTesting(
        isConnected: state.isConnected,
        connectionType: state.connectionType,
        isExpensive: state.isExpensive,
        isConstrained: state.isConstrained
    )
}

private func makeHTTPResponse(
    request: URLRequest,
    statusCode: Int,
    body: String
) throws -> (HTTPURLResponse, Data) {
    guard let url = request.url else {
        throw URLError(.badURL)
    }

    guard let response = HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
    ) else {
        throw URLError(.badServerResponse)
    }

    return (response, Data(body.utf8))
}

@MainActor
final class NetworkMonitorTests: XCTestCase {

    func testConnectionTypeDisplayNames() {
        XCTAssertEqual(NetworkMonitor.ConnectionType.wifi.displayName, "Wi-Fi")
        XCTAssertEqual(NetworkMonitor.ConnectionType.cellular.displayName, "Cellular")
        XCTAssertEqual(NetworkMonitor.ConnectionType.wired.displayName, "Ethernet")
        XCTAssertEqual(NetworkMonitor.ConnectionType.unknown.displayName, "Unknown")
    }

    func testConnectionTypeIcons() {
        XCTAssertEqual(NetworkMonitor.ConnectionType.wifi.icon, "wifi")
        XCTAssertEqual(NetworkMonitor.ConnectionType.cellular.icon, "antenna.radiowaves.left.and.right")
        XCTAssertEqual(NetworkMonitor.ConnectionType.wired.icon, "cable.connector")
        XCTAssertEqual(NetworkMonitor.ConnectionType.unknown.icon, "questionmark.circle")
    }

    func testStatusDescriptionMatchesCurrentFlags() {
        let monitor = NetworkMonitor.shared
        let expected: String

        if monitor.isConnected {
            var parts = [monitor.connectionType.displayName]
            if monitor.isExpensive { parts.append("metered") }
            if monitor.isConstrained { parts.append("low data") }
            expected = parts.joined(separator: ", ")
        } else {
            expected = "No connection"
        }

        XCTAssertEqual(monitor.statusDescription, expected)
    }

    func testNetworkNotificationNames() {
        XCTAssertEqual(Notification.Name.networkDidBecomeAvailable.rawValue, "networkDidBecomeAvailable")
        XCTAssertEqual(Notification.Name.networkDidBecomeUnavailable.rawValue, "networkDidBecomeUnavailable")
    }

    func test_networkMonitor_callbackOnConnect() {
        let monitor = NetworkMonitor.shared
        let originalState = snapshotNetworkState(monitor)
        defer { restoreNetworkState(originalState, monitor: monitor) }

        monitor.updateStateForTesting(
            isConnected: false,
            connectionType: .unknown,
            isExpensive: false,
            isConstrained: false
        )

        let expectation = expectation(forNotification: .networkDidBecomeAvailable, object: nil)

        monitor.updateStateForTesting(
            isConnected: true,
            connectionType: .wifi,
            isExpensive: false,
            isConstrained: false
        )

        wait(for: [expectation], timeout: 1.0)
    }

    func test_networkMonitor_callbackOnDisconnect() {
        let monitor = NetworkMonitor.shared
        let originalState = snapshotNetworkState(monitor)
        defer { restoreNetworkState(originalState, monitor: monitor) }

        monitor.updateStateForTesting(
            isConnected: true,
            connectionType: .wifi,
            isExpensive: false,
            isConstrained: false
        )

        let expectation = expectation(forNotification: .networkDidBecomeUnavailable, object: nil)

        monitor.updateStateForTesting(
            isConnected: false,
            connectionType: .unknown,
            isExpensive: false,
            isConstrained: false
        )

        wait(for: [expectation], timeout: 1.0)
    }

    func test_networkMonitor_callbackOnPathChange() {
        let monitor = NetworkMonitor.shared
        let originalState = snapshotNetworkState(monitor)
        defer { restoreNetworkState(originalState, monitor: monitor) }

        monitor.updateStateForTesting(
            isConnected: true,
            connectionType: .wifi,
            isExpensive: false,
            isConstrained: false
        )

        let expectation = expectation(description: "connection type update")
        var cancellables = Set<AnyCancellable>()

        monitor.$connectionType
            .dropFirst()
            .sink { connectionType in
                if connectionType == .cellular {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        monitor.updateStateForTesting(
            isConnected: true,
            connectionType: .cellular,
            isExpensive: false,
            isConstrained: false
        )

        wait(for: [expectation], timeout: 1.0)
    }

    func test_networkMonitor_wifiVsCellular() {
        let monitor = NetworkMonitor.shared
        let originalState = snapshotNetworkState(monitor)
        defer { restoreNetworkState(originalState, monitor: monitor) }

        monitor.updateStateForTesting(
            isConnected: true,
            connectionType: .wifi,
            isExpensive: false,
            isConstrained: false
        )
        XCTAssertEqual(monitor.connectionType, .wifi)
        XCTAssertEqual(monitor.statusDescription, "Wi-Fi")

        monitor.updateStateForTesting(
            isConnected: true,
            connectionType: .cellular,
            isExpensive: false,
            isConstrained: false
        )
        XCTAssertEqual(monitor.connectionType, .cellular)
        XCTAssertEqual(monitor.statusDescription, "Cellular")
    }

    func test_networkMonitor_constrainedPath() {
        let monitor = NetworkMonitor.shared
        let originalState = snapshotNetworkState(monitor)
        defer { restoreNetworkState(originalState, monitor: monitor) }

        monitor.updateStateForTesting(
            isConnected: true,
            connectionType: .wifi,
            isExpensive: false,
            isConstrained: true
        )

        XCTAssertTrue(monitor.isConstrained)
        XCTAssertTrue(monitor.statusDescription.contains("low data"))
    }

    func test_networkMonitor_expensivePath() {
        let monitor = NetworkMonitor.shared
        let originalState = snapshotNetworkState(monitor)
        defer { restoreNetworkState(originalState, monitor: monitor) }

        monitor.updateStateForTesting(
            isConnected: true,
            connectionType: .wifi,
            isExpensive: true,
            isConstrained: false
        )

        XCTAssertTrue(monitor.isExpensive)
        XCTAssertTrue(monitor.statusDescription.contains("metered"))
    }

    func test_networkMonitor_multipleObservers() {
        let monitor = NetworkMonitor.shared
        let originalState = snapshotNetworkState(monitor)
        defer { restoreNetworkState(originalState, monitor: monitor) }

        monitor.updateStateForTesting(
            isConnected: false,
            connectionType: .unknown,
            isExpensive: false,
            isConstrained: false
        )

        let expectation = XCTestExpectation(description: "multiple observers notified")
        expectation.expectedFulfillmentCount = 2
        let notificationCenter = NotificationCenter.default

        let observerOne = notificationCenter.addObserver(
            forName: .networkDidBecomeAvailable,
            object: nil,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }

        let observerTwo = notificationCenter.addObserver(
            forName: .networkDidBecomeAvailable,
            object: nil,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }

        defer {
            notificationCenter.removeObserver(observerOne)
            notificationCenter.removeObserver(observerTwo)
        }

        monitor.updateStateForTesting(
            isConnected: true,
            connectionType: .wifi,
            isExpensive: false,
            isConstrained: false
        )

        wait(for: [expectation], timeout: 1.0)
    }

    func test_networkMonitor_observerRemoval() {
        let monitor = NetworkMonitor.shared
        let originalState = snapshotNetworkState(monitor)
        defer { restoreNetworkState(originalState, monitor: monitor) }

        monitor.updateStateForTesting(
            isConnected: false,
            connectionType: .unknown,
            isExpensive: false,
            isConstrained: false
        )

        let notificationCenter = NotificationCenter.default
        let keptExpectation = XCTestExpectation(description: "kept observer notified")
        let removedExpectation = XCTestExpectation(description: "removed observer not notified")
        removedExpectation.isInverted = true

        let keptObserver = notificationCenter.addObserver(
            forName: .networkDidBecomeAvailable,
            object: nil,
            queue: nil
        ) { _ in
            keptExpectation.fulfill()
        }

        let removedObserver = notificationCenter.addObserver(
            forName: .networkDidBecomeAvailable,
            object: nil,
            queue: nil
        ) { _ in
            removedExpectation.fulfill()
        }

        notificationCenter.removeObserver(removedObserver)
        defer {
            notificationCenter.removeObserver(keptObserver)
        }

        monitor.updateStateForTesting(
            isConnected: true,
            connectionType: .wifi,
            isExpensive: false,
            isConstrained: false
        )

        wait(for: [keptExpectation, removedExpectation], timeout: 1.0)
    }
}

@MainActor
final class HapticManagerTests: XCTestCase {

    func testImpactHapticsDoNotCrash() {
        HapticManager.light()
        HapticManager.medium()
        HapticManager.rigid()
    }

    func testNotificationHapticsDoNotCrash() {
        HapticManager.success()
        HapticManager.warning()
        HapticManager.error()
    }

    func testSelectionHapticDoesNotCrash() {
        HapticManager.selection()
    }

    func test_hapticManager_impactLight() {
        HapticManager.light()
    }

    func test_hapticManager_impactMedium() {
        HapticManager.medium()
    }

    func test_hapticManager_impactHeavy() {
        HapticManager.heavy()
    }

    func test_hapticManager_impactRigid() {
        HapticManager.rigid()
    }

    func test_hapticManager_impactSoft() {
        HapticManager.soft()
    }

    func test_hapticManager_notificationSuccess() {
        HapticManager.success()
    }

    func test_hapticManager_notificationWarning() {
        HapticManager.warning()
    }

    func test_hapticManager_notificationError() {
        HapticManager.error()
    }

    func test_hapticManager_rapidFireDoesNotCrash() {
        for _ in 0..<25 {
            HapticManager.light()
            HapticManager.medium()
            HapticManager.heavy()
            HapticManager.rigid()
            HapticManager.soft()
            HapticManager.success()
            HapticManager.warning()
            HapticManager.error()
            HapticManager.selection()
        }
    }

    func test_hapticManager_backgroundDoesNotCrash() async {
        let expectation = expectation(description: "background haptics")
        DispatchQueue.global(qos: .userInitiated).async {
            HapticManager.light()
            HapticManager.success()
            HapticManager.selection()
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1.0)
    }
}

@MainActor
final class KeychainHelperTests: XCTestCase {

    private func uniqueValue(_ prefix: String) -> String {
        "\(prefix)-\(UUID().uuidString)"
    }

    func testSSHKeyCRUD() {
        let helper = KeychainHelper.shared
        helper.deleteSSHKey()
        defer { helper.deleteSSHKey() }

        let value = uniqueValue("ssh-key")
        XCTAssertTrue(helper.storeSSHKey(value))
        XCTAssertEqual(helper.retrieveSSHKey(), value)
        XCTAssertTrue(helper.hasSSHKey)
        XCTAssertTrue(helper.deleteSSHKey())
        XCTAssertNil(helper.retrieveSSHKey())
        XCTAssertFalse(helper.hasSSHKey)
    }

    func testPassphraseCRUD() {
        let helper = KeychainHelper.shared
        helper.deletePassphrase()
        defer { helper.deletePassphrase() }

        let value = uniqueValue("passphrase")
        XCTAssertTrue(helper.storePassphrase(value))
        XCTAssertEqual(helper.retrievePassphrase(), value)
        XCTAssertTrue(helper.deletePassphrase())
        XCTAssertNil(helper.retrievePassphrase())
    }

    func testSSHPasswordCRUD() {
        let helper = KeychainHelper.shared
        helper.deleteSSHPassword()
        defer { helper.deleteSSHPassword() }

        let value = uniqueValue("ssh-password")
        XCTAssertTrue(helper.storeSSHPassword(value))
        XCTAssertEqual(helper.retrieveSSHPassword(), value)
        XCTAssertTrue(helper.hasSSHPassword)
        XCTAssertTrue(helper.deleteSSHPassword())
        XCTAssertNil(helper.retrieveSSHPassword())
        XCTAssertFalse(helper.hasSSHPassword)
    }

    func testSSHPasswordEmptyClears() {
        let helper = KeychainHelper.shared
        helper.deleteSSHPassword()
        defer { helper.deleteSSHPassword() }

        XCTAssertTrue(helper.storeSSHPassword(uniqueValue("ssh-password")))
        XCTAssertTrue(helper.storeSSHPassword(""))
        XCTAssertNil(helper.retrieveSSHPassword())
        XCTAssertFalse(helper.hasSSHPassword)
    }

    func testAuthPasswordCRUD() {
        let helper = KeychainHelper.shared
        helper.deleteAuthPassword()
        defer { helper.deleteAuthPassword() }

        let value = uniqueValue("auth-password")
        XCTAssertTrue(helper.storeAuthPassword(value))
        XCTAssertEqual(helper.retrieveAuthPassword(), value)
        XCTAssertTrue(helper.deleteAuthPassword())
        XCTAssertNil(helper.retrieveAuthPassword())
    }

    func testAuthTokenUpdatesExistingValue() {
        let helper = KeychainHelper.shared
        helper.deleteAuthToken()
        defer { helper.deleteAuthToken() }

        let first = uniqueValue("auth-token")
        let second = uniqueValue("auth-token")
        XCTAssertTrue(helper.storeAuthToken(first))
        XCTAssertEqual(helper.retrieveAuthToken(), first)
        XCTAssertTrue(helper.storeAuthToken(second))
        XCTAssertEqual(helper.retrieveAuthToken(), second)
    }

    func testAuthTokenEmptyClears() {
        let helper = KeychainHelper.shared
        helper.deleteAuthToken()
        defer { helper.deleteAuthToken() }

        XCTAssertTrue(helper.storeAuthToken(uniqueValue("auth-token")))
        XCTAssertTrue(helper.storeAuthToken(""))
        XCTAssertNil(helper.retrieveAuthToken())
    }

    func testAPIKeyCRUD() {
        let helper = KeychainHelper.shared
        helper.deleteAPIKey()
        defer { helper.deleteAPIKey() }

        let value = uniqueValue("api-key")
        XCTAssertTrue(helper.storeAPIKey(value))
        XCTAssertEqual(helper.retrieveAPIKey(), value)
        XCTAssertTrue(helper.deleteAPIKey())
        XCTAssertNil(helper.retrieveAPIKey())
    }

    func testUserIdPersistsAcrossCalls() {
        let helper = KeychainHelper.shared
        helper.deleteUserId()
        defer { helper.deleteUserId() }

        let first = helper.getOrCreateUserId()
        let second = helper.getOrCreateUserId()

        XCTAssertFalse(first.isEmpty)
        XCTAssertEqual(first, second)
        XCTAssertEqual(helper.retrieveUserId(), first)
    }

    func testFCMTokenCRUD() {
        let helper = KeychainHelper.shared
        helper.deleteFCMToken()
        defer { helper.deleteFCMToken() }

        let value = uniqueValue("fcm-token")
        XCTAssertTrue(helper.storeFCMToken(value))
        XCTAssertEqual(helper.retrieveFCMToken(), value)
        XCTAssertTrue(helper.hasFCMToken)
        XCTAssertTrue(helper.deleteFCMToken())
        XCTAssertNil(helper.retrieveFCMToken())
        XCTAssertFalse(helper.hasFCMToken)
    }

    func testClearAllRemovesSSHCredentials() {
        let helper = KeychainHelper.shared
        helper.deleteSSHKey()
        helper.deletePassphrase()
        helper.deleteSSHPassword()
        defer {
            helper.deleteSSHKey()
            helper.deletePassphrase()
            helper.deleteSSHPassword()
        }

        XCTAssertTrue(helper.storeSSHKey(uniqueValue("ssh-key")))
        XCTAssertTrue(helper.storePassphrase(uniqueValue("passphrase")))
        XCTAssertTrue(helper.storeSSHPassword(uniqueValue("ssh-password")))

        helper.clearAll()

        XCTAssertNil(helper.retrieveSSHKey())
        XCTAssertNil(helper.retrievePassphrase())
        XCTAssertNil(helper.retrieveSSHPassword())
    }

    func testClearAllCredentialsRemovesAllCredentials() {
        let helper = KeychainHelper.shared
        helper.clearAllCredentials()
        defer { helper.clearAllCredentials() }

        XCTAssertTrue(helper.storeSSHKey(uniqueValue("ssh-key")))
        XCTAssertTrue(helper.storePassphrase(uniqueValue("passphrase")))
        XCTAssertTrue(helper.storeSSHPassword(uniqueValue("ssh-password")))
        XCTAssertTrue(helper.storeAuthPassword(uniqueValue("auth-password")))
        XCTAssertTrue(helper.storeAuthToken(uniqueValue("auth-token")))
        XCTAssertTrue(helper.storeAPIKey(uniqueValue("api-key")))
        XCTAssertTrue(helper.storeFCMToken(uniqueValue("fcm-token")))
        _ = helper.getOrCreateUserId()

        helper.clearAllCredentials()

        XCTAssertNil(helper.retrieveSSHKey())
        XCTAssertNil(helper.retrievePassphrase())
        XCTAssertNil(helper.retrieveSSHPassword())
        XCTAssertNil(helper.retrieveAuthPassword())
        XCTAssertNil(helper.retrieveAuthToken())
        XCTAssertNil(helper.retrieveAPIKey())
        XCTAssertNil(helper.retrieveUserId())
        XCTAssertNil(helper.retrieveFCMToken())
        XCTAssertFalse(helper.hasSSHKey)
        XCTAssertFalse(helper.hasSSHPassword)
        XCTAssertFalse(helper.hasFCMToken)
    }

    func test_keychain_saveOverwrite() {
        let helper = KeychainHelper.shared
        helper.deleteSSHKey()
        defer { helper.deleteSSHKey() }

        let first = uniqueValue("ssh-key")
        let second = uniqueValue("ssh-key")

        XCTAssertTrue(helper.storeSSHKey(first))
        XCTAssertTrue(helper.storeSSHKey(second))
        XCTAssertEqual(helper.retrieveSSHKey(), second)
    }

    func test_keychain_loadNonExistent() {
        let helper = KeychainHelper.shared
        helper.deleteAPIKey()
        defer { helper.deleteAPIKey() }

        XCTAssertNil(helper.retrieveAPIKey())
    }

    func test_keychain_deleteNonExistent() {
        let helper = KeychainHelper.shared
        XCTAssertTrue(helper.deleteAuthPassword())
        XCTAssertTrue(helper.deleteAuthPassword())
    }

    func test_keychain_updateExisting() {
        let helper = KeychainHelper.shared
        helper.deleteAPIKey()
        defer { helper.deleteAPIKey() }

        let first = uniqueValue("api-key")
        let second = uniqueValue("api-key")

        XCTAssertTrue(helper.storeAPIKey(first))
        XCTAssertEqual(helper.retrieveAPIKey(), first)
        XCTAssertTrue(helper.storeAPIKey(second))
        XCTAssertEqual(helper.retrieveAPIKey(), second)
    }

    func test_keychain_updateNonExistent() {
        let helper = KeychainHelper.shared
        helper.deleteAuthPassword()
        defer { helper.deleteAuthPassword() }

        let value = uniqueValue("auth-password")

        XCTAssertTrue(helper.storeAuthPassword(value))
        XCTAssertEqual(helper.retrieveAuthPassword(), value)
    }

    func test_keychain_clearAllItems() {
        let helper = KeychainHelper.shared
        helper.deleteSSHKey()
        helper.deletePassphrase()
        helper.deleteSSHPassword()
        helper.deleteAuthToken()
        defer {
            helper.deleteSSHKey()
            helper.deletePassphrase()
            helper.deleteSSHPassword()
            helper.deleteAuthToken()
        }

        XCTAssertTrue(helper.storeSSHKey(uniqueValue("ssh-key")))
        XCTAssertTrue(helper.storeAuthToken(uniqueValue("auth-token")))

        helper.clearAll()

        XCTAssertNil(helper.retrieveSSHKey())
        XCTAssertNotNil(helper.retrieveAuthToken())
    }

    func test_keychain_accessGroupIsolation() {
        let helper = KeychainHelper.shared
        helper.deleteSSHKey()
        defer { helper.deleteSSHKey() }

        let alternateService = "com.codingbridge.sshkeys.test"
        let account = "ssh_private_key"
        let data = Data(uniqueValue("ssh-key").utf8)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: alternateService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: alternateService,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(deleteQuery as CFDictionary)
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        XCTAssertEqual(status, errSecSuccess)

        XCTAssertNil(helper.retrieveSSHKey())

        SecItemDelete(deleteQuery as CFDictionary)
    }

    func test_keychain_dataProtectionClass() {
        let helper = KeychainHelper.shared
        helper.deletePassphrase()
        defer { helper.deletePassphrase() }

        XCTAssertTrue(helper.storePassphrase(uniqueValue("passphrase")))

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.codingbridge.sshkeys",
            kSecAttrAccount as String: "ssh_key_passphrase",
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        XCTAssertEqual(status, errSecSuccess)

        let attributes = result as? [String: Any]
        let accessible = attributes?[kSecAttrAccessible as String] as? String
        XCTAssertEqual(accessible, kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
    }

    func testHostKeyFingerprintCRUD() {
        let helper = KeychainHelper.shared
        let host = "example.test"
        let port = 22

        helper.deleteHostKeyFingerprint(host: host, port: port)
        defer { helper.deleteHostKeyFingerprint(host: host, port: port) }

        let fingerprint = uniqueValue("fingerprint")
        XCTAssertTrue(helper.storeHostKeyFingerprint(fingerprint, host: host, port: port))
        XCTAssertEqual(helper.retrieveHostKeyFingerprint(host: host, port: port), fingerprint)
        XCTAssertTrue(helper.hasHostKeyFingerprint(host: host, port: port))
        XCTAssertTrue(helper.deleteHostKeyFingerprint(host: host, port: port))
        XCTAssertNil(helper.retrieveHostKeyFingerprint(host: host, port: port))
        XCTAssertFalse(helper.hasHostKeyFingerprint(host: host, port: port))
    }

    func testHostKeyFingerprintRejectsEmpty() {
        let helper = KeychainHelper.shared
        let host = "example.test"
        let port = 22

        XCTAssertFalse(helper.storeHostKeyFingerprint("", host: host, port: port))
    }
}

@MainActor
final class HealthMonitorServiceTests: XCTestCase {

    private func withMockedResponse(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data),
        perform: () async -> Void
    ) async {
        URLProtocol.registerClass(MockURLProtocol.self)
        defer {
            URLProtocol.unregisterClass(MockURLProtocol.self)
            MockURLProtocol.requestHandler = nil
        }

        MockURLProtocol.requestHandler = handler
        await perform()
    }

    func testServerStatusDisplayText() {
        XCTAssertEqual(ServerStatus.connected.displayText, "Connected")
        XCTAssertEqual(ServerStatus.disconnected.displayText, "Disconnected")
        XCTAssertEqual(ServerStatus.checking.displayText, "Checking...")
    }

    func testServerStatusAccessibilityLabel() {
        XCTAssertEqual(ServerStatus.connected.accessibilityLabel, "Server status: Connected")
        XCTAssertEqual(ServerStatus.disconnected.accessibilityLabel, "Server status: Disconnected")
        XCTAssertEqual(ServerStatus.checking.accessibilityLabel, "Server status: Checking connection")
    }

    func testFormatUptimeFormatting() {
        let service = HealthMonitorService.shared

        XCTAssertEqual(service.formatUptime(0), "0s")
        XCTAssertEqual(service.formatUptime(59), "59s")
        XCTAssertEqual(service.formatUptime(60), "1m")
        XCTAssertEqual(service.formatUptime(3661), "1h 1m 1s")
        XCTAssertEqual(service.formatUptime(90061), "1d 1h 1m")
    }

    func testForceCheckSuccessUpdatesMetrics() async {
        let originalState = snapshotNetworkState()
        defer { restoreNetworkState(originalState) }

        NetworkMonitor.shared.updateStateForTesting(
            isConnected: true,
            connectionType: .wifi,
            isExpensive: false,
            isConstrained: false
        )

        URLProtocol.registerClass(MockURLProtocol.self)
        defer {
            URLProtocol.unregisterClass(MockURLProtocol.self)
            MockURLProtocol.requestHandler = nil
        }

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url, url.path == "/health" else {
                throw URLError(.badURL)
            }

            let data = Data("{\"status\":\"ok\",\"version\":\"1.2.3\",\"uptime\":1234,\"agents\":2}".utf8)
            guard let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ) else {
                throw URLError(.badServerResponse)
            }

            return (response, data)
        }

        let service = HealthMonitorService.shared
        service.configure(serverURL: "http://mock.server")
        await service.forceCheck()

        XCTAssertEqual(service.serverStatus, .connected)
        XCTAssertEqual(service.serverVersion, "1.2.3")
        XCTAssertEqual(service.uptime, 1234)
        XCTAssertEqual(service.activeAgents, 2)
        XCTAssertNotNil(service.lastCheck)
        XCTAssertNil(service.lastError)
        XCTAssertEqual(service.formattedUptime, "20m 34s")
        XCTAssertNotNil(service.lastCheckRelative)
        XCTAssertTrue(service.formattedLatency.hasSuffix("ms"))

        let latencyMs = service.latency * 1000
        let expectedStatus: HealthMonitorService.LatencyStatus
        if latencyMs < 100 {
            expectedStatus = .good
        } else if latencyMs < 500 {
            expectedStatus = .moderate
        } else {
            expectedStatus = .poor
        }
        XCTAssertEqual(service.latencyStatus, expectedStatus)

        service.configure(serverURL: "")
    }

    func testForceCheckFailureSetsError() async {
        let originalState = snapshotNetworkState()
        defer { restoreNetworkState(originalState) }

        NetworkMonitor.shared.updateStateForTesting(
            isConnected: true,
            connectionType: .wifi,
            isExpensive: false,
            isConstrained: false
        )

        URLProtocol.registerClass(MockURLProtocol.self)
        defer {
            URLProtocol.unregisterClass(MockURLProtocol.self)
            MockURLProtocol.requestHandler = nil
        }

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url, url.path == "/health" else {
                throw URLError(.badURL)
            }

            let data = Data("{\"error\":\"boom\"}".utf8)
            guard let response = HTTPURLResponse(
                url: url,
                statusCode: 500,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ) else {
                throw URLError(.badServerResponse)
            }

            return (response, data)
        }

        let service = HealthMonitorService.shared
        service.configure(serverURL: "http://mock.server")
        await service.forceCheck()

        XCTAssertEqual(service.serverStatus, .disconnected)
        XCTAssertNotNil(service.lastError)
        XCTAssertTrue(service.lastError?.contains("Server error") ?? false)

        service.configure(serverURL: "")
    }

    func testForceCheckWithoutServerConfigured() async {
        let originalState = snapshotNetworkState()
        defer { restoreNetworkState(originalState) }

        NetworkMonitor.shared.updateStateForTesting(
            isConnected: true,
            connectionType: .wifi,
            isExpensive: false,
            isConstrained: false
        )

        let service = HealthMonitorService.shared
        service.configure(serverURL: "")

        await service.forceCheck()

        XCTAssertEqual(service.serverStatus, .disconnected)
        XCTAssertEqual(service.lastError, "No server configured")
    }

    func test_healthMonitor_retryIntervals() async {
        let service = HealthMonitorService.shared
        service.resetForTesting()
        let originalState = snapshotNetworkState()
        defer { restoreNetworkState(originalState) }

        NetworkMonitor.shared.updateStateForTesting(
            isConnected: true,
            connectionType: .wifi,
            isExpensive: false,
            isConstrained: false
        )

        await withMockedResponse(handler: { request in
            try makeHTTPResponse(request: request, statusCode: 500, body: "{\"error\":\"boom\"}")
        }) {
            service.configure(serverURL: "http://mock.server")
            await service.forceCheck()
        }

        XCTAssertEqual(service.currentBackoffIntervalForTesting, 10)
    }

    func test_healthMonitor_maxRetryAttempts() async {
        let service = HealthMonitorService.shared
        service.resetForTesting()
        let originalState = snapshotNetworkState()
        defer { restoreNetworkState(originalState) }

        NetworkMonitor.shared.updateStateForTesting(
            isConnected: true,
            connectionType: .wifi,
            isExpensive: false,
            isConstrained: false
        )

        await withMockedResponse(handler: { request in
            try makeHTTPResponse(request: request, statusCode: 500, body: "{\"error\":\"boom\"}")
        }) {
            service.configure(serverURL: "http://mock.server")
            await service.forceCheck()
            await service.forceCheck()
            await service.forceCheck()
            await service.forceCheck()
        }

        XCTAssertEqual(service.currentBackoffIntervalForTesting, 30)
    }

    func test_healthMonitor_backoffCalculation() async {
        let service = HealthMonitorService.shared
        service.resetForTesting()
        let originalState = snapshotNetworkState()
        defer { restoreNetworkState(originalState) }

        NetworkMonitor.shared.updateStateForTesting(
            isConnected: true,
            connectionType: .wifi,
            isExpensive: false,
            isConstrained: false
        )

        await withMockedResponse(handler: { request in
            try makeHTTPResponse(request: request, statusCode: 500, body: "{\"error\":\"boom\"}")
        }) {
            service.configure(serverURL: "http://mock.server")
            await service.forceCheck()
            XCTAssertEqual(service.currentBackoffIntervalForTesting, 10)
            await service.forceCheck()
            XCTAssertEqual(service.currentBackoffIntervalForTesting, 20)
            await service.forceCheck()
            XCTAssertEqual(service.currentBackoffIntervalForTesting, 30)
        }
    }

    func test_healthMonitor_successResetsRetry() async {
        let service = HealthMonitorService.shared
        service.resetForTesting()
        let originalState = snapshotNetworkState()
        defer { restoreNetworkState(originalState) }

        NetworkMonitor.shared.updateStateForTesting(
            isConnected: true,
            connectionType: .wifi,
            isExpensive: false,
            isConstrained: false
        )

        var shouldSucceed = false
        await withMockedResponse(handler: { request in
            if shouldSucceed {
                return try makeHTTPResponse(
                    request: request,
                    statusCode: 200,
                    body: "{\"status\":\"ok\",\"version\":\"1.2.3\",\"uptime\":1234,\"agents\":2}"
                )
            }

            return try makeHTTPResponse(request: request, statusCode: 500, body: "{\"error\":\"boom\"}")
        }) {
            service.configure(serverURL: "http://mock.server")
            await service.forceCheck()
            XCTAssertEqual(service.consecutiveFailuresForTesting, 1)
            XCTAssertEqual(service.currentBackoffIntervalForTesting, 10)

            shouldSucceed = true
            await service.forceCheck()
        }

        XCTAssertEqual(service.consecutiveFailuresForTesting, 0)
        XCTAssertEqual(service.currentBackoffIntervalForTesting, 5)
        XCTAssertEqual(service.serverStatus, .connected)
    }

    func test_healthMonitor_consecutiveFailures() async {
        let service = HealthMonitorService.shared
        service.resetForTesting()
        let originalState = snapshotNetworkState()
        defer { restoreNetworkState(originalState) }

        NetworkMonitor.shared.updateStateForTesting(
            isConnected: true,
            connectionType: .wifi,
            isExpensive: false,
            isConstrained: false
        )

        await withMockedResponse(handler: { request in
            try makeHTTPResponse(request: request, statusCode: 500, body: "{\"error\":\"boom\"}")
        }) {
            service.configure(serverURL: "http://mock.server")
            await service.forceCheck()
            await service.forceCheck()
        }

        XCTAssertEqual(service.consecutiveFailuresForTesting, 2)
    }

    func test_healthMonitor_timerScheduling() {
        let service = HealthMonitorService.shared
        service.resetForTesting()
        let originalState = snapshotNetworkState()
        defer { restoreNetworkState(originalState) }

        service.configure(serverURL: "")
        service.startPolling()
        defer { service.stopPolling() }

        XCTAssertTrue(service.isPollingForTesting)
        XCTAssertTrue(service.hasPollTimerForTesting)
    }

    func test_healthMonitor_timerCancellation() {
        let service = HealthMonitorService.shared
        service.resetForTesting()
        let originalState = snapshotNetworkState()
        defer { restoreNetworkState(originalState) }

        service.configure(serverURL: "")
        service.startPolling()
        service.stopPolling()

        XCTAssertFalse(service.isPollingForTesting)
        XCTAssertFalse(service.hasPollTimerForTesting)
    }

    func test_healthMonitor_statusCallback() async {
        let service = HealthMonitorService.shared
        service.resetForTesting()
        let originalState = snapshotNetworkState()
        defer { restoreNetworkState(originalState) }

        NetworkMonitor.shared.updateStateForTesting(
            isConnected: true,
            connectionType: .wifi,
            isExpensive: false,
            isConstrained: false
        )

        let expectation = XCTestExpectation(description: "status updates")
        var statuses: [ServerStatus] = []
        var cancellables = Set<AnyCancellable>()

        service.$serverStatus
            .dropFirst()
            .sink { status in
                statuses.append(status)
                if status == .connected {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        await withMockedResponse(handler: { request in
            try makeHTTPResponse(
                request: request,
                statusCode: 200,
                body: "{\"status\":\"ok\",\"version\":\"1.2.3\",\"uptime\":1234,\"agents\":2}"
            )
        }) {
            service.configure(serverURL: "http://mock.server")
            await service.forceCheck()
        }

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertTrue(statuses.contains(.checking))
        XCTAssertTrue(statuses.contains(.connected))
    }

    func test_healthMonitor_differentEndpoints() async {
        let service = HealthMonitorService.shared
        service.resetForTesting()
        let originalState = snapshotNetworkState()
        defer { restoreNetworkState(originalState) }

        NetworkMonitor.shared.updateStateForTesting(
            isConnected: true,
            connectionType: .wifi,
            isExpensive: false,
            isConstrained: false
        )

        await withMockedResponse(handler: { request in
            guard request.url?.path == "/api/health" else {
                throw URLError(.badURL)
            }
            return try makeHTTPResponse(
                request: request,
                statusCode: 200,
                body: "{\"status\":\"ok\",\"version\":\"1.2.3\",\"uptime\":1234,\"agents\":2}"
            )
        }) {
            service.configure(serverURL: "http://mock.server/api")
            await service.forceCheck()
        }

        XCTAssertEqual(service.serverStatus, .connected)
    }
}
