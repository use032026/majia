

























import Foundation


extension Double: TiercelCompatible {}
extension Tiercel where Base == Double {
    
    
    
    public func convertTimeToDateString() -> String {
        let date = Date(timeIntervalSince1970: base)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
}
