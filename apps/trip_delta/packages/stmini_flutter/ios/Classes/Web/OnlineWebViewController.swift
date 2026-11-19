import Foundation
@preconcurrency import WebKit
import UIKit

/// WebKit retains registered script handlers. This proxy deliberately retains
/// the page weakly so `WKUserContentController` cannot keep a dismissed Web
/// presentation alive.
final class OnlineWebWeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
  weak var target: WKScriptMessageHandler?

  init(target: WKScriptMessageHandler) {
    self.target = target
  }

  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    target?.userContentController(userContentController, didReceive: message)
  }
}

/// The Web-only stack uses the same left-edge pop contract as STMini. Keep
/// WebKit's own history swipe disabled: otherwise its recognizer can consume
/// the gesture and leave a pushed native page visibly stuck in place.
final class OnlineWebNavigationController: UINavigationController, UIGestureRecognizerDelegate {
  override func viewDidLoad() {
    super.viewDidLoad()
    interactivePopGestureRecognizer?.delegate = self
    interactivePopGestureRecognizer?.isEnabled = true
  }

  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    viewControllers.count > 1
  }
}

/// Shared owner for an online `WKWebView` document.
///
/// It deliberately does not know about packages, local resources, keep-alive,
/// or local-runtime APIs. The embedding adapter supplies only a narrow
/// message callback around its WebKit view.
public final class OnlineWebViewController {
  public typealias MessageHandler = (Any) -> Void

  public weak var webView: WKWebView?
  public var onMessage: MessageHandler?
  public var onTitleChanged: ((String) -> Void)?
  public let lifecycle = STOnlineWebDisplayLifecycle()
  private let allowInsecureHttpBridge: Bool

  public init(
    webView: WKWebView,
    allowInsecureHttpBridge: Bool,
    onMessage: MessageHandler? = nil
  ) {
    self.webView = webView
    self.allowInsecureHttpBridge = allowInsecureHttpBridge
    self.onMessage = onMessage
  }

  /// The complete WebKit boundary: main frame and the frame URL still
  /// matching the currently displayed allowed document.
  public func receiveScriptMessage(
    body: Any,
    documentURL: URL?,
    isMainFrame: Bool
  ) -> Bool {
    guard let webView,
          STOnlineWebCore.allowsBridgeMessage(
            documentURL: documentURL,
            isMainFrame: isMainFrame,
            allowInsecureHTTP: allowInsecureHttpBridge
          ),
          STOnlineWebCore.matchesCurrentDocumentOrigin(
            messageDocumentURL: documentURL,
            currentDocumentURL: webView.url,
            allowInsecureHTTP: allowInsecureHttpBridge
          ) else {
      return false
    }
    onMessage?(body)
    return true
  }

  @discardableResult
  public func didCommitPage() -> Bool {
    guard let webView else { return false }
    webView.evaluateJavaScript("document.title") { [weak self] result, error in
      guard error == nil, let title = result as? String,
            let displayTitle = STOnlineWebCore.displayTitle(title) else { return }
      self?.onTitleChanged?(displayTitle)
    }
    return lifecycle.didCommitDocument()
  }

  public func didAppear() -> Bool { lifecycle.didAppear() }
  public func didDisappear() { lifecycle.didDisappear() }
  public func willLoadReplacementDocument() { lifecycle.willLoadReplacementDocument() }
  public func release() { lifecycle.release() }
}

/// UIKit presentation shell for [OnlineWebViewController]. It owns only the
/// ordinary `WKWebView` view hierarchy; origin gating and callback formatting
/// remain in the shared Web owner/Core above.
final class OnlineWebPageViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
  typealias BridgeRequest = (_ method: String, _ params: [String: Any], _ origin: String, _ reply: @escaping ([String: Any]) -> Void) -> Void

  private static let bridgeHandlerName = "CMSScriptMessageChannel"
  private static let debugLogHandlerName = "STMiniDebugLog"

  private let initialURL: URL
  private let allowInsecureHttpNavigation: Bool
  private let showNavigationBar: Bool
  private let bridgeRequest: BridgeRequest
  private let didClose: () -> Void
  private let userContentController = WKUserContentController()
  private lazy var messageHandlerProxy = OnlineWebWeakScriptMessageHandler(target: self)
  private var webView: WKWebView!
  private var owner: OnlineWebViewController!
  private var releasedWebResources = false
  private var didNotifyClose = false
  private let createdAt = ProcessInfo.processInfo.systemUptime
  private var navigationStartedAt: TimeInterval?

  var currentURL: URL? { webView?.url ?? initialURL }

  init(
    url: URL,
    title: String?,
    showNavigationBar: Bool,
    allowInsecureHttpNavigation: Bool,
    bridgeRequest: @escaping BridgeRequest,
    didClose: @escaping () -> Void
  ) {
    initialURL = url
    self.allowInsecureHttpNavigation = allowInsecureHttpNavigation
    self.showNavigationBar = showNavigationBar
    self.bridgeRequest = bridgeRequest
    self.didClose = didClose
    super.init(nibName: nil, bundle: nil)
    if showNavigationBar { navigationItem.title = title }
  }

  required init?(coder: NSCoder) { nil }

  override func loadView() {
    let config = WKWebViewConfiguration()
    config.userContentController = userContentController
    #if DEBUG
    // Local online-H5 debugging has no trusted HTTP bridge. Inject a
    // one-way, debug-only timing sink instead of relaxing bridge authority.
    userContentController.addUserScript(WKUserScript(
      source: """
      window.__STMiniDebugLog__ = function (message) {
        try {
          window.webkit.messageHandlers.STMiniDebugLog.postMessage(String(message).slice(0, 1200));
        } catch (_) {}
      };
      """,
      injectionTime: .atDocumentStart,
      forMainFrameOnly: true))
    #endif
    webView = WKWebView(frame: .zero, configuration: config)
    #if DEBUG
    if #available(iOS 16.4, *) {
      webView.isInspectable = true
    }
    #endif
    // New `/web` and route-child pages are native navigation levels. Reserve
    // the screen-edge gesture for UINavigationController pop, matching Mini.
    webView.allowsBackForwardNavigationGestures = false
    webView.navigationDelegate = self
    owner = OnlineWebViewController(
      webView: webView,
      allowInsecureHttpBridge: allowInsecureHttpNavigation,
      onMessage: { [weak self] body in self?.receivedBridgeMessage(body) })
    owner.onTitleChanged = { [weak self] title in
      self?.navigationItem.title = title
    }
    view = webView
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    userContentController.add(messageHandlerProxy, name: Self.bridgeHandlerName)
    #if DEBUG
    userContentController.add(messageHandlerProxy, name: Self.debugLogHandlerName)
    #endif
    reportTiming("navigation.load_requested", url: initialURL)
    webView.load(URLRequest(url: initialURL))
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    let isRoot = navigationController?.viewControllers.first === self
    navigationController?.setNavigationBarHidden(!showNavigationBar, animated: animated)
    applyMiniNavigationAppearance()
    if !isRoot { navigationController?.interactivePopGestureRecognizer?.isEnabled = true }
    if isRoot && showNavigationBar {
      navigationItem.leftBarButtonItem = UIBarButtonItem(
        barButtonSystemItem: .close,
        target: self,
        action: #selector(goBackOrClose))
    } else if !isRoot && showNavigationBar {
      // Keep the visible affordance and action on the same controller. This
      // mirrors main's explicit H5 back handler and makes a `/web` return
      // independent of UINavigationController's implicit button wiring.
      navigationItem.leftBarButtonItem = UIBarButtonItem(
        image: UIImage(systemName: "chevron.left"),
        style: .plain,
        target: self,
        action: #selector(goBackOrClose))
      navigationItem.leftBarButtonItem?.accessibilityLabel = "Back"
    } else {
      navigationItem.leftBarButtonItem = nil
    }
    reportStack("appeared")
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if owner.didAppear() { sendPageWillAppear() }
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    deliverHostLifecycle(method: "pageWillDisappear")
    owner.didDisappear()
    let navigationIsDismissing = navigationController?.isBeingDismissed == true
    let leavingStack = isBeingDismissed || isMovingFromParent || navigationIsDismissing
    if leavingStack {
      releaseWebResources()
    }
    if (isBeingDismissed || navigationIsDismissing) &&
        (navigationController?.viewControllers.first === self || navigationController == nil) {
      notifyClosed()
    }
    if leavingStack { reportStack("left_stack") }
  }

  deinit {
    releaseWebResources()
  }

  /// Dismissal normally calls this before UIKit releases the controller.
  /// `deinit` repeats it defensively for an interrupted presentation.
  private func releaseWebResources() {
    guard !releasedWebResources else { return }
    releasedWebResources = true
    userContentController.removeScriptMessageHandler(forName: Self.bridgeHandlerName)
    #if DEBUG
    userContentController.removeScriptMessageHandler(forName: Self.debugLogHandlerName)
    #endif
    webView?.navigationDelegate = nil
    owner?.release()
  }

  @objc private func goBackOrClose() {
    guard let navigation = navigationController else {
      reportTiming("navigation.close_tapped", url: webView.url)
      dismiss(animated: true)
      return
    }
    if navigation.viewControllers.first === self {
      reportTiming("navigation.close_tapped", url: webView.url)
      reportStack("close_tapped")
      navigation.dismiss(animated: true)
    } else {
      reportTiming("navigation.back_tapped", url: webView.url)
      reportStack("back_tapped")
      navigation.popViewController(animated: true)
    }
  }

  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    // A subframe is allowed to render/navigate normally. Bridge authority is
    // separately denied by OnlineWebViewController's `isMainFrame` gate.
    if navigationAction.targetFrame?.isMainFrame == false {
      decisionHandler(.allow)
      return
    }
    guard let url = navigationAction.request.url else {
      decisionHandler(.cancel)
      return
    }
    if url.scheme?.lowercased() == "https" {
      decisionHandler(.allow)
      return
    }
    if allowInsecureHttpNavigation, url.scheme?.lowercased() == "http", url.host != nil {
      decisionHandler(.allow)
      return
    }
    decisionHandler(.cancel)
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    reportTiming("navigation.finished", url: webView.url)
    if owner.didCommitPage() { sendPageWillAppear() }
  }

  func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    navigationStartedAt = ProcessInfo.processInfo.systemUptime
    reportTiming("navigation.started", url: webView.url)
  }

  func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    reportTiming("navigation.committed", url: webView.url)
  }

  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    reportTiming("navigation.provisional_failed", url: webView.url, error: error)
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    reportTiming("navigation.failed", url: webView.url, error: error)
  }

  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    #if DEBUG
    if message.name == Self.debugLogHandlerName {
      guard message.frameInfo.isMainFrame, let text = message.body as? String else { return }
      print("[STMini][web_debug] \(text)")
      return
    }
    #endif
    guard message.name == Self.bridgeHandlerName else { return }
    _ = owner.receiveScriptMessage(
      body: message.body,
      documentURL: message.frameInfo.request.url,
      isMainFrame: message.frameInfo.isMainFrame)
  }

  private func receivedBridgeMessage(_ body: Any) {
    guard let request = body as? [String: Any],
          let method = request["method"] as? String,
          !method.isEmpty else { return }
    let params = request["params"] as? [String: Any] ?? [:]
    if method == "setNavigationBarTitle" {
      navigationItem.title = params["title"] as? String
      deliverBridgeResponse(
        ["code": "1", "data": [:]],
        method: method,
        methodId: params["methodId"] as? String ?? "")
      return
    }
    guard let origin = currentBridgeOrigin() else { return }
    bridgeRequest(method, params, origin) { [weak self] response in
      self?.deliverBridgeResponse(response, method: method, methodId: params["methodId"] as? String ?? "")
    }
  }

  private func currentBridgeOrigin() -> String? {
    webView.url.flatMap {
      STOnlineWebCore.normalizedBridgeOrigin(
        $0, allowInsecureHTTP: allowInsecureHttpNavigation)
    }
  }

  private func applyMiniNavigationAppearance() {
    guard showNavigationBar, let navigation = navigationController else { return }
    let appearance = UINavigationBarAppearance()
    appearance.configureWithOpaqueBackground()
    appearance.backgroundColor = .white
    appearance.shadowColor = .clear
    appearance.titleTextAttributes = [
      .foregroundColor: UIColor.black,
      .font: UIFont.boldSystemFont(ofSize: 16),
    ]
    navigation.navigationBar.standardAppearance = appearance
    navigation.navigationBar.scrollEdgeAppearance = appearance
    navigation.navigationBar.compactAppearance = appearance
    navigation.navigationBar.tintColor = .black
  }

  private func reportTiming(_ event: String, url: URL?, error: Error? = nil) {
    #if DEBUG
    let now = ProcessInfo.processInfo.systemUptime
    let controllerElapsedMs = Int((now - createdAt) * 1000)
    let navigationElapsedMs = navigationStartedAt.map { Int((now - $0) * 1000) }
    var fields = [
      "event=\(event)",
      "controllerElapsedMs=\(controllerElapsedMs)",
    ]
    if let navigationElapsedMs { fields.append("navigationElapsedMs=\(navigationElapsedMs)") }
    if let url,
       let scheme = url.scheme,
       let host = url.host {
      fields.append("url=\(scheme)://\(host)\(url.path)")
    }
    if let error = error as NSError? {
      fields.append("errorDomain=\(error.domain)")
      fields.append("errorCode=\(error.code)")
    }
    print("[STMini][web_timing] \(fields.joined(separator: " "))")
    #endif
  }

  private func reportStack(_ event: String) {
    #if DEBUG
    let stackDepth = navigationController?.viewControllers.count ?? 0
    let isRoot = navigationController?.viewControllers.first === self
    print("[STMini][web_navigation] event=\(event) stackDepth=\(stackDepth) isRoot=\(isRoot)")
    #endif
  }

  private func deliverBridgeResponse(_ response: [String: Any], method: String, methodId: String) {
    let payload = STOnlineWebCore.callbackPayload(response: response, method: method, methodId: methodId)
    guard JSONSerialization.isValidJSONObject(payload),
          let data = try? JSONSerialization.data(withJSONObject: payload),
          let json = String(data: data, encoding: .utf8) else { return }
    webView.evaluateJavaScript(STOnlineWebCore.callbackJavaScript(jsonPayload: json.replacingOccurrences(of: "</", with: "<\\/")))
  }

  private func sendPageWillAppear() {
    deliverHostLifecycle(method: "pageWillAppear")
  }

  /// Lifecycle payloads are credential-free and shared by Mini and ordinary
  /// `/web` pages. The H5 bridge queues messages received before a listener
  /// is registered and also has an initial activation fallback.
  func deliverHostLifecycle(method: String, params: [String: Any] = [:]) {
    guard !releasedWebResources else { return }
    var payload: [String: Any] = ["method": method]
    if !params.isEmpty { payload["params"] = params }
    guard JSONSerialization.isValidJSONObject(payload),
          let data = try? JSONSerialization.data(withJSONObject: payload),
          let json = String(data: data, encoding: .utf8) else { return }
    let safeJSON = json.replacingOccurrences(of: "</", with: "<\\/")
    webView.evaluateJavaScript(
      "if (typeof window.CMSCallJsMessage === 'function') { window.CMSCallJsMessage(\(safeJSON)); true; } else { false; }")
  }

  /// Delivers the same credential-free refresh contract used by Mini's
  /// independent `/web` pages. Native storage is read through getUserInfo;
  /// the event itself contains only the reason and never session material.
  func deliverSessionChanged(reason: String) {
    guard !releasedWebResources else { return }
    let messages: [[String: Any]] = [
      ["method": "miniSessionChanged", "params": ["reason": reason]],
      ["method": "updateUserInfo"],
    ]
    guard JSONSerialization.isValidJSONObject(messages),
          let data = try? JSONSerialization.data(withJSONObject: messages),
          let json = String(data: data, encoding: .utf8) else { return }
    let safeJSON = json.replacingOccurrences(of: "</", with: "<\\/")
    webView.evaluateJavaScript(
      "(() => { if (typeof window.CMSCallJsMessage !== 'function') return false; \(safeJSON).forEach((message) => window.CMSCallJsMessage(message)); return true; })();")
  }

  private func notifyClosed() {
    guard !didNotifyClose else { return }
    didNotifyClose = true
    didClose()
  }
}
