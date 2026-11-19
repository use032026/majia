

























import Foundation


public enum TRStatus: String {
    case waiting
    case running
    case suspended
    case canceled
    case failed
    case removed
    case succeeded

    
    case willSuspend
    case willCancel
    case willRemove
}


public enum TRLogLevel {
    case detailed
    case simple
    case none
}

public typealias TRHandler<T> = (T) -> ()


public class Tiercel<Base> {
    internal let base: Base
    internal init(_ base: Base) {
        self.base = base
    }
}


public protocol TiercelCompatible {
    associatedtype CompatibleType
    var tr: CompatibleType { get }
}


extension TiercelCompatible {
    public var tr: Tiercel<Self> {
        get { return Tiercel(self) }
    }
}


public func TiercelLog<T>(_ message: T, file: String = #file, method: String = #function, line: Int = #line) {
#if DEBUG
    switch TRManager.logLevel {
    case .detailed:
        print("")
        print("***************TiercelLog****************")
        let threadNum = (Thread.current.description as NSString).components(separatedBy: "{").last?.components(separatedBy: ",").first ?? ""

        print("source  :  \((file as NSString).lastPathComponent)[\(line)]\n" +
            "Thread  :  \(threadNum)\n" +
            "Info    :  \(message)"
        )
        print("")
    case .simple: print(message)
    case .none: break
    }
#endif
}
