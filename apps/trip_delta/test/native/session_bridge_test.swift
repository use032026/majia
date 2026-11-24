import Foundation

@main struct SessionBridgeTests {
  static func require(_ condition: Bool, _ message: String) {
    if !condition {
      fputs("FAIL: \(message)\n", stderr)
      exit(1)
    }
  }

  static func main() throws {
    // Only in-memory, synthetic snapshots; never read or write an app session.
    let defaults = UserDefaults.standard
    let previous = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
    defer { defaults.setVolatileDomain(previous, forName: UserDefaults.argumentDomain) }
    let prefix = "trip-delta-session-test.\(UUID().uuidString)"
    let authKey = "\(prefix).auth"
    let profileKey = "\(prefix).profile"
    let auth = "{\"token\":\"synthetic-session\",\"user_id\":\"fixture-user\"}"
    let profile = "{\"user\":\"{\\\"userInfo\\\":{\\\"id\\\":\\\"fixture-user\\\"}}\"}"
    var values = previous
    values[authKey] = auth
    values[profileKey] = profile
    defaults.setVolatileDomain(values, forName: UserDefaults.argumentDomain)

    let home = "https://h5.fixture-domain.com"
    let other = "https://activity.fixture-domain.net"
    var context: [String: Any] = [
      "authStorageKey": authKey,
      "bridgeUserInfoStorage": ["storageKey": profileKey, "valueKey": "user", "nestedKey": "userInfo"],
      "webSecurity": ["bridgeOrigins": [home], "sessionDomainSubstring": "fixture-domain"],
    ]
    func call(_ method: String, origin: String, params: [String: Any] = [:], documentURL: String? = nil) -> [String: Any] {
      let nativeOrigin = URL(string: origin).flatMap { STOnlineWebCore.normalizedBridgeOrigin($0, allowInsecureHTTP: true) } ?? origin
      return STOnlineWebSessionBridge.handle(
        method: method, params: params, origin: nativeOrigin,
        documentURL: URL(string: documentURL ?? origin), bridgeContext: context,
        deviceType: "ios", darkMode: false, languageCode: "en") ?? [:]
    }

    for origin in [home, other, "https://child.fixture-domain.org", "\(home):8443",
                   "https://prefix-fixture-domain-suffix.example",
                   "https://192.0.2.1/h5.fixture-domain/polymer/common/#/alipay",
                   "https://192.0.2.1/h5.%66ixture-domain/polymer/common/"] {
      let token = call("getToken", origin: origin)
      require(token["code"] as? String == "1", "Configured host/path substring must allow HTTPS session reads")
      require(token["data"] as? String == "synthetic-session", "Token must come from the stored session")
      let user = call("getUserInfo", origin: origin)["data"] as? [String: Any]
      require(user?["token"] as? String == "synthetic-session", "User response must retain the session")
      require(user?["id"] as? String == "fixture-user", "User response must include the stored profile")
    }

    for origin in ["http://activity.fixture-domain.net", "", "javascript:alert(1)",
                   "https://unrelated.example", "https://unrelated.example/other-path",
                   "https://unrelated.example/#/fixture-domain",
                   "https://unrelated.example/?redirect=https://h5.fixture-domain.com"] {
      for method in ["getToken", "getUserInfo"] {
        let denied = call(method, origin: origin)
        require(denied["code"] as? String == "0", "Unmatched hosts and non-HTTPS session requests must fail")
        require((denied["data"] as? [String: Any])?["msg"] is String, "Failure must use data.msg")
      }
    }

    require(call("getToken", origin: home, documentURL: "https://192.0.2.1/h5.fixture-domain/")["code"] as? String == "0",
            "Current document must match the WebKit-verified message origin")
    require(call("getStorage", origin: home, params: ["key": authKey])["code"] as? String == "1",
            "Home storage must remain readable")
    for method in ["getStorage", "setStorage", "removeStorage"] {
      require(call(method, origin: other, params: ["key": authKey, "data": "{}"])["code"] as? String == "0",
              "Cross-origin raw storage access must remain denied")
    }

    context.removeValue(forKey: "webSecurity")
    require(call("getToken", origin: other)["code"] as? String == "0",
            "Missing security configuration must not allow all origins")
    require(call("getStorage", origin: other, params: ["key": authKey])["code"] as? String == "0",
            "Raw storage still requires an explicit origin")
    context["webSecurity"] = ["bridgeOrigins": [home]]
    require(call("getToken", origin: home)["code"] as? String == "1", "Absent substring must preserve exact-origin reads")
    require(call("getToken", origin: other)["code"] as? String == "0", "Absent substring must preserve exact-origin rejection")
    for invalid: Any in ["", "  ", 7, NSNull()] {
      context["webSecurity"] = ["bridgeOrigins": [home], "sessionDomainSubstring": invalid]
      require(call("getToken", origin: home)["code"] as? String == "0", "Invalid configured substring must fail closed")
    }
    context["webSecurity"] = ["sessionDomainSubstring": " OTHER-CONFIG "]
    require(call("getToken", origin: "https://api.other-config.example")["code"] as? String == "1",
            "Host configuration must select the substring, ignoring case and surrounding spaces")
    require(call("getToken", origin: home)["code"] as? String == "0", "Previous configured substring must not remain authorized")
    context["webSecurity"] = ["sessionDomainSubstring": "fixture-domain"]
    context["authStorageKey"] = NSNull()
    context["bridgeUserInfoStorage"] = NSNull()
    require(call("getToken", origin: other)["data"] as? String == "", "Disabled mappings must not expose a session")

    let otherURL = URL(string: "\(other)/page")!
    require(STOnlineWebCore.allowsBridgeMessage(documentURL: otherURL, isMainFrame: true),
            "Another HTTPS top-level document may invoke the bridge")
    require(!STOnlineWebCore.allowsBridgeMessage(documentURL: otherURL, isMainFrame: false),
            "Iframes must remain rejected")
    require(!STOnlineWebCore.allowsBridgeMessage(documentURL: URL(string: "http://other.example"), isMainFrame: true),
            "HTTP documents must remain rejected")
    require(!STOnlineWebCore.matchesCurrentDocumentOrigin(
      messageDocumentURL: URL(string: home), currentDocumentURL: otherURL),
            "Messages from a previous document must remain rejected")
    require(STOnlineWebCore.matchesCurrentDocumentOrigin(messageDocumentURL: otherURL, currentDocumentURL: otherURL),
            "The current cross-origin page must pass document validation")
    print("Trip Delta 原生会话页面主机名及路径字符串匹配及来源边界测试通过")
  }
}
