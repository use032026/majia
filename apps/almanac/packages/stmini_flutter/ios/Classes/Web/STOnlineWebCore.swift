import Foundation

/// Shared, Web-only rules used by the Flutter host and by STMini's `/web`
/// child pages.  This deliberately contains no package, Mini lifecycle or
/// host-business knowledge, so `mini_web` can consume the same contract
/// without importing the STMini runtime.
///
/// UIKit/WebKit owners supply the actual `WKWebView` and message dispatcher;
/// this file owns the security and callback data contracts that must be
/// identical for every online web container.
public enum STOnlineWebCore {
  public enum CloseAction: Equatable {
    case dismissPresentation
    case popNavigation
  }

  /// A bridge origin is HTTPS by default, with lowercase host and its
  /// effective port. Paths, queries and fragments intentionally never
  /// participate in the authority decision.
  public static func normalizedHTTPSOrigin(_ url: URL) -> String? {
    guard url.scheme?.lowercased() == "https",
          let rawHost = url.host?.trimmingCharacters(in: .whitespacesAndNewlines),
          !rawHost.isEmpty else {
      return nil
    }
    let host = rawHost.lowercased()
    let port = url.port ?? 443
    guard (1...65_535).contains(port) else { return nil }
    return port == 443 ? "https://\(host)" : "https://\(host):\(port)"
  }

  public static func normalizedBridgeOrigin(_ url: URL, allowInsecureHTTP: Bool = false) -> String? {
    guard let scheme = url.scheme?.lowercased(),
          let rawHost = url.host?.trimmingCharacters(in: .whitespacesAndNewlines),
          !rawHost.isEmpty else { return nil }
    let defaultPort: Int
    switch scheme {
    case "https": defaultPort = 443
    case "http" where allowInsecureHTTP: defaultPort = 80
    default: return nil
    }
    let port = url.port ?? defaultPort
    guard (1...65_535).contains(port) else { return nil }
    let host = rawHost.lowercased()
    return port == defaultPort ? "\(scheme)://\(host)" : "\(scheme)://\(host):\(port)"
  }

  /// Normalizes a host-provided allow-list.  Accept only full HTTPS origins:
  /// a path is not an origin and a bare hostname must not accidentally become
  /// trusted by URL's relative-URL parsing.
  public static func normalizedHTTPSOrigins(_ values: [String]) -> Set<String> {
    Set(values.compactMap { raw in
      guard let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
            url.user == nil,
            url.password == nil,
            url.path.isEmpty || url.path == "/",
            url.query == nil,
            url.fragment == nil else {
        return nil
      }
      return normalizedHTTPSOrigin(url)
    })
  }

  public static func normalizedBridgeOrigins(_ values: [String], allowInsecureHTTP: Bool) -> Set<String> {
    Set(values.compactMap { raw in
      guard let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
            url.user == nil, url.password == nil,
            url.path.isEmpty || url.path == "/", url.query == nil, url.fragment == nil else { return nil }
      return normalizedBridgeOrigin(url, allowInsecureHTTP: allowInsecureHTTP)
    })
  }

  /// WKUserContentController registers one message name for every frame.
  /// Any allowed top-level document may invoke the common Web bridge. Iframes
  /// are denied and the caller separately verifies the visible document so a
  /// stale page cannot race a later navigation.
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

  /// The common online-Web header is optional. Keeping the parsing in the
  /// shared core prevents a Web-only controller and a Mini `/web` child from
  /// disagreeing about the historical string-valued configuration contract.
  public static func shouldShowNavigationBar(_ rawValue: String?) -> Bool {
    switch rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "1", "true", "yes": return true
    default: return false
    }
  }

  public static func closeAction(isRootOfNavigationStack: Bool) -> CloseAction {
    isRootOfNavigationStack ? .dismissPresentation : .popNavigation
  }

  public static func displayTitle(_ requestedTitle: String?) -> String? {
    let title = requestedTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
    return title?.isEmpty == false ? title : nil
  }
}

/// Tracks a presentation owner without retaining a stale Flutter/UIKit
/// presenter across repeated online Web opens.  It is intentionally UIKit
/// free so it can be unit tested and reused by a Web-only package.
public final class STOnlineWebPresentationLease<Presenter: AnyObject> {
  public private(set) weak var presenter: Presenter?

  public init() {}

  public func begin(with presenter: Presenter) {
    self.presenter = presenter
  }

  public func end() {
    presenter = nil
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
    languageCode: String,
    storageScope: String? = nil
  ) -> [String: Any]? {
    switch method {
    case "getPackageName":
      return success(["packageName": bridgeContext["packageName"] as? String ?? ""])
    case "getUserInfo":
      return success(userInfo(bridgeContext: bridgeContext, deviceType: deviceType, darkMode: darkMode, languageCode: languageCode))
    case "getToken":
      return success(userInfo(bridgeContext: bridgeContext, deviceType: deviceType, darkMode: darkMode, languageCode: languageCode)["token"] as? String ?? "")
    case "setStorage": return setStorage(params, scope: storageScope)
    case "getStorage": return getStorage(params, scope: storageScope)
    case "removeStorage": return removeStorage(params, scope: storageScope)
    default: return nil
    }
  }

  private static func userInfo(bridgeContext: [String: Any], deviceType: String, darkMode: Bool, languageCode: String) -> [String: Any] {
    var result: [String: Any] = ["device_type": deviceType, "dark_mode": darkMode ? "1" : "0", "language_code": languageCode]
    if let key = validKey(bridgeContext["authStorageKey"]), let values = STMiniScopedStorage.defaults(for: "host-configured-auth")?.string(forKey: key).flatMap(jsonObject) {
      result["token"] = values["token"] ?? values["access_token"]
      result["device_id"] = values["device_id"]
      result["user_id"] = values["user_id"]
    }
    if let config = bridgeContext["bridgeUserInfoStorage"] as? [String: Any],
       let storageKey = validKey(config["storageKey"]),
       let valueKey = config["valueKey"] as? String,
       let values = STMiniScopedStorage.defaults(for: "host-configured-auth")?.string(forKey: storageKey).flatMap(jsonObject),
       let raw = values[valueKey] {
      let selected = (raw as? String).flatMap(jsonObject) ?? raw as? [String: Any]
      let nestedKey = config["nestedKey"] as? String
      let profile = nestedKey.flatMap { selected?[$0] as? [String: Any] } ?? selected
      result.merge(profile ?? [:]) { _, hostValue in hostValue }
    }
    if let hostUserInfo = bridgeContext["userInfo"] as? [String: Any] { result.merge(hostUserInfo) { _, hostValue in hostValue } }
    return result.compactMapValues { $0 }
  }

  private static func setStorage(_ params: [String: Any], scope: String?) -> [String: Any] {
    guard let scope, let defaults = STMiniScopedStorage.defaults(for: scope) else { return failure("当前文档没有存储主体") }
    guard let key = validKey(params["key"]) else { return failure("缺少key") }
    guard let value = params["data"] as? String else { return failure("应当存储json字符串") }
    guard value.lengthOfBytes(using: .utf8) <= maximumStorageBytes else { return failure("存储内容过大") }
    guard jsonValue(value) != nil else { return failure("存储出错") }
    defaults.set(value, forKey: key)
    return success()
  }

  private static func getStorage(_ params: [String: Any], scope: String?) -> [String: Any] {
    guard let scope, let defaults = STMiniScopedStorage.defaults(for: scope) else { return failure("当前文档没有存储主体") }
    guard let key = validKey(params["key"]) else { return failure("缺少key") }
    guard let value = defaults.string(forKey: key) else { return failure("值不存在") }
    return success(jsonValue(value) ?? value)
  }

  private static func removeStorage(_ params: [String: Any], scope: String?) -> [String: Any] {
    guard let scope, let defaults = STMiniScopedStorage.defaults(for: scope) else { return failure("当前文档没有存储主体") }
    guard let key = validKey(params["key"]) else { return failure("缺少key") }
    defaults.removeObject(forKey: key)
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

  public init() {}

  public func didAppear() {
    guard !isReleased else { return }
    isVisible = true
  }

  public func didDisappear() {
    isVisible = false
  }

  public func release() {
    isVisible = false
    isReleased = true
  }
}

/// Serializes presentation replacement without retaining any UIKit object.
/// When callers rapidly request A → B → C, A may finish its presentation, but
/// only C is then presented after A has completely dismissed. This keeps the
/// next presenter lookup outside the dying controller hierarchy.
public final class STOnlineWebPresentationQueue<Request> {
  public enum Step {
    case present(Request)
    case dismissCurrent
    case waiting
  }

  private var hasActivePresentation = false
  private var isTransitioning = false
  private var pendingRequest: Request?

  public init() {}

  /// Returns any queued request superseded by a newer one, so the owner can
  /// resolve its callback rather than leaving a MethodChannel call pending.
  public func enqueue(_ request: Request, hasExistingPresentation: Bool) -> (step: Step, superseded: Request?) {
    if isTransitioning {
      let superseded = pendingRequest
      pendingRequest = request
      return (.waiting, superseded)
    }
    // UIKit may have dismissed an Online Web page through its own back UI.
    // Reconcile that external close before deciding whether to dismiss again.
    if hasActivePresentation && !hasExistingPresentation {
      hasActivePresentation = false
    }
    if hasActivePresentation || hasExistingPresentation {
      hasActivePresentation = true
      isTransitioning = true
      pendingRequest = request
      return (.dismissCurrent, nil)
    }
    isTransitioning = true
    return (.present(request), nil)
  }

  public func didPresent() -> Step? {
    hasActivePresentation = true
    isTransitioning = false
    guard pendingRequest != nil else { return nil }
    isTransitioning = true
    return .dismissCurrent
  }

  public func didDismiss() -> Step? {
    hasActivePresentation = false
    isTransitioning = false
    guard let request = pendingRequest else { return nil }
    pendingRequest = nil
    isTransitioning = true
    return .present(request)
  }

  public func didFailToPresent() -> Step? {
    hasActivePresentation = false
    isTransitioning = false
    guard let request = pendingRequest else { return nil }
    pendingRequest = nil
    isTransitioning = true
    return .present(request)
  }

  public func reset() {
    hasActivePresentation = false
    isTransitioning = false
    pendingRequest = nil
  }
}
