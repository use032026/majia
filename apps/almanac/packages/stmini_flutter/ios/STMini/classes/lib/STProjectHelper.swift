






import Foundation

@objc public class STProjectHelper: NSObject {
    
    
    @objc public class func projectName() -> String! {
        let projectName = Bundle.main.infoDictionary?["CFBundleExecutable"] as! String
        return projectName
    }
    
    
    
    
    
    
    
    @objc public class func Log(_ message: String, file: String = #file, line: Int = #line) {
#if DEBUG
        print("")
        print("***************\(STProjectHelper.projectName()!)-Log****************")
        let threadNum = (Thread.current.description as NSString).components(separatedBy: "{").last?.components(separatedBy: ",").first ?? ""
        print("source  :  \((file as NSString).lastPathComponent)[\(line)]\n" +
              "Thread  :  \(threadNum)\n" +
              "Info    :  \(message)"
        )
#endif
        // Keep DEBUG console output, but also forward it to the host's
        // STLogTool file logger for diagnostics from a physical device.
        if let logHandle = STWebPersonalHandle.sharedInstance().logHandle {
            logHandle("[STMini] \(message)")
        }
    }
    
}
