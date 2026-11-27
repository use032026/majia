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
  private var replyEpoch: UInt64 = 0
  private var released = false
  public func invalidateReplies() { replyEpoch &+= 1 }

  /// Captures native ownership and a per-JavaScript-global document marker.
  public func captureReply(isOwnerCurrent: @escaping () -> Bool, completed: @escaping (@escaping (String) -> Void) -> Void) {
    guard let webView, !released else { return }
    let epoch = replyEpoch
    let url = webView.url
    let candidate = UUID().uuidString
    let key = "__stminiReplyDocument"
    webView.evaluateJavaScript("window.\(key)||(window.\(key)='\(candidate)')") { [weak self, weak webView] value, error in
      guard let self, let webView, error == nil, let token = value as? String,
            self.replyEpoch == epoch, !self.released, self.webView === webView,
            webView.url == url, isOwnerCurrent() else { return }
      completed { [weak self, weak webView] payload in
        DispatchQueue.main.async {
          guard let self, let webView, self.replyEpoch == epoch, !self.released,
                self.webView === webView, webView.url == url, isOwnerCurrent(),
                let data = try? JSONSerialization.data(withJSONObject: [token]),
                let array = String(data: data, encoding: .utf8) else { return }
          webView.evaluateJavaScript("if(window.\(key)===(\(array))[0]){\(STOnlineWebCore.callbackJavaScript(jsonPayload: payload))}", completionHandler: nil)
        }
      }
    }
  }

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
  public func willLoadReplacementDocument() { invalidateReplies(); lifecycle.willLoadReplacementDocument() }
  public func release() { released = true; invalidateReplies(); lifecycle.release() }
}

/// UIKit presentation shell for [OnlineWebViewController]. It owns only the
/// ordinary `WKWebView` view hierarchy; origin gating and callback formatting
/// remain in the shared Web owner/Core above.
final class OnlineWebPageViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
  typealias BridgeRequest = (_ method: String, _ params: [String: Any], _ origin: String, _ documentURL: URL, _ reply: @escaping ([String: Any]) -> Void) -> Void

  private static let bridgeHandlerName = "CMSScriptMessageChannel"
  private static let debugLogHandlerName = "STMiniDebugLog"

  private let initialURL: URL
  private let allowInsecureHttpNavigation: Bool
  private let showNavigationBar: Bool
  private let bridgeRequest: BridgeRequest
  private let captureBridgeOwnership: () -> (() -> Bool)
  private let didClose: () -> Void
  private let userContentController = WKUserContentController()
  private lazy var messageHandlerProxy = OnlineWebWeakScriptMessageHandler(target: self)
  private var webView: WKWebView!
  private var owner: OnlineWebViewController!
  private let loading: STOnlineWebLoadingController
  private let showsLaunchScreen: Bool
  private var initialPageNavigation: WKNavigation?
  private var loadingNavigation: WKNavigation?
  private var pendingTopLevelRequest: URLRequest?
  private var pendingLinkGETURL: URL?
  private var provisionalLinkGETURL: URL?
  private var lastTopLevelRequest: URLRequest?
  private var lastDocumentURL: URL?
  private var processRecovery: STOnlineWebProcessRecovery = .idle
  private weak var knownGETNavigation: WKNavigation?
  private var didCommitKnownGET = false
  private var hasUncommittedNavigation = false
  private var canRecoverInHistory = false
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
    showsLaunchScreen: Bool,
    loadingConfiguration: [String: Any]? = nil,
    captureBridgeOwnership: @escaping () -> (() -> Bool) = { { true } },
    bridgeRequest: @escaping BridgeRequest,
    didClose: @escaping () -> Void
  ) {
    initialURL = url
    self.allowInsecureHttpNavigation = allowInsecureHttpNavigation
    self.showNavigationBar = showNavigationBar
    self.showsLaunchScreen = showsLaunchScreen
    self.bridgeRequest = bridgeRequest
    self.captureBridgeOwnership = captureBridgeOwnership
    self.didClose = didClose
    loading = STOnlineWebLoadingController(configuration: loadingConfiguration,
      readyOrigin: STOnlineWebCore.normalizedBridgeOrigin(url, allowInsecureHTTP: allowInsecureHttpNavigation))
    super.init(nibName: nil, bundle: nil)
    if showNavigationBar { navigationItem.title = title }
  }

  required init?(coder: NSCoder) { nil }

  override func loadView() {
    let config = WKWebViewConfiguration()
    config.userContentController = userContentController
    userContentController.addUserScript(loading.script)
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
    let container = UIView()
    webView.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(webView)
    NSLayoutConstraint.activate([
      webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      webView.topAnchor.constraint(equalTo: container.topAnchor),
      webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
    loading.attach(to: container, webView: webView, parent: self, showsLaunchScreen: showsLaunchScreen)
    loading.retry = { [weak self] in self?.retryPage() }
    view = container
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    userContentController.add(messageHandlerProxy, name: Self.bridgeHandlerName)
    userContentController.add(messageHandlerProxy, name: STOnlineWebLoadingController.handlerName)
    #if DEBUG
    userContentController.add(messageHandlerProxy, name: Self.debugLogHandlerName)
    #endif
    loadInitialPage()
  }

  private func loadInitialPage() {
    loadPage(URLRequest(url: initialURL), isInitialPage: true)
  }

  private var isLoadingInitialPage: Bool {
    loadingNavigation != nil && loadingNavigation === initialPageNavigation
  }

  private func loadPage(_ request: URLRequest, isInitialPage: Bool, preservesHistory: Bool = false) {
    lastTopLevelRequest = request
    loading.begin(showsLaunchScreen: isInitialPage)
    reportTiming("navigation.load_requested", url: request.url)
    let navigation = (preservesHistory ? webView.reload() : nil) ?? webView.load(request)
    // Only a host-initiated, body-free GET can vouch for a committed history item.
    knownGETNavigation = STOnlineWebProcessRecovery.isBodyFreeGET(request) ? navigation : nil
    hasUncommittedNavigation = navigation != nil
    initialPageNavigation = isInitialPage ? navigation : nil
    loadingNavigation = navigation
    if navigation == nil { loading.navigationFailed() }
  }

  private func retryPage() {
    processRecovery = .idle
    if isLoadingInitialPage {
      loadInitialPage()
    } else if let request = lastTopLevelRequest, request.httpMethod?.uppercased() == "GET" {
      loadPage(request, isInitialPage: false)
    } else if let currentDocument = webView.url ?? lastTopLevelRequest?.url {
      // 表单失败后重新打开页面，让用户确认是否再次提交。
      loadPage(URLRequest(url: currentDocument), isInitialPage: false)
    }
  }

  @discardableResult
  private func recoverTerminatedProcessIfNeeded() -> Bool {
    // Covered pages recover only when they become the visible page again.
    let isActivePage = UIApplication.shared.applicationState == .active &&
      viewIfLoaded?.window != nil && navigationController?.visibleViewController === self &&
      !isBeingDismissed && navigationController?.isBeingDismissed != true
    guard !releasedWebResources,
          let url = processRecovery.takeReloadURL(isActivePage: isActivePage) else { return false }
    reportTiming("navigation.content_process_reloading", url: url)
    // Reload the current document with a fresh GET, never replay a form POST.
    let preservesHistory = canRecoverInHistory && webView.backForwardList.currentItem?.url == url
    reportTiming(preservesHistory ? "navigation.recovery_history_reload" : "navigation.recovery_get_fallback", url: url)
    loadPage(URLRequest(url: url), isInitialPage: false, preservesHistory: preservesHistory)
    return true
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

  override func willMove(toParent parent: UIViewController?) {
    // UIKit's moving/dismissing flags are transient. Revoke requests when a
    // removal starts, even if appearance callbacks are skipped or cancelled.
    if parent == nil, self.parent is UINavigationController {
      owner?.invalidateReplies()
    }
    super.willMove(toParent: parent)
  }

  override func didMove(toParent parent: UIViewController?) {
    super.didMove(toParent: parent)
    // Confirmed removal is terminal for this page's retained Web runtime.
    if parent == nil { releaseWebResources() }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    let shouldNotify = owner.didAppear()
    if !recoverTerminatedProcessIfNeeded(), shouldNotify { sendPageWillAppear() }
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
    userContentController.removeScriptMessageHandler(forName: STOnlineWebLoadingController.handlerName)
    loading.release()
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
    let scheme = url.scheme?.lowercased()
    guard scheme == "https" || (allowInsecureHttpNavigation && scheme == "http" && url.host != nil) else {
      decisionHandler(.cancel)
      return
    }
    if navigationAction.targetFrame?.isMainFrame == true {
      if navigationAction.navigationType == .backForward { didCommitKnownGET = false }
      if hasUncommittedNavigation { provisionalLinkGETURL = nil }
      // Only a single, unambiguous main-frame hyperlink can be paired with
      // the next provisional navigation. History and form actions may replay POST.
      let isNewLinkGET = pendingTopLevelRequest == nil && !hasUncommittedNavigation &&
        navigationAction.sourceFrame.isMainFrame && navigationAction.navigationType == .linkActivated &&
        STOnlineWebProcessRecovery.isBodyFreeGET(navigationAction.request)
      if isNewLinkGET && STOnlineWebProcessRecovery.isSameDocumentFragmentLink(url, currentURL: webView.url) {
        decisionHandler(.allow)
        return
      }
      pendingLinkGETURL = isNewLinkGET ? url : nil
      pendingTopLevelRequest = navigationAction.request
    }
    decisionHandler(.allow)
  }

  @available(iOS 26.0, *)
  func webView(_ webView: WKWebView, shouldGoTo backForwardListItem: WKBackForwardListItem,
               willUseInstantBack: Bool, completionHandler: @escaping (Bool) -> Void) {
    // Instant Back can change documents without running the usual policy and commit callbacks.
    didCommitKnownGET = false
    completionHandler(true)
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    reportTiming("navigation.finished", url: webView.url)
    guard let navigation, navigation === loadingNavigation else { return }
    loading.documentFinished()
    if owner.didCommitPage() { sendPageWillAppear() }
  }

  func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    owner.invalidateReplies()
    if let request = pendingTopLevelRequest { lastTopLevelRequest = request }
    provisionalLinkGETURL = pendingLinkGETURL == webView.url ? pendingLinkGETURL : nil
    pendingLinkGETURL = nil
    pendingTopLevelRequest = nil
    loadingNavigation = navigation
    hasUncommittedNavigation = true
    loading.begin(showsLaunchScreen: isLoadingInitialPage)
    navigationStartedAt = ProcessInfo.processInfo.systemUptime
    reportTiming("navigation.started", url: webView.url)
  }

  func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
    if navigation === loadingNavigation {
      pendingLinkGETURL = nil
      provisionalLinkGETURL = nil
      pendingTopLevelRequest = nil
    }
  }

  func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    owner.invalidateReplies()
    reportTiming("navigation.committed", url: webView.url)
    if let navigation, navigation === loadingNavigation {
      didCommitKnownGET = navigation === knownGETNavigation ||
        (provisionalLinkGETURL != nil && provisionalLinkGETURL == webView.url)
      knownGETNavigation = nil
      provisionalLinkGETURL = nil
      hasUncommittedNavigation = false
      lastDocumentURL = webView.url
      loading.documentCommitted()
    }
  }

  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    reportTiming("navigation.provisional_failed", url: webView.url, error: error)
    if let navigation, navigation === loadingNavigation {
      provisionalLinkGETURL = nil
      hasUncommittedNavigation = false
      if (error as NSError).code != NSURLErrorCancelled { loading.navigationFailed() }
    }
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    reportTiming("navigation.failed", url: webView.url, error: error)
    if let navigation, navigation === loadingNavigation, (error as NSError).code != NSURLErrorCancelled { loading.navigationFailed() }
  }

  func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    guard !releasedWebResources else { return }
    let currentItemURL = webView.backForwardList.currentItem?.url
    let url = [webView.url, currentItemURL, lastDocumentURL, lastTopLevelRequest?.url].compactMap { $0 }
      .first { STOnlineWebCore.normalizedBridgeOrigin($0, allowInsecureHTTP: allowInsecureHttpNavigation) != nil }
      ?? initialURL
    reportTiming("navigation.content_process_terminated", url: url)
    if processRecovery == .idle || loading.isReady {
      canRecoverInHistory = STOnlineWebProcessRecovery.canReloadHistory(
        url: url, currentItemURL: currentItemURL,
        didCommitKnownGET: didCommitKnownGET,
        isNavigating: hasUncommittedNavigation || pendingTopLevelRequest != nil)
    }
    let canRecover = processRecovery.recordTermination(at: url, documentWasReady: loading.isReady)
    owner.willLoadReplacementDocument()
    knownGETNavigation = nil
    pendingLinkGETURL = nil
    provisionalLinkGETURL = nil
    pendingTopLevelRequest = nil
    initialPageNavigation = nil
    loadingNavigation = nil
    // Do not spend the navigation timeout while still waiting to be visible.
    loading.begin(showsLaunchScreen: false, startsDeadline: false)
    if canRecover {
      recoverTerminatedProcessIfNeeded()
    } else {
      loading.navigationFailed()
    }
  }

  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    if message.name == STOnlineWebLoadingController.handlerName {
      guard STOnlineWebCore.allowsBridgeMessage(documentURL: message.frameInfo.request.url,
              isMainFrame: message.frameInfo.isMainFrame, allowInsecureHTTP: allowInsecureHttpNavigation),
            STOnlineWebCore.matchesCurrentDocumentOrigin(messageDocumentURL: message.frameInfo.request.url,
              currentDocumentURL: webView.url, allowInsecureHTTP: allowInsecureHttpNavigation) else { return }
      loading.receive(message.body)
      return
    }
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
          !method.isEmpty, let origin = currentBridgeOrigin(),
          let documentURL = webView.url else { return }
    let params = request["params"] as? [String: Any] ?? [:]
    let isBridgeOwnerCurrent = captureBridgeOwnership()
    let requestNavigation = navigationController
    let hadRequestNavigation = requestNavigation != nil
    owner.captureReply(isOwnerCurrent: { [weak self, weak requestNavigation] in
      guard let self, !self.releasedWebResources, !self.isBeingDismissed,
            !self.isMovingFromParent, self.navigationController?.isBeingDismissed != true else { return false }
      if hadRequestNavigation {
        guard let requestNavigation, self.navigationController === requestNavigation,
              requestNavigation.viewControllers.contains(where: { $0 === self }) else { return false }
      } else if self.navigationController != nil {
        return false
      }
      return isBridgeOwnerCurrent()
    }) { [weak self] deliver in
      guard let self else { return }
      let respond: ([String: Any]) -> Void = { response in
        let payload = STOnlineWebCore.callbackPayload(response: response, method: method, methodId: params["methodId"] as? String ?? "")
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        deliver(json.replacingOccurrences(of: "</", with: "<\\/"))
      }
      if method == "setNavigationBarTitle" {
        self.navigationItem.title = params["title"] as? String
        respond(["code": "1", "data": [:]])
      } else {
        self.bridgeRequest(method, params, origin, documentURL, respond)
      }
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

  private func sendPageWillAppear() {
    deliverHostLifecycle(method: "pageWillAppear")
  }

  /// Lifecycle payloads are credential-free and shared by Mini and ordinary
  /// `/web` pages. The H5 bridge queues messages received before a listener
  /// is registered and also has an initial activation fallback.
  func deliverHostLifecycle(method: String, params: [String: Any] = [:]) {
    guard !releasedWebResources else { return }
    if method == "appHide", let url = webView.url {
      // Include SPA route changes that did not trigger a navigation delegate.
      lastDocumentURL = url
    }
    if method == "appShow" {
      if recoverTerminatedProcessIfNeeded() || (processRecovery != .idle && !loading.isReady) { return }
    }
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
    owner?.invalidateReplies()
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
