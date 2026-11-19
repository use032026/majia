






import Foundation


class STWebInfoStorage {
    
    class func sharedInstance() -> STWebInfoStorage {
        
        DispatchQueue.ST_once("STWebInfoStorage") {
            STWebInstanceManager.infoStorage = STWebInfoStorage()
        }
        return STWebInstanceManager.infoStorage!
    }
    
    
    var name: String?
    
    var config: STWebConfig?
    
}
