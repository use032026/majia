






import Foundation
import CryptoKit
import UIKit

/// Warm reuse belongs to the exact local bytes first loaded. A valid version
/// string alone cannot authorize a previously running document after a local
/// replacement. This snapshot is read-only and bounded; it never repairs a pack.
struct STWebMiniPackageIdentity: Equatable {
    let miniId: String
    let version: String
    let entry: String
    private let digest: Data

    static func read(miniId: String, home: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)) -> STWebMiniPackageIdentity? {
        STWebResourceManager.withPackageTransaction(miniId) { readLocked(miniId: miniId, home: home) }
    }

    private static func readLocked(miniId: String, home: URL) -> STWebMiniPackageIdentity? {
        let inventory = LocalPackageInventory(home: home)
        guard let item = try? inventory.package(miniId: miniId, check: {}),
              let version = item["version"], let entry = item["entry"] else { return nil }
        let root = home.standardizedFileURL.resolvingSymlinksInPath()
            .appendingPathComponent("Documents/STMini", isDirectory: true).appendingPathComponent(miniId, isDirectory: true)
        let manager = FileManager.default
        struct Stamp: Equatable {
            let path: String
            let size: UInt64
            let inode: UInt64
            let modified: Date
            let directory: Bool
        }
        func files() throws -> [Stamp] {
            var result: [Stamp] = []
            var total: UInt64 = 0
            func walk(_ directory: URL, depth: Int) throws {
                guard depth <= 16 else { throw LocalPackageInventory.Failure.invalid }
                for url in try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
                    guard result.count < 4096, url.resolvingSymlinksInPath().path == url.path else { throw LocalPackageInventory.Failure.invalid }
                    let attributes = try manager.attributesOfItem(atPath: url.path)
                    let type = attributes[.type] as? FileAttributeType
                    guard type == .typeRegular || type == .typeDirectory,
                          let number = attributes[.systemFileNumber] as? NSNumber,
                          let date = attributes[.modificationDate] as? Date else { throw LocalPackageInventory.Failure.invalid }
                    let size = type == .typeRegular ? (attributes[.size] as? NSNumber)?.uint64Value ?? UInt64.max : 0
                    guard size <= 80 * 1024 * 1024, total <= 80 * 1024 * 1024 - size else { throw LocalPackageInventory.Failure.invalid }
                    total += size
                    let relative = String(url.path.dropFirst(root.path.count + 1))
                    guard LocalPackageInventory.safePath(relative) else { throw LocalPackageInventory.Failure.invalid }
                    result.append(Stamp(path: relative, size: size, inode: number.uint64Value, modified: date, directory: type == .typeDirectory))
                    if type == .typeDirectory { try walk(url, depth: depth + 1) }
                }
            }
            try walk(root, depth: 0)
            return result.sorted { $0.path.utf8.lexicographicallyPrecedes($1.path.utf8) }
        }
        do {
            let before = try files()
            var hash = SHA256()
            for file in before {
                let path = Data(file.path.utf8)
                hash.update(data: Data("\(path.count):\(file.directory ? "d" : "f"):\(file.size):".utf8))
                hash.update(data: path)
                if file.directory { continue }
                guard let stream = InputStream(url: root.appendingPathComponent(file.path)) else { return nil }
                stream.open()
                defer { stream.close() }
                var size: UInt64 = 0
                var buffer = [UInt8](repeating: 0, count: 16_384)
                while true {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    guard count >= 0 else { return nil }
                    if count == 0 { break }
                    size += UInt64(count)
                    guard size <= file.size else { return nil }
                    hash.update(data: Data(buffer.prefix(count)))
                }
                guard size == file.size else { return nil }
            }
            guard try files() == before else { return nil }
            let final = try inventory.package(miniId: miniId, check: {})
            guard final == item else { return nil }
            return STWebMiniPackageIdentity(miniId: miniId, version: version, entry: entry, digest: Data(hash.finalize()))
        } catch { return nil }
    }
}


public struct STWebInstanceManager {

    
    
    static var infoStorage: STWebInfoStorage?
    
    static var webCommonConfig: STWebCommonConfig?
    
    static var personalHandle: STWebPersonalHandle?
    
    
    
    static var reusedLimit = 2
    

    

    
}

/// Keeps cached Mini runtimes attached to the foreground App hierarchy after
/// their visible modal has been dismissed. Merely retaining a detached
/// WKWebView is not enough: WebKit is allowed to throttle its JavaScript
/// timers when the view is no longer in a window. This host is intentionally
/// tiny, transparent and non-interactive; it never becomes a key window or
/// participates in UI. It only applies while the App itself remains
/// foreground-active.
private final class STWebMiniProgramRuntimeHost {

    static let shared = STWebMiniProgramRuntimeHost()

    private weak var hostController: UIViewController?
    private var hostedNavigationControllers: [ObjectIdentifier: STWebNavigationController] = [:]

    private init() {}

    func attach(_ navigationController: STWebNavigationController) {
        let work = {
            if self.hostedNavigationControllers[ObjectIdentifier(navigationController)] != nil {
                return
            }
            guard navigationController.parent == nil,
                  let hostController = self.resolveHostController() else {
                STProjectHelper.Log("小程序运行保活容器不可用，保留缓存但无法维持 Web 运行态")
                return
            }
            let hostView = hostController.view!
            navigationController.willMove(toParent: hostController)
            hostController.addChild(navigationController)
            navigationController.view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
            navigationController.view.alpha = 0.01
            navigationController.view.isUserInteractionEnabled = false
            navigationController.view.accessibilityElementsHidden = true
            hostView.addSubview(navigationController.view)
            navigationController.didMove(toParent: hostController)
            self.hostedNavigationControllers[ObjectIdentifier(navigationController)] = navigationController
            let miniId = (navigationController.viewControllers.first as? STWebMiniprogramCrl)?.miniProgramId ?? ""
            STProjectHelper.Log("小程序<\(miniId)>已挂入持续保活运行容器")
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    func detach(_ navigationController: STWebNavigationController) {
        let work = {
            guard self.hostedNavigationControllers.removeValue(forKey: ObjectIdentifier(navigationController)) != nil else {
                return
            }
            navigationController.willMove(toParent: nil)
            navigationController.view.removeFromSuperview()
            navigationController.removeFromParent()
            navigationController.view.transform = .identity
            navigationController.view.alpha = 1
            navigationController.view.isUserInteractionEnabled = true
            navigationController.view.accessibilityElementsHidden = false
            let miniId = (navigationController.viewControllers.first as? STWebMiniprogramCrl)?.miniProgramId ?? ""
            STProjectHelper.Log("小程序<\(miniId)>退出持续保活运行容器")
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    private func resolveHostController() -> UIViewController? {
        if let hostController, hostController.viewIfLoaded?.window != nil {
            return hostController
        }
        let foregroundScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let window = foregroundScene?.windows.first(where: { $0.isKeyWindow })
            ?? foregroundScene?.windows.first(where: { !$0.isHidden })
        hostController = window?.rootViewController
        return hostController
    }
}

/// Keeps a small number of root Mini-program containers alive after their
/// modal presentation is dismissed.  This is deliberately owned by STMini,
/// rather than by any individual Mini program: a live WebView preserves its
/// JavaScript runtime, bridge subscriptions and page state on re-entry.
///
/// Ordinary entries are FIFO and both ordinary and continuous entries remain
/// attached to the shared invisible runtime host. A package update never
/// replaces files underneath a cached runtime: when the package version
/// changes, that cached runtime is discarded after it next closes and the
/// following launch creates a fresh instance from the new package.
final class STWebMiniProgramKeepAliveStore {

    static let shared = STWebMiniProgramKeepAliveStore()
    private static let continuousKeepAliveWhitelistOptOutDefaultsKey = "STMini.ContinuousKeepAliveWhitelistOptOutMiniIds"

    private struct Entry {
        let miniId: String
        let packageVersion: String
        let packageIdentity: STWebMiniPackageIdentity
        let sessionGeneration: UInt64
        let navigationController: STWebNavigationController
    }

    private var entries: [Entry] = []
    /// These entries are explicitly pinned by the Mini program through the
    /// STMini bridge. They use the same runtime host as ordinary entries, but
    /// do not consume the ordinary FIFO capacity.
    private var continuousEntries: [String: Entry] = [:]
    /// A memory warning deliberately releases hidden WebViews before WebKit
    /// chooses one to kill. Keep an in-process marker so the next cold launch
    /// can explain why a previously kept-alive Mini was reloaded.
    private var memoryWarningReleasedMiniIds: Set<String> = []
    private(set) var sessionGeneration: UInt64 = 0
    private var sessionObservers: [NSObjectProtocol] = []
    private var memoryWarningObserver: NSObjectProtocol?
    private var applicationWillResignActiveObserver: NSObjectProtocol?

    private init() {
        for name in ["kSTLoginSuccessNotification", "kSTChangeAccountSuccessNotification", "kSTLogoutSuccessNotification"] {
            sessionObservers.append(NotificationCenter.default.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in self?.invalidateSession() })
        }
        // Continuous keep-alive intentionally does not consume the normal
        // FIFO quota. It must still yield under actual system memory pressure:
        // discard hidden runtimes proactively and let the next open cold-load
        // from the verified local package instead of waiting for WebKit/iOS to
        // kill an arbitrary content process.
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.releaseHiddenRuntimesForMemoryWarning()
        }
        // When every Mini is already retained, there is no visible root to
        // forward UIApplication lifecycle callbacks. Observe at the pool
        // level so hidden WebViews still receive their final appHide turn.
        applicationWillResignActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.notifyHiddenRuntimesApplicationDidHide()
        }
    }

    deinit {
        sessionObservers.forEach { NotificationCenter.default.removeObserver($0) }
        if let memoryWarningObserver {
            NotificationCenter.default.removeObserver(memoryWarningObserver)
        }
        if let applicationWillResignActiveObserver {
            NotificationCenter.default.removeObserver(applicationWillResignActiveObserver)
        }
    }

    private func releaseHiddenRuntimesForMemoryWarning() {
        let normalEntries = entries
        let pinnedEntries = Array(continuousEntries.values)
        entries.removeAll()
        continuousEntries.removeAll()
        let releasedEntries = normalEntries + pinnedEntries
        releasedEntries.forEach {
            memoryWarningReleasedMiniIds.insert($0.miniId.lowercased())
            discard($0)
        }
        STProjectHelper.Log("小程序收到系统内存警告，已释放隐藏保活实例：普通 \(normalEntries.count) 个，持续 \(pinnedEntries.count) 个")
    }

    /// Returns the once-only notice marker for a runtime that was explicitly
    /// dropped during an iOS memory warning. This is intentionally in memory:
    /// it describes the current App process, not a persistent package state.
    func consumeMemoryWarningRecoveryNotice(miniId: String) -> Bool {
        return memoryWarningReleasedMiniIds.remove(miniId.lowercased()) != nil
    }

    /// `navigationController` is supplied by the close path when UIKit has
    /// already detached the root controller from its navigation hierarchy.
    /// Keeping that reference avoids turning a successful close transition
    /// into an accidental cold launch on the next Mini open.
    func cache(_ controller: STWebMiniprogramCrl,
               navigationController retainedNavigationController: STWebNavigationController? = nil) {
        precondition(Thread.isMainThread)
        if !controller.isKeepAliveRuntimeUsable || controller.skipsKeepAliveOnNextDismiss {
            STProjectHelper.Log("小程序<\(controller.miniProgramId)>首屏未完成或 Web 内容进程已失效，跳过保活缓存")
            controller.releaseClosedRuntime()
            return
        }
        guard !controller.isChild else {
            STProjectHelper.Log("小程序<\(controller.miniProgramId)>是二级页，跳过根保活缓存")
            return
        }
        guard controller.config.webMode == .online else {
            STProjectHelper.Log("小程序<\(controller.miniProgramId)>不是在线包，跳过保活缓存")
            controller.releaseClosedRuntime()
            return
        }
        guard let miniId = controller.name,
              let packageVersion = controller.loadedMiniPackageVersion,
              let identity = controller.loadedMiniPackageIdentity,
              controller.loadedRuntimeSessionGeneration == sessionGeneration,
              STWebMiniPackageIdentity.read(miniId: miniId) == identity,
              let navigationController = retainedNavigationController ?? (controller.navigationController as? STWebNavigationController),
              navigationController.viewControllers.first === controller,
              navigationController.presentingViewController == nil else {
            STProjectHelper.Log("小程序<\(controller.miniProgramId)>本地身份或会话已失效，释放运行态")
            controller.releaseClosedRuntime()
            return
        }

        // A Mini may push an STMini H5 page (for example its usage guide).
        // Cache the navigation controller as a whole so re-entry restores the
        // same visible page and the Mini root runtime underneath it.  The root
        // must remain the first controller; foreign navigation stacks are not
        // eligible for Mini keep-alive.

        if entries.contains(where: { $0.navigationController === navigationController }) || continuousEntries.values.contains(where: { $0.navigationController === navigationController }) { return }
        removeNormalEntry(miniId: miniId)
        controller.setKeepAliveRuntimeHidden(true)
        let entry = Entry(miniId: miniId,
                          packageVersion: packageVersion,
                          packageIdentity: identity, sessionGeneration: sessionGeneration,
                          navigationController: navigationController)

        if isContinuousKeepAliveEnabled(miniId: miniId) {
            if let previous = continuousEntries.updateValue(entry, forKey: miniId),
               previous.navigationController !== navigationController {
                STWebMiniProgramRuntimeHost.shared.detach(previous.navigationController)
                discard(previous)
            }
            STWebMiniProgramRuntimeHost.shared.attach(navigationController)
            controller.setKeepAliveRuntimeHidden(true)
            STProjectHelper.Log("小程序<\(miniId)>进入持续保活缓存，版本 \(packageVersion)")
            return
        }

        if let previous = continuousEntries.removeValue(forKey: miniId),
           previous.navigationController !== navigationController {
            STWebMiniProgramRuntimeHost.shared.detach(previous.navigationController)
            discard(previous)
        }
        entries.append(entry)
        STWebMiniProgramRuntimeHost.shared.attach(navigationController)
        controller.setKeepAliveRuntimeHidden(true)

        while entries.count > STWebInstanceManager.reusedLimit {
            discard(entries.removeFirst())
        }
        STProjectHelper.Log("小程序<\(miniId)>进入普通保活缓存，版本 \(packageVersion)")
    }

    func take(miniId: String, config: STWebConfig) -> STWebNavigationController? {
        precondition(Thread.isMainThread)
        let reuseStartedAt = Date()
        let entry: Entry?
        if let continuous = continuousEntries.removeValue(forKey: miniId) {
            entry = continuous
        } else if let index = entries.firstIndex(where: { $0.miniId == miniId }) {
            entry = entries.remove(at: index)
        } else {
            entry = nil
        }
        guard let entry = entry else {
            return nil
        }
        STWebMiniProgramRuntimeHost.shared.detach(entry.navigationController)

        guard let controller = entry.navigationController.viewControllers.first as? STWebMiniprogramCrl else {
            discard(entry)
            return nil
        }
        guard controller.isKeepAliveRuntimeUsable else {
            STProjectHelper.Log("小程序<\(miniId)>保活实例的 Web 内容进程已失效，释放后冷启动")
            discard(entry)
            return nil
        }
        guard
              entry.sessionGeneration == sessionGeneration,
              STWebMiniPackageIdentity.read(miniId: miniId) == entry.packageIdentity,
              STWebResourceManager.installedMiniPackageVersion(name: miniId) == entry.packageVersion,
              canReuse(miniId: miniId, config: config) else {
            discard(entry)
            return nil
        }

        controller.prepareForKeepAliveReuse(config: config)
        let reuseCostMs = Int(Date().timeIntervalSince(reuseStartedAt) * 1000)
        STProjectHelper.Log("小程序<\(miniId)>命中保活缓存，版本 \(entry.packageVersion)，宿主恢复耗时 \(reuseCostMs)ms")
        return entry.navigationController
    }

    /// The visible Mini root delivers its own lifecycle notification. Cached
    /// roots remain hidden in the runtime host, but must still receive the
    /// last appHide turn so their H5 runtime can persist state and invalidate
    /// any market work that iOS may freeze. appShow stays deferred until the
    /// user explicitly reopens that particular Mini.
    func notifyHiddenRuntimesApplicationDidHide() {
        let hiddenEntries = entries + Array(continuousEntries.values)
        hiddenEntries.forEach { entry in
            guard let controller = entry.navigationController.viewControllers.first as? STWebMiniprogramCrl else {
                return
            }
            controller.notifyHostApplicationHiddenWhileRetained()
        }
        if !hiddenEntries.isEmpty {
            STProjectHelper.Log("小程序 appHide 已下发至隐藏保活实例：\(hiddenEntries.count) 个")
        }
    }

    /// This is intentionally an STMini-level preference, keyed by miniId.
    /// It survives a cold app relaunch as a setting, but the retained WebView
    /// itself only lives for the current App process.
    func setContinuousKeepAlive(_ enabled: Bool, for miniId: String) {
        guard supportsContinuousKeepAlive(miniId: miniId) else {
            STProjectHelper.Log("小程序<\(miniId)>不在持续保活白名单，忽略设置请求")
            return
        }
        var optOutIds = continuousKeepAliveWhitelistOptOutIds()
        if enabled {
            optOutIds.remove(miniId.lowercased())
        } else {
            optOutIds.insert(miniId.lowercased())
        }
        UserDefaults.standard.set(Array(optOutIds).sorted(), forKey: Self.continuousKeepAliveWhitelistOptOutDefaultsKey)
        STProjectHelper.Log("小程序<\(miniId)>持续保活白名单设置：\(enabled)")

        guard !enabled, let entry = continuousEntries.removeValue(forKey: miniId) else {
            return
        }
        entries.removeAll { $0.miniId == miniId }
        entries.append(entry)
        // Continuous and ordinary keep-alive share the same transparent
        // runtime host. Downgrading only changes FIFO capacity accounting;
        // do not detach the live WebView in between.
        STWebMiniProgramRuntimeHost.shared.attach(entry.navigationController)
        while entries.count > STWebInstanceManager.reusedLimit {
            discard(entries.removeFirst())
        }
        STProjectHelper.Log("小程序<\(miniId)>关闭持续保活，回归普通保活 FIFO")
    }

    func isContinuousKeepAliveEnabled(miniId: String) -> Bool {
        return supportsContinuousKeepAlive(miniId: miniId)
            && !continuousKeepAliveWhitelistOptOutIds().contains(miniId.lowercased())
    }

    func supportsContinuousKeepAlive(miniId: String) -> Bool {
        return isContinuousKeepAliveWhitelisted(miniId)
    }

    @discardableResult
    func remove(_ controller: STWebMiniprogramCrl) -> Bool {
        guard let miniId = controller.name else {
            return false
        }
        let normalIndex = entries.firstIndex(where: {
            ($0.navigationController.viewControllers.first as? STWebMiniprogramCrl) === controller
        })
        let continuousEntry = continuousEntries[miniId]
        guard normalIndex != nil || (continuousEntry?.navigationController.viewControllers.first as? STWebMiniprogramCrl) === controller else {
            return false
        }
        if let normalIndex = normalIndex {
            let entry = entries.remove(at: normalIndex)
            STWebMiniProgramRuntimeHost.shared.detach(entry.navigationController)
        }
        if continuousEntry != nil {
            continuousEntries.removeValue(forKey: miniId)
            STWebMiniProgramRuntimeHost.shared.detach(continuousEntry!.navigationController)
        }
        // A cancelled interactive dismissal leaves this controller visible.
        // Keep it running, but do not let an unrelated later detachment skip
        // cleanup before it has been cached again.
        controller.webView.preserveRuntimeWhenDetached = false
        STProjectHelper.Log("小程序<\(miniId)>取消保活缓存")
        return true
    }

    /// A terminated WKWebView can never be safely resumed. Unlike ordinary
    /// cache removal (which may be caused by a cancelled transition), release
    /// its bridge and delegates immediately before the next cold launch.
    @discardableResult
    func discardTerminated(_ controller: STWebMiniprogramCrl) -> Bool {
        guard remove(controller) else { return false }
        controller.releaseClosedRuntime()
        STProjectHelper.Log("小程序<\(controller.miniProgramId)>已丢弃终止的保活实例")
        return true
    }

    private func removeNormalEntry(miniId: String) {
        let removed = entries.filter { $0.miniId == miniId }
        entries.removeAll { $0.miniId == miniId }
        removed.forEach(discard)
    }

    private func isContinuousKeepAliveWhitelisted(_ miniId: String) -> Bool {
        // The reusable container must never embed product Mini IDs. Hosts
        // may opt in through initialize.bridgeContext.miniSecurity; the
        // default is no continuous keep-alive.
        return StminiFlutterPlugin.continuousKeepAliveMiniIds().contains(miniId.lowercased())
    }

    private func continuousKeepAliveWhitelistOptOutIds() -> Set<String> {
        let values = UserDefaults.standard.stringArray(forKey: Self.continuousKeepAliveWhitelistOptOutDefaultsKey) ?? []
        return Set(values.map { $0.lowercased() }.filter { !$0.isEmpty })
    }

    private func canReuse(miniId: String, config: STWebConfig) -> Bool {
        guard config.params?["__st_force_self_update"]?.trimmingCharacters(in: .whitespacesAndNewlines) != "1",
              [config.params?["currentVersion"], config.params?["minSupportVersion"]].compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) }).filter({ !$0.isEmpty }).allSatisfy(STWebResourceManager.validMiniVersion) else { return false }
        if let raw = config.params?["downloadUrl"], !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)).map(StminiFlutterPlugin.isMiniDownloadURLAllowed) != true { return false }
        return STWebResourceManager.isInstalledMiniPackageRunnable(name: miniId,
            currentVersion: config.params?["currentVersion"], minSupportVersion: config.params?["minSupportVersion"])
    }

    func invalidateSession() {
        precondition(Thread.isMainThread)
        MiniPackageOperation.cancelAll()
        sessionGeneration &+= 1
        removeAll()
    }

    func removeAll() {
        precondition(Thread.isMainThread)
        let previous = entries + Array(continuousEntries.values)
        entries.removeAll(); continuousEntries.removeAll()
        previous.forEach(discard)
    }

    private func discard(_ entry: Entry) {
        guard let controller = entry.navigationController.viewControllers.first as? STWebMiniprogramCrl else {
            return
        }
        STWebMiniProgramRuntimeHost.shared.detach(entry.navigationController)
        controller.releaseClosedRuntime()
        STProjectHelper.Log("小程序<\(entry.miniId)>移出保活缓存")
    }
}
