







import UIKit

public protocol STRequest {
    var path: String { get }
    var method: String { get }
    var params: [String: Any] { get }
    var header: [String: Any] { get }
    associatedtype Response: STResponse
}

public extension STRequest {
    var header: [String: Any] {
        get { return [:] }
    }
}
