







import UIKit

public protocol STServer {
    var host: String { get }
    func startRequest<T: STRequest>(_ r: T, handler: @escaping (T.Response) -> Void)
}

public struct URLSessionServer: STServer {
    public let host = "https://www.wanandroid.com"

    public func startRequest<T>(_ r: T, handler: @escaping (T.Response) -> Void) where T : STRequest {
        let url = URL(string: host.appending(r.path))!
        var request = URLRequest(url: url)
        request.httpMethod = r.method
        
        
        let task = URLSession.shared.dataTask(with: request) {
            data, _, error in





        }
        task.resume()
    }
    
    public init() {
    }
}
