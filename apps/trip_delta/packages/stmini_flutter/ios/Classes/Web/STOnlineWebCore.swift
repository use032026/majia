import Foundation

/// Shared Web-only rules used by the Flutter host. This deliberately contains
/// no package, local-runtime lifecycle, or host-business knowledge.
///
/// UIKit/WebKit owners supply the actual `WKWebView` and message dispatcher;
/// this file owns the security and callback data contracts that must be
/// identical for every online web container.
public enum STOnlineWebCore {
  /// A bridge origin is an HTTPS scheme, lowercase host and its effective
  /// port. Paths, queries and fragments intentionally never participate in
  /// the authority decision.
  public static func normalizedHTTPSOrigin(_ url: URL) -> String? {
    guard url.scheme?.lowercased() == "https",
          let origin = normalizedBridgeOrigin(url) else {
      return nil
    }
    return origin
  }

  /// Bridge origin is independent from navigation. HTTP requires an explicit
  /// host opt-in and an exact configured origin in every build.
  public static func normalizedBridgeOrigin(_ url: URL, allowInsecureHTTP: Bool = false) -> String? {
    guard let scheme = url.scheme?.lowercased(),
          let rawHost = url.host?.trimmingCharacters(in: .whitespacesAndNewlines),
          !rawHost.isEmpty else {
      return nil
    }
    let defaultPort: Int
    switch scheme {
    case "https": defaultPort = 443
    case "http" where allowInsecureHTTP: defaultPort = 80
    default: return nil
    }
    let host = rawHost.lowercased()
    let port = url.port ?? defaultPort
    guard (1...65_535).contains(port) else { return nil }
    return port == defaultPort ? "\(scheme)://\(host)" : "\(scheme)://\(host):\(port)"
  }

  /// WKUserContentController registers one message name for every frame.
  /// Every allowed top-level document may invoke the bridge. Iframes and a
  /// document that has already navigated away remain rejected.
  public static func allowsBridgeMessage(
    documentURL: URL?,
    isMainFrame: Bool,
    allowInsecureHTTP: Bool = false
  ) -> Bool {
    guard isMainFrame,
          let documentURL,
          normalizedBridgeOrigin(documentURL, allowInsecureHTTP: allowInsecureHTTP) != nil else {
      return false
    }
    return true
  }

  /// The origin supplied by WebKit's message frame must describe the document
  /// still displayed by the WebView. A navigation can commit between script
  /// scheduling and native delivery; accepting only the frame URL would let a
  /// stale first-party document race a later third-party page.
  public static func matchesCurrentDocumentOrigin(
    messageDocumentURL: URL?,
    currentDocumentURL: URL?,
    allowInsecureHTTP: Bool = false
  ) -> Bool {
    guard let messageOrigin = messageDocumentURL.flatMap({ normalizedBridgeOrigin($0, allowInsecureHTTP: allowInsecureHTTP) }),
          let currentOrigin = currentDocumentURL.flatMap({ normalizedBridgeOrigin($0, allowInsecureHTTP: allowInsecureHTTP) }) else {
      return false
    }
    return messageOrigin == currentOrigin
  }

  /// Gives every callback the stable `method`, `methodId`, `code`, `data`
  /// envelope expected by CMSJsCallBack.  In particular, failures never leak
  /// a top-level `msg`; callers always find it at `data.msg`.
  public static func callbackPayload(
    response: [String: Any],
    method: String,
    methodId: String
  ) -> [String: Any] {
    var payload = response
    payload["method"] = method
    payload["methodId"] = methodId
    if payload["code"] == nil {
      payload["code"] = "1"
    }
    let isFailure = String(describing: payload["code"] ?? "") == "0"
    if isFailure {
      // Failure details have one canonical location. Historical adapters may
      // have sent a top-level msg or a scalar data value; normalize both
      // forms rather than silently replacing a useful error with a generic
      // one.
      let topLevelMessage = payload.removeValue(forKey: "msg") as? String
      var data = payload["data"] as? [String: Any] ?? [:]
      if data["msg"] == nil {
        data["msg"] = topLevelMessage ?? "请求失败"
      }
      payload["data"] = data
    } else if payload["data"] == nil {
      payload["data"] = [:]
    }
    return payload
  }

  /// The concrete web owner serializes the payload separately (it may need to
  /// sanitize host values).  Keeping JavaScript construction here prevents
  /// the two web products from drifting in their CMSJsCallBack invocation.
  public static func callbackJavaScript(jsonPayload: String) -> String {
    "if (typeof window.CMSJsCallBack === 'function') { window.CMSJsCallBack(\(jsonPayload)); true; } else { false; }"
  }

  /// Common visible-page signal used after the first commit and after an
  /// external native flow (for example login) returns to the Web document.
  public static func pageWillAppearJavaScript() -> String {
    "if (typeof window.CMSCallJsMessage === 'function') { window.CMSCallJsMessage({method:'pageWillAppear'}); }"
  }

  /// The common online-Web header is optional. Keeping the parsing in the
  /// shared core keeps every Web display owner on the same historical
  /// string-valued configuration contract.
  public static func shouldShowNavigationBar(_ rawValue: String?) -> Bool {
    switch rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "1", "true", "yes": return true
    default: return false
    }
  }

  public static func displayTitle(_ requestedTitle: String?) -> String? {
    let title = requestedTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
    return title?.isEmpty == false ? title : nil
  }
}

/// Session-only subset of the ordinary H5 bridge, shared by the full and
/// Web-only runtimes. It contains no Mini package, route or business API.
public enum STOnlineWebSessionBridge {
  private static let maximumStorageBytes = 1_048_576

  /// Returns nil for methods that belong to the embedding host. Callers must
  /// invoke this only after the current-document/main-frame bridge check.
  public static func handle(
    method: String,
    params: [String: Any],
    bridgeContext: [String: Any],
    deviceType: String,
    darkMode: Bool,
    languageCode: String
  ) -> [String: Any]? {
    switch method {
    case "getPackageName":
      return success(["packageName": bridgeContext["packageName"] as? String ?? ""])
    case "getUserInfo":
      return success(userInfo(bridgeContext: bridgeContext, deviceType: deviceType, darkMode: darkMode, languageCode: languageCode))
    case "getToken":
      return success(userInfo(bridgeContext: bridgeContext, deviceType: deviceType, darkMode: darkMode, languageCode: languageCode)["token"] as? String ?? "")
    case "setStorage": return setStorage(params)
    case "getStorage": return getStorage(params)
    case "removeStorage": return removeStorage(params)
    default: return nil
    }
  }

  private static func userInfo(bridgeContext: [String: Any], deviceType: String, darkMode: Bool, languageCode: String) -> [String: Any] {
    var result: [String: Any] = ["device_type": deviceType, "dark_mode": darkMode ? "1" : "0", "language_code": languageCode]
    if let key = validKey(bridgeContext["authStorageKey"]), let values = UserDefaults.standard.string(forKey: key).flatMap(jsonObject) {
      result["token"] = values["token"] ?? values["access_token"]
      result["device_id"] = values["device_id"]
      result["user_id"] = values["user_id"]
    }
    if let config = bridgeContext["bridgeUserInfoStorage"] as? [String: Any],
       let storageKey = validKey(config["storageKey"]),
       let valueKey = config["valueKey"] as? String,
       let values = UserDefaults.standard.string(forKey: storageKey).flatMap(jsonObject),
       let raw = values[valueKey] {
      let selected = (raw as? String).flatMap(jsonObject) ?? raw as? [String: Any]
      let nestedKey = config["nestedKey"] as? String
      let profile = nestedKey.flatMap { selected?[$0] as? [String: Any] } ?? selected
      result.merge(profile ?? [:]) { _, hostValue in hostValue }
    }
    if let hostUserInfo = bridgeContext["userInfo"] as? [String: Any] { result.merge(hostUserInfo) { _, hostValue in hostValue } }
    return result.compactMapValues { $0 }
  }

  private static func setStorage(_ params: [String: Any]) -> [String: Any] {
    guard let key = validKey(params["key"]) else { return failure("缺少key") }
    guard let value = params["data"] as? String else { return failure("应当存储json字符串") }
    guard value.lengthOfBytes(using: .utf8) <= maximumStorageBytes else { return failure("存储内容过大") }
    guard jsonValue(value) != nil else { return failure("存储出错") }
    UserDefaults.standard.set(value, forKey: key)
    return success()
  }

  private static func getStorage(_ params: [String: Any]) -> [String: Any] {
    guard let key = validKey(params["key"]) else { return failure("缺少key") }
    guard let value = UserDefaults.standard.string(forKey: key) else { return failure("值不存在") }
    return success(jsonValue(value) ?? value)
  }

  private static func removeStorage(_ params: [String: Any]) -> [String: Any] {
    guard let key = validKey(params["key"]) else { return failure("缺少key") }
    UserDefaults.standard.removeObject(forKey: key)
    return success()
  }

  private static func validKey(_ raw: Any?) -> String? {
    guard let key = raw as? String, !key.isEmpty, key.count <= 256 else { return nil }
    return key
  }

  private static func jsonObject(_ value: String) -> [String: Any]? { jsonValue(value) as? [String: Any] }
  private static func jsonValue(_ value: String) -> Any? {
    guard let data = value.data(using: .utf8) else { return nil }
    return try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
  }
  private static func success(_ data: Any = [String: Any]()) -> [String: Any] { ["code": "1", "data": data] }
  private static func failure(_ message: String) -> [String: Any] { ["code": "0", "data": ["msg": message]] }
}

/// Shared visibility/teardown state for a Web controller. It deliberately has
/// no UIKit dependency: the owning view controller maps its appearance calls
/// onto this state and uses it to prevent delayed reloads after a page was
/// covered or released.
public final class STOnlineWebDisplayLifecycle {
  public private(set) var isVisible = false
  public private(set) var isReleased = false
  private var hasCommittedDocument = false

  public init() {}

  /// Returns true only when the current committed document becomes visible.
  public func didAppear() -> Bool {
    guard !isReleased else { return false }
    isVisible = true
    return hasCommittedDocument
  }

  public func didDisappear() {
    isVisible = false
  }

  /// Returns true only for a first visible commit. A native screen that later
  /// covers this page is handled by `didAppear` when it returns.
  public func didCommitDocument() -> Bool {
    guard !isReleased else { return false }
    let firstVisibleCommit = isVisible && !hasCommittedDocument
    hasCommittedDocument = true
    return firstVisibleCommit
  }

  public func willLoadReplacementDocument() {
    hasCommittedDocument = false
  }

  public func release() {
    isVisible = false
    isReleased = true
  }
}

/// Makes a dismissal idempotent when UIKit invokes both the page callback and
/// a programmatic dismissal completion for the same presentation.
public final class STOnlineWebPresentationCloseGate {
  private var isOpen = false

  public init() {}

  public func begin() { isOpen = true }

  /// True exactly once for each begun presentation.
  public func closeOnce() -> Bool {
    guard isOpen else { return false }
    isOpen = false
    return true
  }
}

/// Serializes a close requested while UIKit is still presenting a controller.
/// Calling `dismiss` before `present` completion is unreliable; callers wait
/// for `.dismissNow` from `didPresent()` instead.
public final class STOnlineWebPresentationCloseCoordinator {
  public enum Action: Equatable {
    case none
    case waitForPresentation
    case dismissNow
  }

  private var presentationInFlight = false
  private var closeRequested = false

  public init() {}

  public func beginPresentation() {
    presentationInFlight = true
  }

  public func requestClose() -> Action {
    if presentationInFlight {
      closeRequested = true
      return .waitForPresentation
    }
    return .dismissNow
  }

  public func didPresent() -> Action {
    presentationInFlight = false
    guard closeRequested else { return .none }
    closeRequested = false
    return .dismissNow
  }
}
