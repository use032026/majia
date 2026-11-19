







import Foundation

@objc public class STWebPopView: UIView {
    
    public var webView: STMiniWebView!
    private var leftMargin: Int = 50
    private var rightMargin: Int = 50
    private var aspectRatio: CGFloat = 0.75 
    private var url: String = ""
    private var isTapDismiss: Bool = false
    
    
    public typealias STWebPopViewCallback = ([String: Any]?, Bool) -> Void
    
    @objc public var callback: STWebPopViewCallback?
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialUI()
    }
    
    @objc public init(leftMargin: Int = 50,
                      rightMargin: Int = 50,
                      aspectRatio: CGFloat = 0.75,
                      url: String = "") {
        self.leftMargin = leftMargin
        self.rightMargin = rightMargin
        self.aspectRatio = aspectRatio
        self.url = url
        super.init(frame: .zero)
        initialUI()
    }
        
    private func initialUI() {
        frame = CGRect(
            x: 0,
            y: 0,
            width: UIScreen.main.bounds.size.width,
            height: UIScreen.main.bounds.size.height
        )
        backgroundColor = UIColor.ST_hex("#000000", alpha: 0.3)
        if isTapDismiss {
            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismiss)))
        }
        
        let maxWidth = Int(UIScreen.main.bounds.width) - leftMargin - rightMargin
        let height = CGFloat(maxWidth) / aspectRatio
        let yPos = (UIScreen.main.bounds.height - height) / 2
        webView = STMiniWebView.init(frame: CGRect(x: CGFloat(leftMargin),
                                               y: yPos,
                                               width: CGFloat(maxWidth),
                                               height: height),
                                 bindCrl: nil)
        webView.isChild = true
        webView.environment = STWebEnv.pop
        webView.layer.cornerRadius = 12;
        webView.layer.masksToBounds = true;
        addSubview(webView)
        if !url.isEmpty {
            if url.hasPrefix(STH5Prefix.http) || url.hasPrefix(STH5Prefix.https) {
                
                let url = URL(string: url)
                let request = URLRequest(url: url!)
                webView.load(request)
            }
            else if url.hasPrefix(STMiniPrefix.local) {
                
                let name = url.replacingOccurrences(of: STMiniPrefix.local, with: "")
                let (miniPath, toPath) = STWebResourceManager.localMiniProgramPath(name: name)
                if miniPath!.count > 0 {
                    let url = URL.init(string: miniPath!)
                    let toUrl = URL.init(string: toPath!)
                    webView.loadFileURL(url!, allowingReadAccessTo: toUrl!)
                }
                else {
                    STProjectHelper.Log("本地小程序\(url)找不到 \n 路径：\(miniPath!)")
                }
            }
            else {
                STProjectHelper.Log("STWebPopView 不支持在线小程序")
            }
        }
    }
    
    @objc public func showAt(_ view: UIView) {
        view.addSubview(self)
    }
    
    @objc func dismiss() {
        self.callback?([:], true)
        removeFromSuperview()
    }
    
    @objc public func complete(info: [String: Any]) {
        self.callback?(info, false)
        removeFromSuperview()
    }
    
}
