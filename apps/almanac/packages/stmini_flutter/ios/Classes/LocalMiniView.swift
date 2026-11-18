import Flutter
import UIKit
import WebKit

/// Explicit local-only Flutter adapter over derived pinned Mini WebView semantics.
public final class LocalMiniViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  private let allowed: () -> Bool
  private let views = NSHashTable<LocalMiniView>.weakObjects()
  public init(messenger: FlutterBinaryMessenger, allowed: @escaping () -> Bool) {
    self.messenger = messenger; self.allowed = allowed
  }
  public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  public func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    let value = LocalMiniView(frame: frame, messenger: messenger, viewId: viewId, arguments: args, allowed: allowed)
    views.add(value); return value
  }
  public func detach() { views.allObjects.forEach { $0.close() } }
}

public final class LocalMiniView: NSObject, FlutterPlatformView, WKNavigationDelegate, WKUIDelegate {
  private let root: UIView
  private let channel: FlutterMethodChannel
  private let allowed: () -> Bool
  private let home: URL
  private let queue = DispatchQueue(label: "stmini.local-renderer.identity")
  private final class IdentityRead {
    private let lock = NSLock()
    private var cancelled = false
    private let deadline = ProcessInfo.processInfo.systemUptime + 4
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    func check() throws {
      lock.lock(); let stopped = cancelled; lock.unlock()
      if stopped || ProcessInfo.processInfo.systemUptime >= deadline { throw LocalPackageInventory.Failure.unavailable }
    }
  }
  private var identity: IdentityRead?
  private var identityRunning = false
  private var pendingIdentity: (() -> Void)?
  private var history = [URL]()
  private var historyIndex = -1
  private var activeNavigation: WKNavigation?
  private var requestedDocument: URL?
  private var generation = 0
  private var closed = false
  private var phase = "loading"
  private var errorCode: String?
  private var miniId: String?
  private var version: String?
  private var entry: String?
  private var resource: LocalMiniResource?
  public private(set) var webView: WKWebView?
  private var expectedDocument: URL?
  private var deliveredDocument: URL?
  private var timeout: DispatchWorkItem?

  /// Production factory always uses system home. An independent native test can
  /// supply its private fixture home; no Flutter channel may choose a root.
  public init(frame: CGRect, messenger: FlutterBinaryMessenger, viewId: Int64, arguments: Any?,
              allowed: @escaping () -> Bool, home: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)) {
    self.root = UIView(frame: frame); self.allowed = allowed; self.home = home
    self.channel = FlutterMethodChannel(name: "stmini_flutter/local_view/\(viewId)", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result: result) }
    guard let args = arguments as? [String: Any], Set(args.keys) == ["miniId", "version"],
          let id = args["miniId"] as? String, Self.matches(id, "[a-z0-9][a-z0-9_-]{0,63}"),
          let number = args["version"] as? String, Self.matches(number, "[0-9]{1,9}(\\.[0-9]{1,9}){0,7}") else {
      fail("invalid_parameters"); return
    }
    guard allowed() else { fail("not_initialized"); return }
    miniId = id; version = number; reload()
  }
  public func view() -> UIView { root }
  public func state() -> [String: Any] {
    ["phase": phase, "canGoBack": !closed && historyIndex > 0,
     "errorCode": errorCode as Any? ?? NSNull()]
  }
  private func emit() { if !closed { channel.invokeMethod("stateChanged", arguments: state()) } }
  private func beginNavigation(_ url: URL? = nil) -> Int {
    generation += 1; activeNavigation = nil; deliveredDocument = nil; expectedDocument = url; resource?.beginNavigation()
    timeout?.cancel(); phase = "loading"; errorCode = nil
    let token = generation
    let work = DispatchWorkItem { [weak self] in
      guard let self, !self.closed, self.generation == token, self.phase == "loading" else { return }
      self.fail("render_timeout")
    }
    timeout = work; DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: work); emit()
    return token
  }
  private func fail(_ code: String) {
    guard !closed else { return }
    timeout?.cancel(); timeout = nil; phase = "failed"; errorCode = code
    webView?.stopLoading()
    let label = UILabel(frame: root.bounds); label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    label.text = "Local Mini unavailable"; label.textAlignment = .center; label.accessibilityIdentifier = "stmini-local-error"
    root.addSubview(label); emit()
  }
  private func reload() {
    guard !closed else { return }
    guard allowed() else { fail("not_initialized"); return }
    guard let id = miniId, let number = version else { fail("invalid_parameters"); return }
    identity?.cancel(); pendingIdentity = nil
    let read = IdentityRead(); identity = read
    let token = beginNavigation(), requiredEntry = entry, home = self.home
    destroyWebView()
    let work: () -> Void = { [weak self] in
      guard let self, !self.closed, self.identity === read else { return }
      self.identityRunning = true
      self.queue.async { [weak self] in
        let inventory = LocalPackageInventory(home: home)
        let outcome = Result { try inventory.verifiedPackage(miniId: id, version: number, entry: requiredEntry, check: read.check) }
        DispatchQueue.main.async { [weak self] in
          guard let self else { return }
          self.identityRunning = false
          if !self.closed && self.phase == "loading" && self.generation == token && self.identity === read {
            switch outcome {
            case .success(let item):
              if let path = item["entry"] {
                self.entry = self.entry ?? path
                let resource = LocalMiniResource(inventory: inventory, miniId: id, version: number, entry: path)
                self.resource = resource; self.configure(resource, token: token)
              } else { self.fail("package_unavailable") }
            case .failure: self.fail("package_unavailable")
            }
          }
          let next = self.pendingIdentity; self.pendingIdentity = nil
          next?()
        }
      }
    }
    if identityRunning { pendingIdentity = work } else { work() }
  }
  private func configure(_ resource: LocalMiniResource, token: Int) {
    resource.identityInvalid = { [weak self, weak resource] in
      guard let self, let resource, !self.closed, self.generation == token,
            resource === self.resource else { return }
      resource.close(); self.fail("package_unavailable")
    }
    let config = WKWebViewConfiguration()
    config.websiteDataStore = .nonPersistent()
    config.preferences.javaScriptEnabled = true
    config.preferences.javaScriptCanOpenWindowsAutomatically = false
    config.allowsInlineMediaPlayback = false
    config.mediaTypesRequiringUserActionForPlayback = .all
    config.setURLSchemeHandler(resource, forURLScheme: "stmini")
    // WK content blockers support a restricted regex syntax without alternation.
    let rulesData = try! JSONSerialization.data(withJSONObject: ["https?", "wss?", "ftp", "file", "data", "blob"].map {
      ["trigger": ["url-filter": "^" + $0 + ":"], "action": ["type": "block"]]
    })
    let rules = String(data: rulesData, encoding: .utf8)!
    WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "stmini-local-resource-block-v1", encodedContentRuleList: rules) { [weak self] list, error in
      guard let self, !self.closed, self.phase == "loading", self.generation == token else { return }
      guard error == nil, let list else { self.fail("resource_unavailable"); return }
      config.userContentController.add(list)
      let view = WKWebView(frame: self.root.bounds, configuration: config)
      view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      view.navigationDelegate = self; view.uiDelegate = self
      view.scrollView.delaysContentTouches = false; view.scrollView.canCancelContentTouches = false
      self.root.subviews.forEach { $0.removeFromSuperview() }; self.root.addSubview(view); self.webView = view
      let target = self.requestedDocument ?? resource.entryURL
      if self.historyIndex < 0 { self.history = [target]; self.historyIndex = 0 }
      self.expectedDocument = target
      resource.mainResourceDelivered = { [weak self] url in
        guard let self, !self.closed, resource === self.resource,
              Self.withoutFragment(self.expectedDocument) == Self.withoutFragment(url), resource.isHTML(url) else { return }
        self.deliveredDocument = url
      }
      self.activeNavigation = view.load(URLRequest(url: target))
    }
  }
  public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                      decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    guard !closed, webView === self.webView, let resource,
          navigationAction.targetFrame?.isMainFrame == true,
          navigationAction.request.httpMethod == "GET", let url = navigationAction.request.url,
          resource.path(url) != nil, resource.isHTML(url) else { decisionHandler(.cancel); return }
    if phase == "loading" && expectedDocument?.absoluteString == url.absoluteString && navigationAction.navigationType != .reload { decisionHandler(.allow); return }
    if navigationAction.navigationType != .reload && url.fragment != expectedDocument?.fragment && Self.withoutFragment(url) == Self.withoutFragment(expectedDocument) {
      // Same-document anchors have no new main-resource commit. Keep ready and
      // never arm a new launch timeout for them.
      expectedDocument = url; requestedDocument = url; decisionHandler(.allow); return
    }
    decisionHandler(.cancel)
    if Self.withoutFragment(url) != Self.withoutFragment(expectedDocument) {
      history = Array(history.prefix(historyIndex + 1)); history.append(url); historyIndex += 1
    }
    requestedDocument = url; reload()
  }
  public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                      decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
    guard !closed, webView === self.webView, navigationResponse.isForMainFrame,
          let url = navigationResponse.response.url, resource?.path(url) != nil,
          navigationResponse.response.mimeType == "text/html" else { decisionHandler(.cancel); return }
    decisionHandler(.allow)
  }
  public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    // didCommit begins receiving the current main document. DOM/visibility is
    // independently verified by native tests, not asserted by this phase.
    guard !closed, phase == "loading", webView === self.webView, navigation === activeNavigation, let url = webView.url,
          resource?.isHTML(url) == true, expectedDocument == url, deliveredDocument == url else { return }
    timeout?.cancel(); timeout = nil; phase = "ready"; errorCode = nil; emit()
  }
  public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    if webView === self.webView && !closed && navigation === activeNavigation && (error as NSError).code != NSURLErrorCancelled { fail("resource_unavailable") }
  }
  public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    if webView === self.webView && !closed && navigation === activeNavigation && (error as NSError).code != NSURLErrorCancelled { fail("resource_unavailable") }
  }
  public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    if webView === self.webView && !closed { destroyWebView(); fail("renderer_terminated") }
  }
  public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                      for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? { nil }
  @available(iOS 15.0, *)
  public func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                      initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                      decisionHandler: @escaping (WKPermissionDecision) -> Void) { decisionHandler(.deny) }
  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.arguments == nil else { result(FlutterError(code: "invalid_parameters", message: "Control accepts no arguments.", details: nil)); return }
    switch call.method {
    case "state": result(state())
    case "reload": reload(); result(nil)
    case "close": close(); result(nil)
    case "goBack":
      let back = !closed && phase == "ready" && historyIndex > 0
      if back { historyIndex -= 1; requestedDocument = history[historyIndex]; reload() }; result(back)
    default: result(FlutterMethodNotImplemented)
    }
  }
  private func destroyWebView() {
    resource?.close(); resource = nil
    webView?.stopLoading(); webView?.navigationDelegate = nil; webView?.uiDelegate = nil
    webView?.configuration.userContentController.removeAllUserScripts()
    webView?.removeFromSuperview(); webView = nil
  }
  public func close() {
    guard !closed else { return }
    closed = true; generation += 1; identity?.cancel(); identity = nil; pendingIdentity = nil; timeout?.cancel(); timeout = nil; destroyWebView()
    root.subviews.forEach { $0.removeFromSuperview() }; phase = "closed"; errorCode = nil
    channel.invokeMethod("stateChanged", arguments: state())
  }
  deinit {
    channel.setMethodCallHandler(nil)
    identity?.cancel()
    let resource = self.resource, webView = self.webView
    DispatchQueue.main.async { resource?.close(); webView?.stopLoading(); webView?.navigationDelegate = nil; webView?.uiDelegate = nil; webView?.removeFromSuperview() }
  }
  private static func withoutFragment(_ url: URL?) -> String? {
    guard let url, var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
    parts.fragment = nil; return parts.string
  }
  private static func matches(_ text: String, _ pattern: String) -> Bool {
    guard let range = text.range(of: pattern, options: .regularExpression) else { return false }
    return range == text.startIndex..<text.endIndex
  }
}
