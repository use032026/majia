import XCTest
import stmini_flutter

class RunnerTests: XCTestCase {
  func testWebSessionStorageAndIdentityRequireTheConfiguredHTTPSOrigin() throws {
    let authKey = UUID().uuidString
    let cacheKey = UUID().uuidString
    defer {
      UserDefaults.standard.removeObject(forKey: authKey)
      UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    let origin = "https://first.example"
    let context: [String: Any] = [
      "authStorageKey": authKey,
      "bridgeUserInfoStorage": ["storageKey": cacheKey, "valueKey": "user", "nestedKey": "userInfo"],
      "webSecurity": ["bridgeOrigins": [origin, "http://first.example"]],
    ]
    func call(_ method: String, _ params: [String: Any] = [:], from source: String,
              context bridgeContext: [String: Any]) throws -> [String: Any] {
      try XCTUnwrap(STOnlineWebSessionBridge.handle(
        method: method, params: params, origin: source, bridgeContext: bridgeContext,
        deviceType: "ios", darkMode: false, languageCode: "zh"))
    }

    let auth: [String: Any] = ["key": authKey, "data": #"{"access_token":"fixture-token","user_id":"fixture-id"}"#]
    let profile: [String: Any] = ["key": cacheKey, "data": #"{"user":"{\"userInfo\":{\"nickname\":\"Fixture\"}}"}"#]
    XCTAssertEqual(try call("setStorage", auth, from: origin, context: context)["code"] as? String, "1")
    XCTAssertEqual(try call("setStorage", profile, from: origin, context: context)["code"] as? String, "1")

    for source in ["https://other.example", "https://first.example:444", "http://first.example"] {
      XCTAssertEqual(try call("getUserInfo", from: source, context: context)["code"] as? String, "0")
      XCTAssertEqual(try call("getToken", from: source, context: context)["code"] as? String, "0")
      XCTAssertEqual(try call("getStorage", ["key": cacheKey], from: source, context: context)["code"] as? String, "0")
      XCTAssertEqual(try call("setStorage", ["key": authKey, "data": "{}"], from: source, context: context)["code"] as? String, "0")
      XCTAssertEqual(try call("removeStorage", ["key": authKey], from: source, context: context)["code"] as? String, "0")
    }
    XCTAssertEqual(try call("getUserInfo", from: origin, context: ["authStorageKey": authKey])["code"] as? String, "0")

    let response = try call("getUserInfo", from: origin, context: context)
    let userInfo = try XCTUnwrap(response["data"] as? [String: Any])
    XCTAssertEqual(userInfo["token"] as? String, "fixture-token")
    XCTAssertEqual(userInfo["user_id"] as? String, "fixture-id")
    XCTAssertEqual(userInfo["nickname"] as? String, "Fixture")
    XCTAssertEqual(try call("getToken", from: origin, context: context)["data"] as? String, "fixture-token")
  }
}
