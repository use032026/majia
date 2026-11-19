







import Foundation

public extension Bundle{
    static var STMiniBundle: Bundle? {
        struct StaticBundle {
            static let miniStr: String =  Bundle(for: STMiniWebView.self).path(forResource: "STMini", ofType: "bundle")!
            static let rbundle: Bundle = Bundle(path: Bundle(path: miniStr)!.path(forResource: "Resource", ofType: "bundle")!)!
        }
        return StaticBundle.rbundle
    }
}
