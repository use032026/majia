






import Foundation
import UIKit


public class STWebCommonConfig {
    
    public class func sharedInstance() -> STWebCommonConfig {
        
        DispatchQueue.ST_once("STWebCommonConfig") {
            STWebInstanceManager.webCommonConfig = STWebCommonConfig()
        }
        return STWebInstanceManager.webCommonConfig!
    }
    
    
    public var naviBarColor: UIColor = .white
    
    public var naviBarBottomLineIsHidden: Bool = false
    
}
