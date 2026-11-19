






import Foundation

public struct STWebServer: STServer {
    
    public let host = ""

    public func startRequest<T>(_ r: T, handler: @escaping (T.Response) -> Void) where T : STRequest {
        let urlStr = host.appending(r.path)
        let url = URL(string: urlStr)!
        var request = URLRequest(url: url)
        request.httpMethod = r.method
        let task = URLSession.shared.dataTask(with: request) {
            data, response, error in
            
            
            var resDic: [String: Any]
            if data != nil {
                resDic = try! JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String: Any] ?? [:]
            }
            else {
                resDic = [:]
            }
            var res = T.Response.parse(dic: resDic)
            if error != nil {
                
                res?.code = "0"
                res?.error = error
                DispatchQueue.main.async {
                    handler(res!)
                }
            }
            else {
                let httpResponse = response as! HTTPURLResponse
                if httpResponse.statusCode == 200 {
                    
                    DispatchQueue.main.async {
                        handler(res!)
                    }
                }
                else {
                    
                    res?.code = "0"
                    res?.error = STBaseError.init("请求出错")
                    DispatchQueue.main.async {
                        handler(res!)
                    }
                }
            }
        }
        task.resume()
    }
    
    public init() {
    }
    
}
