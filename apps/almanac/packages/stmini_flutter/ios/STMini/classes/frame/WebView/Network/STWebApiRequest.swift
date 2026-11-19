






import Foundation

struct STApiModel: STResponse {
    
    var originDic: [String: Any]!

    static func parse(dic: [String: Any]) -> STApiModel? {
        
        if dic.count > 0 {
            var model = STApiModel.init(originDic: dic["data"] as? [String : Any] ?? [:])
            
            model.code = (dic["errorCode"] as? String ?? "0") == "0" ? "1" : "0"
            model.error = STBaseError(dic["errorMsg"] as? String ?? "")
            return model
        }
        else {
            return STApiModel.init(originDic: [:])
        }
    }
    
}

struct STWebApiRequest: STRequest {
    
    var path: String
    var method: String
    var params: [String : Any]
    typealias Response = STApiModel
    
}
