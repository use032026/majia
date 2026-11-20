






import Foundation
import CoreVideo
import UIKit


protocol STWebApiHandler {
    
    
    
    
    
    
    static func callBack<T>(_ info: [String: Any], model: T) where T: STWebApiForm
    
}


protocol STWebApiForm {
    
    
    var webview: STMiniWebView? { get }
    var documentGeneration: UInt64? { get }
    
    var method: String { get }

    /// A request can be concurrent with other Bridge calls.  The native
    /// callback must preserve this identifier so the H5 Promise resolves the
    /// response that belongs to it.
    var methodId: String { get }
    
    var params: [String: Any] { get }
    
    associatedtype Handler: STWebApiHandler
    
}







/// Native authority captured at request receipt, not resampled when a queued
/// effect executes. This is distinct from the CMS reply-generation guard.
struct STWebBridgeEffectLease {
    private weak var webView: STMiniWebView?
    private weak var controller: UIViewController?
    private weak var navigationController: UINavigationController?
    private weak var miniRoot: STWebMiniprogramCrl?
    private weak var window: UIWindow?
    private let generation: UInt64
    private let documentURL: URL
    private let hadNavigation: Bool
    private let hadRoot: Bool
    private let hadWindow: Bool
    private let stack: [ObjectIdentifier]
    private let rootVersion: String?

    init?(webView: STMiniWebView?, generation: UInt64?, requiresMiniRoot: Bool = false) {
        guard Thread.isMainThread, let webView, let generation,
              webView.hasNativeEffectAuthority, webView.bridgeDocumentGeneration == generation,
              let documentURL = webView.url, webView.allowsHostSensitiveBridge,
              let controller = webView.bindCrl else { return nil }
        let navigation = controller.navigationController
        let root = webView.owningMiniRootController()
        if requiresMiniRoot && root == nil { return nil }
        if let navigation, !navigation.viewControllers.contains(where: { $0 === controller }) { return nil }
        let originalWindow = controller.viewIfLoaded?.window
        self.webView = webView; self.controller = controller
        navigationController = navigation; miniRoot = root
        window = originalWindow
        self.generation = generation; self.documentURL = documentURL
        hadNavigation = navigation != nil; hadRoot = root != nil; hadWindow = originalWindow != nil
        stack = navigation?.viewControllers.map(ObjectIdentifier.init) ?? []
        rootVersion = root?.loadedMiniPackageVersion
    }

    func isCurrent() -> Bool {
        guard Thread.isMainThread, let webView, let controller,
              webView.hasNativeEffectAuthority, webView.bindCrl === controller, webView.bridgeDocumentGeneration == generation,
              webView.url == documentURL, webView.allowsHostSensitiveBridge,
              !controller.isBeingDismissed, !controller.isMovingFromParent else { return false }
        if hadWindow && (window == nil || controller.viewIfLoaded?.window !== window) { return false }
        if hadNavigation {
            guard let navigationController, controller.navigationController === navigationController,
                  !navigationController.isBeingDismissed,
                  navigationController.viewControllers.map(ObjectIdentifier.init) == stack else { return false }
        } else if controller.navigationController != nil { return false }
        if hadRoot {
            guard let miniRoot, webView.owningMiniRootController() === miniRoot,
                  !miniRoot.isBeingDismissed, !miniRoot.isMovingFromParent else { return false }
            if let rootVersion,
               STWebResourceManager.installedMiniPackageVersion(name: miniRoot.name) != rootVersion { return false }
        }
        return true
    }

    func ownsTarget(_ target: STMiniWebView) -> Bool {
        guard isCurrent(), let navigationController, let miniRoot,
              let owner = target.bindCrl, owner.navigationController === navigationController,
              navigationController.viewControllers.contains(where: { $0 === owner }),
              target.owningMiniRootController() === miniRoot else { return false }
        return true
    }
}
