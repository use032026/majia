






import Foundation
import UIKit


@objc public enum STWebMode: Int {
    case h5
    case online
    case local
}


@objc public enum STWebOpenSource: Int {
    case h5
    case mini
}

/// Defines how much host-provided bridge capability an H5 controller may
/// request. This is deliberately an *upper bound*: ordinary external pages
/// never receive host account/session/business APIs.
@objc public enum STWebBridgePolicy: Int {
    /// An ordinary external H5 page. It can use the common Web bridge but
    /// never receives Mini package/update/navigation APIs.
    case externalUntrusted
    /// An HTTPS page pushed by a verified Mini through `open({ router: "/web" })`.
    /// It may use the host's ordinary bridge just like the native STMini
    /// implementation and retains the verified root Mini identity while that
    /// root remains in its navigation stack.
    case miniExternal
    /// A verified installed Mini package, or a host-bundled local Mini page.
    case localMini
}


@objc public class STWebConfig: NSObject {
    @objc public var webMode: STWebMode = .online
    public var path: String?          
    @objc public var params: [String: String]?  
    /// The original mini:// URL. It is native-only metadata used to remember
    /// a successfully installed online package's update source; it is never
    /// exposed to the mini program JavaScript runtime.
    public var sourceLink: String?
    public var openSource: STWebOpenSource = .h5 
    /// Defaults to the external Web behavior without Mini-only APIs.
    @objc public var bridgePolicy: STWebBridgePolicy = .externalUntrusted
    /// HTTP navigation/Bridge stays disabled unless the host explicitly opts in.
    public var allowsInsecureHttpNavigation = false
    
    public override init() {
        super.init()
    }
    
    public init(webMode: STWebMode) {
        self.webMode = webMode
        super.init()
    }
    
    public init(webMode: STWebMode, path: String? = nil, params: [String: String]? = nil) {
        self.webMode = webMode
        self.path = path
        self.params = params
        super.init()
    }
}

@objc public enum STWebEnv: Int {
    case normal
    case card
    case pop
}
