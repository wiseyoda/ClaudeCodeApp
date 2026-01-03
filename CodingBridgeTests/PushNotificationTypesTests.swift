import XCTest
@testable import CodingBridge

final class PushNotificationTypesTests: XCTestCase {

    // MARK: - CLIPushRegisterRequest Tests

    func test_pushRegisterRequest_encodesCorrectly() throws {
        let request = CLIPushRegisterRequest(
            fcmToken: "test-fcm-token-123",
            platform: .ios,
            environment: .sandbox,
            appVersion: "1.0.0",
            osVersion: "18.0"
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["fcmToken"] as? String, "test-fcm-token-123")
        XCTAssertEqual(json?["platform"] as? String, "ios")
        XCTAssertEqual(json?["environment"] as? String, "sandbox")
        XCTAssertEqual(json?["appVersion"] as? String, "1.0.0")
        XCTAssertEqual(json?["osVersion"] as? String, "18.0")
    }

    // MARK: - CLIPushRegisterResponse Tests

    func test_pushRegisterResponse_decodesSuccessfully() throws {
        let json = """
        {
            "success": true,
            "tokenId": "token-id-456"
        }
        """

        let response = try JSONDecoder().decode(
            CLIPushRegisterResponse.self,
            from: Data(json.utf8)
        )

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.tokenId, "token-id-456")
    }

    func test_pushRegisterResponse_decodesWithTokenId() throws {
        // tokenId is now required in the API schema
        let json = """
        {
            "success": false,
            "tokenId": "failed-registration-id"
        }
        """

        let response = try JSONDecoder().decode(
            CLIPushRegisterResponse.self,
            from: Data(json.utf8)
        )

        XCTAssertFalse(response.success)
        XCTAssertEqual(response.tokenId, "failed-registration-id")
    }

    // MARK: - CLILiveActivityRegisterRequest Tests

    func test_liveActivityRegisterRequest_encodesCorrectly() throws {
        let sessionUUID = UUID()
        let request = CLILiveActivityRegisterRequest(
            pushToken: "push-token-abc",
            pushToStartToken: "start-token-xyz",
            activityId: "activity-123",
            sessionId: sessionUUID,
            attributesType: "CodingBridgeAttributes",
            platform: .ios,
            environment: .production
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["pushToken"] as? String, "push-token-abc")
        XCTAssertEqual(json?["pushToStartToken"] as? String, "start-token-xyz")
        XCTAssertEqual(json?["activityId"] as? String, "activity-123")
        XCTAssertEqual(json?["sessionId"] as? String, sessionUUID.uuidString)
        XCTAssertEqual(json?["attributesType"] as? String, "CodingBridgeAttributes")
        XCTAssertEqual(json?["platform"] as? String, "ios")
        XCTAssertEqual(json?["environment"] as? String, "production")
    }

    func test_liveActivityRegisterRequest_encodesWithNilPushToStartToken() throws {
        let sessionUUID = UUID()
        let request = CLILiveActivityRegisterRequest(
            pushToken: "push-token-abc",
            pushToStartToken: nil,
            activityId: "activity-123",
            sessionId: sessionUUID,
            attributesType: nil,
            platform: nil,
            environment: .sandbox
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["pushToken"] as? String, "push-token-abc")
        XCTAssertNil(json?["pushToStartToken"])
    }

    // MARK: - CLILiveActivityRegisterResponse Tests

    func test_liveActivityRegisterResponse_decodesSuccessfully() throws {
        let json = """
        {
            "success": true,
            "activityTokenId": "activity-token-789"
        }
        """

        let response = try JSONDecoder().decode(
            CLILiveActivityRegisterResponse.self,
            from: Data(json.utf8)
        )

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.activityTokenId, "activity-token-789")
    }

    // MARK: - CLIPushInvalidateRequest Tests

    func test_pushInvalidateRequest_encodesTokenTypeFCM() throws {
        let request = CLIPushInvalidateRequest(tokenType: .fcm, token: "fcm-token")

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["tokenType"] as? String, "fcm")
        XCTAssertEqual(json?["token"] as? String, "fcm-token")
    }

    func test_pushInvalidateRequest_encodesTokenTypeLiveActivity() throws {
        let request = CLIPushInvalidateRequest(tokenType: .liveActivity, token: "la-token")

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["tokenType"] as? String, "live_activity")
        XCTAssertEqual(json?["token"] as? String, "la-token")
    }

    // MARK: - CLIPushStatusResponse Tests

    func test_pushStatusResponse_decodesFullResponse() throws {
        let json = """
        {
            "provider": "fcm",
            "providerEnabled": true,
            "fcmTokenRegistered": true,
            "fcmTokenLastUpdated": "2024-01-15T10:30:00Z",
            "liveActivityTokens": [
                {
                    "activityId": "activity-1",
                    "sessionId": "session-1",
                    "registeredAt": "2024-01-15T10:00:00Z",
                    "hasUpdateToken": true,
                    "hasPushToStartToken": false
                }
            ],
            "recentDeliveries": []
        }
        """

        let response = try JSONDecoder().decode(
            CLIPushStatusResponse.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(response.provider, "fcm")
        XCTAssertTrue(response.providerEnabled)
        XCTAssertTrue(response.fcmTokenRegistered)
        XCTAssertEqual(response.fcmTokenLastUpdated, "2024-01-15T10:30:00Z")
        XCTAssertEqual(response.liveActivityTokens.count, 1)

        let token = response.liveActivityTokens[0]
        XCTAssertEqual(token.activityId, "activity-1")
        XCTAssertEqual(token.sessionId, "session-1")
        XCTAssertEqual(token.registeredAt, "2024-01-15T10:00:00Z")
        XCTAssertTrue(token.hasUpdateToken)
        XCTAssertFalse(token.hasPushToStartToken)
    }

    func test_pushStatusResponse_decodesEmptyLiveActivityTokens() throws {
        let json = """
        {
            "provider": "fcm",
            "providerEnabled": false,
            "fcmTokenRegistered": false,
            "liveActivityTokens": [],
            "recentDeliveries": []
        }
        """

        let response = try JSONDecoder().decode(
            CLIPushStatusResponse.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(response.provider, "fcm")
        XCTAssertFalse(response.providerEnabled)
        XCTAssertFalse(response.fcmTokenRegistered)
        XCTAssertNil(response.fcmTokenLastUpdated)
        XCTAssertTrue(response.liveActivityTokens.isEmpty)
    }

    // MARK: - Success Response Tests

    func test_successResponse_decodesSuccess() throws {
        // CLIPushRegisterResponse now requires tokenId
        let json = """
        {"success": true, "tokenId": "success-token"}
        """

        let response = try JSONDecoder().decode(
            CLIPushRegisterResponse.self,
            from: Data(json.utf8)
        )

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.tokenId, "success-token")
    }

    func test_successResponse_decodesFailure() throws {
        // CLIPushRegisterResponse now requires tokenId
        let json = """
        {"success": false, "tokenId": "failure-token"}
        """

        let response = try JSONDecoder().decode(
            CLIPushRegisterResponse.self,
            from: Data(json.utf8)
        )

        XCTAssertFalse(response.success)
        XCTAssertEqual(response.tokenId, "failure-token")
    }
}
