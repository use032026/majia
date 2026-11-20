







import UIKit


@objc open class STWebMiniprogramCrl: STViewController, STWebCrlProtocol {
    
    public var webView: STMiniWebView!
    
    public var config: STWebConfig!
    
    public var name: String! = ""
    /// Stable package identity for host-side adapters.  Expose an explicit
    /// Objective-C bridge instead of relying on KVC for Swift-only `name`.
    @objc public var miniProgramId: String {
        return STWebResourceManager.miniNameHandle(name: name).0 ?? ""
    }
    fileprivate var isShow: Bool = false
    public var isChild: Bool = false
    /// The process lifecycle belongs to the one Mini root currently shown by
    /// the host, not to every retained WebView in the keep-alive pool.  A
    /// child page keeps its root selected so its underlying Mini runtime still
    /// receives the host event while the child is on top.
    private static weak var currentHostMiniRoot: STWebMiniprogramCrl?


    fileprivate var interactive: STWebTransInteractive!

    fileprivate lazy var transAnimation: STWebTransAnimation = {
        let trans = STWebTransAnimation(transType: .present)
        trans.completion = { [weak self] transType, succeeded in
            self?.handleTransitionCompletion(type: transType, succeeded: succeeded)
        }
        return trans
    }()
    
    fileprivate var loadAnimationView: STWebMiniLoadAnimate?
    /// An online Mini must let its native loading layer reach the first frame
    /// before it starts package resolution/download. Starting work from
    /// `viewDidLoad` races a modal presentation (notably from Flutter) and
    /// can leave users looking at a blank white controller while the ZIP is
    /// already transferring.
    private var hasStartedInitialOnlinePackageLoad = false
    private var hasEmittedCloseEvent = false
    /// A loading view is owned by one root-document navigation, never by an
    /// arbitrary WebKit completion.  In particular, `WKNavigation` objects
    /// are not exposed through `STWebCrlProtocol`, so the ticket is armed
    /// only after `stopLoading()` has retired the previous navigation and is
    /// accepted only after the successor has entered and left loading.
    private enum RootMiniDocumentTrust {
        /// The entry returned by the verified installed-package manifest.
        case installed
        /// A host-bundled Mini root loaded with WKWebView's explicit read
        /// access directory.  The source URL is created by
        /// `localMiniProgramPath`, never by page navigation.
        case bundled(allowingReadAccessTo: URL)
    }
    private struct RootMiniDocumentLoadTicket {
        let generation: UInt
        let expectedURL: URL
        let trust: RootMiniDocumentTrust
        var observedSuccessorLoading = false
    }
    private var rootMiniDocumentGeneration: UInt = 0
    private var rootMiniDocumentTicket: RootMiniDocumentLoadTicket?
    private var rootMiniDocumentReadyGeneration: UInt?
    private var rootMiniLoadingObservation: NSKeyValueObservation?
    /// Only a self-managed forced update supplies an explicit native retry.
    /// Its source URL is not necessarily present in the original Grid link.
    private var onlineLoadingRetryAction: (() -> Void)?
    /// Set only by the capsule's explicit refresh action.  A normal close or
    /// interactive dismissal remains eligible for keep-alive.
    /// Version of the package that this WebView actually loaded.  The keep-
    /// alive pool compares it with disk before reusing the runtime so a newly
    /// installed package is always picked up on the next cold launch.
    private(set) var loadedMiniPackageVersion: String?
    private(set) var loadedMiniPackageIdentity: STWebMiniPackageIdentity?
    private(set) var loadedRuntimeSessionGeneration: UInt64 = 0
    private(set) var isRuntimeRetainedHidden = false
    private var hasReleasedRuntime = false
    var skipsKeepAliveOnNextDismiss = false
    /// An active Mini runtime is usable only after its first document
    /// has completed and while WKWebView's content process is still alive.
    /// iOS may terminate a background Web Content process; presenting that
    /// retained WebView again otherwise results in a permanent white page.
    private(set) var isKeepAliveRuntimeUsable = false
    /// The Web Content process may be killed while this controller is still
    /// visible. Reuse is no longer safe, but retain a one-shot notification
    /// so the cold-loaded Mini can explain the recovery after it renders.
    private var isRecoveringTerminatedWebContentProcess = false
    private static let terminatedProcessToastKeyPrefix = "STMini.TerminatedWebContentProcessToast."
    /// WebKit can defer `webViewWebContentProcessDidTerminate` until the next
    /// interaction after the App wakes. Track the background transition and
    /// probe the visible Mini after a short grace period. A probe timeout is
    /// not proof that the Web Content process died: iOS can still be restoring
    /// a healthy WebView, so only WebKit's real termination callback starts a
    /// cold recovery and shows the termination notice.
    private var backgroundEnteredAt: Date?
    private var lastBackgroundDurationMs = 0
    private var warmActivationGeneration: UInt64 = 0
    private var needsWarmVisibilityActivation = false
    private struct WarmActivationTicket {
        weak var webView: STMiniWebView?
        weak var navigation: UINavigationController?
        weak var window: UIWindow?
        let documentGeneration: UInt64
        let documentURL: URL
        let sessionGeneration: UInt64
        let activationGeneration: UInt64
        let stack: [ObjectIdentifier]
    }
    private var foregroundProcessProbeID: UUID?
    private static let foregroundProcessProbeInitialDelay: TimeInterval = 1.5
    private static let foregroundProcessProbeTimeout: TimeInterval = 1.2
    private static let foregroundProcessProbeRetryDelay: TimeInterval = 0.35
    private static let foregroundProcessProbeMaxAttempts = 2

    private var hostOperationID: String? {
        guard let value = miniParameter("__st_operation_id"), !value.isEmpty else { return nil }
        return value
    }

    private func emitHostEvent(_ name: String, _ payload: [String: Any] = [:]) {
        var event = payload
        event["miniId"] = miniProgramId
        if let hostOperationID {
            event["operationId"] = hostOperationID
        }
        StminiFlutterPlugin.emitMiniRuntimeEvent(name, payload: event)
    }
    
    fileprivate var capsuleBar: STWebMiniprogramCapsuleBar!
    
    fileprivate lazy var titleLbl: UILabel = {
        let lbl  = UILabel.init(frame: CGRectMake(0, 0, 200, 40))
        lbl.textAlignment = .center;
        lbl.backgroundColor = .clear;
        lbl.font = UIFont.boldSystemFont(ofSize: 16)
        lbl.textColor = .black
        return lbl
    }()
    open override var title: String? {
        get {
            return self.titleLbl.text
        }
        set {
            self.titleLbl.text = newValue
        }
    }
    
    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if #available(iOS 13.0, *) {
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                STWebApiManager.sendScriptMessageWithMethod("darkModeChanged", params: [:], webview: webView)
            }
        }
    }
    
    @objc public init(name: String!, config: STWebConfig!, isChild: Bool) {
        super.init(nibName: nil, bundle: nil)
        self.name = name
        self.config = config
        self.isChild = isChild
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateUserInfo(_:)),
            name: Notification.Name(STWebPersonalHandle.sharedInstance().noti_updateUserInfo),
            object: nil
        )
        // Login state and the selected trading account both change the scope
        // of a Quant Mini session.  The Mini must fail closed immediately,
        // rather than keep workers alive until its periodic session refresh.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(quantSessionDidChange(_:)),
            // STLoginSuccessNotification from the host notification contract.
            name: Notification.Name("kSTLoginSuccessNotification"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(quantSessionDidChange(_:)),
            // STMini is a standalone Pod and cannot import the host's
            // STCore symbol directly; this is STChangeAccountSuccessNotification.
            name: Notification.Name("kSTChangeAccountSuccessNotification"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(quantSessionDidChange(_:)),
            // STLogoutSuccessNotification from the host notification contract.
            name: Notification.Name("kSTLogoutSuccessNotification"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hostLocaleDidChange(_:)),
            // STLanguageDidChangedNotification from the host notification contract.
            name: Notification.Name("kCmsLanguageDidChangedNotification"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground(_:)),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive(_:)),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        navigationItem.titleView = titleLbl
        
        
        webView = STMiniWebView(frame: .zero, bindCrl: self)
        // The root only receives this capability after its document resolves
        // to a verified installed `stmini://` resource (or a bundled local
        // Mini). `STMiniWebView` validates that concrete URL on every call.
        webView.configureBridgePolicy(.localMini)
        observeRootMiniDocumentLoading()
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        
        if config.webMode == .online {
            if shouldShowTabbar() {
                NSLayoutConstraint.activate([
                    webView.topAnchor.constraint(equalTo: view.topAnchor),
                    webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
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
        }
        else {
            if shouldShowNavigationBar() {
                if shouldShowTabbar() {
                    NSLayoutConstraint.activate([
                        webView.topAnchor.constraint(equalTo: view.topAnchor, constant: STScreenHelper.ST_navigationFullHeight()),
                        webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                        webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                        webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
                    ])
                }
                else {
                    NSLayoutConstraint.activate([
                        webView.topAnchor.constraint(equalTo: view.topAnchor, constant: STScreenHelper.ST_navigationFullHeight()),
                        webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                        webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                    ])
                }
            }
            else {
                if shouldShowTabbar() {
                    NSLayoutConstraint.activate([
                        webView.topAnchor.constraint(equalTo: view.topAnchor),
                        webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                        webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                        webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
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
            }
        }
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        self.edgesForExtendedLayout = .all
        self.extendedLayoutIncludesOpaqueBars = true
        
        
        let (miniName, _) = STWebResourceManager.miniNameHandle(name: name)
        // Never expose an uninitialized white WebView for a Mini's first
        // page. This one native loading layer covers local-file loading,
        // version checks, downloads and the first H5 document load; it is
        // removed only when `webviewDidFinish` is received.
        if !isChild, let miniId = miniName, !miniId.isEmpty {
            beginOnlineMiniLoading(miniId: miniId)
        }
        if config.webMode != .online {
            
            
            let (miniPath, toPath) = STWebResourceManager.localMiniProgramPath(name: name)
            if miniPath!.count > 0 {
                let baseURL = URL(string: miniPath!)!
                let toURL = URL(string: toPath!)!
                
                if let path = config.path, !path.isEmpty {
                    
                    var fragment = path
                    
                    
                    if let params = config.params, !params.isEmpty {
                        let queryString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
                        fragment += "?" + queryString
                    }
                    
                    
                    if var components = URLComponents(string: miniPath!) {
                        components.fragment = fragment
                        if let finalURL = components.url {
                            STProjectHelper.Log("使用WebConfig拼接的URL: \(finalURL.absoluteString)")
                            loadBundledRootMiniDocument(finalURL, allowingReadAccessTo: toURL)
                        } else {
                            
                            let fallbackURLString = miniPath! + "#" + fragment
                            if let fallbackURL = URL(string: fallbackURLString) {
                                loadBundledRootMiniDocument(fallbackURL, allowingReadAccessTo: toURL)
                            } else {
                                loadBundledRootMiniDocument(baseURL, allowingReadAccessTo: toURL)
                            }
                        }
                    }
                } else {
                    
                    loadBundledRootMiniDocument(baseURL, allowingReadAccessTo: toURL)
                }
            } else {
                STProjectHelper.Log("本地小程序\(miniName!)找不到 \n 路径：\(miniPath!)")
                if !isChild {
                    finishOnlineLoading(message: STMiniLocalized("mini.local_package_missing", "小程序本地包不存在"))
                }
            }
        }
        
        if config.webMode == .online || shouldPresentAsMiniProgram() {
            refreshRootMiniChrome()
        } else {
            
            if shouldShowNavigationBar() {
                view.addSubview(naviView)
                naviView.backgroundColor = STWebCommonConfig.sharedInstance().naviBarColor
                addNaviBtn(image: STWebResourceManager.imageNamed(name: "back"), position: .left, action: #selector(back))
            }
        }
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasEmittedCloseEvent = false
        isShow = !isRuntimeRetainedHidden
        if !isChild && !isRuntimeRetainedHidden {
            Self.currentHostMiniRoot = self
        }
        STWebApiManager.sendScriptMessageWithMethod("pageWillAppear", params: [:], webview: webView)
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !isRuntimeRetainedHidden, !hasReleasedRuntime else { return }
        startInitialOnlinePackageLoadIfNeeded()
        installRootInteractiveDismissalIfNeeded()
        // STMini's original full-screen interactive dismissal is owned by
        // the first page. Nested mini pages remain normal navigation pushes.


    }

    private func startInitialOnlinePackageLoadIfNeeded() {
        guard !isChild,
              config.webMode == .online,
              !hasStartedInitialOnlinePackageLoad else {
            return
        }
        hasStartedInitialOnlinePackageLoad = true
        // The presentation has completed, so the loading ring/name have been
        // rendered before URLSession, verification and unpacking begin.
        DispatchQueue.main.async { [weak self] in
            self?.loadOnlineMiniPackage()
        }
    }
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isShow = false
        STWebApiManager.sendScriptMessageWithMethod("pageWillDisAppear", params: [:], webview: webView)
        if !isChild,
           (isBeingDismissed || navigationController?.isBeingDismissed == true) {
            prepareForNativeDismissal()

        }
        if !isChild,
           (isBeingDismissed || navigationController?.isBeingDismissed == true),
           Self.currentHostMiniRoot === self {
            Self.currentHostMiniRoot = nil
        }

    }

    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // A detached root no longer receives application lifecycle events.
        clearCurrentHostMiniRootIfNeeded()
        guard !isChild, !skipsKeepAliveOnNextDismiss,
              let navigation = navigationController as? STWebNavigationController,
              navigation.presentingViewController == nil, navigation.view.window == nil else { return }
        STWebMiniProgramKeepAliveStore.shared.cache(self, navigationController: navigation)
    }
    
    deinit {

        if Self.currentHostMiniRoot === self {
            Self.currentHostMiniRoot = nil
        }
        NotificationCenter.default.removeObserver(self)
        
        
        // UIKit may release an unpresented controller before viewDidLoad.
        // Teardown owns only optional native cleanup, never asynchronous JS
        // or a forced view load that could extend a canceled page's lifetime.
        STProjectHelper.Log("crl释放")
        let currentWebView = webView
        currentWebView?.cleanup()
        currentWebView?.removeFromSuperview()
        webView = nil
    }
    
    
    
    
    private func shouldShowNavigationBar() -> Bool {
        
        if let params = config.params,
           let isNeedNavigationBar = params["isNeedNavigationBar"] {
            
            
            let lowercased = isNeedNavigationBar.lowercased()
            return lowercased == "1" || lowercased == "true" || lowercased == "yes"
        }
        
        
        return false
    }
    
    
    private func shouldShowTabbar() -> Bool {
        
        if let params = config.params {
            if let isOnTabbar = params["isOnTabbar"] {
                
                let stringValue: String
                if let str = isOnTabbar as? String {
                    stringValue = str
                } else if let num = isOnTabbar as? NSNumber {
                    
                    if CFGetTypeID(num) == CFBooleanGetTypeID() {
                        stringValue = num.boolValue ? "1" : "0"
                    } else {
                        stringValue = num.stringValue
                    }
                } else {
                    stringValue = String(describing: isOnTabbar)
                }
                
                
                let lowercased = stringValue.lowercased()
                return lowercased == "1" || lowercased == "true" || lowercased == "yes"
            }
        }
        
        
        return false
    }

    private func shouldPresentAsMiniProgram() -> Bool {
        guard let value = config.params?["presentAsMiniProgram"]?.lowercased() else {
            return false
        }
        return value == "1" || value == "true" || value == "yes"
    }

    /// `ishome` is a package-owned, root-only policy.  It is deliberately not
    /// read from `config.params`: Grid/QR links are untrusted presentation
    /// metadata and must not change close behaviour.
    private func isHomeMiniProgram() -> Bool {
        STWebResourceManager.miniPackageIsHome(name: name)
    }

    private func refreshRootMiniChrome() {
        guard !isChild,
              (config.webMode == .online || shouldPresentAsMiniProgram()) else { return }
        // A first online launch has no verified manifest until the download
        // completes. Keep the loader clean and create normal chrome only once
        // a package was selected.
        if config.webMode == .online,
           !STWebResourceManager.isInstalledMiniPackageUsable(name: name) {
            capsuleBar?.removeFromSuperview()
            return
        }
        if isHomeMiniProgram() {
            interactive?.invalidate()
            interactive = nil
            capsuleBar?.removeFromSuperview()
            STProjectHelper.Log("小程序<\(miniProgramId)>启用 ishome，隐藏根页胶囊并禁用侧滑关闭")
        } else {
            initialCapsuleBar()
        }
    }



    private func installRootInteractiveDismissalIfNeeded() {
        guard !isChild,
              navigationController?.viewControllers.first === self,
              interactive == nil,
              (config.webMode != .online || STWebResourceManager.isInstalledMiniPackageUsable(name: name)),
              !isHomeMiniProgram() else {
            return
        }
        interactive = STWebTransInteractive(target: self)
    }

    private func loadOnlineMiniPackage() {
        guard let miniId = STWebResourceManager.miniNameHandle(name: name).0 else {
            finishOnlineLoading(message: "Invalid Mini identifier")
            return
        }
        guard !STWebResourceManager.requestsPackageMutation(parameters: config.params) else {
            finishOnlineLoading(message: "Mini package downloads, installation and updates are unsupported")
            return
        }
        guard STWebResourceManager.isInstalledMiniPackageRunnable(name: miniId,
            currentVersion: miniParameter("currentVersion"), minSupportVersion: miniParameter("minSupportVersion")) else {
            finishOnlineLoading(message: "No verified local Mini package meets the required version")
            return
        }
        if let icon = miniParameter("iconUrl"), !isValidHTTPURL(icon) {
            finishOnlineLoading(message: "Invalid Mini icon URL")
            return
        }
        beginOnlineMiniLoading(miniId: miniId)
        openOnlineMiniPackage()
    }

    private func miniParameter(_ key: String) -> String? {
        guard let value = config.params?[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    private func isValidHTTPURL(_ value: String) -> Bool {
        guard let url = URL(string: value) else { return false }
        return isValidHTTPURL(url)
    }

    private func isValidHTTPURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              let host = url.host?.trimmingCharacters(in: .whitespacesAndNewlines),
              !host.isEmpty else {
            return false
        }
        return true
    }





    /// Handles a package update requested by the currently running Mini.
    /// The caller can supply a URL but can never select another miniId or pass
    /// a version: the active controller and downloaded verified manifest are
    /// authoritative. `isForce` is the only behavioural switch: forced
    /// updates cover the current WebView with the native loading view and only
    /// resume after the downloaded package has passed validation and loaded.


    /// Loading starts before the mini package is available, so the host must
    /// select the display name directly from the unified mini:// link. The
    /// App language, not the device region, decides whether miniNameEn wins.
    private func isCurrentAppLanguageChinese() -> Bool {
        let savedLanguage = UserDefaults.standard.string(forKey: "STLanguageCode") ?? ""
        let language = (savedLanguage.isEmpty ? (Locale.preferredLanguages.first ?? "") : savedLanguage)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return language == "zh" || language.hasPrefix("zh-") || language.hasPrefix("zh_")
    }

    /// Link identity is presentation-only.  It cannot change the package
    /// selected by `STWebResourceManager`, whose manifest remains the source
    /// of package identity.  For a missing localized link field prefer the
    /// same-language verified manifest before falling back to the other link
    /// field, so an English host does not unnecessarily show a Chinese name.
    private func suppliedLocalizedLoadingMiniName() -> String? {
        isCurrentAppLanguageChinese() ? miniParameter("miniName") : miniParameter("miniNameEn")
    }

    private func suppliedFallbackLoadingMiniName() -> String? {
        isCurrentAppLanguageChinese() ? miniParameter("miniNameEn") : miniParameter("miniName")
    }

    private func beginOnlineMiniLoading(miniId: String) {
        guard loadAnimationView == nil else { return }
        invalidateRootMiniDocumentLoad()
        let loadingAnimation = initialLoadAnimationView()
        let loadingView = loadingAnimation as! UIView
        loadingView.frame = view.bounds
        loadingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // This screen represents a Mini runtime handoff, not a translucent
        // progress hint. It must conceal the outgoing H5 and its dialogs.
        loadingView.backgroundColor = .systemBackground
        loadingView.isOpaque = true
        loadAnimationView = loadingAnimation
        view.addSubview(loadingView)
        view.bringSubviewToFront(loadingView)
        updateLoadAnimationIdentity(miniId: miniId)
        loadRemoteLoadAnimationIcon(miniId: miniId)
    }





    /// The URLSession temporary file is only valid for the lifetime of this
    /// delegate callback. Copy it on the callback queue, then return to the
    /// main queue for all controller state and UI work.






    /// A LAN QR may be opened while the device is still establishing its first
    /// connection to the local server. Retry that transport step once before
    /// showing an error; package validation/install errors must never retry or
    /// fall back because they indicate a real package problem.






    /// A QR may be temporarily unreachable after this mini program has
    /// already been installed. Download failure is not an integrity failure,
    /// so a previously verified package remains a safe fallback. Archives
    /// that did download but fail manifest/install validation never use this
    /// path and are still reported as installation failures.


    private func observeRootMiniDocumentLoading() {
        rootMiniLoadingObservation = webView.observe(\.isLoading, options: [.new]) { [weak self] _, change in
            guard change.newValue == true else { return }
            guard let self,
                  var ticket = self.rootMiniDocumentTicket,
                  ticket.generation == self.rootMiniDocumentGeneration else {
                return
            }
            // The ticket is installed after `stopLoading()` and directly
            // before this root request.  A successor navigation becoming
            // loading is the generation boundary that an old same-URL
            // `didFinish` cannot cross.
            ticket.observedSuccessorLoading = true
            self.rootMiniDocumentTicket = ticket
        }
    }

    private func invalidateRootMiniDocumentLoad() {
        rootMiniDocumentGeneration &+= 1
        rootMiniDocumentTicket = nil
        rootMiniDocumentReadyGeneration = nil
    }

    /// Starts a trusted root document in a fresh navigation generation.
    /// Calling `stopLoading` while no ticket is armed makes a completion from
    /// the outgoing page harmless; arming on the next main-loop turn then
    /// binds the ticket to the request we issue below.
    private func loadTrustedRootMiniDocument(
        _ url: URL,
        trust: RootMiniDocumentTrust,
        performLoad: @escaping () -> Void
    ) {
        rootMiniDocumentGeneration &+= 1
        let generation = rootMiniDocumentGeneration
        rootMiniDocumentTicket = nil
        rootMiniDocumentReadyGeneration = nil
        webView.stopLoading()
        DispatchQueue.main.async { [weak self] in
            guard let self, self.rootMiniDocumentGeneration == generation else { return }
            self.rootMiniDocumentTicket = RootMiniDocumentLoadTicket(
                generation: generation,
                expectedURL: url,
                trust: trust
            )
            performLoad()
        }
    }

    private func loadVerifiedRootMiniDocument(_ url: URL) {
        loadTrustedRootMiniDocument(url, trust: .installed) { [weak self] in
            self?.webView.load(URLRequest(url: url))
        }
    }

    private func loadBundledRootMiniDocument(_ url: URL, allowingReadAccessTo readAccessURL: URL) {
        // Child controllers have no root overlay and must preserve their
        // established direct file-navigation path.
        guard !isChild else {
            webView.loadFileURL(url, allowingReadAccessTo: readAccessURL)
            return
        }
        loadTrustedRootMiniDocument(url, trust: .bundled(allowingReadAccessTo: readAccessURL)) { [weak self] in
            self?.webView.loadFileURL(url, allowingReadAccessTo: readAccessURL)
        }
    }

    /// Pure URL portion of bundled-root verification. Kept internal so the
    /// Runner XCTest target can cover exact-root, sub-page and external-file
    /// cases without constructing a WKWebView. The caller additionally asks
    /// STMiniWebView to validate the active Mini/Bridge document.
    static func isTrustedBundledRootDocumentURL(
        _ currentURL: URL,
        expectedURL: URL,
        allowingReadAccessTo readAccessURL: URL
    ) -> Bool {
        guard currentURL == expectedURL,
              expectedURL.isFileURL,
              currentURL.isFileURL else {
            return false
        }
        let rootPath = readAccessURL.standardizedFileURL.path
        let entryPath = expectedURL.standardizedFileURL.path
        return entryPath.hasPrefix(rootPath + "/")
    }

    private func isExpectedTrustedRootMiniDocument(_ currentURL: URL, ticket: RootMiniDocumentLoadTicket) -> Bool {
        guard !isChild,
              currentURL == ticket.expectedURL,
              webView.isVerifiedCurrentRootMiniDocumentForLaunch(currentURL) else {
            return false
        }
        switch ticket.trust {
        case .installed:
            guard config.webMode == .online,
                  STWebResourceManager.isInstalledMiniPackageUsable(name: name),
                  let entry = STWebResourceManager.installedMiniPackageEntry(name: name),
                  let verifiedURL = STWebResourceManager.installedMiniPackageRootURL(name: name, entry: entry) else {
                return false
            }
            // Fragment is Mini routing state.  It must remain part of the
            // root document identity so a sub-page or redirected entry cannot
            // claim the root ticket merely because it shares a package dir.
            return ticket.expectedURL == verifiedURL
        case .bundled(let readAccessURL):
            guard config.webMode == .local else {
                return false
            }
            return Self.isTrustedBundledRootDocumentURL(
                currentURL,
                expectedURL: ticket.expectedURL,
                allowingReadAccessTo: readAccessURL
            )
        }
    }

    private func resolvedLoadingMiniName(miniId: String, fallbackName: String? = nil, useInstalledPresentation: Bool = false) -> String? {
        let suppliedLocalizedName = suppliedLocalizedLoadingMiniName()
        let suppliedFallbackName = suppliedFallbackLoadingMiniName()
        // A verified manifest may fill a missing localized link name and a
        // missing link icon independently.  Link metadata remains first only
        // for its current-language field; it never changes package identity.
        let useLocalPresentation = useInstalledPresentation ||
            STWebResourceManager.isInstalledMiniPackageUsable(name: miniId)
        let installedName = useLocalPresentation
            ? STWebResourceManager.installedMiniPackagePreferredDisplayName(
                name: miniId,
                preferEnglish: !isCurrentAppLanguageChinese()
            )
            : nil
        return suppliedLocalizedName ?? installedName ?? suppliedFallbackName ?? fallbackName
    }

    private func updateLoadAnimationIdentity(miniId: String, fallbackName: String? = nil, useInstalledPresentation: Bool = false) {
        let hasSuppliedIcon = !(config.params?["iconUrl"]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let useLocalPresentation = useInstalledPresentation ||
            STWebResourceManager.isInstalledMiniPackageUsable(name: miniId)
        let displayName = resolvedLoadingMiniName(
            miniId: miniId,
            fallbackName: fallbackName,
            useInstalledPresentation: useInstalledPresentation
        )
        let icon = !hasSuppliedIcon && useLocalPresentation
            ? STWebResourceManager.installedMiniPackageIconURL(name: miniId).flatMap { UIImage(contentsOfFile: $0.path) }
            : nil
        loadAnimationView?.updateMiniIdentity(miniId, miniName: displayName, icon: icon)
    }

    private func loadRemoteLoadAnimationIcon(miniId: String) {
        guard let iconURLString = config.params?["iconUrl"],
              let iconURL = URL(string: iconURLString),
              isValidHTTPURL(iconURL) else {
            return
        }
        URLSession.shared.dataTask(with: iconURL) { [weak self] data, _, _ in
            guard let self = self,
                  let data = data,
                  let image = UIImage(data: data) else {
                return
            }
            DispatchQueue.main.async {
                let displayName = self.resolvedLoadingMiniName(miniId: miniId)
                self.loadAnimationView?.updateMiniIdentity(miniId, miniName: displayName, icon: image)
            }
        }.resume()
    }

    private func openOnlineMiniPackage() {
        guard STWebResourceManager.isInstalledMiniPackageRunnable(
            name: name, currentVersion: miniParameter("currentVersion"),
            minSupportVersion: miniParameter("minSupportVersion")) else {
            finishOnlineLoading(message: STMiniLocalized("mini.local_package_invalid", "小程序本地包未达到最低运行版本"))
            return
        }
        guard let entry = STWebResourceManager.installedMiniPackageEntry(name: name) else {
            finishOnlineLoading(message: STMiniLocalized("mini.local_package_invalid", "小程序本地包未通过完整性校验"))
            return
        }
        guard let url = STWebResourceManager.installedMiniPackageRootURL(name: name, entry: entry) else {
            finishOnlineLoading(message: STMiniLocalized("mini.local_entry_invalid", "小程序本地入口无效"))
            return
        }
        guard let identity = STWebMiniPackageIdentity.read(miniId: miniProgramId) else {
            finishOnlineLoading(message: STMiniLocalized("mini.local_package_invalid", "小程序本地包未通过完整性校验"))
            return
        }
        loadedMiniPackageIdentity = identity
        loadedRuntimeSessionGeneration = STWebMiniProgramKeepAliveStore.shared.sessionGeneration
        loadedMiniPackageVersion = identity.version
        refreshRootMiniChrome()

        loadVerifiedRootMiniDocument(url)
    }

    private func finishOnlineLoading(message: String) {
        invalidateRootMiniDocumentLoad()
        STProjectHelper.Log(message)
        emitHostEvent("mini_open_failed", [
            "code": "open_failed",
            "message": message,
            "retryable": true,
        ])
        loadAnimationView?.finished()
        loadAnimationView = nil
        let retryAction = onlineLoadingRetryAction
        onlineLoadingRetryAction = nil

        // 在线包失败时以前只移除了加载动画，容器会呈现空白页。
        // 明确反馈原因并允许原地重试，避免扫码安装时看起来像“打开成功但白屏”。
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(title: onlineLoadingFailureTitle(for: message), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: STMiniLocalized("mini.close", "关闭"), style: .cancel) { [weak self] _ in
            self?.close()
        })
        alert.addAction(UIAlertAction(title: STMiniLocalized("mini.retry", "重试"), style: .default) { [weak self] _ in
            if let retryAction = retryAction {
                retryAction()
            } else {
                self?.loadOnlineMiniPackage()
            }
        })
        present(alert, animated: true)
    }

    private func onlineLoadingFailureTitle(for message: String) -> String {
        if message == STMiniLocalized("mini.download_timeout_detail", "小程序下载超时，网络可能较慢，请检查网络后重试") {
            return STMiniLocalized("mini.download_timeout", "小程序下载超时")
        }
        if message == STMiniLocalized("mini.download_failed_retry", "小程序下载失败，请稍后重试")
            || message == STMiniLocalized("mini.download_failed_network", "小程序下载失败，请检查网络连接后重试") {
            return STMiniLocalized("mini.download_failed", "小程序下载失败")
        }
        return STMiniLocalized("mini.open_failed", "小程序打开失败")
    }

    
}


extension STWebMiniprogramCrl {

    /// A retained hierarchy is a JavaScript runtime, never a source of native
    /// authority. Revoke every sibling before UIKit can reattach it offscreen.
    var allowsNativeRuntimeEffects: Bool { !isRuntimeRetainedHidden && !hasReleasedRuntime }

    func runtimeWebViews(in navigation: UINavigationController? = nil) -> [STMiniWebView] {
        let controllers = (navigation ?? navigationController)?.viewControllers ?? [self]
        return controllers.compactMap { controller in
            if let mini = controller as? STWebMiniprogramCrl { return mini.webView }
            return (controller as? STWebH5Crl)?.webView
        }
    }

    func prepareForNativeDismissal() {
        guard !isChild else { return }
        isRuntimeRetainedHidden = true
        isShow = false
        warmActivationGeneration &+= 1
        needsWarmVisibilityActivation = false
        // A new hidden boundary must not replay the last visible resume.
        lastBackgroundDurationMs = 0
        foregroundProcessProbeID = nil
        let preserve = isKeepAliveRuntimeUsable && !skipsKeepAliveOnNextDismiss && config.webMode == .online
        runtimeWebViews().forEach {
            $0.nativeEffectsSuspended = true
            $0.invalidateBridgeDocumentSession()
            $0.preserveRuntimeWhenDetached = preserve
        }
        if Self.currentHostMiniRoot === self { Self.currentHostMiniRoot = nil }
    }

    func setKeepAliveRuntimeHidden(_ hidden: Bool) {
        if hidden {
            prepareForNativeDismissal()
            sendHostMessage("hostMiniRuntimeVisibilityChanged", params: ["hidden": true])
            return
        }
        guard !hasReleasedRuntime,
              loadedRuntimeSessionGeneration == STWebMiniProgramKeepAliveStore.shared.sessionGeneration,
              loadedMiniPackageIdentity == STWebMiniPackageIdentity.read(miniId: miniProgramId),
              let navigation = navigationController, navigation.presentingViewController != nil,
              !navigation.isBeingDismissed, navigation.view.window != nil else {
            releaseClosedRuntime()
            navigationController?.dismiss(animated: false)
            return
        }
        isRuntimeRetainedHidden = false
        isShow = navigation.visibleViewController === self
        Self.currentHostMiniRoot = self
        hasEmittedCloseEvent = false
        runtimeWebViews().forEach {
            $0.invalidateBridgeDocumentSession()
            $0.nativeEffectsSuspended = false
            $0.preserveRuntimeWhenDetached = false
        }
        (navigation.visibleViewController as? STWebH5Crl)?.resumeAfterMiniCache()
        let backgroundDurationMs = lastBackgroundDurationMs
        lastBackgroundDurationMs = 0
        enqueueWarmActivation(backgroundDurationMs: backgroundDurationMs)
    }

    private func enqueueWarmActivation(backgroundDurationMs: Int) {
        guard let webView, let navigation = navigationController, let documentURL = webView.url,
              let window = navigation.viewIfLoaded?.window else { return }
        warmActivationGeneration &+= 1
        needsWarmVisibilityActivation = true
        let ticket = WarmActivationTicket(webView: webView, navigation: navigation, window: window,
            documentGeneration: webView.bridgeDocumentGeneration, documentURL: documentURL,
            sessionGeneration: STWebMiniProgramKeepAliveStore.shared.sessionGeneration,
            activationGeneration: warmActivationGeneration,
            stack: navigation.viewControllers.map(ObjectIdentifier.init))
        // One original-context transaction. Both calls enter the same WK
        // execution queue in visibility-before-resume order; no later layer
        // resamples a new document/session or reads the consumed duration.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isCurrentWarmActivation(ticket), let webView = ticket.webView else { return }
            self.needsWarmVisibilityActivation = false
            STWebApiManager.sendScriptMessageWithMethod("hostMiniRuntimeVisibilityChanged", params: ["hidden": false], webview: webView)
            guard self.isCurrentWarmActivation(ticket) else { return }
            STWebApiManager.sendScriptMessageWithMethod("appShow", params: ["backgroundDurationMs": backgroundDurationMs, "recoveryMode": "warm_reopen"], webview: webView)
        }
    }

    private func isCurrentWarmActivation(_ ticket: WarmActivationTicket) -> Bool {
        guard !hasReleasedRuntime, !isRuntimeRetainedHidden, Self.currentHostMiniRoot === self,
              warmActivationGeneration == ticket.activationGeneration,
              STWebMiniProgramKeepAliveStore.shared.sessionGeneration == ticket.sessionGeneration,
              loadedRuntimeSessionGeneration == ticket.sessionGeneration,
              let webView = ticket.webView, self.webView === webView,
              webView.bridgeDocumentGeneration == ticket.documentGeneration,
              webView.url == ticket.documentURL, webView.hasNativeEffectAuthority,
              let navigation = ticket.navigation as? STWebNavigationController, navigationController === navigation,
              navigation.viewControllers.first === self,
              navigation.viewControllers.map(ObjectIdentifier.init) == ticket.stack,
              let window = ticket.window, navigation.viewIfLoaded?.window === window,
              window.isKeyWindow, !window.isHidden, navigation.presentingViewController != nil,
              !navigation.isBeingDismissed, !navigation.hasForeignPresentedOwner else { return false }
        return true
    }

    func notifyHostApplicationHiddenWhileRetained() {
        guard isKeepAliveRuntimeUsable else { return }
        sendHostLifecycleMessage("appHide")
        STProjectHelper.Log("[STMini][Lifecycle] appHide delivered retained miniId=\(miniProgramId)")
    }

    func prepareForKeepAliveReuse(config: STWebConfig) {
        self.config = config
        // A warm open never downloads, installs or mutates package metadata.
        foregroundProcessProbeID = nil
    }

    func releaseClosedRuntime() {
        guard !hasReleasedRuntime else { return }
        prepareForNativeDismissal()
        hasReleasedRuntime = true
        isKeepAliveRuntimeUsable = false
        invalidateRootMiniDocumentLoad()
        interactive?.invalidate(); interactive = nil
        transAnimation.clearSnapshot()
        NotificationCenter.default.removeObserver(self)
        runtimeWebViews().forEach { $0.preserveRuntimeWhenDetached = false; $0.cleanup() }
        navigationController?.viewControllers.compactMap { $0 as? STWebH5Crl }.forEach { $0.releaseAfterMiniCache() }
    }

    @objc private func updateUserInfo(_: Notification) {
        sendHostMessage("updateUserInfo", params: [:])
        // A profile refresh is not necessarily a login or trading-account
        // boundary. Keep a retained Quant Mini running and refresh only its
        // display here. Real login/logout/account-switch notifications above
        // are routed through quantSessionDidChange instead.
    }

    @objc private func quantSessionDidChange(_: Notification) {
        runtimeWebViews().forEach { $0.invalidateBridgeDocumentSession() }
        sendHostMessage("hostQuantSessionChanged", params: [:])
    }

    @objc private func hostLocaleDidChange(_ notification: Notification) {
        sendHostMessage("hostLocaleChanged", params: ["locale": hostLocaleCode()])
    }

    @objc private func applicationDidEnterBackground(_ notification: Notification) {
        backgroundEnteredAt = Date()
        let miniId = miniProgramId
        STProjectHelper.Log("[STMini][Lifecycle] app_background miniId=\(miniId) visible=\(isShow) runtimeUsable=\(isKeepAliveRuntimeUsable)")
    }

    /// `willResignActive` is intentionally used instead of waiting for
    /// `didEnterBackground`: WebKit still has a short runnable window here to
    /// flush state before iOS suspends it.  The static root guard prevents
    /// cached Mini WebViews from receiving a foreground/background event that
    /// belongs to another, currently visible Mini.
    @objc private func applicationWillResignActive(_ notification: Notification) {
        guard Self.currentHostMiniRoot === self else { return }
        // A queued foreground activation cannot outlive a real appHide.
        // Keep its visibility need so the next actual resume may create a
        // fresh ordered activation, while appHide still sends immediately.
        warmActivationGeneration &+= 1
        sendHostLifecycleMessage("appHide")
        STProjectHelper.Log("[STMini][Lifecycle] appHide delivered miniId=\(miniProgramId)")
    }

    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        let backgroundDuration = backgroundEnteredAt.map { Date().timeIntervalSince($0) } ?? 0
        lastBackgroundDurationMs = max(0, Int(backgroundDuration * 1000))
        backgroundEnteredAt = nil
        if Self.currentHostMiniRoot === self {
            let resumedDurationMs = lastBackgroundDurationMs
            lastBackgroundDurationMs = 0
            if needsWarmVisibilityActivation {
                enqueueWarmActivation(backgroundDurationMs: resumedDurationMs)
            } else {
                sendHostLifecycleMessage("appShow", params: [
                    "backgroundDurationMs": resumedDurationMs,
                    "recoveryMode": "visible_resume",
                ])
            }
            STProjectHelper.Log("[STMini][Lifecycle] appShow delivered miniId=\(miniProgramId)")
        }
        let miniId = miniProgramId
        let willProbe = backgroundDuration >= 1 && isShow && isKeepAliveRuntimeUsable && !isRecoveringTerminatedWebContentProcess
        STProjectHelper.Log("[STMini][Lifecycle] app_foreground miniId=\(miniId) backgroundDurationMs=\(Int(backgroundDuration * 1000)) visible=\(isShow) runtimeUsable=\(isKeepAliveRuntimeUsable) willProbe=\(willProbe)")
        // Ignore short Control Center / permission interruptions. The probe is
        // for a resumed, already-rendered Mini after a genuine background stay.
        guard backgroundDuration >= 1,
              isShow,
              isKeepAliveRuntimeUsable,
              !isRecoveringTerminatedWebContentProcess else {
            return
        }
        // A foregrounded WebView may need more than one run-loop turn before
        // JavaScript can execute. Do not turn an immediate readyState timeout
        // into a false "content process terminated" recovery.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.foregroundProcessProbeInitialDelay) { [weak self] in
            guard let self = self,
                  self.isShow,
                  self.isKeepAliveRuntimeUsable,
                  !self.isRecoveringTerminatedWebContentProcess else {
                return
            }
            self.probeWebContentProcessAfterForeground()
        }
    }

    private func sendHostMessage(_ method: String, params: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let webView = self.webView,
                  self.isShow || self.isKeepAliveRuntimeUsable else { return }
            // Keep-alive may retain the root behind an internal Mini page or
            // after dismissal. It still owns the Quant runtime, so account
            // and locale invalidations must reach it before it is shown again.
            STWebApiManager.sendScriptMessageWithMethod(method, params: params, webview: webView)
        }
    }

    /// App lifecycle is delivered while UIKit may be about to suspend the
    /// process. Unlike ordinary UI notifications, do not insert an extra main
    /// queue turn when we already run on main, otherwise `appHide` can miss
    /// the last runnable window before WebKit is frozen.
    private func sendHostLifecycleMessage(_ method: String, params: [String: Any] = [:]) {
        let send = { [weak self] in
            guard let self = self,
                  let webView = self.webView,
                  self.isShow || self.isKeepAliveRuntimeUsable else { return }
            STWebApiManager.sendScriptMessageWithMethod(method, params: params, webview: webView)
        }
        if Thread.isMainThread {
            send()
        } else {
            DispatchQueue.main.async(execute: send)
        }
    }

    private func clearCurrentHostMiniRootIfNeeded() {
        guard !isChild,
              Self.currentHostMiniRoot === self,
              let navigationController = navigationController as? STWebNavigationController,
              navigationController.presentingViewController == nil,
              navigationController.view.window == nil else {
            return
        }
        Self.currentHostMiniRoot = nil
    }

    private func hostLocaleCode() -> String {
        let savedLanguage = UserDefaults.standard.string(forKey: "STLanguageCode") ?? ""
        let sourceLanguage = savedLanguage.isEmpty ? (Locale.preferredLanguages.first ?? "") : savedLanguage
        let language = sourceLanguage
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if language.hasPrefix("zh") {
            return language.contains("hant") || language.contains("tw") || language.contains("hk") || language.contains("mo") ? "zh-Hant" : "zh-Hans"
        }
        return language.isEmpty ? "en-US" : sourceLanguage
    }

}


extension STWebMiniprogramCrl {
    
    
    public func webviewDidFinish() {
        // Child pages never own the root launch ticket, overlay, or first
        // content event. Both installed and bundled roots use the same
        // generation/current-document gate below.
        guard !isChild else {
            isKeepAliveRuntimeUsable = true
            isRecoveringTerminatedWebContentProcess = false
            return
        }
        guard let ticket = rootMiniDocumentTicket,
              ticket.generation == rootMiniDocumentGeneration,
              ticket.observedSuccessorLoading,
              rootMiniDocumentReadyGeneration != ticket.generation,
              !webView.isLoading,
              let currentURL = webView.url,
              isExpectedTrustedRootMiniDocument(currentURL, ticket: ticket) else {
            // WebKit calls this for frames reached by redirects, Mini-owned
            // sub-pages and sometimes an outgoing navigation.  None owns the
            // root launch overlay or the operation's first-content event.
            STProjectHelper.Log("[DirectMini] ignored non-root or stale didFinish miniId=\(miniProgramId) generation=\(rootMiniDocumentGeneration) url=\(webView?.url?.absoluteString ?? "nil")")
            return
        }
        rootMiniDocumentReadyGeneration = ticket.generation
        rootMiniDocumentTicket = nil
        isKeepAliveRuntimeUsable = true
        isRecoveringTerminatedWebContentProcess = false

        loadAnimationView?.finished()
        emitHostEvent("mini_first_content_ready", ["version": loadedMiniPackageVersion ?? ""])
        showTerminatedProcessRecoveryToastIfNeeded()
        showMemoryWarningRecoveryToastIfNeeded()
    }

    /// A package can pass archive validation while its first root navigation
    /// still fails (for example after a Web Content process reset).  Treat
    /// only the active, expected root ticket as a launch failure; cancellation
    /// and a child/redirect failure must not replace the current Mini with an
    /// alert.  `finishOnlineLoading` supplies the stable retry/close terminal
    /// state used by forced updates, while non-forced silent updates never arm
    /// a root ticket or overlay in the first place.
    public func webviewDidFailNavigation(_ error: NSError) {
        guard config.webMode == .online,
              error.domain != NSURLErrorDomain || error.code != NSURLErrorCancelled,
              let ticket = rootMiniDocumentTicket,
              ticket.generation == rootMiniDocumentGeneration,
              ticket.observedSuccessorLoading,
              let currentURL = webView?.url,
              isExpectedTrustedRootMiniDocument(currentURL, ticket: ticket) else {
            return
        }
        finishOnlineLoading(message: STMiniLocalized("mini.root_document_failed", "小程序页面加载失败，请重试"))
    }

    /// Called by STMiniWebView when WKWebView loses its Web Content process.
    /// Do not leave the current controller displaying an unusable WebView:
    /// remove it from keep-alive immediately and cold-load the installed Mini.
    public func webviewContentProcessDidTerminate() {
        guard !isRecoveringTerminatedWebContentProcess else { return }
        foregroundProcessProbeID = nil
        isRecoveringTerminatedWebContentProcess = true
        isKeepAliveRuntimeUsable = false
        let miniId = miniProgramId
        if STWebMiniProgramKeepAliveStore.shared.discardTerminated(self) { return }
        UserDefaults.standard.set(true, forKey: Self.terminatedProcessToastKeyPrefix + miniId)
        STProjectHelper.Log("小程序<\(miniId)>Web 内容进程已终止，已移出保活缓存并冷启动恢复")

        // A detached cache entry is discarded here; the next user opening
        // constructs a new controller. A visible controller has no cache
        // entry, so reload it now instead of leaving a white page onscreen.
        guard Self.currentHostMiniRoot === self else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.reloadAfterWebContentProcessTermination()
        }
    }

    private func reloadAfterWebContentProcessTermination() {
        guard webView != nil else { return }
        // Online Minis always load the verified on-disk package, so this is a
        // true cold document load rather than a reload of a dead process.
        if config.webMode == .online {
            beginOnlineMiniLoading(miniId: miniProgramId)
            openOnlineMiniPackage()
        } else {
            // Preserve the established local-Mini loading path while still
            // forcing WKWebView to create a new Web Content process.
            webView.reload()
        }
    }

    /// A terminated Web Content process is not guaranteed to invoke its
    /// delegate immediately after the device wakes. An evaluateJavaScript
    /// round-trip is cheap for a healthy document. WebKit can be briefly busy
    /// while restoring after sleep, so probe failures remain non-fatal and
    /// are retried later. A real delegate termination remains authoritative.
    private func probeWebContentProcessAfterForeground(attempt: Int = 1) {
        guard webView != nil, !isRecoveringTerminatedWebContentProcess else { return }
        let probeID = UUID()
        foregroundProcessProbeID = probeID
        webView.evaluateJavaScript("document.readyState") { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self = self, self.foregroundProcessProbeID == probeID else { return }
                self.foregroundProcessProbeID = nil
                if error != nil {
                    self.retryForegroundProcessProbeOrRecover(attempt: attempt, reason: "失败")
                } else {
                    STProjectHelper.Log("[STMini][Lifecycle] foreground_probe_success miniId=\(self.miniProgramId) attempt=\(attempt)")
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.foregroundProcessProbeTimeout) { [weak self] in
            guard let self = self,
                  self.foregroundProcessProbeID == probeID,
                  self.isShow,
                  !self.isRecoveringTerminatedWebContentProcess else {
                return
            }
            self.foregroundProcessProbeID = nil
            self.retryForegroundProcessProbeOrRecover(attempt: attempt, reason: "超时")
        }
    }

    private func retryForegroundProcessProbeOrRecover(attempt: Int, reason: String) {
        guard isShow, isKeepAliveRuntimeUsable, !isRecoveringTerminatedWebContentProcess else { return }
        if attempt < Self.foregroundProcessProbeMaxAttempts {
            STProjectHelper.Log("小程序<\(miniProgramId)>前台探测\(reason)，短暂等待后重试 \(attempt + 1)/\(Self.foregroundProcessProbeMaxAttempts)")
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.foregroundProcessProbeRetryDelay) { [weak self] in
                guard let self = self,
                      self.isShow,
                      self.isKeepAliveRuntimeUsable,
                      !self.isRecoveringTerminatedWebContentProcess else { return }
                self.probeWebContentProcessAfterForeground(attempt: attempt + 1)
            }
            return
        }
        // A failed readiness probe is not evidence that WebKit terminated.
        // Cap this foreground pass at two probes and wait for a real WebKit
        // termination callback (or the next foreground transition) instead
        // of scheduling a permanent 3-second polling loop.
        STProjectHelper.Log("小程序<\(miniProgramId)>前台探测\(reason)且重试失败，本次恢复不再探测；等待 WebKit 真实终止回调或下次前台恢复")
    }

    private func showTerminatedProcessRecoveryToastIfNeeded() {
        let key = Self.terminatedProcessToastKeyPrefix + miniProgramId
        guard UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.removeObject(forKey: key)
        let message = STMiniLocalized("mini.process_terminated", "小程序运行进程已被系统终止，已重新加载")
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let webView = self.webView else { return }
            if let apiHandle = STWebPersonalHandle.sharedInstance().apiHandle {
                _ = apiHandle(["method": "showToast", "params": ["title": message, "duration": 2]], webView)
            } else {
                STProjectHelper.Log("小程序<\(self.miniProgramId)>恢复提示未显示：宿主未提供 Toast handler")
            }
        }
    }


    
    
    private func showMemoryWarningRecoveryToastIfNeeded() {
        guard STWebMiniProgramKeepAliveStore.shared.consumeMemoryWarningRecoveryNotice(miniId: miniProgramId) else { return }
        let message = STMiniLocalized("mini.memory_released", "小程序后台运行实例已因内存压力释放，已重新加载")
        if let apiHandle = STWebPersonalHandle.sharedInstance().apiHandle,
           let webView = webView {
            _ = apiHandle(["method": "showToast", "params": ["title": message, "duration": 2]], webView)
        } else {
            STProjectHelper.Log("小程序<\(miniProgramId)>内存压力恢复提示未显示：宿主未提供 Toast handler")
        }
    }

    public func close() { close(completion: {}) }

    func close(completion: @escaping () -> Void) {
        prepareForNativeDismissal()
        let retainedNavigationController = navigationController as? STWebNavigationController
        invalidateRootMiniDocumentLoad()
        dismiss(animated: true) { [weak self, retainedNavigationController] in
            guard let self, !self.isChild, !self.hasReleasedRuntime else { completion(); return }
            if !self.hasEmittedCloseEvent {
                self.hasEmittedCloseEvent = true
                self.emitHostEvent("mini_closed", ["reason": "dismissed"])
            }
            STWebMiniProgramKeepAliveStore.shared.cache(self, navigationController: retainedNavigationController)
            completion()
        }
    }

}


extension STWebMiniprogramCrl: STWebMiniprogramCapsuleBarDelegate {
    
    
    func initialCapsuleBar() {
        if (capsuleBar == nil) {
            capsuleBar = STWebMiniprogramCapsuleBar(frame: CGRectMake(view.ST_right - ST_CapsuleBarRightGap - ST_CapsuleBarItemWidth*2, STScreenHelper.ST_statusBarHeight() + (STScreenHelper.ST_navigationBarHeight() - ST_CapsuleBarItemHeight)/2, ST_CapsuleBarItemWidth*2, ST_CapsuleBarItemHeight))
            capsuleBar.delegate = self
            view.addSubview(capsuleBar)
        }
    }
    
    

    
    
    func changeCapsuleBar(isShowStandIn: Bool) {
        // Transition-finished is a process-wide notification. Controllers
        // created for child/loading Mini routes do not own a capsule bar, so
        // touching the implicitly-unwrapped outlet here used to terminate the
        // host with a Swift fatal error after a scanned Mini package opened.
        guard !isHomeMiniProgram(), let capsuleBar = capsuleBar else {
            return
        }
        capsuleBar.removeFromSuperview()
        if isShowStandIn {
            view.addSubview(capsuleBar)
        }
        else {
            (view.window ?? navigationController?.view.window)?.addSubview(capsuleBar)
        }
    }

    func more() {
        let toolView = STWebToolView.init(frame: CGRectMake(0, 0, view.ST_width, 200), items: [["title": STMiniLocalized("mini.reenter", "重新进入小程序"), "imgStr": "tool_shuaxin", "key": "reEnter"]])
        let popConfig = HLPopConfig()
        popConfig.popBackColor = .ST_hex("#E8E8E8")
        popConfig.cornerRadius = 10
        popConfig.corner = [UIRectCorner.topLeft,UIRectCorner.topRight]
        HLPopViewController().showBottomPopView(toolView, config: popConfig) { [weak self] info, isCancel in
            if isCancel != true {
                if info["key"] != nil {
                    
                    let key = info["key"] as! String
                    STProjectHelper.Log("toolView点击-\(key)")
                    if key == "reEnter" {
                        // Explicit "re-enter" is a refresh action, not a
                        // warm resume.  Drop this runtime before presenting
                        // the new root Mini program.
                        self?.skipsKeepAliveOnNextDismiss = true
                        self?.prepareForNativeDismissal()
                        let infoStorage = STWebInfoStorage.sharedInstance()
                        infoStorage.config = self?.config
                        infoStorage.name = self?.name
                        self?.dismiss(animated: true, completion: {
                            STWebOpenHandler.reOpenMiniprogram()
                        })
                    }
                }
            }
        }
    }
    
    
    func initialLoadAnimationView() -> STWebMiniLoadAnimate {
        return STWebMiniLoadAnimationView(frame: view.bounds)
    }
    
    @objc func back(){
        if(navigationController?.children[0] == self){
            close()
            return;
        }
        navigationController?.popViewController(animated: true)
    }
    
}

extension STWebMiniprogramCrl: UIViewControllerTransitioningDelegate {


    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        transAnimation.transType = .present
        return transAnimation
    }


    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        changeCapsuleBar(isShowStandIn: true)
        transAnimation.transType = .dismiss
        transAnimation.interactive = interactive
        return transAnimation
    }


    public func interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return nil
    }


    public func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return interactive?.isInteractive == true ? interactive : nil
    }

}


extension STWebMiniprogramCrl {

    /// The capsule belongs to a visible Mini only. After a successful close
    /// it must not remain attached to the host window; a cancelled gesture
    /// restores it because the Mini is still on screen.
    fileprivate func handleTransitionCompletion(type: STWebTransType, succeeded: Bool) {
        switch type {
        case .present:
            if succeeded { changeCapsuleBar(isShowStandIn: false) }
            else { capsuleBar?.removeFromSuperview(); releaseClosedRuntime() }
        case .dismiss:
            if succeeded {
                capsuleBar?.removeFromSuperview()
            } else {
                changeCapsuleBar(isShowStandIn: false)
                setKeepAliveRuntimeHidden(false)
            }
        }
    }
}
