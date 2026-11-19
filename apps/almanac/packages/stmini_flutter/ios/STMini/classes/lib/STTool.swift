






import Foundation
import UIKit

public class STTool: NSObject {
    
    @objc public class func convertDictionaryToString(dict: [String: Any]) -> String {
        var result:String = ""
        do {
            
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: JSONSerialization.WritingOptions.init(rawValue: 0))
            
            if let JSONString = String(data: jsonData, encoding: String.Encoding.utf8) {
                result = JSONString
            }
            
        } catch {
            result = ""
        }
        return result
    }
    
    
    
    
    
    
    @objc public class func getUrlParameters(url: String) -> [String: String]? {
        var params: [String: String] = [:]
        let array = url.components(separatedBy: "?")
        params["urlPath"] = array.first
        if array.count == 2 {
            let paramsStr = array[1]
            if paramsStr.count > 0 {
                let paramsArray = paramsStr.components(separatedBy: "&")
                for param in paramsArray {
                    let arr = param.components(separatedBy: "=")
                    if arr.count == 2 {
                        params[arr[0]] = arr[1]
                    }
                }
            }
        }
        return params
    }
    
    
    @objc public class func currentViewController() -> (UIViewController?) {
        var window = UIApplication.shared.keyWindow
        if window?.windowLevel != UIWindow.Level.normal{
            let windows = UIApplication.shared.windows
            for  windowTemp in windows{
                if windowTemp.windowLevel == UIWindow.Level.normal{
                    window = windowTemp
                    break
                }
            }
        }
        let vc = window?.rootViewController
        return currentVC(vc)
    }
    
    class private func currentVC(_ vc :UIViewController?) -> UIViewController? {
        if vc == nil {
            return nil
        }
        if let presentVC = vc?.presentedViewController {
            return currentVC(presentVC)
        }
        else if let tabVC = vc as? UITabBarController {
            if let selectVC = tabVC.selectedViewController {
                return currentVC(selectVC)
            }
            return nil
        }
        else if let naiVC = vc as? UINavigationController {
            return currentVC(naiVC.visibleViewController)
        }
        else {
            return vc
        }
    }
    
}
