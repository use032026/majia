







import UIKit

public protocol STResponse {
    
    
    static func parse(dic: [String: Any]) -> Self?
    
    
    var code: String { get set }
    
    
    var error: Error? { get set }
    
    
    var handled: Bool { get set }
    
}


public extension STResponse {
    
    var code: String {
        get { return "1" }
        set {}
    }
    
    var error: Error? {
        get { return nil }
        set {}
    }
    
    var handled: Bool {
        get { return false }
        set {}
    }
    
}


public struct STBaseError: LocalizedError {
    
    
    var desc = "未知错误"
    
    
    var reason = ""
    
    
    var suggestion = ""
    
    
    var help = ""
    
    
    public var errorDescription: String? {
        return desc
    }
    
    public var failureReason: String? {
        return reason
    }
    
    public var recoverySuggestion: String? {
        return suggestion
    }
    
    public var helpAnchor: String? {
        return help
    }
    
    public init(_ desc: String) {
        self.desc = desc
    }
    
}
