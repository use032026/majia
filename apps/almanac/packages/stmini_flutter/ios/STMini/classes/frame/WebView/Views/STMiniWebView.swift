






import Foundation
@preconcurrency import WebKit

@objc public class STMiniWebView: WKWebView {
    
    @objc public var isChild: Bool = false
    @objc public var environment: STWebEnv = STWebEnv.normal
    
    @objc public weak var bindCrl: (STViewController&STWebCrlProtocol)?
    /// Root Mini-program controllers may be retained by STMini's LRU cache
    /// after a modal dismissal.  Detaching their hierarchy must not tear down
    /// the WebView bridge, otherwise the next presentation would be a blank,
    /// non-interactive WebView instead of a real warm start.
    @objc public var preserveRuntimeWhenDetached: Bool = false
    private var hasCleanedUp: Bool = false
    var nativeEffectsSuspended = false
    var hasNativeEffectAuthority: Bool {
        guard !hasCleanedUp, !nativeEffectsSuspended,
              owningMiniRootController()?.allowsNativeRuntimeEffects ?? true else { return false }
        return (bindCrl as? STWebH5Crl)?.allowsNativePageEffects ?? true
    }
    public private(set) var bridgeDocumentGeneration: UInt64 = 0
    private let installedIdentityLock = NSLock()
    private var installedIdentity: (miniId: String, version: String, entry: String)?

    // A live downloaded Mini never silently switches to files from a later
    // installed version. A replacement identity needs a new native WebView.
    private func bindInstalledDocumentIdentity(_ target: URL) -> Bool {
        guard let parts = URLComponents(url: target, resolvingAgainstBaseURL: false),
              parts.scheme == STWebResourceManager.installedMiniResourceScheme,
              parts.user == nil, parts.password == nil, parts.port == nil,
              let host = parts.host, host.hasSuffix(".stmini.local") else { return false }
        let id = String(host.dropLast(".stmini.local".count))
        guard let item = try? LocalPackageInventory(home: URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true))
                .read(check: {}).first(where: { $0["miniId"] == id }),
              let version = item["version"], let entry = item["entry"] else { return false }
        installedIdentityLock.lock(); defer { installedIdentityLock.unlock() }
        if let bound = installedIdentity {
            return bound.miniId == id && bound.version == version && bound.entry == entry
        }
        installedIdentity = (id, version, entry)
        return true
    }

    func verifiedBoundResource(_ target: URL) -> URL? {
        installedIdentityLock.lock(); let bound = installedIdentity; installedIdentityLock.unlock()
        guard let bound, var parts = URLComponents(url: target, resolvingAgainstBaseURL: false),
              parts.scheme == STWebResourceManager.installedMiniResourceScheme,
              parts.user == nil, parts.password == nil, parts.port == nil,
              parts.host == "\(bound.miniId).stmini.local" else { return nil }
        parts.query = nil; parts.fragment = nil
        guard let plain = parts.url,
              let path = LocalMiniResource.decodePath(plain, scheme: STWebResourceManager.installedMiniResourceScheme,
                                                     host: "\(bound.miniId).stmini.local") else { return nil }
        return try? LocalPackageInventory(home: URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true))
            .verifiedResource(miniId: bound.miniId, version: bound.version, entry: bound.entry, path: path, check: {})
    }

    public func invalidateBridgeDocumentSession() { bridgeDocumentGeneration &+= 1 }
    // Keep the ownership details in this file; the plugin receives only a
    // native-derived storage subject after the existing bridge checks.
    func isolatedStorageSubject() -> String? {
        guard allowsHostSensitiveBridge, let current = url else { return nil }
        let origin = STOnlineWebCore.normalizedHTTPSOrigin(current)
        if let root = owningMiniRootController(), allowsLocalMiniBridge {
            let id = root.miniProgramId.lowercased()
            guard !id.isEmpty else { return nil }
            if let origin { return "mini:\(id)|web:\(origin)" }
            guard isVerifiedLocalMiniDocument(current) else { return nil }
            return "mini:\(id)|local"
        }
        return origin.map { "web:\($0)" }
    }

    /// The controller's requested bridge policy separates ordinary Web from
    /// package-verified Mini-only APIs.
    private var bridgePolicy: STWebBridgePolicy = .externalUntrusted
    private var allowsInsecureHttpNavigation = false
    // WKUserContentController strongly retains its script-message handlers.  Keep
    // the handler separate from the web view so registering the bridge does not
    // create a WKWebView -> configuration -> handler -> WKWebView retain cycle.
    private var scriptMessageHandler: STWeakScriptMessageHandler?
    
    
    private lazy var loadingBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator: UIActivityIndicatorView
        if #available(iOS 13.0, *) {
            indicator = UIActivityIndicatorView(style: .large)
        } else {
            indicator = UIActivityIndicatorView(style: .gray)
        }
        indicator.color = .gray 
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    
    private lazy var loadingImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = true 
        return imageView
    }()
    
    
    @objc public convenience init(frame: CGRect, bindCrl: (STViewController&STWebCrlProtocol)?) {
        self.init(frame: frame, configuration: Self.stMiniWebViewConfiguration())
        self.bindCrl = bindCrl
    }

    private static func stMiniWebViewConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        if #available(iOS 11.0, *) {
            configuration.setURLSchemeHandler(
                STWebSchemeHandler.shared,
                forURLScheme: STWebResourceManager.installedMiniResourceScheme
            )
        }
        return configuration
    }
    
    
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        backgroundColor = .clear
        uiDelegate = self
        navigationDelegate = self

        // WKWebView is backed by a UIScrollView. Its default touch delay is
        // useful for scroll views, but makes form controls in a Mini page
        // feel as though they need repeated taps before receiving focus.
        // A WebView owns the browser's own scroll/touch arbitration, so hand
        // the first tap to the page immediately and do not cancel it once a
        // scroll gesture starts.
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = false
        
        initialWebViewConfiguration()
        
        setupLoadingViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    private func setupLoadingViews() {
        
        addSubview(loadingBackgroundView)
        addSubview(loadingImageView)
        addSubview(loadingIndicator)
        
        
        NSLayoutConstraint.activate([
            loadingBackgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            loadingBackgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            loadingBackgroundView.topAnchor.constraint(equalTo: topAnchor),
            loadingBackgroundView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        
        NSLayoutConstraint.activate([
            loadingImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingImageView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    
    private func showLoadingIndicator() {
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let personalHandle = STWebPersonalHandle.sharedInstance()
            
            
            self.loadingBackgroundView.isHidden = false
            self.bringSubviewToFront(self.loadingBackgroundView)
            
            if let loadingImg = personalHandle.loadingImg, !loadingImg.isEmpty {
                
                if let image = UIImage(named: loadingImg) {
                    self.loadingImageView.image = image
                    self.loadingImageView.isHidden = false
                    self.bringSubviewToFront(self.loadingImageView)
                    self.bringSubviewToFront(self.loadingIndicator)
                } else {
                    
                    self.loadingImageView.isHidden = true
                    self.loadingIndicator.startAnimating()
                    self.bringSubviewToFront(self.loadingIndicator)
                }
            } else {
                
                self.loadingImageView.isHidden = true
                self.loadingIndicator.startAnimating()
                self.bringSubviewToFront(self.loadingIndicator)
            }
        }
    }
    
    
    private func hideLoadingIndicator() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.loadingIndicator.stopAnimating()
            self.loadingImageView.isHidden = true
            self.loadingBackgroundView.isHidden = true
        }
    }
    
    public override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        if (newSuperview == nil && !preserveRuntimeWhenDetached) {
            cleanup()
        } else {
            
            hideLoadingIndicator()
        }
    }

    /// Controllers set this before their first navigation.  Keeping the
    /// policy on the WebView means every bridge delivery is checked against
    /// the document that is actually visible after redirects or user links.
    public func configureBridgePolicy(_ policy: STWebBridgePolicy,
                                      allowsInsecureHttpNavigation: Bool = false) {
        bridgePolicy = policy
        self.allowsInsecureHttpNavigation = allowsInsecureHttpNavigation
    }

    /// Whether this *current* main document may reach the ordinary
    /// host-supplied Web bridge. Mini-only APIs are checked separately.
    @objc public var allowsHostSensitiveBridge: Bool {
        guard hasNativeEffectAuthority, let currentURL = url else { return false }
        switch bridgePolicy {
        case .miniExternal, .externalUntrusted:
            return STOnlineWebCore.allowsBridgeMessage(
                documentURL: currentURL,
                isMainFrame: true
            )
        case .localMini:
            return isVerifiedLocalMiniDocument(currentURL)
        }
    }

    /// Any allowed top-level external document may use the Web-only host
    /// forwarding contract. Installed/local Mini pages continue through the
    /// Mini runtime and never acquire this fallback capability.
    @objc public var allowsOnlineWebHostForwarding: Bool {
        switch bridgePolicy {
        case .miniExternal, .externalUntrusted:
            return allowsHostSensitiveBridge
        case .localMini:
            return false
        }
    }

    /// Mini-only package, update and navigation APIs must never be granted to
    /// a regular host `/web` page. A Mini-pushed HTTPS page inherits the
    /// already-verified root Mini identity, matching native STMini.
    @objc public var allowsLocalMiniBridge: Bool {
        guard hasNativeEffectAuthority, let currentURL = url else { return false }
        switch bridgePolicy {
        case .localMini:
            return isVerifiedLocalMiniDocument(currentURL)
        case .miniExternal:
            return currentURL.scheme?.lowercased() == "https" &&
                currentURL.host != nil &&
                owningMiniRootController() != nil
        case .externalUntrusted:
            return false
        }
    }
    
    
    func initialWebViewConfiguration() {
        configuration.preferences.setValue(true, forKey:"allowFileAccessFromFileURLs")
        let handler = STWeakScriptMessageHandler(delegate: self)
        scriptMessageHandler = handler
        configuration.userContentController.add(handler, name: "CMSScriptMessageChannel")
    }
    
    
    public func clearCache() {
        let dateFrom: NSDate = NSDate.init(timeIntervalSince1970: 0)
        let websiteDataTypes: NSSet = WKWebsiteDataStore.allWebsiteDataTypes() as NSSet
        WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes as! Set, modifiedSince: dateFrom as Date) {
            STProjectHelper.Log("清空缓存完成")
        }
    }
    
    
    @objc public func cleanup() {
        bridgeDocumentGeneration &+= 1
        if hasCleanedUp {
            return
        }
        hasCleanedUp = true
        
        stopLoading()
        
        
        configuration.userContentController.removeScriptMessageHandler(forName: "CMSScriptMessageChannel")
        scriptMessageHandler = nil
        
        
        uiDelegate = nil
        navigationDelegate = nil
        
        
        configuration.userContentController.removeAllUserScripts()
        
        
        hideLoadingIndicator()
        
        
        subviews.forEach { $0.removeFromSuperview() }
    }

    deinit {
        cleanup()
        STProjectHelper.Log("webview释放")
    }
    
}

/// A weak forwarding handler prevents WKUserContentController from retaining
/// STMiniWebView through its JavaScript bridge registration.
private final class STWeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}


extension STMiniWebView: WKScriptMessageHandler {
    
    public func userContentController(_ userContentController: WKUserContentController,
                                      didReceive message: WKScriptMessage) {
        guard message.name == "CMSScriptMessageChannel", hasNativeEffectAuthority else { return }
        // Remote host H5 and Mini `/web` share OnlineWebViewController. Keep
        // STMini's local-package path below untouched: it has a distinct
        // verified-resource authorization boundary.
        if let h5 = bindCrl as? STWebH5Crl,
           let owner = h5.onlineWebOwner {
            if !owner.receiveScriptMessage(
                body: message.body,
                documentURL: message.frameInfo.request.url,
                isMainFrame: message.frameInfo.isMainFrame
            ) {
                STProjectHelper.Log("STMini Online Web Bridge 拒绝非受信消息")
            }
            return
        }
        // `WKUserContentController` uses one handler name for every frame.
        // Without this guard an untrusted iframe can invoke the same native
        // APIs as its parent document. Never forward subframe messages.
        guard message.frameInfo.isMainFrame else {
            STProjectHelper.Log("STMini Bridge 拒绝 iframe 消息")
            return
        }
        guard isBridgeDocumentAllowed(message.frameInfo.request.url, isMainFrame: message.frameInfo.isMainFrame) else {
            STProjectHelper.Log("STMini Bridge 拒绝非受控顶层页面")
            return
        }
        let localDocumentMatches = message.frameInfo.request.url.flatMap { sender -> Bool? in
            guard sender.scheme == STWebResourceManager.installedMiniResourceScheme,
                  let current = url, current.scheme == sender.scheme else { return nil }
            return isVerifiedLocalMiniDocument(sender) && isVerifiedLocalMiniDocument(current)
                && sender.host == current.host && sender.path == current.path && sender.query == current.query
        } ?? false
        guard localDocumentMatches || STOnlineWebCore.matchesCurrentDocumentOrigin(
            messageDocumentURL: message.frameInfo.request.url,
            currentDocumentURL: url,
            allowInsecureHTTP: allowsInsecureHttpNavigation
        ) else {
            STProjectHelper.Log("STMini Bridge 拒绝已过期或与当前页面不一致的消息")
            return
        }
        STWebApiManager.dealWithApiMessage(message.body, webView: self)
    }
    
}


extension STMiniWebView: WKUIDelegate {
    
    
    
    
    
    
    
    
    
}


extension STMiniWebView: WKNavigationDelegate {
    
    public func webView(_ webView: WKWebView,
                        decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        STProjectHelper.Log("加载周期：\(String(describing: navigationAction.request.url?.absoluteString))")

        // `targetFrame == nil` is a new-window request. STMini does not
        // create a second WKWebView for it, but it must still be treated as a
        // top-level request for scheme policy rather than becoming an HTTP
        // bypass through `target=_blank` / `window.open`.
        let isTopLevelRequest = navigationAction.targetFrame?.isMainFrame ?? true
        if isTopLevelRequest, nativeEffectsSuspended || owningMiniRootController()?.isRuntimeRetainedHidden == true {
            decisionHandler(.cancel); return
        }
        if isTopLevelRequest, let target = navigationAction.request.url,
           target.scheme == STWebResourceManager.installedMiniResourceScheme,
           !bindInstalledDocumentIdentity(target) { decisionHandler(.cancel); return }
        if isTopLevelRequest,
           let targetURL = navigationAction.request.url,
           !isTopLevelNavigationAllowed(targetURL) {
            STProjectHelper.Log("STMini 拒绝不安全顶层跳转：\(targetURL.scheme ?? "<none>")")
            decisionHandler(.cancel)
            return
        }
        
        
        if isTopLevelRequest {
            showLoadingIndicator()
        }
        
        decisionHandler(.allow)
    }
    
    public func webView(_ webView: WKWebView,
                        decidePolicyFor navigationResponse: WKNavigationResponse,
                        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        
        decisionHandler(.allow)
    }
    
    
    
    
    
    
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if webView === self { bridgeDocumentGeneration &+= 1 }
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        STProjectHelper.Log("加载周期：加载完成")
        
        hideLoadingIndicator()
        (webView as! STMiniWebView).bindCrl?.webviewDidFinish()
    }
    
    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        STProjectHelper.Log("加载周期：渲染完成")
        
        hideLoadingIndicator()
        if let h5 = (webView as? STMiniWebView)?.bindCrl as? STWebH5Crl,
           h5.onlineWebOwner != nil {
            h5.onlineWebOwner?.didCommitPage()
            return
        }
        webView.evaluateJavaScript("document.title") { (result, error) -> Void in if error == nil {
            guard let title = result as? String else {
                return
            }
            STProjectHelper.Log("加载周期：网页标题：\(title)")
            (webView as! STMiniWebView).bindCrl?.title = title
        }}
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        STProjectHelper.Log("加载周期：加载失败 - didFail")
        
        hideLoadingIndicator()
        (webView as? STMiniWebView)?.bindCrl?.webviewDidFailNavigation?(error as NSError)
    }
    
    public func webView(_ webView: WKWebView,
                        didFailProvisionalNavigation navigation: WKNavigation!,
                        withError error: Error) {
        STProjectHelper.Log("加载周期：加载失败 - didFailProvisionalNavigation")
        
        hideLoadingIndicator()
        (webView as? STMiniWebView)?.bindCrl?.webviewDidFailNavigation?(error as NSError)
    }
    
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        STProjectHelper.Log("加载周期：页面发生错误")
        // The callback is delivered for the WebView whose content process
        // died.  Do not hard-code the Mini root here: Mini-owned `/web` pages
        // are STWebH5Crl instances and must recover their own document too.
        (webView as? STMiniWebView)?.bindCrl?.webviewContentProcessDidTerminate()
        hideLoadingIndicator()
    }
    
}

private extension STMiniWebView {


    func isBridgeDocumentAllowed(_ documentURL: URL?, isMainFrame: Bool = true) -> Bool {
        guard let documentURL else { return false }
        switch bridgePolicy {
        case .localMini:
            return isMainFrame && isVerifiedLocalMiniDocument(documentURL)
        case .miniExternal, .externalUntrusted:
            return STOnlineWebCore.allowsBridgeMessage(
                documentURL: documentURL,
                isMainFrame: isMainFrame,
                allowInsecureHTTP: allowsInsecureHttpNavigation
            )
        }
    }

    func isTopLevelNavigationAllowed(_ targetURL: URL) -> Bool {
        switch bridgePolicy {
        case .localMini:
            return isVerifiedLocalMiniDocument(targetURL)
        case .miniExternal, .externalUntrusted:
            // Navigation remains available to ordinary HTTPS documents. The
            // bridge boundary applies to the current top-level document, not
            // to a user's browser navigation.
            return Self.isAllowedExternalWebURL(
                targetURL, allowInsecureHTTP: allowsInsecureHttpNavigation)
        }
    }

    func isVerifiedLocalMiniDocument(_ candidateURL: URL) -> Bool {
        guard let rootMini = owningMiniRootController(),
              let miniId = Self.normalizedMiniID(rootMini.miniProgramId) else {
            return false
        }
        if Self.matchesInstalledMiniOrigin(candidateURL, miniId: miniId) {
            // The host match alone is not enough: the resource resolver also
            // validates that this is a regular file inside the *currently
            // verified* installed package.
            return verifiedBoundResource(candidateURL) != nil
        }
        return isCurrentBundledMiniDocument(candidateURL, rootMini: rootMini)
    }

    func isCurrentBundledMiniDocument(_ candidateURL: URL, rootMini: STWebMiniprogramCrl) -> Bool {
        // A file-backed document is supported only for the root of an
        // explicitly local Mini. H5 children and online Minis never receive
        // file:// bridge access, even if they can construct a matching path.
        guard candidateURL.isFileURL,
              bindCrl === rootMini,
              rootMini.config.webMode == .local,
              let rawBundleRoot = STWebResourceManager.localMiniProgramPath(name: rootMini.name).1,
              let bundleRoot = URL(string: rawBundleRoot)?.standardizedFileURL else {
            return false
        }
        let documentURL = candidateURL.standardizedFileURL
        return documentURL.path.hasPrefix(bundleRoot.path + "/")
    }

    static func normalizedMiniID(_ rawMiniID: String) -> String? {
        let normalized = rawMiniID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty,
              normalized.range(of: "^[a-z0-9_-]+$", options: .regularExpression) != nil else {
            return nil
        }
        return normalized
    }

    static func isAllowedExternalWebURL(_ candidateURL: URL, allowInsecureHTTP: Bool = false) -> Bool {
        guard candidateURL.host?.isEmpty == false,
              let scheme = candidateURL.scheme?.lowercased() else {
            return false
        }
        return scheme == "https" || (allowInsecureHTTP && scheme == "http")
    }
}

extension STMiniWebView {
    func owningMiniRootController() -> STWebMiniprogramCrl? {
        if let root = bindCrl as? STWebMiniprogramCrl, !root.isChild {
            return root
        }
        return bindCrl?.navigationController?.viewControllers.first(where: { controller in
            guard let root = controller as? STWebMiniprogramCrl else { return false }
            return !root.isChild
        }) as? STWebMiniprogramCrl
    }

    /// Narrow controller-facing launch gate. Keep the actual local-package and
    /// Bridge-document verification private to this file; callers only learn
    /// whether the WebView currently bound to a root Mini may complete its
    /// native launch presentation.
    func isVerifiedCurrentRootMiniDocumentForLaunch(_ candidateURL: URL) -> Bool {
        guard let rootMini = bindCrl as? STWebMiniprogramCrl,
              !rootMini.isChild else {
            return false
        }
        return isVerifiedLocalMiniDocument(candidateURL)
    }

    /// Exposed at module scope solely so the iOS unit suite can cover the
    /// identity boundary. Production authorization additionally calls the
    /// private installed-package resource resolver above.
    static func matchesInstalledMiniOrigin(_ candidateURL: URL, miniId: String) -> Bool {
        guard let normalizedMiniID = normalizedMiniID(miniId),
              candidateURL.scheme?.lowercased() == STWebResourceManager.installedMiniResourceScheme,
              let host = candidateURL.host?.lowercased() else {
            return false
        }
        return host == "\(normalizedMiniID).stmini.local"
    }
}
