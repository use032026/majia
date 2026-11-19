

























import Foundation

extension Int64: TiercelCompatible {}
extension Tiercel where Base == Int64 {
    
    
    
    
    public func convertSpeedToString() -> String {
        let size = convertBytesToString()
        return [size, "s"].joined(separator: "/")
    }
    
    
    
    
    public func convertTimeToString() -> String {
        let formatter = DateComponentsFormatter()
        
        formatter.unitsStyle = .positional
        
        return formatter.string(from: TimeInterval(base)) ?? ""
    }
    
    
    
    
    public func convertBytesToString() -> String {
        return ByteCountFormatter.string(fromByteCount: base, countStyle: .file)
    }
    
    
}
