






import UIKit
import WebKit
import Network


@objc open class STWebH5Crl: STViewController, STWebCrlProtocol {
    
    public var webView: STMiniWebView!
    
    public var config: STWebConfig!
    /// Shared lifecycle state keeps ordinary H5 and Mini-pushed `/web` pages
    /// from running delayed network recovery after they leave the screen.
    private let onlineWebLifecycle = STOnlineWebDisplayLifecycle()
    fileprivate var isShow: Bool { onlineWebLifecycle.isVisible }
    public var url: String!
    public var isChild: Bool = false
    /// Set by Mini-owned local navigation or intercepted Mini `open /web`.
    /// A pushed page carrying this marker is part of the owning Mini
    /// navigation stack, so it may use the same generic STMini APIs as the
    /// root page. Ordinary `/web` pages keep the default false value.
    @objc public var isMiniInternalPage: Bool = false
    /// True only for the package-owned child pushed after an online `/web`
    /// page requests an in-package route such as `/login`.
    @objc public var isMiniRouteChild: Bool = false
    var onlineWebOwner: OnlineWebViewController?
    fileprivate var progressView : UIProgressView?
    fileprivate var observation: NSKeyValueObservation?
    /// Ordinary H5 pages are never eligible for Mini keep-alive.  Release the
    /// WebKit runtime as soon as the controller actually leaves its navigation
    /// stack instead of waiting for `deinit`: WebKit may otherwise keep its
    /// scroll view/process alive long enough for the debug leak detector to
    /// report the already-popped page.
    private var hasReleasedWebRuntime = false
    /// A WKWebView content process can be reclaimed while this controller is
    /// still on top of a Mini navigation stack.  Keep recovery local to the
    /// affected page; the root Mini may still have a healthy strategy runtime.
    private var isRecoveringTerminatedWebContentProcess = false
    private var terminatedWebContentProcessRecoveryCount = 0
    private var lastTerminatedWebContentProcessRecoveryAt: Date?
    private var terminatedWebContentProcessRecoveryToken: UUID?
    private static let terminatedWebContentProcessRecoveryWindow: TimeInterval = 60
    private static let terminatedWebContentProcessRecoveryTimeout: TimeInterval = 12
    /// A remote H5 may be opened before the user grants network permission.
    /// Keep a bounded retry for transient failures and then wait for an actual
    /// offline -> online path transition instead of permanently showing a
    /// blank failed WebView or reloading forever.
    private static let networkNavigationRetryDelays: [TimeInterval] = [0.8, 2, 5]
    private var networkNavigationRetryCount = 0
    private var networkNavigationRetryToken: UUID?
    private var waitingForNetworkRecovery = false
    private var lastObservedNetworkPathStatus: NWPath.Status?
    private var networkRecoveryMonitor: NWPathMonitor?
    private let networkRecoveryQueue = DispatchQueue(label: "com.stmini.h5-network-recovery")
    /// Ordinary online H5 pages share the host app lifecycle. A covered page
    /// receives `appHide` for persistence, while only the visible page gets
    /// `appShow`; its later `pageWillAppear` performs deferred recovery.
    private var onlineAppHideObserver: NSObjectProtocol?
    private var onlineAppShowObserver: NSObjectProtocol?
    private var onlineBackgroundEnteredAt: Date?
    /// UIKit may reset `isMovingFromParent` by `viewDidDisappear`. Capture the
    /// terminal transition in `viewWillDisappear` so parent-owned H5 pages
    /// are still released after their containing controller is popped.
    @objc public private(set) var shouldReleaseWebRuntimeAfterDisappear = false
    /// Do not use STViewController.naviView here. Its frame-based button is
    /// created before this full-screen Mini child has a final width, which
    /// can leave the back affordance outside the rendered header.
    fileprivate let h5HeaderView = UIView()
    fileprivate let h5BackButton = UIButton(type: .custom)
    fileprivate let h5BackImageView = UIImageView()
    fileprivate lazy var h5TitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textColor = .black
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    /// STViewController hides UINavigationController's bar and the H5
    /// container renders its own header. Keep the title in that visible
    /// header so both regular H5 and Mini-pushed H5 pages behave the same.
    open override var title: String? {
        get { h5TitleLabel.text }
        set { h5TitleLabel.text = STOnlineWebCore.displayTitle(newValue) }
    }
    
    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if #available(iOS 13.0, *) {
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                STWebApiManager.sendScriptMessageWithMethod("darkModeChanged", params: [:], webview: webView)
            }
        }
    }
    
    /// Keep the historical Objective-C initializer available for ordinary
    /// host `/web` pages.
    @objc public init(url: String!, config: STWebConfig!, isChild: Bool = false) {
        super.init(nibName: nil, bundle: nil)
        self.url = url
        self.config = config
        self.isChild = isChild
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateUserInfo(_:)),
            name: Notification.Name(STWebPersonalHandle.sharedInstance().noti_updateUserInfo),
            object: nil
        )
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        
        webView = STMiniWebView(frame: .zero, bindCrl: self)
        // `STWebH5Crl` remains the Mini-stack adapter. STOnlineWebCore grants
        // the common Web bridge only to the top-level document currently
        // displayed by this WebView; local Mini APIs stay package-verified.
        webView.configureBridgePolicy(
            config.bridgePolicy,
            allowsInsecureHttpNavigation: config.allowsInsecureHttpNavigation
        )
        if config.bridgePolicy != .localMini {
            onlineWebOwner = OnlineWebViewController(
                webView: webView,
                allowInsecureHttpBridge: config.allowsInsecureHttpNavigation,
                onMessage: { [weak self] body in
                    guard let webView = self?.webView else { return }
                    STWebApiManager.dealWithApiMessage(body, webView: webView)
                }
            )
            onlineWebOwner?.onTitleChanged = { [weak self] title in self?.title = title }
            installOnlineApplicationLifecycleObservers()
        }
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        
        if shouldShowNavigationBar() {
            NSLayoutConstraint.activate([
                webView.topAnchor.constraint(equalTo: view.topAnchor, constant: STScreenHelper.ST_navigationFullHeight()),
                webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
        else {
            NSLayoutConstraint.activate([
                webView.topAnchor.constraint(equalTo: view.topAnchor),
                webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        self.edgesForExtendedLayout = .all
        self.extendedLayoutIncludesOpaqueBars = true
            
        let url = URL(string: url)
        if let url, url.isFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else if let url {
            webView.load(URLRequest(url: url))
        }
            
        
        view.backgroundColor = .white
        
        
        if shouldShowNavigationBar() {
            h5HeaderView.translatesAutoresizingMaskIntoConstraints = false
            h5HeaderView.backgroundColor = STWebCommonConfig.sharedInstance().naviBarColor
            view.addSubview(h5HeaderView)

            h5BackButton.translatesAutoresizingMaskIntoConstraints = false
            h5BackButton.accessibilityLabel = "Back"
            h5BackButton.addTarget(self, action: #selector(STWebH5Crl.back), for: .touchUpInside)
            // Keep the button as the hit target. The visible image is an
            // independent UIImageView, exactly as the capsule/tool icons.
            h5BackImageView.translatesAutoresizingMaskIntoConstraints = false
            h5BackImageView.contentMode = .scaleAspectFit
            let backImage = STWebResourceManager.imageNamed(name: "back")
            h5BackImageView.image = backImage
            if backImage == nil {
                STProjectHelper.Log("STWebH5Crl 返回图标 back 未找到")
            }
            h5HeaderView.addSubview(h5BackImageView)
            h5HeaderView.addSubview(h5BackButton)

            h5HeaderView.addSubview(h5TitleLabel)
            NSLayoutConstraint.activate([
                h5HeaderView.topAnchor.constraint(equalTo: view.topAnchor),
                h5HeaderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                h5HeaderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                h5HeaderView.heightAnchor.constraint(equalToConstant: STScreenHelper.ST_navigationFullHeight()),
                h5BackButton.leadingAnchor.constraint(equalTo: h5HeaderView.leadingAnchor, constant: 6),
                h5BackButton.bottomAnchor.constraint(equalTo: h5HeaderView.bottomAnchor),
                h5BackButton.widthAnchor.constraint(equalToConstant: STScreenHelper.ST_navigationBarHeight()),
                h5BackButton.heightAnchor.constraint(equalToConstant: STScreenHelper.ST_navigationBarHeight()),
                h5BackImageView.centerXAnchor.constraint(equalTo: h5BackButton.centerXAnchor),
                h5BackImageView.centerYAnchor.constraint(equalTo: h5BackButton.centerYAnchor),
                h5BackImageView.widthAnchor.constraint(equalToConstant: 24),
                h5BackImageView.heightAnchor.constraint(equalToConstant: 24),
                h5TitleLabel.leadingAnchor.constraint(equalTo: h5BackButton.trailingAnchor, constant: 8),
                h5TitleLabel.trailingAnchor.constraint(equalTo: h5HeaderView.trailingAnchor, constant: -(STScreenHelper.ST_navigationBarHeight() + 8)),
                h5TitleLabel.bottomAnchor.constraint(equalTo: h5HeaderView.bottomAnchor),
                h5TitleLabel.heightAnchor.constraint(equalToConstant: STScreenHelper.ST_navigationBarHeight())
            ])
            
            if config.openSource == .h5 {
                
                
            }
        }
        
        
        
        
        
        
        
        
        
        
        
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        shouldReleaseWebRuntimeAfterDisappear = false
        onlineWebLifecycle.didAppear()
        onlineWebOwner?.didAppear()
        retryH5NavigationWhenVisibleIfNeeded()
        STWebApiManager.sendScriptMessageWithMethod("pageWillAppear", params: [:], webview: webView)
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        onlineWebLifecycle.didDisappear()
        onlineWebOwner?.didDisappear()
        // Do not reload a page that is currently covered or being popped.
        // The monitor remains active and `viewWillAppear` resumes recovery.
        networkNavigationRetryToken = nil
        shouldReleaseWebRuntimeAfterDisappear = shouldReleaseWebRuntimeWhenDisappearing()
        // Preserve the existing H5 lifecycle contract for every disappearance,
        // including a hard pop/dismiss. The actual WebView teardown happens
        // after the transition completes in `viewDidDisappear`.
        STWebApiManager.sendScriptMessageWithMethod("pageWillDisAppear", params: [:], webview: webView)
    }

    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // Do not clean up merely because another controller was pushed above
        // this one: that page may still be returned to.  Cleanup is only for
        // a pop/dismiss (including dismissal of the containing navigation
        // controller), where this ordinary H5 page cannot be reused.
        if shouldReleaseWebRuntimeAfterDisappear || shouldReleaseWebRuntimeWhenDisappearing() {
            releaseWebRuntimeIfNeeded(reason: "controller_disappeared")
        }
    }
    
    func listView() -> UIView {
        return self.view
    }
    
    deinit {
        releaseWebRuntimeIfNeeded(reason: "controller_deinit")
        STProjectHelper.Log("crl释放")
    }

    private func releaseWebRuntimeIfNeeded(reason: String) {
        guard !hasReleasedWebRuntime else { return }
        hasReleasedWebRuntime = true
        onlineWebLifecycle.release()
        onlineWebOwner?.release()
        onlineWebOwner = nil

        removeOnlineApplicationLifecycleObservers()
        NotificationCenter.default.removeObserver(self)
        observation = nil
        stopNetworkRecovery()

        // `STMiniWebView.cleanup()` stops loading, removes the JS bridge and
        // clears WebKit delegates before the controller is released.  Do not
        // evaluate JavaScript here: an asynchronous teardown callback can
        // prolong the lifetime of a page that has already been popped.
        let currentWebView = webView
        currentWebView?.cleanup()
        currentWebView?.removeFromSuperview()
        webView = nil
        STProjectHelper.Log("STWebH5Crl 退出并释放 WebView 运行时，原因: \(reason)")
    }

    private func isLeavingNavigationStack() -> Bool {
        isBeingDismissed ||
            isMovingFromParent ||
            navigationController?.isBeingDismissed == true ||
            navigationController?.isMovingFromParent == true ||
            parent?.isBeingDismissed == true ||
            parent?.isMovingFromParent == true
    }

    private func shouldReleaseWebRuntimeWhenDisappearing() -> Bool {
        if !isMiniInternalPage {
            return isLeavingNavigationStack()
        }

        // A Mini-owned H5 page is retained only when the root navigation
        // controller is cached as a whole.  If this child itself is popped,
        // it cannot be reused and must release independently.
        return isMovingFromParent
    }
    
    
    
    
    private func shouldShowNavigationBar() -> Bool {
        
        return STOnlineWebCore.shouldShowNavigationBar(config.params?["isNeedNavigationBar"])
    }

    private func installOnlineApplicationLifecycleObservers() {
        let notifications = NotificationCenter.default
        onlineAppHideObserver = notifications.addObserver(
            forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, !self.hasReleasedWebRuntime else { return }
            self.onlineBackgroundEnteredAt = Date()
            STWebApiManager.sendScriptMessageWithMethod("appHide", params: [:], webview: self.webView)
        }
        onlineAppShowObserver = notifications.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, !self.hasReleasedWebRuntime, self.isVisibleOnlineWebPage else { return }
            let duration = self.onlineBackgroundEnteredAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0
            self.onlineBackgroundEnteredAt = nil
            STWebApiManager.sendScriptMessageWithMethod("appShow", params: [
                "backgroundDurationMs": max(0, duration),
                "recoveryMode": "visible_resume",
            ], webview: self.webView)
        }
    }

    private func removeOnlineApplicationLifecycleObservers() {
        let notifications = NotificationCenter.default
        if let onlineAppHideObserver { notifications.removeObserver(onlineAppHideObserver) }
        if let onlineAppShowObserver { notifications.removeObserver(onlineAppShowObserver) }
        onlineAppHideObserver = nil
        onlineAppShowObserver = nil
    }

    private var isVisibleOnlineWebPage: Bool {
        guard isViewLoaded, view.window != nil, !isBeingDismissed else { return false }
        guard let navigationController else { return true }
        return navigationController.visibleViewController === self && !navigationController.isBeingDismissed
    }

}


extension STWebH5Crl {
    
    @objc private func updateUserInfo(_ notification: Notification) {
        if isShow {
            STWebApiManager.sendScriptMessageWithMethod("updateUserInfo", params: [:], webview: webView)
        }
    }
    
}

extension STWebH5Crl {
    
    
    public func webviewDidFinish() {
        isRecoveringTerminatedWebContentProcess = false
        terminatedWebContentProcessRecoveryToken = nil
        stopNetworkRecovery()
        progressView?.isHidden = true
    }

    public func webviewDidFailNavigation(_ error: NSError) {
        guard !hasReleasedWebRuntime,
              webView != nil,
              isShow,
              isNetworkNavigationError(error) else {
            return
        }

        // WKWebView may report both provisional and final failure for the
        // same navigation. One pending retry is enough.
        guard networkNavigationRetryToken == nil else { return }
        scheduleNetworkNavigationRetry(reason: "\(error.domain)(\(error.code))")
    }

    private func isNetworkNavigationError(_ error: NSError) -> Bool {
        guard error.domain == NSURLErrorDomain else { return false }
        switch error.code {
        case NSURLErrorTimedOut,
             NSURLErrorCannotFindHost,
             NSURLErrorCannotConnectToHost,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorDNSLookupFailed,
             NSURLErrorNotConnectedToInternet,
             NSURLErrorInternationalRoamingOff,
             NSURLErrorCallIsActive,
             NSURLErrorDataNotAllowed:
            return true
        default:
            return false
        }
    }

    private func scheduleNetworkNavigationRetry(reason: String) {
        waitingForNetworkRecovery = true
        startNetworkRecoveryMonitorIfNeeded()

        guard networkNavigationRetryCount < Self.networkNavigationRetryDelays.count else {
            STProjectHelper.Log("STWebH5Crl H5 网络重试已用尽，等待网络恢复 path_change reason=\(reason)")
            return
        }

        let delay = Self.networkNavigationRetryDelays[networkNavigationRetryCount]
        let token = UUID()
        networkNavigationRetryToken = token
        networkNavigationRetryCount += 1
        STProjectHelper.Log("STWebH5Crl H5 网络加载失败，准备重试 \(networkNavigationRetryCount)/\(Self.networkNavigationRetryDelays.count) delay=\(delay)s reason=\(reason)")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self,
                  self.networkNavigationRetryToken == token,
                  self.isShow,
                  !self.hasReleasedWebRuntime,
                  self.webView != nil else { return }
            self.networkNavigationRetryToken = nil
            self.webView.reload()
        }
    }

    private func startNetworkRecoveryMonitorIfNeeded() {
        guard networkRecoveryMonitor == nil else { return }
        let monitor = NWPathMonitor()
        networkRecoveryMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self else { return }
                let didRecover = self.lastObservedNetworkPathStatus != nil
                    && self.lastObservedNetworkPathStatus != .satisfied
                    && path.status == .satisfied
                self.lastObservedNetworkPathStatus = path.status
                guard didRecover,
                      self.waitingForNetworkRecovery,
                      self.isShow,
                      !self.hasReleasedWebRuntime,
                      self.webView != nil else { return }
                self.networkNavigationRetryToken = nil
                self.networkNavigationRetryCount = 0
                self.waitingForNetworkRecovery = false
                STProjectHelper.Log("STWebH5Crl 检测到网络恢复，重新加载 H5")
                self.webView.reload()
            }
        }
        monitor.start(queue: networkRecoveryQueue)
    }

    private func retryH5NavigationWhenVisibleIfNeeded() {
        guard waitingForNetworkRecovery,
              networkNavigationRetryToken == nil,
              !hasReleasedWebRuntime,
              webView != nil else { return }
        networkNavigationRetryCount = 0
        waitingForNetworkRecovery = false
        STProjectHelper.Log("STWebH5Crl 页面重新可见，重试 H5 加载")
        webView.reload()
    }

    private func stopNetworkRecovery() {
        networkNavigationRetryToken = nil
        networkNavigationRetryCount = 0
        waitingForNetworkRecovery = false
        lastObservedNetworkPathStatus = nil
        networkRecoveryMonitor?.cancel()
        networkRecoveryMonitor = nil
    }

    /// This is also invoked for Mini-owned `open({ router: "/web" })` pages.
    /// Reload the exact approved page instead of leaving the dead WKWebView
    /// white.  Two terminations in a short window are treated as a bad page or
    /// an unrecoverable renderer loop and safely leave the affected page.
    public func webviewContentProcessDidTerminate() {
        guard !hasReleasedWebRuntime,
              webView != nil else { return }

        // A second system callback means the reload itself lost its content
        // process. It supersedes the pending timeout and consumes the second
        // recovery attempt instead of leaving a white page until that timeout.
        if isRecoveringTerminatedWebContentProcess {
            isRecoveringTerminatedWebContentProcess = false
            terminatedWebContentProcessRecoveryToken = nil
        }

        let now = Date()
        if let previous = lastTerminatedWebContentProcessRecoveryAt,
           now.timeIntervalSince(previous) > Self.terminatedWebContentProcessRecoveryWindow {
            terminatedWebContentProcessRecoveryCount = 0
        }
        lastTerminatedWebContentProcessRecoveryAt = now
        terminatedWebContentProcessRecoveryCount += 1

        guard terminatedWebContentProcessRecoveryCount <= 2 else {
            fallbackFromRepeatedWebContentTermination()
            return
        }

        isRecoveringTerminatedWebContentProcess = true
        let token = UUID()
        terminatedWebContentProcessRecoveryToken = token
        STProjectHelper.Log("STWebH5Crl Web 内容进程已终止，重载当前页面 attempt=\(terminatedWebContentProcessRecoveryCount)")
        webView.reload()

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.terminatedWebContentProcessRecoveryTimeout) { [weak self] in
            guard let self = self,
                  self.terminatedWebContentProcessRecoveryToken == token,
                  self.isRecoveringTerminatedWebContentProcess else { return }
            // `webViewDidFinish` did not arrive. Retry once through the same
            // bounded recovery path; the third failed attempt falls back.
            self.isRecoveringTerminatedWebContentProcess = false
            self.terminatedWebContentProcessRecoveryToken = nil
            self.webviewContentProcessDidTerminate()
        }
    }

    private func fallbackFromRepeatedWebContentTermination() {
        isRecoveringTerminatedWebContentProcess = false
        terminatedWebContentProcessRecoveryToken = nil
        let message: String
        if isMiniInternalPage {
            message = STMiniLocalized("mini.page_recovery_failed_home", "页面恢复失败，已返回小程序首页")
            STProjectHelper.Log("STWebH5Crl Mini 二级页恢复失败，返回小程序首页")
        } else {
            message = STMiniLocalized("mini.page_recovery_failed_previous", "页面恢复失败，已返回上一页")
            STProjectHelper.Log("STWebH5Crl 普通 H5 页面恢复失败，返回上一页")
        }
        if let apiHandle = STWebPersonalHandle.sharedInstance().apiHandle,
           let webView = webView {
            _ = apiHandle(["method": "showToast", "params": ["title": message, "duration": 2]], webView)
        }
        if isMiniInternalPage {
            navigationController?.popViewController(animated: true)
        } else {
            back()
        }
    }
    
    public func close() {
        self.back()
    }
    
}


extension STWebH5Crl {
    
    @objc func back(){
        let isRoot = navigationController?.children.first == self
        switch STOnlineWebCore.closeAction(isRootOfNavigationStack: isRoot) {
        case .dismissPresentation:
            dismiss(animated: true, completion:nil)
        case .popNavigation:
            navigationController?.popViewController(animated: true)
        }
    }
    
    @objc func more(){
        let toolView = STWebToolView.init(frame: CGRectMake(0, 0, view.ST_width, 200), items: [["title": "刷新", "imgStr": "tool_shuaxin", "key": "refresh"], ["title": "复制链接", "imgStr": "tool_lianjie", "key": "copy"]])
        let popConfig = HLPopConfig()
        popConfig.popBackColor = .ST_hex("#E8E8E8")
        popConfig.cornerRadius = 10
        popConfig.corner = [UIRectCorner.topLeft,UIRectCorner.topRight]
        HLPopViewController().showBottomPopView(toolView, config: popConfig) { [weak self] info, isCancel in
            if isCancel != true {
                if info["key"] != nil {
                    
                    let key = info["key"] as! String
                    STProjectHelper.Log("toolView点击-\(key)")
                    if key == "refresh" {
                        
                        self?.webView.reload()
                        
                        self?.progressView?.isHidden = false
                        self?.progressView?.progress = 0.05
                    }
                    else if key == "copy" {
                    }
                }
            }
        }
    }
    
}
