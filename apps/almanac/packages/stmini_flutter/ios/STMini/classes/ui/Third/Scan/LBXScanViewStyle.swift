







import UIKit


public enum LBXScanViewAnimationStyle {
    case LineMove 
    case NetGrid 
    case LineStill 
    case None 
}


public enum LBXScanViewPhotoframeAngleStyle {
    case Inner 
    case Outer 
    case On 
}


public struct LBXScanViewStyle {
    
    

    
    public var isNeedShowRetangle = true

    
    public var whRatio: CGFloat = 1.0

    
    public var centerUpOffset: CGFloat = 44

    
    public var xScanRetangleOffset: CGFloat = 60

    
    public var colorRetangleLine = UIColor.white

    

    
    public var photoframeAngleStyle = LBXScanViewPhotoframeAngleStyle.Outer

    
    public var colorAngle = UIColor(red: 0.0, green: 167.0 / 255.0, blue: 231.0 / 255.0, alpha: 1.0)

    
    public var photoframeAngleW: CGFloat = 24.0
    public var photoframeAngleH: CGFloat = 24.0
    
    
    public var photoframeLineW: CGFloat = 6

    

    
    public var anmiationStyle = LBXScanViewAnimationStyle.LineMove

    
    public var animationImage: UIImage?

    

    public var color_NotRecoginitonArea = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.5)

    public init() { }
    
}
