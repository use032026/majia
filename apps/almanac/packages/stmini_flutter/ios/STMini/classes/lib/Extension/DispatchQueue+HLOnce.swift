






import Foundation

extension DispatchQueue {
    static var ST_onceToken = [String]()
    public class func ST_once(_ token: String, _ block: () -> Void) {
        
        objc_sync_enter(self)
        
        defer {
            objc_sync_exit(self)
        }
        if ST_onceToken.contains(token) {
            return
        }
        ST_onceToken.append(token)
        block()
    }
}
