







import UIKit

open class LBXScanView: UIView {
    
    
    var viewStyle = LBXScanViewStyle()

    
    var scanRetangleRect = CGRect.zero

    
    var scanLineAnimation: LBXScanLineAnimation?

    
    var scanNetAnimation: LBXScanNetAnimation?
    
    
    var scanLineStill: UIImageView?

    
    var activityView: UIActivityIndicatorView?

    
    var labelReadying: UILabel?

    
    var isAnimationing = false
    
    
    public init(frame: CGRect, vstyle: LBXScanViewStyle) {
        viewStyle = vstyle

        switch viewStyle.anmiationStyle {
        case LBXScanViewAnimationStyle.LineMove:
            scanLineAnimation = LBXScanLineAnimation.instance()
        case LBXScanViewAnimationStyle.NetGrid:
            scanNetAnimation = LBXScanNetAnimation.instance()
        case LBXScanViewAnimationStyle.LineStill:
            scanLineStill = UIImageView()
            scanLineStill?.image = viewStyle.animationImage
        default:
            break
        }

        var frameTmp = frame
        frameTmp.origin = CGPoint.zero

        super.init(frame: frameTmp)

        backgroundColor = UIColor.clear
    }
    
    override init(frame: CGRect) {
        var frameTmp = frame
        frameTmp.origin = CGPoint.zero

        super.init(frame: frameTmp)

        backgroundColor = UIColor.clear
    }
    
    public required init?(coder aDecoder: NSCoder) {
        self.init()
    }

    deinit {
        if scanLineAnimation != nil {
            scanLineAnimation!.stopStepAnimating()
        }
        if scanNetAnimation != nil {
            scanNetAnimation!.stopStepAnimating()
        }
    }
    
    
    
    func startScanAnimation() {
        guard !isAnimationing else {
            return
        }
        isAnimationing = true

        let cropRect = getScanRectForAnimation()

        switch viewStyle.anmiationStyle {
        case .LineMove:
            scanLineAnimation?.startAnimatingWithRect(animationRect: cropRect,
                                                      parentView: self,
                                                      image: viewStyle.animationImage)
        case .NetGrid:
            scanNetAnimation?.startAnimatingWithRect(animationRect: cropRect,
                                                     parentView: self,
                                                     image: viewStyle.animationImage)
        case .LineStill:
            let stillRect = CGRect(x: cropRect.origin.x + 20,
                                   y: cropRect.origin.y + cropRect.size.height / 2,
                                   width: cropRect.size.width - 40,
                                   height: 2)
            scanLineStill?.frame = stillRect

            addSubview(scanLineStill!)
            scanLineStill?.isHidden = false
        default: break
        }
    }
    
    
    func stopScanAnimation() {
        isAnimationing = false
        switch viewStyle.anmiationStyle {
        case .LineMove:
            scanLineAnimation?.stopStepAnimating()
        case .NetGrid:
            scanNetAnimation?.stopStepAnimating()
        case .LineStill:
            scanLineStill?.isHidden = true
        default: break
        }
    }
    
    
    
    open override func draw(_ rect: CGRect) {
        drawScanRect()
    }
    
    
    func drawScanRect() {
        let XRetangleLeft = viewStyle.xScanRetangleOffset
        var sizeRetangle = CGSize(width: frame.size.width - XRetangleLeft * 2.0, height: frame.size.width - XRetangleLeft * 2.0)
        
        if viewStyle.whRatio != 1.0 {
            let w = sizeRetangle.width
            var h = w / viewStyle.whRatio
            h = CGFloat(Int(h))
            sizeRetangle = CGSize(width: w, height: h)
        }
        
        
        let YMinRetangle = frame.size.height / 2.0 - sizeRetangle.height / 2.0 - viewStyle.centerUpOffset
        let YMaxRetangle = YMinRetangle + sizeRetangle.height
        let XRetangleRight = frame.size.width - XRetangleLeft
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        
        
        
        context.setFillColor(viewStyle.color_NotRecoginitonArea.cgColor)
        
        
        var rect = CGRect(x: 0, y: 0, width: frame.size.width, height: YMinRetangle)
        context.fill(rect)

        
        rect = CGRect(x: 0, y: YMinRetangle, width: XRetangleLeft, height: sizeRetangle.height)
        context.fill(rect)

        
        rect = CGRect(x: XRetangleRight, y: YMinRetangle, width: XRetangleLeft, height: sizeRetangle.height)
        context.fill(rect)

        
        rect = CGRect(x: 0, y: YMaxRetangle, width: frame.size.width, height: frame.size.height - YMaxRetangle)
        context.fill(rect)
        
        context.strokePath()
        
        if viewStyle.isNeedShowRetangle {
            
            context.setStrokeColor(viewStyle.colorRetangleLine.cgColor)
            context.setLineWidth(1)
            context.addRect(CGRect(x: XRetangleLeft, y: YMinRetangle, width: sizeRetangle.width, height: sizeRetangle.height))

            
            

            context.strokePath()
        }

        scanRetangleRect = CGRect(x: XRetangleLeft, y: YMinRetangle, width: sizeRetangle.width, height: sizeRetangle.height)
        
        
        

        
        let wAngle = viewStyle.photoframeAngleW
        let hAngle = viewStyle.photoframeAngleH

        
        let linewidthAngle = viewStyle.photoframeLineW 

        
        var diffAngle = linewidthAngle / 3
        diffAngle = linewidthAngle / 2 
        diffAngle = linewidthAngle / 2 
        diffAngle = 0 
        
        switch viewStyle.photoframeAngleStyle {
        case .Outer: diffAngle = linewidthAngle / 3 
        case .On: diffAngle = 0
        case .Inner: diffAngle = -viewStyle.photoframeLineW / 2
        }
        
        context.setStrokeColor(viewStyle.colorAngle.cgColor)
        context.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)

        
        context.setLineWidth(linewidthAngle)
        
        
        
        let leftX = XRetangleLeft - diffAngle
        let topY = YMinRetangle - diffAngle
        let rightX = XRetangleRight + diffAngle
        let bottomY = YMaxRetangle + diffAngle

        
        context.move(to: CGPoint(x: leftX - linewidthAngle / 2, y: topY))
        context.addLine(to: CGPoint(x: leftX + wAngle, y: topY))
        
        
        context.move(to: CGPoint(x: leftX, y: topY - linewidthAngle / 2))
        context.addLine(to: CGPoint(x: leftX, y: topY + hAngle))
        
        
        context.move(to: CGPoint(x: leftX - linewidthAngle / 2, y: bottomY))
        context.addLine(to: CGPoint(x: leftX + wAngle, y: bottomY))
        
        
        context.move(to: CGPoint(x: leftX, y: bottomY + linewidthAngle / 2))
        context.addLine(to: CGPoint(x: leftX, y: bottomY - hAngle))

        
        context.move(to: CGPoint(x: rightX + linewidthAngle / 2, y: topY))
        context.addLine(to: CGPoint(x: rightX - wAngle, y: topY))
        
        
        context.move(to: CGPoint(x: rightX, y: topY - linewidthAngle / 2))
        context.addLine(to: CGPoint(x: rightX, y: topY + hAngle))

        
        context.move(to: CGPoint(x: rightX + linewidthAngle / 2, y: bottomY))
        context.addLine(to: CGPoint(x: rightX - wAngle, y: bottomY))

        
        context.move(to: CGPoint(x: rightX, y: bottomY + linewidthAngle / 2))
        context.addLine(to: CGPoint(x: rightX, y: bottomY - hAngle))
        
        context.strokePath()
    }
    
    
    static func getScanRectWithPreView(preView: UIView, style: LBXScanViewStyle) -> CGRect {
        let XRetangleLeft = style.xScanRetangleOffset
        let width = preView.frame.size.width - XRetangleLeft * 2
        let height = width
        var sizeRetangle = CGSize(width: width, height: height)

        if style.whRatio != 1 {
            let w = sizeRetangle.width
            var h = w / style.whRatio

            let hInt: Int = Int(h)
            h = CGFloat(hInt)

            sizeRetangle = CGSize(width: w, height: h)
        }

        
        let YMinRetangle = preView.frame.size.height / 2.0 - sizeRetangle.height / 2.0 - style.centerUpOffset
        
        let cropRect = CGRect(x: XRetangleLeft, y: YMinRetangle, width: sizeRetangle.width, height: sizeRetangle.height)

        
        var rectOfInterest: CGRect

        
        let size = preView.bounds.size
        let p1 = size.height / size.width

        let p2: CGFloat = 1920.0 / 1080.0 
        if p1 < p2 {
            let fixHeight = size.width * 1920.0 / 1080.0
            let fixPadding = (fixHeight - size.height) / 2
            rectOfInterest = CGRect(x: (cropRect.origin.y + fixPadding) / fixHeight,
                                    y: cropRect.origin.x / size.width,
                                    width: cropRect.size.height / fixHeight,
                                    height: cropRect.size.width / size.width)

        } else {
            let fixWidth = size.height * 1080.0 / 1920.0
            let fixPadding = (fixWidth - size.width) / 2
            rectOfInterest = CGRect(x: cropRect.origin.y / size.height,
                                    y: (cropRect.origin.x + fixPadding) / fixWidth,
                                    width: cropRect.size.height / size.height,
                                    height: cropRect.size.width / fixWidth)
        }

        return rectOfInterest
    }
    
    func getRetangeSize() -> CGSize {
        let XRetangleLeft = viewStyle.xScanRetangleOffset
        var sizeRetangle = CGSize(width: frame.size.width - XRetangleLeft * 2, height: frame.size.width - XRetangleLeft * 2)

        let w = sizeRetangle.width
        var h = w / viewStyle.whRatio
        h = CGFloat(Int(h))
        sizeRetangle = CGSize(width: w, height: h)

        return sizeRetangle
    }
    
    func deviceStartReadying(readyStr: String) {
        let XRetangleLeft = viewStyle.xScanRetangleOffset
        let sizeRetangle = getRetangeSize()

        
        let YMinRetangle = frame.size.height / 2.0 - sizeRetangle.height / 2.0 - viewStyle.centerUpOffset

        
        if activityView == nil {
            activityView = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))

            activityView?.center = CGPoint(x: XRetangleLeft + sizeRetangle.width / 2 - 50, y: YMinRetangle + sizeRetangle.height / 2)
            activityView?.style = UIActivityIndicatorView.Style.whiteLarge

            addSubview(activityView!)

            let labelReadyRect = CGRect(x: activityView!.frame.origin.x + activityView!.frame.size.width + 10,
                                        y: activityView!.frame.origin.y,
                                        width: 100,
                                        height: 30)
            labelReadying = UILabel(frame: labelReadyRect)
            labelReadying?.text = readyStr
            labelReadying?.backgroundColor = UIColor.clear
            labelReadying?.textColor = UIColor.white
            labelReadying?.font = UIFont.systemFont(ofSize: 18.0)
            addSubview(labelReadying!)
        }

        addSubview(labelReadying!)
        activityView?.startAnimating()
    }
    
    func deviceStopReadying() {
        if activityView != nil {
            activityView?.stopAnimating()
            activityView?.removeFromSuperview()
            labelReadying?.removeFromSuperview()

            activityView = nil
            labelReadying = nil
        }
    }

}


public extension LBXScanView {
    
    
    func getScanRectForAnimation() -> CGRect {
        let XRetangleLeft = viewStyle.xScanRetangleOffset
        var sizeRetangle = CGSize(width: frame.size.width - XRetangleLeft * 2,
                                  height: frame.size.width - XRetangleLeft * 2)
        
        if viewStyle.whRatio != 1 {
            let w = sizeRetangle.width
            let h = w / viewStyle.whRatio
            sizeRetangle = CGSize(width: w, height: CGFloat(Int(h)))
        }
        
        
        let YMinRetangle = frame.size.height / 2.0 - sizeRetangle.height / 2.0 - viewStyle.centerUpOffset
        
        let cropRect = CGRect(x: XRetangleLeft, y: YMinRetangle, width: sizeRetangle.width, height: sizeRetangle.height)
        
        return cropRect
    }
    
}
