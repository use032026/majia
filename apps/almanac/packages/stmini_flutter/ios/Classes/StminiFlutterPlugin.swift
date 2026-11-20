import Flutter
import Photos
import Toast_Swift
import UIKit

/// iOS bridge for the generic STMini container.
///
/// This class intentionally does not import a business App's login, account,
/// router or trading code. STMini itself owns package handling and framework
/// APIs; the plugin supplies only safe, generic host UI/language/log behavior.
public final class StminiFlutterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private static let maximumMiniStorageBytes = 1_048_576
  /// Base64 expands binary data by roughly one third. Keep the encoded input
  /// bounded before decoding so an untrusted Mini cannot exhaust host memory.
  private static let maximumMiniImageBase64Bytes = 26_214_400

  private let inventoryQueue = DispatchQueue(label: "stmini.local-inventory")
  private var detached = false
  var photoLibraryAccess = STMiniPhotoLibraryAccess.system
  private var inventoryQuery: InventoryQuery?
  private final class InventoryQuery {
    var result: FlutterResult?
    var work: DispatchWorkItem?
    private let lock = NSLock()
    private var cancelled = false
    private let deadline = ProcessInfo.processInfo.systemUptime + 4
    init(result: @escaping FlutterResult) { self.result = result }
    func cancel() { lock.lock(); cancelled = true; lock.unlock(); work?.cancel() }
    func check() throws {
      lock.lock(); let invalid = cancelled; lock.unlock()
      if invalid || ProcessInfo.processInfo.systemUptime >= deadline { throw LocalPackageInventory.Failure.unavailable }
    }
  }
  private var localViews: LocalMiniViewFactory?
  private var eventLease = UUID()
  private var eventSink: FlutterEventSink?
  /// Reverse calls are limited to an already-authorized Online Web document.
  /// Keep the channel weakly coupled to the Flutter handler; no Mini runtime
  /// API is exposed through this path.
  private var methodChannel: FlutterMethodChannel?
  private weak var presentingViewController: UIViewController?
  private let ownedMiniNavigations = NSHashTable<STWebNavigationController>.weakObjects()
  private var miniOperationGeneration: UInt64 = 0
  private final class MiniCloseRequest {
    let result: FlutterResult
    private(set) var completed = false
    init(_ result: @escaping FlutterResult) { self.result = result }
    func complete(_ value: Any?) { guard !completed else { return }; completed = true; result(value) }
  }
  private var miniCloseRequests: [MiniCloseRequest] = []
  private final class OnlineWebPresentationRequest {
    let generation: UInt64
    private(set) var completed = false
    let webURL: URL
    let params: [String: String]
    let showNavigationBar: Bool
    let result: FlutterResult
    init(webURL: URL, params: [String: String], showNavigationBar: Bool, result: @escaping FlutterResult, generation: UInt64) {
      self.webURL = webURL; self.params = params; self.showNavigationBar = showNavigationBar
      self.result = result; self.generation = generation
    }
    func complete(_ value: Any?) { guard !completed else { return }; completed = true; result(value) }
  }
  /// Serializes rapid `openWeb` calls so presentation/dismissal transitions
  /// cannot overlap or use an H5 controller that UIKit is removing.
  private let onlineWebPresentationQueue = STOnlineWebPresentationQueue<OnlineWebPresentationRequest>()
  private var onlineWebPresentationGeneration: UInt64 = 0
  private var onlineWebRequests: [OnlineWebPresentationRequest] = []
  private weak var standaloneOnlineNavigation: UINavigationController?
  private var onlineWebCloseInProgress = false
  private var onlineWebCloseResults: [FlutterResult] = []
  private var initialized = false
  /// Optional, JSON-compatible context supplied by the embedding Flutter app.
  /// STMini stays reusable: it never imports a host's account/login module.
  private var bridgeContext: [String: Any] = [:]
  private static weak var registeredInstance: StminiFlutterPlugin?
  /// Read-only host context for the vendored STMini framework APIs. Values
  /// stay host supplied so this reusable component contains no product IDs,
  /// domains, or storage-key assumptions.
  static var bridgeContextSnapshot: [String: Any] = [:]

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = StminiFlutterPlugin()
    registeredInstance = instance
    let methodChannel = FlutterMethodChannel(
      name: "stmini_flutter/methods", binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(
      name: "stmini_flutter/events", binaryMessenger: registrar.messenger())
    instance.methodChannel = methodChannel
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    registrar.publish(instance)
    let factory = LocalMiniViewFactory(messenger: registrar.messenger()) { [weak instance] in
      instance?.initialized == true && instance?.detached == false
    }
    instance.localViews = factory
    registrar.register(factory, withId: "stmini_flutter/local_view")
    eventChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      guard let arguments = call.arguments as? [String: Any],
            Set(arguments.keys).isSubset(of: ["bridgeContext", "loadingImage"]),
            let context = arguments["bridgeContext"] as? [String: Any], Set(context.keys).isSubset(of: ["packageName", "miniSecurity"]), Self.validMiniSecurity(context["miniSecurity"]),
            context["packageName"] as? String == "com.almanac.lite", Bundle.main.bundleIdentifier == "com.almanac.lite",
            arguments["loadingImage"] == nil || arguments["loadingImage"] is String, !detached else {
        result(FlutterError(code: "unsupported_host_configuration", message: "Only the Deynu host identity is configured.", details: nil)); return
      }
      configureIfNeeded(loadingImage: arguments["loadingImage"] as? String, bridgeContext: context)
      emit("runtime_initialized", state())
      result(nil)
    case "foundationState": result(state())
    case "closeWeb":
      guard !detached else { result(FlutterError(code: "cancelled", message: "Web runtime detached.", details: nil)); return }
      cancelOnlineWebRequests()
      guard let navigation = standaloneOnlineNavigation else { result(nil); return }
      guard !isCoveredStandaloneWebNavigation(navigation) else {
        revokeOnlineWebAuthority(navigation)
        result(FlutterError(code: "web_covered", message: "The owned Web page is covered by another presentation.", details: nil)); return
      }
      onlineWebCloseResults.append(result)
      guard !onlineWebCloseInProgress else { return }
      onlineWebCloseInProgress = true
      revokeOnlineWebAuthority(navigation)
      dismissStandaloneOnlineNavigation(navigation)
    case "notifyWebSessionChanged":
      guard !detached else { result(FlutterError(code: "cancelled", message: "Web runtime detached.", details: nil)); return }
      let original = standaloneOnlineNavigation
      let wasVisible = original.map(isVisibleStandaloneWebNavigation) ?? false
      cancelOnlineWebRequests()
      STWebMiniProgramKeepAliveStore.shared.invalidateSession()
      if let original { revokeOnlineWebAuthority(original) }
      guard wasVisible, let navigation = original, navigation === standaloneOnlineNavigation,
            isVisibleStandaloneWebNavigation(navigation) else { result(0); return }
      var count = 0
      navigation.viewControllers.compactMap { $0 as? STWebH5Crl }.forEach { page in
        guard page === navigation.visibleViewController, let view = page.webView,
              !view.isLoading, view.url.flatMap(STOnlineWebCore.normalizedHTTPSOrigin) != nil else { return }
        view.nativeEffectsSuspended = false
        STWebApiManager.sendScriptMessageWithMethod("miniSessionChanged", params: ["reason": "hostSessionChanged"], webview: view)
        count += 1
      }
      result(count)
    case "openMini":
      guard initialized, !detached else { result(FlutterError(code: "not_initialized", message: "Initialize the Mini runtime first.", details: nil)); return }
      guard let arguments = call.arguments as? [String: Any],
            let link = arguments["link"] as? String,
            link.lowercased().hasPrefix("mini://") else {
        result(FlutterError(code: "invalid_mini_link", message: "link must start with mini://", details: nil))
        return
      }
      configureIfNeeded(loadingImage: nil, bridgeContext: nil)
      let operationId = UUID().uuidString
      if STWebResourceManager.requestsPackageMutation(link: link) {
        result(FlutterError(code: "unsupported", message: "Mini package downloads, installation and updates are unavailable.", details: nil))
        return
      }
      guard STWebResourceManager.isInstalledMiniPackageRunnable(link: link) else {
        result(FlutterError(code: "mini_package_unavailable", message: "No verified local Mini package meets the required version.", details: nil))
        return
      }
      guard let controller = currentPresentingViewController() else {
        Self.emitMiniRuntimeEvent("mini_open_failed", payload: [
          "operationId": operationId,
          "code": "no_presenting_controller",
          "message": "No active Flutter view controller",
          "retryable": true,
        ])
        result(FlutterError(code: "no_presenting_controller", message: "No active Flutter view controller", details: nil))
        return
      }
      miniOperationGeneration &+= 1
      let openingGeneration = miniOperationGeneration
      presentingViewController = controller
      let operationLink = linkWithOperationID(link, operationID: operationId)
      // Keep the original event for hosts already observing it. New consumers
      // can use the operation-scoped lifecycle events below.
      emit("open_requested", ["link": redactedMiniLink(link)])
      emit("mini_opening", ["operationId": operationId, "link": redactedMiniLink(operationLink)])
      let openingSession = STWebMiniProgramKeepAliveStore.shared.sessionGeneration
      DispatchQueue.main.async { [weak self] in
        guard let self, !self.detached, self.initialized, openingGeneration == self.miniOperationGeneration,
              openingSession == STWebMiniProgramKeepAliveStore.shared.sessionGeneration,
              !controller.isBeingDismissed, controller.navigationController?.isBeingDismissed != true else {
          Self.emitMiniRuntimeEvent("mini_open_failed", payload: ["operationId": operationId, "code": "cancelled", "message": "Mini opening context expired.", "retryable": true])
          result(FlutterError(code: "cancelled", message: "Mini opening context expired.", details: nil)); return
        }
        STWebOpenHandler.openWeb(url: operationLink, params: nil, crl: controller, navi: nil)
        if let navigation = controller.presentedViewController as? STWebNavigationController,
           navigation.viewControllers.first is STWebMiniprogramCrl {
          self.ownedMiniNavigations.add(navigation)
        }
        result(nil)
      }
    case "openWeb":
      guard initialized, !detached else { result(FlutterError(code: "not_initialized", message: "Initialize the Web runtime first.", details: nil)); return }
      guard let arguments = call.arguments as? [String: Any],
            let url = arguments["url"] as? String,
            let webURL = URL(string: url.trimmingCharacters(in: .whitespacesAndNewlines)),
            let scheme = webURL.scheme?.lowercased(),
            (scheme == "https" || (scheme == "http" && Self.allowsInsecureHttpNavigation())),
            webURL.host?.isEmpty == false, webURL.user == nil, webURL.password == nil else {
        result(FlutterError(code: "invalid_web_url", message: "url must be an absolute HTTPS URL", details: nil))
        return
      }
      configureIfNeeded(loadingImage: nil, bridgeContext: nil)
      let showNavigationBar = arguments["showNavigationBar"] as? Bool ?? true
      let title = arguments["title"] as? String
      var params = ["isNeedNavigationBar": showNavigationBar ? "true" : "false"]
      if let title, !title.isEmpty {
        params["title"] = title
      }
      emit("web_open_requested", ["url": redactedWebURL(webURL)])
      let generation = onlineWebPresentationGeneration
      DispatchQueue.main.async { [weak self] in
        guard let self, !self.detached, generation == self.onlineWebPresentationGeneration else { result(FlutterError(code: "cancelled", message: "Web runtime detached or request cancelled.", details: nil)); return }
        self.presentOnlineWeb(
          webURL: webURL,
          params: params,
          showNavigationBar: showNavigationBar,
          result: result)
      }
    case "closeMini":
      guard !detached else { result(FlutterError(code: "cancelled", message: "Mini runtime detached.", details: nil)); return }
      miniOperationGeneration &+= 1 // also cancels an open not yet dispatched
      let closingGeneration = miniOperationGeneration
      let closingSession = STWebMiniProgramKeepAliveStore.shared.sessionGeneration
      guard let controller = currentPresentingViewController(),
            let navigation = (controller as? STWebNavigationController) ?? (controller.navigationController as? STWebNavigationController),
            ownedMiniNavigations.allObjects.contains(where: { $0 === navigation }),
            let root = navigation.viewControllers.first as? STWebMiniprogramCrl,
            navigation.presentingViewController != nil else { result(nil); return }
      root.prepareForNativeDismissal()
      let request = MiniCloseRequest(result)
      miniCloseRequests.removeAll { $0.completed }; miniCloseRequests.append(request)
      DispatchQueue.main.async { [weak self, weak navigation, weak root] in
        guard let self, !self.detached, self.miniOperationGeneration == closingGeneration,
              STWebMiniProgramKeepAliveStore.shared.sessionGeneration == closingSession,
              let navigation, let root, navigation.viewControllers.first === root,
              navigation.presentingViewController != nil, !navigation.isBeingDismissed,
              !navigation.hasForeignPresentedOwner,
              self.ownedMiniNavigations.allObjects.contains(where: { $0 === navigation }) else {
          // A superseding operation may leave the same original root visible.
          // Restore it only through the strict fresh-grant path, never old leases.
          if let self, !self.detached, let navigation, let root,
             navigation.viewControllers.first === root, navigation.presentingViewController != nil,
             !navigation.isBeingDismissed, !navigation.hasForeignPresentedOwner { root.setKeepAliveRuntimeHidden(false) }
          request.complete(FlutterError(code: "cancelled", message: "Mini closing context expired.", details: nil)); return
        }
        root.close {
          guard !self.detached, self.miniOperationGeneration == closingGeneration,
                STWebMiniProgramKeepAliveStore.shared.sessionGeneration == closingSession else {
            request.complete(FlutterError(code: "cancelled", message: "Mini closing context expired.", details: nil)); return
          }
          self.emit("closed", [:]); request.complete(nil)
        }
      }
    case "isAvailable":
      result(true)
    case "installedPackages":
      readInventory(call.arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventLease = UUID()
    eventSink = events
    if initialized { emit("runtime_initialized", state()) }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventLease = UUID()
    eventSink = nil
    return nil
  }

  private let standaloneWebViews = NSHashTable<STMiniWebView>.weakObjects()
  private func state() -> [String: Any] {
    ["stage": "mini", "runtimeMode": "mini", "miniPackageMode": "local_only", "initialized": initialized,
     "miniPackageDownloadAvailable": false, "miniPackageInstallAvailable": false, "miniPackageUpdateAvailable": false,
     "packageName": initialized ? ("com.almanac.lite" as Any) : NSNull(),
     "localizedClose": STMiniLocalized("mini.close", "Close"),
     "capabilities": ["host_configuration", "language_resolution", "runtime_events", "local_inventory", "local_renderer", "local_mini_runtime", "framework_bridge", "isolated_storage"],
     "localRendererAvailable": true, "miniLoadingAvailable": true, "webLoadingAvailable": true, "miniChildWebAvailable": true, "closedMiniCacheAvailable": true]
  }

  private func readInventory(_ arguments: Any?, result: @escaping FlutterResult) {
    guard arguments == nil else {
      result(FlutterError(code: "invalid_inventory_arguments", message: "Inventory accepts no arguments.", details: nil)); return
    }
    guard initialized, !detached else {
      result(FlutterError(code: "not_initialized", message: "Initialize the foundation first.", details: nil)); return
    }
    guard inventoryQuery == nil else {
      result(FlutterError(code: "inventory_busy", message: "Inventory query already in progress.", details: nil)); return
    }
    let query = InventoryQuery(result: result)
    inventoryQuery = query
    let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    let work = DispatchWorkItem { [weak self, query] in
      let outcome = Result { try LocalPackageInventory(home: home).read(check: query.check) }
      DispatchQueue.main.async { [weak self, query] in
        query.work = nil
        guard let owner = self, owner.inventoryQuery === query, !owner.detached else {
          let cancelled = query.result; query.result = nil
          cancelled?(FlutterError(code: "inventory_cancelled", message: "Inventory query cancelled.", details: nil)); return
        }
        owner.inventoryQuery = nil
        let completion = query.result; query.result = nil
        switch outcome {
        case .success(let packages): completion?(packages)
        case .failure: completion?(FlutterError(code: "inventory_unavailable", message: "Local inventory could not be read.", details: nil))
        }
      }
    }
    query.work = work
    inventoryQueue.async(execute: work)
  }


  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    detached = true
    miniOperationGeneration &+= 1
    let cancelledMiniCloses = miniCloseRequests; miniCloseRequests.removeAll()
    cancelledMiniCloses.forEach { $0.complete(FlutterError(code: "cancelled", message: "Mini runtime detached.", details: nil)) }
    cancelOnlineWebRequests()
    let cancelledCloses = onlineWebCloseResults; onlineWebCloseResults.removeAll()
    onlineWebCloseInProgress = false
    cancelledCloses.forEach { $0(FlutterError(code: "cancelled", message: "Web runtime detached.", details: nil)) }
    if let navigation = standaloneOnlineNavigation {
      revokeOnlineWebAuthority(navigation)
      navigation.viewControllers.compactMap { $0 as? STWebH5Crl }.forEach { $0.releaseAfterMiniCache() }
      if let owned = navigation as? STStandaloneWebNavigationController { owned.retireWhenUncovered() }
      else if !isCoveredStandaloneWebNavigation(navigation) { navigation.dismiss(animated: false) }
    }
    standaloneOnlineNavigation = nil
    // Only navigations created/taken by this plugin's own openMini calls are
    // eligible. Never discover and dismiss unrelated application UI.
    let ownedMini = ownedMiniNavigations.allObjects; ownedMiniNavigations.removeAllObjects()
    ownedMini.forEach { navigation in
      guard let root = navigation.viewControllers.first as? STWebMiniprogramCrl else { return }
      root.prepareForNativeDismissal(); root.releaseClosedRuntime()
      navigation.retireWhenUncovered(root: root)
    }
    STWebMiniProgramKeepAliveStore.shared.invalidateSession()
    eventLease = UUID(); eventSink = nil; methodChannel = nil
    NotificationCenter.default.removeObserver(self)
    if Self.registeredInstance === self { Self.registeredInstance = nil; Self.bridgeContextSnapshot = [:] }
    localViews?.detach(); localViews = nil
    initialized = false
    if let query = inventoryQuery {
      inventoryQuery = nil
      query.cancel()
      query.work = nil
      let completion = query.result; query.result = nil
      completion?(FlutterError(code: "inventory_cancelled", message: "Inventory query cancelled.", details: nil))
    }
    eventSink = nil
  }

  /// `openWeb` can be called while a prior host-opened H5 is still the top
  /// controller. Presenting from that dying H5 causes UIKit's "not in the
  /// window hierarchy" warning and intermittently loses the second page.
  /// Dismiss first, then resolve the current Flutter presenter in completion.
  private func presentOnlineWeb(
    webURL: URL,
    params: [String: String],
    showNavigationBar: Bool,
    result: @escaping FlutterResult
  ) {
    let request = OnlineWebPresentationRequest(
      webURL: webURL,
      params: params,
      showNavigationBar: showNavigationBar,
      result: result, generation: onlineWebPresentationGeneration
    )
    onlineWebRequests.removeAll { $0.completed }
    onlineWebRequests.append(request)
    // The recorded owner remains an owner while covered. Looking only at
    // the top controller would lose A and overwrite it with a new Web C.
    let existing = standaloneOnlineNavigation.flatMap { $0.presentingViewController != nil ? $0 : nil }
    if let existing, isCoveredStandaloneWebNavigation(existing) {
      revokeOnlineWebAuthority(existing)
      request.complete(FlutterError(code: "web_covered", message: "Reveal the owned Web page before replacing it.", details: nil))
      return
    }
    let action = onlineWebPresentationQueue.enqueue(
      request,
      hasExistingPresentation: existing != nil
    )
    // A newer open replaces a request that had not reached UIKit yet. Resolve
    // the older MethodChannel invocation rather than leaving it pending; the
    // newest page is the visible result of this serialized transition.
    action.superseded?.complete(FlutterError(code: "superseded", message: "A newer Web open replaced this request.", details: nil))
    performOnlineWebPresentationStep(action.step, existing: existing)
  }

  private func performOnlineWebPresentationStep(
    _ step: STOnlineWebPresentationQueue<OnlineWebPresentationRequest>.Step,
    existing: UIViewController? = nil
  ) {
    switch step {
    case .waiting:
      return
    case .dismissCurrent:
      if onlineWebCloseInProgress { return }
      let container = existing ?? standaloneOnlineNavigation
      guard let container else {
        if let next = onlineWebPresentationQueue.didDismiss() {
          performOnlineWebPresentationStep(next)
        }
        return
      }
      if let navigation = container as? UINavigationController, isCoveredStandaloneWebNavigation(navigation) {
        revokeOnlineWebAuthority(navigation)
        rejectCoveredWebRequests()
        return
      }
      let generation = onlineWebPresentationGeneration
      if let navigation = container as? UINavigationController { revokeOnlineWebAuthority(navigation) }
      container.dismiss(animated: true) { [weak self] in
        guard let self, !self.detached, self.onlineWebPresentationGeneration == generation else { return }
        // Completion is the only place that advances the queue. The next
        // `present` resolves its presenter anew, after UIKit removed this H5.
        if let next = self.onlineWebPresentationQueue.didDismiss() {
          self.performOnlineWebPresentationStep(next)
        }
      }
    case .present(let request):
      guard !detached, request.generation == onlineWebPresentationGeneration else {
        request.complete(FlutterError(code: "cancelled", message: "Web presentation expired.", details: nil)); return
      }
      guard let presenter = currentPresentingViewController() else {
        request.complete(FlutterError(code: "no_presenting_controller", message: "No active Flutter view controller", details: nil))
        if let next = onlineWebPresentationQueue.didFailToPresent() {
          performOnlineWebPresentationStep(next)
        }
        return
      }
      let navigationController = STStandaloneWebNavigationController()
      navigationController.onWillCover = { [weak self, weak navigationController] in
        if let navigationController { self?.revokeOnlineWebAuthority(navigationController) }
      }
      navigationController.modalPresentationStyle = .fullScreen
      let config = STWebConfig(webMode: .h5, params: request.params)
      config.bridgePolicy = Self.externalWebBridgePolicy(for: request.webURL)
      config.allowsInsecureHttpNavigation = Self.allowsInsecureHttpNavigation()
      STWebOpenHandler.openH5(url: request.webURL.absoluteString, config: config, navi: navigationController, appendParameters: false)
      navigationController.viewControllers.compactMap { $0 as? STWebH5Crl }.forEach { page in
        page.onNativeCoverage = { [weak self, weak navigationController] in
          if let navigationController { self?.revokeOnlineWebAuthority(navigationController) }
        }
        page.revokeStandaloneAuthority()
      }
      navigationController.isNavigationBarHidden = !request.showNavigationBar
      standaloneOnlineNavigation = navigationController
      presenter.present(navigationController, animated: true) { [weak self] in
        guard let self, !self.detached, request.generation == self.onlineWebPresentationGeneration else {
          request.complete(FlutterError(code: "cancelled", message: "Web presentation expired.", details: nil))
          if self?.onlineWebCloseInProgress != true {
            if self?.isCoveredStandaloneWebNavigation(navigationController) == true {
              navigationController.viewControllers.compactMap { $0 as? STWebH5Crl }.forEach { $0.releaseAfterMiniCache() }
              navigationController.retireWhenUncovered()
            } else { navigationController.dismiss(animated: false) }
          }
          return
        }
        if self.grantVisibleStandaloneWebAuthority(navigationController) {
          self.emit("web_opened", ["url": self.redactedWebURL(request.webURL)])
          request.complete(nil)
        } else {
          request.complete(FlutterError(code: "web_covered", message: "Web presentation no longer has visible authority.", details: nil))
        }
        if let next = self.onlineWebPresentationQueue.didPresent() {
          self.performOnlineWebPresentationStep(next)
        }
      }
    }
  }

  private func isVisibleStandaloneWebNavigation(_ navigation: UINavigationController) -> Bool {
    guard !onlineWebCloseInProgress, !navigation.isBeingPresented, !navigation.isBeingDismissed,
          navigation.presentingViewController != nil,
          let page = navigation.visibleViewController as? STWebH5Crl else { return false }
    return page.isUnobscuredStandalonePage
  }

  private func isCoveredStandaloneWebNavigation(_ navigation: UINavigationController) -> Bool {
    if navigation.presentedViewController != nil || navigation.visibleViewController?.presentedViewController != nil { return true }
    if navigation.presentingViewController != nil, !navigation.isBeingPresented, !navigation.isBeingDismissed,
       let window = navigation.viewIfLoaded?.window {
      return STWebH5Crl.topVisibleController(in: window) !== navigation.visibleViewController
    }
    return false
  }

  private func grantVisibleStandaloneWebAuthority(_ navigation: UINavigationController) -> Bool {
    guard !detached, standaloneOnlineNavigation === navigation, isVisibleStandaloneWebNavigation(navigation),
          let page = navigation.visibleViewController as? STWebH5Crl, let web = page.webView else { return false }
    web.invalidateBridgeDocumentSession()
    web.nativeEffectsSuspended = false
    return true
  }

  private func rejectCoveredWebRequests() {
    onlineWebPresentationQueue.reset()
    onlineWebRequests.forEach { request in
      request.complete(FlutterError(code: "web_covered", message: "The owned Web page is covered.", details: nil))
    }
    onlineWebRequests.removeAll { $0.completed }
  }

  private func dismissStandaloneOnlineNavigation(_ navigation: UINavigationController) {
    if isCoveredStandaloneWebNavigation(navigation) {
      revokeOnlineWebAuthority(navigation)
      onlineWebCloseInProgress = false
      let rejected = onlineWebCloseResults; onlineWebCloseResults.removeAll()
      rejected.forEach { $0(FlutterError(code: "web_covered", message: "The owned Web page is covered.", details: nil)) }
      rejectCoveredWebRequests()
      return
    }
    let finished = { [weak self] in
      guard let self else { return }
      if self.standaloneOnlineNavigation === navigation { self.standaloneOnlineNavigation = nil }
      self.onlineWebCloseInProgress = false
      let completed = self.onlineWebCloseResults; self.onlineWebCloseResults.removeAll()
      completed.forEach { $0(nil) }
      if !self.detached, let next = self.onlineWebPresentationQueue.didDismiss() { self.performOnlineWebPresentationStep(next) }
    }
    if navigation.presentingViewController == nil, !navigation.isBeingPresented, !navigation.isBeingDismissed { finished(); return }
    if navigation.isBeingDismissed, let coordinator = navigation.transitionCoordinator {
      coordinator.animate(alongsideTransition: nil) { _ in finished() }
    } else if navigation.isBeingPresented, let coordinator = navigation.transitionCoordinator {
      coordinator.animate(alongsideTransition: nil) { [weak self] _ in self?.dismissStandaloneOnlineNavigation(navigation) }
    } else {
      navigation.dismiss(animated: true, completion: finished)
    }
  }

  private func cancelOnlineWebRequests() {
    onlineWebPresentationGeneration &+= 1
    onlineWebPresentationQueue.reset()
    onlineWebRequests.forEach { $0.complete(FlutterError(code: "cancelled", message: "Web presentation cancelled.", details: nil)) }
    onlineWebRequests.removeAll()
  }

  private func revokeOnlineWebAuthority(_ navigation: UINavigationController) {
    navigation.viewControllers.compactMap { $0 as? STWebH5Crl }.forEach { page in
      page.webView?.nativeEffectsSuspended = true
      page.webView?.invalidateBridgeDocumentSession()
    }
  }

  private static func validMiniSecurity(_ raw: Any?) -> Bool {
    guard let raw else { return true }
    guard let security = raw as? [String: Any], Set(security.keys) == ["continuousKeepAliveMiniIds"],
          let ids = security["continuousKeepAliveMiniIds"] as? [String], ids.count <= 32 else { return false }
    return ids.allSatisfy { $0.range(of: "^[a-z0-9][a-z0-9_-]{0,63}$", options: .regularExpression) != nil }
  }

  static func continuousKeepAliveMiniIds() -> Set<String> {
    guard let security = bridgeContextSnapshot["miniSecurity"] as? [String: Any],
          let values = security["continuousKeepAliveMiniIds"] as? [String] else {
      return []
    }
    return Set(values.compactMap { value in
      let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      return normalized.isEmpty ? nil : normalized
    })
  }

  private func configureIfNeeded(loadingImage: String?, bridgeContext: [String: Any]?) {
    if let bridgeContext {
      if initialized { STWebMiniProgramKeepAliveStore.shared.invalidateSession() }
      self.bridgeContext = bridgeContext
      Self.bridgeContextSnapshot = bridgeContext
      applyOneTimeStorageResetIfRequested()
    }
    let handle = STWebPersonalHandle.sharedInstance()
    if let loadingImage, !loadingImage.isEmpty {
      handle.loadingImg = loadingImage
    }
    guard !initialized else { return }
    initialized = true

    handle.darkModeHandle = { UITraitCollection.current.userInterfaceStyle == .dark }
    handle.logHandle = { [weak self] message in
      self?.emit("native_log", ["message": message])
    }
    handle.apiHandle = { [weak self] message, webView in
      self?.handleGenericHostAPI(message, webView: webView)
        ?? ["handled": 0]
    }
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(installedPackagesDidChange(_:)),
      name: Notification.Name(STMiniPackageRegistry.installedPackagesDidChangeNotificationName()),
      object: nil)
  }





  /// External `/web` documents use the common Web bridge, but never acquire
  /// Mini package/update/navigation APIs from the reusable Mini runtime.
  static func externalWebBridgePolicy(for url: URL) -> STWebBridgePolicy {
    .externalUntrusted
  }

  static func allowsInsecureHttpNavigation() -> Bool {
    let security = bridgeContextSnapshot["webSecurity"] as? [String: Any]
    return security?["allowInsecureHTTP"] as? Bool ?? false
  }



  static func emitMiniRuntimeEvent(_ name: String, payload: [String: Any]) {
    registeredInstance?.emit(name, payload)
  }







  private func linkWithOperationID(_ link: String, operationID: String) -> String {
    guard var components = URLComponents(string: link) else { return link }
    var items = components.queryItems ?? []
    items.removeAll { $0.name == "__st_operation_id" }
    items.append(URLQueryItem(name: "__st_operation_id", value: operationID))
    components.queryItems = items
    return components.string ?? link
  }

  /// A host may explicitly recover one Mini from obsolete or corrupted
  /// persisted state. STMini owns only the generic versioned-key mechanism;
  /// the host supplies the keys and can remove the request after diagnosis.
  private func applyOneTimeStorageResetIfRequested() {
    guard let reset = bridgeContext["storageReset"] as? [String: Any],
          let version = reset["version"] as? String,
          !version.isEmpty,
          let keys = reset["keys"] as? [String],
          !keys.isEmpty else {
      return
    }

    let marker = "stmini.storage-reset.\(version)"
    guard !UserDefaults.standard.bool(forKey: marker) else { return }
    keys.filter { !$0.isEmpty }.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    UserDefaults.standard.set(true, forKey: marker)
    STProjectHelper.Log("STMini applied requested one-time storage reset version=\(version)")
  }

  /// Generic APIs that are useful in any host. Business methods deliberately
  /// return `handled: 0`, allowing STMini framework APIs to run or the Mini to
  /// receive a clear unsupported-method response.
  private func handleGenericHostAPI(_ message: [String: Any], webView: STMiniWebView) -> [String: Any] {
    if webView.allowsOnlineWebHostForwarding { standaloneWebViews.add(webView) }
    let callerGeneration = webView.bridgeDocumentGeneration
    let callerURL = webView.url
    let method = message["method"] as? String ?? ""
    let params = message["params"] as? [String: Any] ?? [:]
    // A Mini child Web document can use the shared session bridge. Keep its
    // ordinary session bridge in the shared Web core so mini_web receives the
    // exact same package identity and persisted session contract.
    if webView.allowsOnlineWebHostForwarding,
       let response = STOnlineWebSessionBridge.handle(
        method: method,
        params: params,
        bridgeContext: bridgeContext,
        deviceType: "ios",
        darkMode: currentPresentingViewController()?.traitCollection.userInterfaceStyle == .dark,
        languageCode: normalizedLanguage(),
        storageScope: storageScope(for: webView)) {
      return ["handled": 1, "code": response["code"] ?? "0", "data": response["data"] ?? [:]]
    }
    switch method {
    case "showToast":
      let title = (params["title"] as? String) ?? (params["msg"] as? String) ?? ""
      let duration = toastDuration(params["duration"])
      self.performForCurrentDocument(webView, generation: callerGeneration, documentURL: callerURL) {
        (webView.bindCrl?.view ?? self.currentPresentingViewController()?.view)?.makeToast(title, duration: duration)
      }
      return success()
    case "showLoading":
      let title = (params["title"] as? String) ?? (params["message"] as? String) ?? ""
      self.performForCurrentDocument(webView, generation: callerGeneration, documentURL: callerURL) {
        guard let view = webView.bindCrl?.view ?? self.currentPresentingViewController()?.view else { return }
        self.showLoading(in: view, title: title)
      }
      return success()
    case "hideLoading":
      self.performForCurrentDocument(webView, generation: callerGeneration, documentURL: callerURL) {
        guard let view = webView.bindCrl?.view ?? self.currentPresentingViewController()?.view else { return }
        self.hideLoading(in: view)
      }
      return success()
    case "close":
      self.performForCurrentDocument(webView, generation: callerGeneration, documentURL: callerURL) {
        self.closeMiniPage(webView: webView, params: params)
      }
      return success()
    case "more":
      self.performForCurrentDocument(webView, generation: callerGeneration, documentURL: callerURL) {
        (webView.bindCrl as? STWebH5Crl)?.more()
      }
      return success()
    case "setStatusBarTextColor":
      let isDark = bridgeBool(params["isDark"]) ?? true
      self.performForCurrentDocument(webView, generation: callerGeneration, documentURL: callerURL) {
        webView.bindCrl?.currentStatusBarStyle = isDark ? .darkContent : .lightContent
        webView.bindCrl?.setNeedsStatusBarAppearanceUpdate()
      }
      return success()
    case "getStatusBarHeight":
      let height = mainThreadValue { statusBarHeight(for: webView) }
      return success(["height": String(format: "%.6f", height)])
    case "setClipBoardData":
      guard let text = params["text"] as? String else { return failure("缺少 text") }
      self.performForCurrentDocument(webView, generation: callerGeneration, documentURL: callerURL) {
        UIPasteboard.general.string = text
      }
      return success()
    case "jumpWeb":
      guard let url = httpURL(from: params["url"]) else { return failure("url不合法") }
      self.performForCurrentDocument(webView, generation: callerGeneration, documentURL: callerURL) {
        UIApplication.shared.open(url, options: [:])
      }
      return success()
    case "systemShareText":
      guard let text = params["text"] as? String else { return failure("缺少 text") }
      presentShareSheet(items: [text], from: webView)
      return success()
    case "systemShareUrl":
      guard let url = httpURL(from: params["urlStr"]) else {
        return params["urlStr"] == nil ? failure("缺少 urlStr") : failure("url不合法")
      }
      presentShareSheet(items: [url], from: webView)
      return success()
    case "systemShareImage":
      guard let rawImage = params["imgFileStr"] as? String else { return failure("缺少 imgFileStr") }
      guard isValidMiniImageInput(rawImage) else { return failure("图片数据过大") }
      guard let image = image(fromBase64: rawImage) else { return failure("分享图片数据有误") }
      presentShareSheet(items: [image], from: webView)
      return success()
    case "saveImageToPhotosAlbum":
      guard let rawImage = params["imgFileStr"] as? String else { return failure("缺少 imgFileStr") }
      guard isValidMiniImageInput(rawImage) else { return failure("图片数据过大") }
      guard let image = image(fromBase64: rawImage) else { return failure("图片数据有误") }
      saveImageToPhotoLibrary(image, params: params, webView: webView)
      return ["handled": 2]
    case "showPopWeb":
      guard let url = miniPopupURL(from: params["url"]) else { return failure("url不合法") }
      let margins = mainThreadValue {
        popupMargins(left: params["left"], right: params["right"])
      }
      let ratio = boundedRatio(params["ratio"], fallback: 1)
      self.performForCurrentDocument(webView, generation: callerGeneration, documentURL: callerURL) {
        let popup = STWebPopView(leftMargin: margins.left, rightMargin: margins.right, aspectRatio: ratio, url: url)
        popup.callback = { [weak webView] _, _ in
          self.performForCurrentDocument(webView, generation: callerGeneration, documentURL: callerURL) {
            webView?.bindCrl?.viewWillAppear(true)
          }
        }
        popup.showAt(self.currentPresentingViewController()?.view ?? webView)
      }
      return success()
    case "codeVerifSucc":
      self.performForCurrentDocument(webView, generation: callerGeneration, documentURL: callerURL) {
        if webView.environment == .pop, let popup = webView.superview as? STWebPopView {
          popup.complete(info: params)
        }
      }
      return success()
    case "getConfig":
      return success(bridgeConfig(for: webView))
    case "getLanguage":
      return ["handled": 1, "code": "1", "data": ["language": normalizedLanguage()]]
    case "setLanguage":
      return setMiniLanguage(params)
    case "setStorage":
      return setMiniStorage(params, webView: webView)
    case "getStorage":
      return getMiniStorage(params, webView: webView)
    case "removeStorage":
      return removeMiniStorage(params, webView: webView)
    case "getPackageName":
      // Package identity belongs to the embedding host. Returning an empty
      // value by default keeps this reusable component free of business IDs.
      let packageName = (bridgeContext["packageName"] as? String) ?? ""
      return success(["packageName": packageName])
    case "getUserInfo":
      return success(bridgeUserInfo())
    case "getToken":
      let hostToken = (bridgeContext["userInfo"] as? [String: Any])?["token"] as? String
      return success(hostToken ?? "")
    case "applog":
      if let message = params["msg"] ?? params["message"] {
        emit("native_log", ["message": String(describing: message)])
      }
      return success()
    case "logNetworkRequest":
      emit("network_log", sanitizedNetworkLog(params))
      return ["handled": 1, "code": "1", "data": ["recorded": true]]
    default:
      guard webView.allowsOnlineWebHostForwarding else {
        return ["handled": 0]
      }
      forwardOnlineWebBridgeRequest(message, webView: webView)
      return ["handled": 2]
    }
  }

  /// For a configured first-party Online Web origin, pass an otherwise
  /// unhandled request to Flutter. The native side intentionally sends the
  /// normalized origin rather than a document URL, which avoids leaking query
  /// credentials and gives Android/iOS hosts the same authorization key.
  private func performForCurrentDocument(_ webView: STMiniWebView?, generation: UInt64,
                                        documentURL: URL?, work: @escaping () -> Void) {
    DispatchQueue.main.async { [weak self, weak webView] in
      guard let self, !self.detached, let webView,
            webView.bridgeDocumentGeneration == generation, webView.url == documentURL,
            webView.allowsHostSensitiveBridge else { return }
      work()
    }
  }

  private func forwardOnlineWebBridgeRequest(_ message: [String: Any], webView: STMiniWebView) {
    guard let method = message["method"] as? String,
          let methodId = message["methodId"] as? String,
          let currentURL = webView.url,
          let origin = STOnlineWebCore.normalizedHTTPSOrigin(currentURL) else {
      STWebApiManager.callBack(
        ["code": "0", "data": ["msg": "网页 Bridge 请求无效"]],
        method: message["method"] as? String ?? "",
        methodId: message["methodId"] as? String ?? "",
        webView: webView
      )
      return
    }
    guard let methodChannel else {
      STWebApiManager.callBack(
        ["code": "0", "data": ["msg": "宿主未注册网页 Bridge 处理器"]],
        method: method,
        methodId: methodId,
        webView: webView
      )
      return
    }
    let params = message["params"] as? [String: Any] ?? [:]
    let documentGeneration = webView.bridgeDocumentGeneration
    methodChannel.invokeMethod("webBridgeRequest", arguments: [
      "method": method,
      "params": params,
      "origin": origin,
    ]) { [weak webView] response in
      guard let webView, webView.bridgeDocumentGeneration == documentGeneration, webView.url == currentURL, webView.allowsOnlineWebHostForwarding else { return }
      let result: [String: Any]
      if let flutterError = response as? FlutterError {
        result = ["code": "0", "data": ["msg": flutterError.message ?? "宿主网页 Bridge 调用失败"]]
      } else if response == nil || (response as AnyObject?) === FlutterMethodNotImplemented {
        result = ["code": "0", "data": ["msg": "宿主未处理网页 Bridge 请求"]]
      } else if let payload = response as? [String: Any] {
        result = Self.normalizeOnlineWebBridgeResponse(payload)
      } else {
        result = ["code": "0", "data": ["msg": "宿主网页 Bridge 返回格式无效"]]
      }
      STWebApiManager.callBack(result, method: method, methodId: methodId, webView: webView)
    }
  }

  /// Keep the reverse MethodChannel contract byte-for-byte aligned with
  /// Android: only code/data return to H5. A failed host reply always has a
  /// nested `data.msg`, even if Flutter returned a legacy scalar or top-level
  /// message field.
  static func normalizeOnlineWebBridgeResponse(_ payload: [String: Any]) -> [String: Any] {
    let code: String
    switch payload["code"] {
    case let value as NSNumber:
      code = value.intValue == 0 ? "0" : "1"
    case let value as String:
      code = value.trimmingCharacters(in: .whitespacesAndNewlines) == "0" ? "0" : "1"
    default:
      code = "1"
    }
    if code == "0" {
      var data = payload["data"] as? [String: Any] ?? [:]
      if (data["msg"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
        data["msg"] = "宿主处理网页请求失败"
      }
      return ["code": "0", "data": data]
    }
    return ["code": "1", "data": payload["data"] ?? [:]]
  }

  private func success(_ data: Any = [:]) -> [String: Any] {
    ["handled": 1, "code": "1", "data": data]
  }

  /// Mirror the standard iOS H5 bridge close contract.  A missing count closes
  /// the current Mini-owned page; zero returns to the Mini root (or dismisses
  /// a standalone page); a positive count pops that many navigation levels.
  private func closeMiniPage(webView: STMiniWebView, params: [String: Any]) {
    guard let controller = webView.bindCrl else { return }
    guard let rawCount = params["count"] else {
      controller.close()
      return
    }

    let count: Int
    if let number = rawCount as? NSNumber {
      count = number.intValue
    } else if let string = rawCount as? String, let parsed = Int(string) {
      count = parsed
    } else {
      controller.close()
      return
    }

    guard count >= 0 else {
      controller.close()
      return
    }
    guard let navigationController = controller.navigationController else {
      controller.dismiss(animated: true)
      return
    }
    if count == 0 {
      navigationController.popToRootViewController(animated: true)
      return
    }
    let targetIndex = navigationController.viewControllers.count - 1 - count
    guard targetIndex >= 0 else {
      controller.close()
      return
    }
    navigationController.popToViewController(
      navigationController.viewControllers[targetIndex],
      animated: true)
  }

  /// The ordinary iOS bridge stores validated JSON text in UserDefaults and
  /// deserializes it when reading. Do the same here: UserDefaults never sees
  /// an NSNull/property-list-incompatible object, while H5 receives its
  /// original JSON value.
  private func setMiniStorage(_ params: [String: Any], webView: STMiniWebView) -> [String: Any] {
    guard let scope = storageScope(for: webView), let defaults = STMiniScopedStorage.defaults(for: scope) else { return failure("当前文档没有存储主体") }
    guard let key = validMiniStorageKey(params["key"]) else {
      return failure("缺少key")
    }
    guard let value = params["data"] as? String else {
      return failure("应当存储json字符串")
    }
    guard value.lengthOfBytes(using: .utf8) <= Self.maximumMiniStorageBytes else {
      return failure("存储内容过大")
    }
    guard jsonValue(from: value) != nil else {
      return failure("存储出错")
    }
    defaults.set(value, forKey: key)
    return success()
  }

  private func getMiniStorage(_ params: [String: Any], webView: STMiniWebView) -> [String: Any] {
    guard let scope = storageScope(for: webView), let defaults = STMiniScopedStorage.defaults(for: scope) else { return failure("当前文档没有存储主体") }
    guard let key = validMiniStorageKey(params["key"]) else {
      return failure("缺少key")
    }
    guard let stored = defaults.object(forKey: key) else {
      return failure("值不存在")
    }
    if let value = stored as? String {
      // Preserve the legacy iOS contract: old non-JSON strings remain
      // readable as strings, while all current JSON snapshot values decode.
      return success(jsonValue(from: value) ?? value)
    }
    return success(stored)
  }

  /// Removes one Mini-owned storage entry. Keeping this separate from
  /// setStorage lets an authentication logout invalidate the old snapshot
  /// before its anonymous replacement is persisted.
  private func removeMiniStorage(_ params: [String: Any], webView: STMiniWebView) -> [String: Any] {
    guard let scope = storageScope(for: webView), let defaults = STMiniScopedStorage.defaults(for: scope) else { return failure("当前文档没有存储主体") }
    guard let key = validMiniStorageKey(params["key"]) else {
      return failure("缺少key")
    }
    defaults.removeObject(forKey: key)
    return success()
  }

  private func storageScope(for webView: STMiniWebView) -> String? {
    webView.isolatedStorageSubject()
  }

  private func validMiniStorageKey(_ rawKey: Any?) -> String? {
    guard let key = rawKey as? String,
          !key.isEmpty,
          key.count <= 256 else {
      return nil
    }
    return key
  }

  private func jsonValue(from value: String) -> Any? {
    guard let data = value.data(using: .utf8) else { return nil }
    return try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
  }

  private func bridgeBool(_ value: Any?) -> Bool? {
    if let value = value as? Bool { return value }
    if let value = value as? NSNumber { return value.boolValue }
    guard let text = value as? String else { return nil }
    switch text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "1", "true", "yes", "on": return true
    case "0", "false", "no", "off": return false
    default: return nil
    }
  }

  private func toastDuration(_ value: Any?) -> TimeInterval {
    let duration: TimeInterval
    if let number = value as? NSNumber { duration = number.doubleValue }
    else if let text = value as? String, let number = Double(text) { duration = number }
    else { duration = 1 }
    return min(max(duration, 0.1), 10)
  }

  /// Keep the common iOS bridge schema even when a reusable host does not
  /// supply product-specific endpoints. Hosts may override any field through
  /// `bridgeContext.config`; STMini never imports their configuration module.
  private func bridgeConfig(for webView: STMiniWebView) -> [String: Any] {
    var result: [String: Any] = [
      "isChild": webView.isChild ? "1" : "0",
      "baseHost": "",
      "captchaApiKey": "",
      "channel": "",
    ]
    if let config = bridgeContext["config"] as? [String: Any] {
      result.merge(config) { _, hostValue in hostValue }
    }
    return result
  }

  private func statusBarHeight(for webView: STMiniWebView) -> CGFloat {
    if #available(iOS 13.0, *),
       let height = webView.bindCrl?.view.window?.windowScene?.statusBarManager?.statusBarFrame.height,
       height > 0 {
      return height
    }
    return webView.bindCrl?.view.safeAreaInsets.top ?? 0
  }

  private func httpURL(from value: Any?) -> URL? {
    guard let raw = value as? String,
          let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
          let scheme = url.scheme?.lowercased(),
          ["http", "https"].contains(scheme),
          url.host?.isEmpty == false else {
      return nil
    }
    return url
  }

  private func miniPopupURL(from value: Any?) -> String? {
    guard let raw = value as? String else { return nil }
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if httpURL(from: value) != nil || value.hasPrefix(STMiniPrefix.local) {
      return value
    }
    return nil
  }

  private func image(fromBase64 rawValue: String) -> UIImage? {
    let payload = rawValue.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false).last
    guard let payload,
          let data = Data(base64Encoded: String(payload), options: .ignoreUnknownCharacters) else {
      return nil
    }
    return UIImage(data: data)
  }

  private func isValidMiniImageInput(_ rawValue: String) -> Bool {
    rawValue.lengthOfBytes(using: .utf8) <= Self.maximumMiniImageBase64Bytes
  }

  private func boundedInt(_ value: Any?, fallback: Int, range: ClosedRange<Int>) -> Int {
    let parsed: Int?
    if let value = value as? NSNumber { parsed = value.intValue }
    else if let value = value as? String { parsed = Int(value) }
    else { parsed = nil }
    return min(max(parsed ?? fallback, range.lowerBound), range.upperBound)
  }

  private func boundedRatio(_ value: Any?, fallback: CGFloat) -> CGFloat {
    let parsed: CGFloat?
    if let value = value as? NSNumber { parsed = CGFloat(value.doubleValue) }
    else if let value = value as? String, let number = Double(value) { parsed = CGFloat(number) }
    else { parsed = nil }
    return min(max(parsed ?? fallback, 0.2), 3)
  }

  private func popupMargins(left: Any?, right: Any?) -> (left: Int, right: Int) {
    var leftMargin = boundedInt(left, fallback: 50, range: 0...160)
    var rightMargin = boundedInt(right, fallback: 50, range: 0...160)
    // STWebPopView derives its width by subtracting both margins. Keep at
    // least 120pt for the child WebView even on the narrowest phone screen.
    let maximumTotal = max(0, Int(UIScreen.main.bounds.width.rounded(.down)) - 120)
    if leftMargin + rightMargin > maximumTotal {
      leftMargin = min(leftMargin, maximumTotal)
      rightMargin = min(rightMargin, maximumTotal - leftMargin)
    }
    return (leftMargin, rightMargin)
  }

  private func mainThreadValue<T>(_ operation: () -> T) -> T {
    if Thread.isMainThread { return operation() }
    return DispatchQueue.main.sync(execute: operation)
  }

  private func presentShareSheet(items: [Any], from webView: STMiniWebView) {
    let generation = webView.bridgeDocumentGeneration
    let documentURL = webView.url
    performForCurrentDocument(webView, generation: generation, documentURL: documentURL) {
      guard let controller = webView.bindCrl ?? self.currentPresentingViewController() else { return }
      let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
      if let popover = activity.popoverPresentationController {
        popover.sourceView = controller.view
        popover.sourceRect = CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.midY, width: 1, height: 1)
      }
      controller.present(activity, animated: true)
    }
  }

  func saveImageToPhotoLibrary(_ image: UIImage, params: [String: Any], webView: STMiniWebView) {
    // WebKit request entry is main-thread owned. Permission and Photos
    // completions may be background callbacks; none reads WK state there.
    guard Thread.isMainThread, !detached,
          let lease = STWebBridgeEffectLease(webView: webView, generation: webView.bridgeDocumentGeneration) else { return }
    let originalGeneration = webView.bridgeDocumentGeneration
    let access = photoLibraryAccess
    var writeStarted = false
    var finished = false
    let complete: (Bool, String?) -> Void = { [weak self, weak webView] saved, message in
      DispatchQueue.main.async {
        guard !finished else { return }
        finished = true
        guard let self, !self.detached, let webView, lease.isCurrent() else { return }
        let result: [String: Any] = saved
          ? ["code": "1", "data": [:]]
          : ["code": "0", "data": ["msg": message ?? "保存出错"]]
        var model = STWebApiModel(dict: ["method": "saveImageToPhotosAlbum", "params": params])
        model.webview = webView
        model.documentGeneration = originalGeneration
        STWebApiManager.callBack(result, model: model)
      }
    }
    guard let usage = Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryAddUsageDescription") as? String,
          !usage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { complete(false, "宿主未配置相册写入权限"); return }
    let write = { [weak self] in
      DispatchQueue.main.async {
        guard let self, !self.detached, !writeStarted, !finished, lease.isCurrent() else { return }
        writeStarted = true
        access.writeImage(image) { saved in complete(saved, saved ? nil : "保存出错") }
      }
    }
    let authorize: (PHAuthorizationStatus) -> Void = { [weak self] status in
      DispatchQueue.main.async {
        guard let self, !self.detached, !finished, lease.isCurrent() else { return }
        if STMiniPhotoLibraryAccess.mayWrite(status) { write() }
        else { complete(false, "没有权限") }
      }
    }
    let status = access.authorizationStatus()
    if status == .notDetermined { access.requestAuthorization(authorize) }
    else if STMiniPhotoLibraryAccess.mayWrite(status) { write() }
    else { complete(false, "没有权限") }
  }

  private func bridgeUserInfo() -> [String: Any] {
    let isDark = currentPresentingViewController()?.traitCollection.userInterfaceStyle == .dark
    var result: [String: Any] = [
      "device_type": "ios",
      "dark_mode": isDark ? "1" : "0",
      "language_code": normalizedLanguage(),
    ]
    // A host that owns authentication may supply its normal H5 bridge payload
    // through `initialize({ bridgeContext: { userInfo: ... } })`.
    if let userInfo = bridgeContext["userInfo"] as? [String: Any] {
      result.merge(userInfo) { _, hostValue in hostValue }
    }
    return result
  }

  private func failure(_ message: String) -> [String: Any] {
    ["handled": 1, "code": "0", "data": ["msg": message]]
  }

  @objc private func installedPackagesDidChange(_ notification: Notification) {
    var payload = installedPackagesPayload()
    if let miniId = notification.userInfo?["miniId"] as? String {
      payload["miniId"] = miniId
    }
    if let version = notification.userInfo?["version"] as? String {
      payload["version"] = version
    }
    emit("installed_packages_changed", payload)
  }

  private func installedPackagesPayload() -> [String: Any] {
    let packages = STMiniPackageRegistry.installedPackages().map { item in
      [
        "miniId": item.miniId,
        "miniName": item.miniName,
        "iconUrl": item.iconURL,
        "launchLink": item.launchLink,
      ]
    }
    return ["packages": packages]
  }

  private func normalizedLanguage() -> String {
    let language = (UserDefaults.standard.string(forKey: "STLanguageCode")
      ?? Locale.preferredLanguages.first
      ?? "en").trimmingCharacters(in: .whitespacesAndNewlines)
    let normalized = language.lowercased()
    if normalized.hasPrefix("zh-hant") || normalized.contains("hant") || normalized.hasPrefix("zh-tw") || normalized.hasPrefix("zh-hk") {
      return "zh-Hant"
    }
    if normalized.hasPrefix("zh") { return "zh-Hans" }
    return normalized.hasPrefix("en") ? "en-US" : language
  }

  /// Persists the Mini H5's selected locale for STMini-owned UI.  This is
  /// intentionally separate from the Mini storage snapshots: native loading,
  /// retry and alert UI can be shown before a WebView has restored its
  /// JavaScript localStorage.  Existing visible UIKit views are not rebuilt;
  /// every subsequently presented STMini view reads this value dynamically.
  private func setMiniLanguage(_ params: [String: Any]) -> [String: Any] {
    guard let rawLanguage = (params["language"] as? String) ?? (params["languageCode"] as? String) else {
      return failure("缺少 language")
    }
    let language = rawLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !language.isEmpty,
          language.count <= 64,
          language.unicodeScalars.allSatisfy({
            CharacterSet.letters.contains($0)
              || CharacterSet.decimalDigits.contains($0)
              || $0 == "-"
              || $0 == "_"
          }) else {
      return failure("language 无效")
    }
    UserDefaults.standard.set(language, forKey: "STLanguageCode")
    return success(["language": normalizedLanguage()])
  }

  /// `showLoading` is a generic bridge API. Keep it in UIKit so every host
  /// gets the same behavior without embedding an additional third-party
  /// framework (and its separate privacy-manifest maintenance burden).
  private func showLoading(in view: UIView, title: String) {
    if let overlay = view.subviews.compactMap({ $0 as? STMiniLoadingOverlay }).first {
      overlay.update(title: title)
      return
    }

    let overlay = STMiniLoadingOverlay(title: title)
    view.addSubview(overlay)
    NSLayoutConstraint.activate([
      overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      overlay.topAnchor.constraint(equalTo: view.topAnchor),
      overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
  }

  private func hideLoading(in view: UIView) {
    view.subviews.compactMap { $0 as? STMiniLoadingOverlay }.forEach { $0.removeFromSuperview() }
  }

  private func currentPresentingViewController() -> UIViewController? {
    let root: UIViewController?
    if #available(iOS 13.0, *) {
      root = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) }
        .first?.rootViewController
    } else {
      root = UIApplication.shared.keyWindow?.rootViewController
    }
    return topController(from: root)
  }



  private func topController(from controller: UIViewController?) -> UIViewController? {
    if let presented = controller?.presentedViewController, !presented.isBeingDismissed {
      return topController(from: presented)
    }
    if let navigation = controller as? UINavigationController {
      return topController(from: navigation.visibleViewController)
    }
    if let tab = controller as? UITabBarController {
      return topController(from: tab.selectedViewController)
    }
    if let presented = controller?.presentedViewController, !presented.isBeingDismissed {
      return topController(from: presented)
    }
    return controller
  }

  private func sanitizedNetworkLog(_ params: [String: Any]) -> [String: Any] {
    var log: [String: Any] = [:]
    for key in ["phase", "method", "status", "error"] {
      if let value = params[key] { log[key] = value }
    }
    if let rawURL = params["url"] as? String,
       var components = URLComponents(string: rawURL) {
      components.query = nil
      log["url"] = components.string ?? ""
    }
    return log
  }

  private func redactedWebURL(_ url: URL) -> String {
    var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
    parts?.query = nil; parts?.fragment = nil; parts?.user = nil; parts?.password = nil
    return parts?.string ?? "<invalid>"
  }

  private func redactedMiniLink(_ link: String) -> String {
    guard var components = URLComponents(string: link) else { return "mini://" }
    components.query = nil
    return components.string ?? "mini://"
  }

  private func emit(_ name: String, _ payload: [String: Any]) {
    let lease = eventLease
    guard let sink = eventSink else { return }
    let event: [String: Any] = ["name": name, "payload": payload]
    let deliver = { [weak self] in
      guard let self, self.eventLease == lease, !self.detached else { return }
      sink(event)
    }
    if Thread.isMainThread { deliver() } else { DispatchQueue.main.async(execute: deliver) }
  }

}

/// Lightweight UIKit replacement for MBProgressHUD used by the Mini bridge.
/// It deliberately lives in this file to keep the plugin dependency-free.
private final class STMiniLoadingOverlay: UIView {
  private let titleLabel = UILabel()

  init(title: String) {
    super.init(frame: .zero)
    translatesAutoresizingMaskIntoConstraints = false
    backgroundColor = UIColor.black.withAlphaComponent(0.12)
    isUserInteractionEnabled = true
    accessibilityViewIsModal = true
    accessibilityLabel = title.isEmpty ? "Loading" : title

    let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
    card.translatesAutoresizingMaskIntoConstraints = false
    card.layer.cornerRadius = 12
    card.clipsToBounds = true

    let indicator = UIActivityIndicatorView(style: .medium)
    indicator.translatesAutoresizingMaskIntoConstraints = false
    indicator.color = .white
    indicator.startAnimating()

    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.font = .systemFont(ofSize: 13)
    titleLabel.textColor = .white
    titleLabel.textAlignment = .center
    titleLabel.numberOfLines = 2
    titleLabel.text = title

    addSubview(card)
    card.contentView.addSubview(indicator)
    card.contentView.addSubview(titleLabel)
    NSLayoutConstraint.activate([
      card.centerXAnchor.constraint(equalTo: centerXAnchor),
      card.centerYAnchor.constraint(equalTo: centerYAnchor),
      card.widthAnchor.constraint(greaterThanOrEqualToConstant: 96),
      card.widthAnchor.constraint(lessThanOrEqualToConstant: 240),
      card.heightAnchor.constraint(greaterThanOrEqualToConstant: 88),
      indicator.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 20),
      indicator.centerXAnchor.constraint(equalTo: card.contentView.centerXAnchor),
      titleLabel.topAnchor.constraint(equalTo: indicator.bottomAnchor, constant: 10),
      titleLabel.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 16),
      titleLabel.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -16),
      titleLabel.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -16),
    ])
  }

  required init?(coder: NSCoder) {
    nil
  }

  func update(title: String) {
    titleLabel.text = title
    accessibilityLabel = title.isEmpty ? "Loading" : title
  }
}

/// Injectable OS boundary for controlled permission/write tests. The default
/// remains the real add-only Photos API; no fixture is installed by the App.
struct STMiniPhotoLibraryAccess {
  var authorizationStatus: () -> PHAuthorizationStatus
  var requestAuthorization: (@escaping (PHAuthorizationStatus) -> Void) -> Void
  var writeImage: (UIImage, @escaping (Bool) -> Void) -> Void

  static func mayWrite(_ status: PHAuthorizationStatus) -> Bool {
    if status == .authorized { return true }
    if #available(iOS 14, *), status == .limited { return true }
    return false
  }

  static let system = STMiniPhotoLibraryAccess(
    authorizationStatus: {
      if #available(iOS 14, *) { return PHPhotoLibrary.authorizationStatus(for: .addOnly) }
      return PHPhotoLibrary.authorizationStatus()
    },
    requestAuthorization: { completion in
      if #available(iOS 14, *) { PHPhotoLibrary.requestAuthorization(for: .addOnly, handler: completion) }
      else { PHPhotoLibrary.requestAuthorization(completion) }
    },
    writeImage: { image, completion in
      PHPhotoLibrary.shared().performChanges({ PHAssetChangeRequest.creationRequestForAsset(from: image) }) { saved, _ in completion(saved) }
    })
}


/// Lifecycle hooks belong only to this plugin-owned Web container. Foreign
/// modal presentations remain untouched. If an engine detaches while covered,
/// retire our own inert container only after that foreign owner has left.
private final class STStandaloneWebNavigationController: UINavigationController {
  var onWillCover: (() -> Void)?
  private var retirementTimer: Timer?

  override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
    onWillCover?()
    super.present(viewControllerToPresent, animated: flag, completion: completion)
  }

  func retireWhenUncovered() {
    guard retirementTimer == nil else { return }
    if finishRetirementIfUncovered() { return }
    retirementTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
      _ = self?.finishRetirementIfUncovered()
    }
  }

  @discardableResult private func finishRetirementIfUncovered() -> Bool {
    guard presentingViewController != nil else {
      retirementTimer?.invalidate(); retirementTimer = nil
      return true
    }
    guard !isBeingPresented, !isBeingDismissed, presentedViewController == nil,
          visibleViewController?.presentedViewController == nil,
          let window = viewIfLoaded?.window,
          STWebH5Crl.topVisibleController(in: window) === visibleViewController else { return false }
    retirementTimer?.invalidate(); retirementTimer = nil
    dismiss(animated: false)
    return true
  }

  deinit { retirementTimer?.invalidate() }
}
