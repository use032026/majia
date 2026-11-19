

























import Foundation

extension DispatchQueue: TiercelCompatible {}
extension Tiercel where Base: DispatchQueue {
    internal func safeAsync(_ block: @escaping ()->()) {
        if Thread.isMainThread {
            block()
        } else if base == DispatchQueue.main {
            base.async { block() }
        } else {
            DispatchQueue.main.async {
                block()
            }
        }
    }
    
}
