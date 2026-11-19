import Foundation
@preconcurrency import WebKit

/// Shared owner for an online `WKWebView` document.
///
/// It deliberately does not know about Mini packages, local resources,
/// keep-alive or STMini APIs. The embedding adapter supplies only a narrow
/// message callback; both host `openWeb` and a Mini-pushed `/web` construct
/// this owner around their WebKit view.
public final class OnlineWebViewController {
  public typealias MessageHandler = (Any) -> Void

  public weak var webView: WKWebView?
  public var onMessage: MessageHandler?
  public var onTitleChanged: ((String) -> Void)?
  public let lifecycle = STOnlineWebDisplayLifecycle()
  private let allowInsecureHttpBridge: Bool

  public init(
    webView: WKWebView,
    allowInsecureHttpBridge: Bool = false,
    onMessage: MessageHandler? = nil
  ) {
    self.webView = webView
    self.allowInsecureHttpBridge = allowInsecureHttpBridge
    self.onMessage = onMessage
  }

  /// The complete WebKit boundary: an allowed-protocol main frame whose URL
  /// still matches the currently displayed document.
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

  public func didCommitPage() {
    guard let webView else { return }
    webView.evaluateJavaScript("document.title") { [weak self] result, error in
      guard error == nil, let title = result as? String,
            let displayTitle = STOnlineWebCore.displayTitle(title) else { return }
      self?.onTitleChanged?(displayTitle)
    }
  }

  public func didAppear() { lifecycle.didAppear() }
  public func didDisappear() { lifecycle.didDisappear() }
  public func release() { lifecycle.release() }
}
