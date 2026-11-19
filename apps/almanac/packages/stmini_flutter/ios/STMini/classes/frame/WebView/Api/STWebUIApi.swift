






import Foundation


struct STWebUIApi {
    
    
    
    
    
    
    
    
    func showToast<T>(model: T) where T: STWebApiForm {
        guard let msg = model.params["msg"] as? String else {
            STProjectHelper.Log("api<showToast>msg没有传")
            return
        }
        var mode = model.params["mode"] as? UInt32
        if (mode == nil) {
            mode = 0
        }
        var duration = model.params["duration"] as? TimeInterval
        if (duration == nil) {
            duration = 2
        }
        var location = model.params["location"] as? UInt32
        if (location == nil) {
            location = 2
        }
        
        T.Handler.callBack(["code": "1", "msg": "成功"], model: model)
    }
    
    
    
    
    
    func setNavigationBarTitle<T>(model: T) where T: STWebApiForm {
        guard let title = model.params["title"] as? String else {
            STProjectHelper.Log("api<setNavigationBarTitle>title没有传")
            return
        }
        model.webview!.bindCrl!.title = title
    }
    
}
