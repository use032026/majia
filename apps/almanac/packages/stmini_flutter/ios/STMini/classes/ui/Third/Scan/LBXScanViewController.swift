







import UIKit
import Foundation
import AVFoundation

public protocol LBXScanViewControllerDelegate: class {
     func scanFinished(scanResult: LBXScanResult, error: String?)
}

public protocol QRRectDelegate {
    func drawwed()
}

open class LBXScanViewController: UIViewController {
    
    
    open weak var scanResultDelegate: LBXScanViewControllerDelegate?

    /// Objective-C callers can use this callback without depending on the
    /// Swift-only `LBXScanResult` type.
    @objc public var scanResultHandler: ((String?, String?) -> Void)?

    open var delegate: QRRectDelegate?

    open var scanObj: LBXScanWrapper?

    open var scanStyle: LBXScanViewStyle? = LBXScanViewStyle()

    open var qRScanView: LBXScanView?

    
    open var isOpenInterestRect = false
    
    
    open var isSupportContinuous = false;

    
    public var arrayCodeType: [AVMetadataObject.ObjectType]?

    
    public var isNeedCodeImage = false

    
    public var readyString: String! = "loading"

    open override func viewDidLoad() {
        super.viewDidLoad()

        

        
        view.backgroundColor = UIColor.black
        edgesForExtendedLayout = UIRectEdge(rawValue: 0)
        
        drawScanView()
        perform(#selector(LBXScanViewController.startScan), with: nil, afterDelay: 0.3)
    }

    open func setNeedCodeImage(needCodeImg: Bool) {
        isNeedCodeImage = needCodeImg
    }

    
    open func setOpenInterestRect(isOpen: Bool) {
        isOpenInterestRect = isOpen
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    @objc open func startScan() {
        if scanObj == nil {
            var cropRect = CGRect.zero
            if isOpenInterestRect {
                cropRect = LBXScanView.getScanRectWithPreView(preView: view, style: scanStyle!)
            }

            
            if arrayCodeType == nil {
                arrayCodeType = [AVMetadataObject.ObjectType.qr as NSString,
                                 AVMetadataObject.ObjectType.ean13 as NSString,
                                 AVMetadataObject.ObjectType.code128 as NSString] as [AVMetadataObject.ObjectType]
            }

            scanObj = LBXScanWrapper(videoPreView: view,
                                     objType: arrayCodeType!,
                                     isCaptureImg: isNeedCodeImage,
                                     cropRect: cropRect,
                                     success: { [weak self] (arrayResult) -> Void in
                                         guard let strongSelf = self else {
                                             return
                                         }
                                         
                                         strongSelf.qRScanView?.stopScanAnimation()
                                         strongSelf.handleCodeResult(arrayResult: arrayResult)
            })
            
            
        }
        
        scanObj?.supportContinuous = isSupportContinuous;

        
        qRScanView?.deviceStopReadying()

        
        qRScanView?.startScanAnimation()

        
        scanObj?.start()
    }
    
    open func drawScanView() {
        if qRScanView == nil {
            qRScanView = LBXScanView(frame: view.frame, vstyle: scanStyle!)
            view.addSubview(qRScanView!)
            delegate?.drawwed()
        }
        qRScanView?.deviceStartReadying(readyStr: readyString)
    }
   

    
    open func handleCodeResult(arrayResult: [LBXScanResult]) {
        if let handler = scanResultHandler {
            let result = arrayResult.first
            handler(result?.strScanned, result == nil ? "no scan result" : nil)
            return
        }

        guard let delegate = scanResultDelegate else {
            fatalError("you must set scanResultDelegate or override this method without super keyword")
        }
        
        if !isSupportContinuous {
            navigationController?.popViewController(animated: true)

        }
        
        if let result = arrayResult.first {
            delegate.scanFinished(scanResult: result, error: nil)
        } else {
            let result = LBXScanResult(str: nil, img: nil, barCodeType: nil, corner: nil)
            delegate.scanFinished(scanResult: result, error: "no scan result")
        }
    }
    
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        qRScanView?.stopScanAnimation()
        scanObj?.stop()
    }
    
    @objc open func openPhotoAlbum() {
        LBXPermissions.authorizePhotoWith { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = UIImagePickerController.SourceType.photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true, completion: nil)
        }
    }
}


extension LBXScanViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.delegate = nil
        picker.dismiss(animated: true, completion: nil)
        
        let editedImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage
        let originalImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage
        guard let image = editedImage ?? originalImage else {
            showMsg(title: nil, message: NSLocalizedString("Identify failed", comment: "Identify failed"))
            return
        }
        let arrayResult = LBXScanWrapper.recognizeQRImage(image: image)
        if !arrayResult.isEmpty {
            handleCodeResult(arrayResult: arrayResult)
        }
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.delegate = nil
        picker.dismiss(animated: true, completion: nil)
    }
    
}


private extension LBXScanViewController {
    
    func showMsg(title: String?, message: String?) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let alertAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil)
        alertController.addAction(alertAction)
        present(alertController, animated: true, completion: nil)
    }
    
}
