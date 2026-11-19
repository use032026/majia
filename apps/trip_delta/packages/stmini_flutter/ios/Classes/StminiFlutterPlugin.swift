import Flutter
import UIKit

/// Flutter adapter for ordinary online Web documents only.
public final class StminiFlutterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var methodChannel: FlutterMethodChannel?
  /// One ordinary-Web navigation stack is retained for the life of a Web
  /// session. The root is presented once; subsequent `/web` requests push
  /// inside this stack, matching the full STMini H5 navigation contract.
  private var activeNavigationController: UINavigationController?
  private let presentationCloseGate = STOnlineWebPresentationCloseGate()
  private let closeCoordinator = STOnlineWebPresentationCloseCoordinator()
  private var allowInsecureHttpNavigation = false
  private var bridgeContext: [String: Any] = [:]
  private var isPresentingNavigation = false
  private var pendingPushRequests: [OnlineWebRequest] = []
  private var pendingCloseResults: [FlutterResult] = []
  private var appHideObserver: NSObjectProtocol?
  private var appShowObserver: NSObjectProtocol?
  private var backgroundStartedAt: Date?

  override init() {
    super.init()
    let notifications = NotificationCenter.default
    appHideObserver = notifications.addObserver(
      forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in
      self?.backgroundStartedAt = Date()
      self?.deliverHostLifecycle(method: "appHide")
    }
    appShowObserver = notifications.addObserver(
      forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in
      guard let self else { return }
      let duration = self.backgroundStartedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0
      self.backgroundStartedAt = nil
      self.deliverHostLifecycle(method: "appShow", params: ["backgroundDurationMs": duration])
    }
  }

  deinit {
    let notifications = NotificationCenter.default
    if let appHideObserver { notifications.removeObserver(appHideObserver) }
    if let appShowObserver { notifications.removeObserver(appShowObserver) }
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = StminiFlutterPlugin()
    let methods = FlutterMethodChannel(
      name: "stmini_flutter/methods", binaryMessenger: registrar.messenger())
    let events = FlutterEventChannel(
      name: "stmini_flutter/events", binaryMessenger: registrar.messenger())
    instance.methodChannel = methods
    registrar.addMethodCallDelegate(instance, channel: methods)
    events.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      let arguments = call.arguments as? [String: Any] ?? [:]
      configureBridgeOrigins(arguments["bridgeContext"] as? [String: Any])
      result(nil)
    case "openWeb":
      openWeb(call.arguments as? [String: Any] ?? [:], result: result)
    case "closeWeb":
      closeWeb(result: result)
    case "notifyWebSessionChanged":
      notifyWebSessionChanged(call.arguments as? [String: Any] ?? [:], result: result)
    case "isAvailable":
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func configureBridgeOrigins(_ context: [String: Any]?) {
    bridgeContext = context ?? [:]
    let security = bridgeContext["webSecurity"] as? [String: Any]
    allowInsecureHttpNavigation = security?["allowInsecureHTTP"] as? Bool ?? false
  }

  private func deliverHostLifecycle(method: String, params: [String: Any] = [:]) {
    let pages = activeNavigationController?.viewControllers
      .compactMap { $0 as? OnlineWebPageViewController }
      ?? []
    if method == "appShow" {
      // All retained pages must persist when backgrounding, but only the
      // visible page may recover when foregrounding.  Covered pages receive
      // pageWillAppear when they are popped back to the foreground.
      (activeNavigationController?.visibleViewController as? OnlineWebPageViewController)?
        .deliverHostLifecycle(method: method, params: params)
      return
    }
    pages.forEach { $0.deliverHostLifecycle(method: method, params: params) }
  }

  private func openWeb(_ arguments: [String: Any], result: @escaping FlutterResult) {
    guard let raw = arguments["url"] as? String,
          let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
          let host = url.host, !host.isEmpty,
          isPermittedURL(url, allowInsecureHttpNavigation: allowInsecureHttpNavigation) else {
      result(FlutterError(code: "invalid_web_url", message: "url must be an absolute HTTPS URL", details: nil))
      return
    }
    let request = OnlineWebRequest(
      url: url,
      title: arguments["title"] as? String,
      showNavigationBar: arguments["showNavigationBar"] as? Bool ?? true,
      allowInsecureHttpNavigation: allowInsecureHttpNavigation,
      result: result)
    emit("web_open_requested", ["url": redacted(url)])
    DispatchQueue.main.async { [weak self] in self?.openOrPush(request) }
  }

  private func openOrPush(_ request: OnlineWebRequest) {
    guard let navigation = activeNavigationController,
          navigation.presentingViewController != nil,
          !navigation.isBeingDismissed else {
      activeNavigationController = nil
      presentRootWeb(request)
      return
    }
    guard !isPresentingNavigation else {
      enqueuePendingPush(request)
      return
    }
    pushWeb(request, onto: navigation)
  }

  /// UIKit 在根导航控制器正在 present 时不能继续 push。完整保留请求，待
  /// present 完成后依次处理；URL 相同也不能丢弃任一 `/web` 跳转。
  private func enqueuePendingPush(_ request: OnlineWebRequest) {
    pendingPushRequests.append(request)
  }

  private func takePendingPushRequests() -> [OnlineWebRequest] {
    let requests = pendingPushRequests
    pendingPushRequests.removeAll()
    return requests
  }

  private func resolvePendingPushRequests() {
    takePendingPushRequests().forEach { $0.result(nil) }
  }

  private func presentRootWeb(_ request: OnlineWebRequest) {
    guard let presenter = currentPresenter() else {
      request.result(FlutterError(code: "no_presenting_controller", message: "No active Flutter view controller", details: nil))
      return
    }
    let page = makeWebPage(request)
    let navigation = OnlineWebNavigationController(rootViewController: page)
    navigation.modalPresentationStyle = .fullScreen
    navigation.isNavigationBarHidden = !request.showNavigationBar
    activeNavigationController = navigation
    isPresentingNavigation = true
    presentationCloseGate.begin()
    closeCoordinator.beginPresentation()
    presenter.present(navigation, animated: true) { [weak self] in
      guard let self else { return }
      self.isPresentingNavigation = false
      self.emit("web_opened", ["url": self.redacted(request.url)])
      request.result(nil)
      if self.closeCoordinator.didPresent() == .dismissNow {
        self.dismissActiveWeb(completions: self.takePendingCloseResults())
        return
      }
      self.takePendingPushRequests().forEach {
        self.pushWeb($0, onto: navigation, animated: false)
      }
    }
  }

  private func pushWeb(
    _ request: OnlineWebRequest,
    onto navigation: UINavigationController,
    animated: Bool = true
  ) {
    navigation.setNavigationBarHidden(!request.showNavigationBar, animated: animated)
    navigation.pushViewController(makeWebPage(request), animated: animated)
    reportNavigation("push", navigation: navigation, url: request.url)
    emit("web_opened", ["url": redacted(request.url)])
    request.result(nil)
  }

  private func makeWebPage(_ request: OnlineWebRequest) -> OnlineWebPageViewController {
    OnlineWebPageViewController(
      url: request.url,
      title: request.title,
      showNavigationBar: request.showNavigationBar,
      allowInsecureHttpNavigation: request.allowInsecureHttpNavigation,
      bridgeRequest: { [weak self] method, params, origin, reply in
        self?.forwardBridgeRequest(method: method, params: params, origin: origin, reply: reply)
      },
      didClose: { [weak self] in self?.webDidClose() })
  }

  private func closeWeb(result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self, self.activeNavigationController != nil else {
        self?.resolvePendingPushRequests()
        result(nil)
        return
      }
      if let navigation = self.activeNavigationController,
         navigation.viewControllers.count > 1,
         !self.isPresentingNavigation {
        self.resolvePendingPushRequests()
        self.reportNavigation("bridge_pop", navigation: navigation, url: (navigation.topViewController as? OnlineWebPageViewController)?.currentURL)
        navigation.popViewController(animated: true)
        result(nil)
        return
      }
      self.resolvePendingPushRequests()
      switch self.closeCoordinator.requestClose() {
      case .waitForPresentation:
        self.pendingCloseResults.append(result)
      case .dismissNow:
        self.dismissActiveWeb(completions: [result])
      case .none:
        result(nil)
      }
    }
  }

  /// Mirrors Mini's sibling-Web session notification for a Web-only stack.
  /// The top page is the login/route child that initiated the notification;
  /// earlier pages (including the originating `/web`) receive the update
  /// before the child pops back to them.
  private func notifyWebSessionChanged(_ arguments: [String: Any], result: @escaping FlutterResult) {
    let rawReason = arguments["reason"] as? String ?? "sessionChanged"
    let reason = String(rawReason.prefix(64))
    DispatchQueue.main.async { [weak self] in
      guard let navigation = self?.activeNavigationController else {
        result(0)
        return
      }
      let source = navigation.topViewController
      let targets = navigation.viewControllers.compactMap { $0 as? OnlineWebPageViewController }
        .filter { $0 !== source }
      targets.forEach { $0.deliverSessionChanged(reason: reason) }
      #if DEBUG
      print("[STMini][web_session_changed] reason=\(reason) notified=\(targets.count)")
      #endif
      result(targets.count)
    }
  }

  private func dismissActiveWeb(completions: [FlutterResult]) {
    guard let active = activeNavigationController else {
      webDidClose()
      completions.forEach { $0(nil) }
      return
    }
    active.dismiss(animated: true) { [weak self] in
      self?.webDidClose()
      completions.forEach { $0(nil) }
    }
  }

  private func takePendingCloseResults() -> [FlutterResult] {
    let results = pendingCloseResults
    pendingCloseResults.removeAll()
    return results
  }

  private func webDidClose() {
    guard presentationCloseGate.closeOnce() else { return }
    activeNavigationController = nil
    isPresentingNavigation = false
    resolvePendingPushRequests()
    emit("web_closed", [:])
  }

  private func forwardBridgeRequest(
    method: String,
    params: [String: Any],
    origin: String,
    reply: @escaping ([String: Any]) -> Void
  ) {
    if let response = STOnlineWebSessionBridge.handle(
      method: method,
      params: params,
      bridgeContext: bridgeContext,
      deviceType: "ios",
      darkMode: currentPresenter()?.traitCollection.userInterfaceStyle == .dark,
      languageCode: onlineLanguageCode()) {
      #if DEBUG
      if method == "getUserInfo" || method == "getToken" {
        let data = response["data"] as? [String: Any] ?? [:]
        let token = (data["token"] as? String) ?? (response["data"] as? String) ?? ""
        let userID = data["user_id"] ?? data["id"]
        let userIdPresent = userID.map { !String(describing: $0).isEmpty } ?? false
        print("[STMini][web_session_bridge] method=\(method) tokenPresent=\(!token.isEmpty) userIdPresent=\(userIdPresent)")
      }
      #endif
      reply(response)
      return
    }
    guard let channel = methodChannel else {
      reply(failure("宿主未处理该网页请求"))
      return
    }
    channel.invokeMethod("webBridgeRequest", arguments: [
      "method": method,
      "params": params,
      "origin": origin,
    ]) { value in
      reply(self.normalizedBridgeResponse(value))
    }
  }

  private func normalizedBridgeResponse(_ value: Any?) -> [String: Any] {
    guard let response = value as? [String: Any] else { return failure("宿主未处理该网页请求") }
    let failed = String(describing: response["code"] ?? "1") == "0"
    if failed {
      let data = response["data"] as? [String: Any]
      return ["code": "0", "data": data ?? ["msg": "宿主处理网页请求失败"]]
    }
    return ["code": "1", "data": response["data"] ?? [:]]
  }

  private func failure(_ message: String) -> [String: Any] {
    ["code": "0", "data": ["msg": message]]
  }

  private func onlineLanguageCode() -> String {
    let language = (Locale.preferredLanguages.first ?? "en").lowercased()
    if language.hasPrefix("zh-hant") || language.hasPrefix("zh-tw") || language.hasPrefix("zh-hk") {
      return "zh-Hant"
    }
    if language.hasPrefix("zh") { return "zh-Hans" }
    return language.hasPrefix("en") ? "en-US" : language
  }

  private func currentPresenter() -> UIViewController? {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
    var controller = windows.first(where: \.isKeyWindow)?.rootViewController
      ?? windows.first?.rootViewController
    while let presented = controller?.presentedViewController, !presented.isBeingDismissed {
      controller = presented
    }
    return controller
  }

  private func isPermittedURL(_ url: URL, allowInsecureHttpNavigation: Bool) -> Bool {
    let scheme = url.scheme?.lowercased()
    return scheme == "https" || (allowInsecureHttpNavigation && scheme == "http")
  }

  private func redacted(_ url: URL) -> String {
    guard let scheme = url.scheme, let host = url.host else { return "" }
    return "\(scheme)://\(host)\(url.path)"
  }

  private func emit(_ name: String, _ payload: [String: Any]) {
    eventSink?(["name": name, "payload": payload])
  }

  private func reportNavigation(_ event: String, navigation: UINavigationController, url: URL?) {
    #if DEBUG
    let location = url.map { redacted($0) } ?? ""
    print("[STMini][web_navigation] event=\(event) stackDepth=\(navigation.viewControllers.count) url=\(location)")
    #endif
  }
}

private struct OnlineWebRequest {
  let url: URL
  let title: String?
  let showNavigationBar: Bool
  let allowInsecureHttpNavigation: Bool
  let result: FlutterResult
}
