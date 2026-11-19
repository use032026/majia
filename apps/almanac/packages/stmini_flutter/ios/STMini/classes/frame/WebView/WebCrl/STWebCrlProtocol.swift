






import Foundation
import UIKit


@objc public protocol STWebCrlProtocol: NSObjectProtocol {
    
    
    var config: STWebConfig! { get set }
    var webView: STMiniWebView! { get set }
    
    
    func webviewDidFinish()

    /// Navigation failures are optional because only controllers that load
    /// ordinary remote H5 pages need transport-level recovery.
    @objc optional func webviewDidFailNavigation(_ error: NSError)

    /// WKWebView owns a separate Web Content process.  The callback belongs to
    /// the concrete controller that owns the affected WebView, which can be a
    /// Mini root or a Mini-owned H5 child page.
    func webviewContentProcessDidTerminate()
    
    func close()
    
}
