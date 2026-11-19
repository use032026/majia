







import Foundation

@objc public class STWebCardView: UIView {
    
    public var webView: STMiniWebView!
    private var url: String = ""
    private var cornerRadius: CGFloat = 0

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialUI()
    }
    
    @objc public init(url: String = "", cornerRadius: CGFloat = 0) {
        super.init(frame: .zero)
        self.url = url
        self.cornerRadius = cornerRadius
        initialUI()
    }
    
    private func initialUI() {
        webView = STMiniWebView.init(frame: .zero,
                                 bindCrl: nil)
        webView.isChild = true
        webView.environment = STWebEnv.card
        webView.layer.cornerRadius = self.cornerRadius;
        webView.layer.masksToBounds = true;
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)
        
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: self.topAnchor),
            webView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
        if self.url.count > 0 {
            let url = URL(string: url)
            let request = URLRequest(url: url!)
            webView.load(request)
        }
    }
    
    @objc public func pageWillAppear() {
        STWebApiManager.sendScriptMessageWithMethod("pageWillAppear", params: [:], webview: webView)
    }
    
    @objc public func pageWillDisAppear() {
        STWebApiManager.sendScriptMessageWithMethod("pageWillDisAppear", params: [:], webview: webView)
    }
    
    @objc public func updateUserInfo() {
        STWebApiManager.sendScriptMessageWithMethod("updateUserInfo", params: [:], webview: webView)
    }
    
    @objc public func refresh() {
        STWebApiManager.sendScriptMessageWithMethod("refresh", params: [:], webview: webView)
    }
    
    @objc public func darkModeChanged() {
        STWebApiManager.sendScriptMessageWithMethod("darkModeChanged", params: [:], webview: webView)
    }
    
}
