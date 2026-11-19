






import Foundation


struct STWebApiModel: STWebApiForm {
    
    
    weak var webview: STMiniWebView? { didSet { documentGeneration = webview?.bridgeDocumentGeneration } }
    var documentGeneration: UInt64?
    
    var method: String = ""
    
    var methodId: String = ""
    
    var params: [String: Any] = [:]
    
    typealias Handler = STWebApiManager
    
    
    init(dict: [String: Any]) {
        method = dict["method"] as? String ?? ""
        params = dict["params"] as? [String: Any] ?? [:]
        methodId = params["methodId"] as? String ?? ""
    }
    
}
