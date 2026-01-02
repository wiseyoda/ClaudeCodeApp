import XCTest
@testable import CodingBridge

final class CLIPushNotificationTypesTests: XCTestCase {

    // MARK: - CLIPushRegisterRequest

    func test_pushRegisterRequest_encodesRequiredFields() throws {
        let request = CLIPushRegisterRequest(fcmToken: "token-123", platform: .ios, environment: .sandbox)

        let json = try encodeToJSON(request)

        XCTAssertEqual(json["fcmToken"] as? String, "token-123")
        XCTAssertEqual(json["environment"] as? String, "sandbox")
    }

    func test_pushRegisterRequest_platformEncodesAsIos() throws {
        let request = CLIPushRegisterRequest(fcmToken: "token-123", platform: .ios, environment: .production)

        let json = try encodeToJSON(request)

        XCTAssertEqual(json["platform"] as? String, "ios")
    }

    func test_pushRegisterRequest_encodesOptionalFields() throws {
        let request = CLIPushRegisterRequest(
            fcmToken: "token-123",
            platform: .ios,
            environment: .production,
            appVersion: "1.2.3",
            osVersion: "18.1"
        )

        let json = try encodeToJSON(request)

        XCTAssertEqual(json["appVersion"] as? String, "1.2.3")
        XCTAssertEqual(json["osVersion"] as? String, "18.1")
    }

    func test_pushRegisterRequest_omitsNilOptionals() throws {
        let request = CLIPushRegisterRequest(fcmToken: "token-123", platform: .ios, environment: .production)

        let json = try encodeToJSON(request)

        XCTAssertFalse(json.keys.contains("appVersion"))
        XCTAssertFalse(json.keys.contains("osVersion"))
    }

    func test_pushRegisterRequest_encodesAppVersionOnly() throws {
        let request = CLIPushRegisterRequest(
            fcmToken: "token-123",
            platform: .ios,
            environment: .production,
            appVersion: "2.0.0",
            osVersion: nil
        )

        let json = try encodeToJSON(request)

        XCTAssertEqual(json["appVersion"] as? String, "2.0.0")
        XCTAssertFalse(json.keys.contains("osVersion"))
    }

    func test_pushRegisterRequest_encodesOsVersionOnly() throws {
        let request = CLIPushRegisterRequest(
            fcmToken: "token-123",
            platform: .ios,
            environment: .production,
            appVersion: nil,
            osVersion: "18.2"
        )

        let json = try encodeToJSON(request)

        XCTAssertEqual(json["osVersion"] as? String, "18.2")
        XCTAssertFalse(json.keys.contains("appVersion"))
    }

    // MARK: - CLIPushRegisterResponse

    func test_pushRegisterResponse_decodesWithTokenId() throws {
        let response = try decodeJSON(
            CLIPushRegisterResponse.self,
            json: """
            {"success": true, "tokenId": "token-id-1"}
            """
        )

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.tokenId, "token-id-1")
    }

    func test_pushRegisterResponse_decodesWithEmptyTokenId() throws {
        // tokenId is now required in the generated type
        let response = try decodeJSON(
            CLIPushRegisterResponse.self,
            json: """
            {"success": false, "tokenId": ""}
            """
        )

        XCTAssertFalse(response.success)
        XCTAssertEqual(response.tokenId, "")
    }

    func test_pushRegisterResponse_encodesAllFields() throws {
        let response = CLIPushRegisterResponse(success: true, tokenId: "token-id-2")

        let json = try encodeToJSON(response)

        XCTAssertEqual(json["success"] as? Bool, true)
        XCTAssertEqual(json["tokenId"] as? String, "token-id-2")
    }

    // MARK: - CLILiveActivityRegisterRequest

    func test_liveActivityRegisterRequest_encodesAllFields() throws {
        let sessionUUID = UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!
        let request = CLILiveActivityRegisterRequest(
            pushToken: "push-token-1",
            pushToStartToken: "start-token-1",
            activityId: "activity-1",
            sessionId: sessionUUID,
            attributesType: "CustomAttributes",
            platform: .ios,
            environment: .production
        )

        let json = try encodeToJSON(request)

        XCTAssertEqual(json["pushToken"] as? String, "push-token-1")
        XCTAssertEqual(json["pushToStartToken"] as? String, "start-token-1")
        XCTAssertEqual(json["activityId"] as? String, "activity-1")
        XCTAssertEqual(json["sessionId"] as? String, sessionUUID.uuidString.uppercased())
        XCTAssertEqual(json["attributesType"] as? String, "CustomAttributes")
        XCTAssertEqual(json["environment"] as? String, "production")
    }

    func test_liveActivityRegisterRequest_platformEncodesAsIos() throws {
        let sessionUUID = UUID()
        let request = CLILiveActivityRegisterRequest(
            pushToken: "push-token-1",
            activityId: "activity-1",
            sessionId: sessionUUID,
            platform: .ios,
            environment: .production
        )

        let json = try encodeToJSON(request)

        XCTAssertEqual(json["platform"] as? String, "ios")
    }

    func test_liveActivityRegisterRequest_omitsNilOptionals() throws {
        let sessionUUID = UUID()
        let request = CLILiveActivityRegisterRequest(
            pushToken: "push-token-1",
            activityId: "activity-1",
            sessionId: sessionUUID
        )

        let json = try encodeToJSON(request)

        // Optional fields should be omitted when nil
        XCTAssertFalse(json.keys.contains("attributesType"))
        XCTAssertFalse(json.keys.contains("platform"))
        XCTAssertFalse(json.keys.contains("environment"))
    }

    func test_liveActivityRegisterRequest_omitsNilPushToStartToken() throws {
        let sessionUUID = UUID()
        let request = CLILiveActivityRegisterRequest(
            pushToken: "push-token-1",
            pushToStartToken: nil,
            activityId: "activity-1",
            sessionId: sessionUUID,
            environment: .production
        )

        let json = try encodeToJSON(request)

        XCTAssertFalse(json.keys.contains("pushToStartToken"))
    }

    func test_liveActivityRegisterRequest_omitsNilAttributesType() throws {
        let sessionUUID = UUID()
        let request = CLILiveActivityRegisterRequest(
            pushToken: "push-token-1",
            pushToStartToken: "start-token-1",
            activityId: "activity-1",
            sessionId: sessionUUID,
            attributesType: nil,
            environment: .production
        )

        let json = try encodeToJSON(request)

        XCTAssertFalse(json.keys.contains("attributesType"))
    }

    func test_liveActivityRegisterRequest_encodesPushToStartToken() throws {
        let sessionUUID = UUID()
        let request = CLILiveActivityRegisterRequest(
            pushToken: "push-token-1",
            pushToStartToken: "start-token-1",
            activityId: "activity-1",
            sessionId: sessionUUID,
            environment: .production
        )

        let json = try encodeToJSON(request)

        XCTAssertEqual(json["pushToStartToken"] as? String, "start-token-1")
    }

    // MARK: - CLILiveActivityRegisterResponse

    func test_liveActivityRegisterResponse_decodesWithActivityTokenId() throws {
        let response = try decodeJSON(
            CLILiveActivityRegisterResponse.self,
            json: """
            {"success": true, "activityTokenId": "activity-token-1"}
            """
        )

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.activityTokenId, "activity-token-1")
    }

    func test_liveActivityRegisterResponse_decodesWithEmptyActivityTokenId() throws {
        // activityTokenId is now required in the generated type
        let response = try decodeJSON(
            CLILiveActivityRegisterResponse.self,
            json: """
            {"success": false, "activityTokenId": ""}
            """
        )

        XCTAssertFalse(response.success)
        XCTAssertEqual(response.activityTokenId, "")
    }

    func test_liveActivityRegisterResponse_encodesAllFields() throws {
        let response = CLILiveActivityRegisterResponse(success: true, activityTokenId: "activity-token-2")

        let json = try encodeToJSON(response)

        XCTAssertEqual(json["success"] as? Bool, true)
        XCTAssertEqual(json["activityTokenId"] as? String, "activity-token-2")
    }

    // MARK: - CLIPushInvalidateRequest

    func test_pushInvalidateRequest_tokenTypeRawValues() {
        // TokenType is now a top-level enum, not nested in CLIPushInvalidateRequest
        XCTAssertEqual(TokenType.fcm.rawValue, "fcm")
        XCTAssertEqual(TokenType.liveActivity.rawValue, "live_activity")
    }

    func test_pushInvalidateRequest_encodesFcmTokenType() throws {
        let request = CLIPushInvalidateRequest(tokenType: .fcm, token: "fcm-token")

        let json = try encodeToJSON(request)

        XCTAssertEqual(json["tokenType"] as? String, "fcm")
        XCTAssertEqual(json["token"] as? String, "fcm-token")
    }

    func test_pushInvalidateRequest_encodesLiveActivityTokenType() throws {
        let request = CLIPushInvalidateRequest(tokenType: .liveActivity, token: "live-token")

        let json = try encodeToJSON(request)

        XCTAssertEqual(json["tokenType"] as? String, "live_activity")
        XCTAssertEqual(json["token"] as? String, "live-token")
    }

    // MARK: - CLIPushStatusResponse

    func test_pushStatusResponse_decodesFullPayload() throws {
        let response = try decodeJSON(
            CLIPushStatusResponse.self,
            json: """
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
                },
                {
                  "activityId": "activity-2",
                  "sessionId": "session-2",
                  "registeredAt": "2024-01-16T10:00:00Z",
                  "hasUpdateToken": false,
                  "hasPushToStartToken": true
                }
              ],
              "recentDeliveries": [
                {
                  "type": "fcm",
                  "sentAt": "2024-01-15T11:00:00Z",
                  "success": true
                }
              ]
            }
            """
        )

        XCTAssertEqual(response.provider, "fcm")
        XCTAssertTrue(response.providerEnabled)
        XCTAssertTrue(response.fcmTokenRegistered)
        XCTAssertEqual(response.fcmTokenLastUpdated, "2024-01-15T10:30:00Z")
        XCTAssertEqual(response.liveActivityTokens.count, 2)
        XCTAssertEqual(response.liveActivityTokens[0].activityId, "activity-1")
        XCTAssertEqual(response.liveActivityTokens[1].activityId, "activity-2")
        XCTAssertEqual(response.recentDeliveries.count, 1)
        XCTAssertEqual(response.recentDeliveries[0].type, "fcm")
        XCTAssertTrue(response.recentDeliveries[0].success)
    }

    func test_pushStatusResponse_decodesWithoutLastUpdated() throws {
        let response = try decodeJSON(
            CLIPushStatusResponse.self,
            json: """
            {
              "provider": "fcm",
              "providerEnabled": false,
              "fcmTokenRegistered": false,
              "liveActivityTokens": [],
              "recentDeliveries": []
            }
            """
        )

        XCTAssertEqual(response.provider, "fcm")
        XCTAssertFalse(response.providerEnabled)
        XCTAssertFalse(response.fcmTokenRegistered)
        XCTAssertNil(response.fcmTokenLastUpdated)
        XCTAssertTrue(response.liveActivityTokens.isEmpty)
        XCTAssertTrue(response.recentDeliveries.isEmpty)
    }

    func test_pushStatusResponse_decodesLiveActivityTokenFields() throws {
        let response = try decodeJSON(
            CLIPushStatusResponse.self,
            json: """
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
                  "hasUpdateToken": false,
                  "hasPushToStartToken": true
                }
              ],
              "recentDeliveries": []
            }
            """
        )

        let token = response.liveActivityTokens[0]
        XCTAssertEqual(token.activityId, "activity-1")
        XCTAssertEqual(token.sessionId, "session-1")
        XCTAssertEqual(token.registeredAt, "2024-01-15T10:00:00Z")
        XCTAssertFalse(token.hasUpdateToken)
        XCTAssertTrue(token.hasPushToStartToken)
    }

    // MARK: - LiveActivityTokenInfo

    func test_liveActivityTokenInfo_decodesAllFields() throws {
        let token = try decodeJSON(
            LiveActivityTokenInfo.self,
            json: """
            {
              "activityId": "activity-1",
              "sessionId": "session-1",
              "registeredAt": "2024-01-15T10:00:00Z",
              "hasUpdateToken": true,
              "hasPushToStartToken": false
            }
            """
        )

        XCTAssertEqual(token.activityId, "activity-1")
        XCTAssertEqual(token.sessionId, "session-1")
        XCTAssertEqual(token.registeredAt, "2024-01-15T10:00:00Z")
        XCTAssertTrue(token.hasUpdateToken)
        XCTAssertFalse(token.hasPushToStartToken)
    }

    // MARK: - Helpers

    private func encodeToJSON<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        return object as? [String: Any] ?? [:]
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, json: String) throws -> T {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(type, from: data)
    }
}
