

























import Foundation


extension Array {
    public func safeObjectAtIndex(_ index: Int) -> Element? {
        if index < self.count {
            return self[index]
        } else {
            return nil
        }
    }
}
