







import Foundation

public class STWebPersonalHandle: NSObject {
    
    
    @objc public var apiHandle: (([String: Any], STMiniWebView) -> [String: Any])?

    /// Host adapter for the quant-only API surface. STMini owns method
    /// recognition and Mini navigation-stack isolation; the host supplies the
    /// account, MCP-session and scoped-persistence implementation because
    /// those services belong to the embedding App rather than the container.
    /// Ordinary H5 never reaches this adapter.
    @objc public var quantMiniApiHandle: (([String: Any], STMiniWebView) -> [String: Any])?

    /// Optional host-owned implementation for the common Mini update-check
    /// API. STMini invokes it only when the verified package manifest has
    /// `updateself: "0"`; third-party Minis stay self-updating.
    @objc public var miniProgramUpdateCheckHandle: (([String: Any], STMiniWebView) -> [String: Any])?
    
    @objc public var logHandle: ((String) -> Void)?
    
    @objc public var loadingImg: String?
    
    @objc public var noti_updateUserInfo: String = ""
    
    
    @objc public var darkModeHandle: (() -> Bool)?

    @objc public class func sharedInstance() -> STWebPersonalHandle {
        
        DispatchQueue.ST_once("STWebPersonalHandle") {
            STWebInstanceManager.personalHandle = STWebPersonalHandle()
        }
        return STWebInstanceManager.personalHandle!
    }
}
