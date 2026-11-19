






import Foundation
import UIKit

public class STScreenHelper: NSObject {
    @objc public class func keyWindow() -> UIWindow! {
        return (UIApplication.shared.keyWindow)!
    }
    
    
    @objc public class func ST_safeDistanceTop() -> CGFloat {
        if #available(iOS 13.0, *) {
            let scene = UIApplication.shared.connectedScenes.first
            guard let windowScene = scene as? UIWindowScene else { return 0 }
            guard let window = windowScene.windows.first else { return 0 }
            return window.safeAreaInsets.top
        } else if #available(iOS 11.0, *) {
            guard let window = UIApplication.shared.windows.first else { return 0 }
            return window.safeAreaInsets.top
        }
        return 0;
    }
    
    
    @objc public class func ST_safeDistanceBottom() -> CGFloat {
        if #available(iOS 13.0, *) {
            let scene = UIApplication.shared.connectedScenes.first
            guard let windowScene = scene as? UIWindowScene else { return 0 }
            guard let window = windowScene.windows.first else { return 0 }
            return window.safeAreaInsets.bottom
        } else if #available(iOS 11.0, *) {
            guard let window = UIApplication.shared.windows.first else { return 0 }
            return window.safeAreaInsets.bottom
        }
        return 0;
    }
    
    
    @objc public class func ST_statusBarHeight() -> CGFloat {
        var statusBarHeight: CGFloat = 0
        if #available(iOS 13.0, *) {
            let scene = UIApplication.shared.connectedScenes.first
            guard let windowScene = scene as? UIWindowScene else { return 0 }
            guard let statusBarManager = windowScene.statusBarManager else { return 0 }
            statusBarHeight = statusBarManager.statusBarFrame.height
        } else {
            statusBarHeight = UIApplication.shared.statusBarFrame.height
        }
        return statusBarHeight
    }
    
    
    @objc public class func ST_navigationBarHeight() -> CGFloat {
        return 44.0
    }
    
    
    @objc public class func ST_navigationFullHeight() -> CGFloat {
        return STScreenHelper.ST_statusBarHeight() + STScreenHelper.ST_navigationBarHeight()
    }
    
    
    @objc public class func ST_tabBarHeight() -> CGFloat {
        return 49.0
    }
    
    
    @objc public class func ST_tabBarFullHeight() -> CGFloat {
        return STScreenHelper.ST_tabBarHeight() + STScreenHelper.ST_safeDistanceBottom()
    }
    
    
    
    
    
    
    @objc public class func screenShotIn(view: UIView!) -> UIImage {
        
        UIGraphicsBeginImageContext(view.frame.size)
        view.layer.render(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
    
    
    
    
    
    
    @objc public class func screenShot(saveToAlbum: Bool = false) -> UIImage {
        let layer = UIApplication.shared.keyWindow!.layer
        let scale = UIScreen.main.scale
        UIGraphicsBeginImageContextWithOptions(layer.frame.size, false, scale);
        layer.render(in: UIGraphicsGetCurrentContext()!)
        let screenshot = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        if saveToAlbum {
            UIImageWriteToSavedPhotosAlbum(screenshot!, nil, nil, nil)
        }
        return screenshot!
    }
    
}
