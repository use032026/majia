







import UIKit
import AVFoundation

public struct LBXScanResult {
    
    
    public var strScanned: String?
    
    
    public var imgScanned: UIImage?
    
    
    public var strBarCodeType: String?

    
    public var arrayCorner: [AnyObject]?

    public init(str: String?, img: UIImage?, barCodeType: String?, corner: [AnyObject]?) {
        strScanned = str
        imgScanned = img
        strBarCodeType = barCodeType
        arrayCorner = corner
    }
}



open class LBXScanWrapper: NSObject,AVCaptureMetadataOutputObjectsDelegate {
    
    let device = AVCaptureDevice.default(for: AVMediaType.video)
    var input: AVCaptureDeviceInput?
    var output: AVCaptureMetadataOutput

    let session = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer?
    var stillImageOutput: AVCaptureStillImageOutput

    
    var arrayResult = [LBXScanResult]()

    
    var successBlock: ([LBXScanResult]) -> Void

    
    var isNeedCaptureImage: Bool

    
    var isNeedScanResult = true
    
    
    var supportContinuous = false
    
    
    
    init(videoPreView: UIView,
         objType: [AVMetadataObject.ObjectType] = [(AVMetadataObject.ObjectType.qr as NSString) as AVMetadataObject.ObjectType],
         isCaptureImg: Bool,
         cropRect: CGRect = .zero,
         success: @escaping (([LBXScanResult]) -> Void)) {
        
        successBlock = success
        output = AVCaptureMetadataOutput()
        isNeedCaptureImage = isCaptureImg
        stillImageOutput = AVCaptureStillImageOutput()

        super.init()
        
        guard let device = device else {
            return
        }
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch let error as NSError {
#if DEBUG
            print("AVCaptureDeviceInput(): \(error)")
#endif
        }
        guard let input = input else {
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }

        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        if session.canAddOutput(stillImageOutput) {
            session.addOutput(stillImageOutput)
        }

        stillImageOutput.outputSettings = [AVVideoCodecJPEG: AVVideoCodecKey]

        session.sessionPreset = AVCaptureSession.Preset.high

        
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)

        output.metadataObjectTypes = objType

        

        if !cropRect.equalTo(CGRect.zero) {
            
            output.rectOfInterest = cropRect
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill

        var frame: CGRect = videoPreView.frame
        frame.origin = CGPoint.zero
        previewLayer?.frame = frame

        videoPreView.layer.insertSublayer(previewLayer!, at: 0)

        if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.continuousAutoFocus) {
            do {
                try input.device.lockForConfiguration()
                input.device.focusMode = AVCaptureDevice.FocusMode.continuousAutoFocus
                input.device.unlockForConfiguration()
            } catch let error as NSError {
#if DEBUG
                print("device.lockForConfiguration(): \(error)")
#endif
            }
        }
    }

    public func metadataOutput(_ output: AVCaptureMetadataOutput,
                               didOutput metadataObjects: [AVMetadataObject],
                               from connection: AVCaptureConnection) {
        captureOutput(output, didOutputMetadataObjects: metadataObjects, from: connection)
    }
    
    func start() {
        if !session.isRunning {
            isNeedScanResult = true
            session.startRunning()
        }
    }
    
    func stop() {
        if session.isRunning {
            isNeedScanResult = false
            session.stopRunning()
        }
    }
    
    open func captureOutput(_ captureOutput: AVCaptureOutput,
                            didOutputMetadataObjects metadataObjects: [Any],
                            from connection: AVCaptureConnection!) {
        guard isNeedScanResult else {
            
            return
        }
        isNeedScanResult = false

        arrayResult.removeAll()

        
        for current in metadataObjects {
            guard let code = current as? AVMetadataMachineReadableCodeObject else {
                continue
            }
            
            #if !targetEnvironment(simulator)
            
            arrayResult.append(LBXScanResult(str: code.stringValue,
                                             img: UIImage(),
                                             barCodeType: code.type.rawValue,
                                             corner: code.corners as [AnyObject]?))
            #endif
        }

        if arrayResult.isEmpty || supportContinuous {
            isNeedScanResult = true
        }
        if !arrayResult.isEmpty {
            
            if supportContinuous {
                successBlock(arrayResult)
            }
            else if isNeedCaptureImage {
                captureImage()
            } else {
                stop()
                successBlock(arrayResult)
            }
        }
    }
    
    
    open func captureImage() {
        guard let stillImageConnection = connectionWithMediaType(mediaType: AVMediaType.video as AVMediaType,
                                                                 connections: stillImageOutput.connections as [AnyObject]) else {
                                                                    return
        }
        stillImageOutput.captureStillImageAsynchronously(from: stillImageConnection, completionHandler: { (imageDataSampleBuffer, _) -> Void in
            self.stop()
            if let imageDataSampleBuffer = imageDataSampleBuffer,
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer) {
                
                let scanImg = UIImage(data: imageData)
                for idx in 0 ... self.arrayResult.count - 1 {
                    self.arrayResult[idx].imgScanned = scanImg
                }
            }
            self.successBlock(self.arrayResult)
        })
    }
    
    open func connectionWithMediaType(mediaType: AVMediaType, connections: [AnyObject]) -> AVCaptureConnection? {
        for connection in connections {
            guard let connectionTmp = connection as? AVCaptureConnection else {
                continue
            }
            for port in connectionTmp.inputPorts where port.mediaType == mediaType {
                return connectionTmp
            }
        }
        return nil
    }
    
    
    

    open func changeScanRect(cropRect: CGRect) {
        
        stop()
        output.rectOfInterest = cropRect
        start()
    }

    
    open func changeScanType(objType: [AVMetadataObject.ObjectType]) {
        
        output.metadataObjectTypes = objType
    }
    
    open func isGetFlash() -> Bool {
        return device != nil && device!.hasFlash && device!.hasTorch
    }
    
    
    open func setTorch(torch: Bool) {
        guard isGetFlash() else {
            return
        }
        do {
            try input?.device.lockForConfiguration()
            input?.device.torchMode = torch ? AVCaptureDevice.TorchMode.on : AVCaptureDevice.TorchMode.off
            input?.device.unlockForConfiguration()
        } catch let error as NSError {
#if DEBUG
            print("device.lockForConfiguration(): \(error)")
#endif
        }
    }
    
    
    
    open func changeTorch() {
        let torch = input?.device.torchMode == .off
        setTorch(torch: torch)
    }
    
    
    static func defaultMetaDataObjectTypes() -> [AVMetadataObject.ObjectType] {
        var types =
            [
                AVMetadataObject.ObjectType.qr,
                AVMetadataObject.ObjectType.upce,
                AVMetadataObject.ObjectType.code39,
                AVMetadataObject.ObjectType.code39Mod43,
                AVMetadataObject.ObjectType.ean13,
                AVMetadataObject.ObjectType.ean8,
                AVMetadataObject.ObjectType.code93,
                AVMetadataObject.ObjectType.code128,
                AVMetadataObject.ObjectType.pdf417,
                AVMetadataObject.ObjectType.aztec,
            ]
        

        types.append(AVMetadataObject.ObjectType.interleaved2of5)
        types.append(AVMetadataObject.ObjectType.itf14)
        types.append(AVMetadataObject.ObjectType.dataMatrix)
        return types
    }
    
    
    public static func recognizeQRImage(image: UIImage) -> [LBXScanResult] {
        guard let cgImage = image.cgImage else {
            return []
        }
        let detector = CIDetector(ofType: CIDetectorTypeQRCode,
                                  context: nil,
                                  options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])!
        let img = CIImage(cgImage: cgImage)
        let features = detector.features(in: img, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        return features.filter {
            $0.isKind(of: CIQRCodeFeature.self)
        }.map {
            $0 as! CIQRCodeFeature
        }.map {
            LBXScanResult(str: $0.messageString,
                          img: image,
                          barCodeType: AVMetadataObject.ObjectType.qr.rawValue,
                          corner: nil)
        }
    }
    
    
    
    public static func createCode(codeType: String, codeString: String, size: CGSize, qrColor: UIColor, bkColor: UIColor) -> UIImage? {
        let stringData = codeString.data(using: .utf8)

        
        
        
        
        
        let qrFilter = CIFilter(name: codeType)
        qrFilter?.setValue(stringData, forKey: "inputMessage")
        qrFilter?.setValue("H", forKey: "inputCorrectionLevel")

        
        let colorFilter = CIFilter(name: "CIFalseColor",
                                   parameters: [
                                       "inputImage": qrFilter!.outputImage!,
                                       "inputColor0": CIColor(cgColor: qrColor.cgColor),
                                       "inputColor1": CIColor(cgColor: bkColor.cgColor),
                                   ]
        )

        guard let qrImage = colorFilter?.outputImage,
        let cgImage = CIContext().createCGImage(qrImage, from: qrImage.extent) else {
            return nil
        }

        UIGraphicsBeginImageContext(size)
        let context = UIGraphicsGetCurrentContext()!
        context.interpolationQuality = CGInterpolationQuality.none
        context.scaleBy(x: 1.0, y: -1.0)
        context.draw(cgImage, in: context.boundingBoxOfClipPath)
        let codeImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return codeImage
    }
    
    public static func createCode128(codeString: String, size: CGSize, qrColor: UIColor, bkColor: UIColor) -> UIImage? {
        let stringData = codeString.data(using: String.Encoding.utf8)

        
        
        
        
        
        let qrFilter = CIFilter(name: "CICode128BarcodeGenerator")
        qrFilter?.setDefaults()
        qrFilter?.setValue(stringData, forKey: "inputMessage")

        guard let outputImage = qrFilter?.outputImage else {
            return nil
        }
        let context = CIContext()
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: UIImage.Orientation.up)

        
        return resizeImage(image: image, quality: CGInterpolationQuality.none, rate: 20.0)
    }
    
    
    
    static func getConcreteCodeImage(srcCodeImage: UIImage, codeResult: LBXScanResult) -> UIImage? {
        let rect = getConcreteCodeRectFromImage(srcCodeImage: srcCodeImage, codeResult: codeResult)
        guard !rect.isEmpty, let img = imageByCroppingWithStyle(srcImg: srcCodeImage, rect: rect) else {
            return nil
        }
        return imageRotation(image: img, orientation: UIImage.Orientation.right)
    }
    
    
    public static func getConcreteCodeImage(srcCodeImage: UIImage, rect: CGRect) -> UIImage? {
        guard !rect.isEmpty, let img = imageByCroppingWithStyle(srcImg: srcCodeImage, rect: rect) else {
            return nil
        }
        return imageRotation(image: img, orientation: UIImage.Orientation.right)
    }
    
    
    public static func getConcreteCodeRectFromImage(srcCodeImage: UIImage, codeResult: LBXScanResult) -> CGRect {
        guard let corner = codeResult.arrayCorner as? [[String: Float]], corner.count >= 4 else {
            return .zero
        }

        let dicTopLeft = corner[0]
        let dicTopRight = corner[1]
        let dicBottomRight = corner[2]
        let dicBottomLeft = corner[3]

        let xLeftTopRatio = dicTopLeft["X"]!
        let yLeftTopRatio = dicTopLeft["Y"]!
        
        let xRightTopRatio = dicTopRight["X"]!
        let yRightTopRatio = dicTopRight["Y"]!

        let xBottomRightRatio = dicBottomRight["X"]!
        let yBottomRightRatio = dicBottomRight["Y"]!

        let xLeftBottomRatio = dicBottomLeft["X"]!
        let yLeftBottomRatio = dicBottomLeft["Y"]!

        
        let xMinLeft = CGFloat(min(xLeftTopRatio, xLeftBottomRatio))
        let xMaxRight = CGFloat(max(xRightTopRatio, xBottomRightRatio))

        let yMinTop = CGFloat(min(yLeftTopRatio, yRightTopRatio))
        let yMaxBottom = CGFloat(max(yLeftBottomRatio, yBottomRightRatio))

        let imgW = srcCodeImage.size.width
        let imgH = srcCodeImage.size.height
        
        
        return CGRect(x: xMinLeft * imgH,
                      y: yMinTop * imgW,
                      width: (xMaxRight - xMinLeft) * imgH,
                      height: (yMaxBottom - yMinTop) * imgW)
    }
    
    
    
    
    public static func addImageLogo(srcImg: UIImage, logoImg: UIImage, logoSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContext(srcImg.size)
        srcImg.draw(in: CGRect(x: 0, y: 0, width: srcImg.size.width, height: srcImg.size.height))
        let rect = CGRect(x: srcImg.size.width / 2 - logoSize.width / 2,
                          y: srcImg.size.height / 2 - logoSize.height / 2,
                          width: logoSize.width,
                          height: logoSize.height)
        logoImg.draw(in: rect)
        let resultingImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resultingImage!
    }
    
    
    static func resizeImage(image: UIImage, quality: CGInterpolationQuality, rate: CGFloat) -> UIImage? {
        var resized: UIImage?
        let width = image.size.width * rate
        let height = image.size.height * rate

        UIGraphicsBeginImageContext(CGSize(width: width, height: height))
        let context = UIGraphicsGetCurrentContext()
        context?.interpolationQuality = quality
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))

        resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resized
    }

    
    static func imageByCroppingWithStyle(srcImg: UIImage, rect: CGRect) -> UIImage? {
        guard let imagePartRef = srcImg.cgImage?.cropping(to: rect) else {
            return nil
        }
        return UIImage(cgImage: imagePartRef)
    }
    
    
    static func imageRotation(image: UIImage, orientation: UIImage.Orientation) -> UIImage {
        var rotate: Double = 0.0
        var rect: CGRect
        var translateX: CGFloat = 0.0
        var translateY: CGFloat = 0.0
        var scaleX: CGFloat = 1.0
        var scaleY: CGFloat = 1.0

        switch orientation {
        case .left:
            rotate = .pi / 2
            rect = CGRect(x: 0, y: 0, width: image.size.height, height: image.size.width)
            translateX = 0
            translateY = -rect.size.width
            scaleY = rect.size.width / rect.size.height
            scaleX = rect.size.height / rect.size.width
        case .right:
            rotate = 3 * .pi / 2
            rect = CGRect(x: 0, y: 0, width: image.size.height, height: image.size.width)
            translateX = -rect.size.height
            translateY = 0
            scaleY = rect.size.width / rect.size.height
            scaleX = rect.size.height / rect.size.width
        case .down:
            rotate = .pi
            rect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
            translateX = -rect.size.width
            translateY = -rect.size.height
        default:
            rotate = 0.0
            rect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
            translateX = 0
            translateY = 0
        }

        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()!
        
        context.translateBy(x: 0.0, y: rect.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.rotate(by: CGFloat(rotate))
        context.translateBy(x: translateX, y: translateY)

        context.scaleBy(x: scaleX, y: scaleY)
        
        context.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: rect.size.width, height: rect.size.height))
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
    
}
