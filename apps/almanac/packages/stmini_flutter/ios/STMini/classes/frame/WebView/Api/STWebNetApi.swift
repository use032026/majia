






import Foundation


struct STWebNetApi {
    
    
    
    
    
    
    
    
    
    func request<T>(model: T) where T: STWebApiForm {
        guard let url = model.params["url"] as? String else {
            STProjectHelper.Log("api<request>url没有传")
            return
        }
        var data = model.params["data"] as? [String: Any]
        if (data == nil) {
            data = [:]
        }
        var header = model.params["header"] as? [String: Any]
        if (header == nil) {
            header = [:]
        }
        var timeout = model.params["timeout"] as? TimeInterval
        if (timeout == nil) {
            timeout = 60000
        }
        var method = model.params["method"] as? String
        if (method == nil) {
            method = "GET"
        }
        STWebServer().startRequest(STWebApiRequest(path: url, method: method!, params: data!)) { apiModel in
            STProjectHelper.Log("url<\(url)>请求结果: \n\(String(describing: apiModel.originDic))")
            T.Handler.callBack(["code": apiModel.code,
                                         "msg": apiModel.error.debugDescription,
                                         "data": apiModel.originDic ?? [:]], model: model)
        }
    }
    
}
