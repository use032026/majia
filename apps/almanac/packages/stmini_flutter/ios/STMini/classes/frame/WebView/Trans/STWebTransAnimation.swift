






import Foundation
import QuartzCore
import UIKit

let transitionBackScale = 0.97
let transitionShadowAlpha = 0.6

enum STWebTransType {
    case present
    case dismiss
}

class STWebTransAnimation: NSObject, UIViewControllerAnimatedTransitioning {

    
    weak var interactive: STWebTransInteractive?
    
    var transType: STWebTransType! = .present
    
    var transitionBack: UIImageView?
    
    var transitionShadow: UIView?

    /// A transition belongs to one Mini root controller. A global completion
    /// notification would also wake cached Mini controllers and make their
    /// capsule bars reappear above the host page.
    var completion: ((STWebTransType, Bool) -> Void)?

    override init() {
        super.init()
    }
    
    convenience init(transType: STWebTransType) {
        self.init()
        self.transType = transType
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        if (transType == .present) {
            return 0.4
        }
        else {
            return 0.4
        }
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        let containerBounds = containerView.bounds
        if self.transType == .present {
            
            
            let transitionBack = UIImageView(image: STWebInstanceManager.scanScreenShot ?? STScreenHelper.screenShot())
            self.transitionBack = transitionBack
            
            let tempLayer = CALayer()
            tempLayer.frame = containerBounds
            tempLayer.backgroundColor = UIColor.black.cgColor
            containerView.layer.addSublayer(tempLayer)
            transitionBack.frame = containerBounds
            containerView.addSubview(transitionBack)
            transitionBack.layer.setAffineTransform(CGAffineTransform(scaleX: 1, y: 1))
            
            let transitionShadow = UIView(frame: containerBounds)
            self.transitionShadow = transitionShadow
            transitionShadow.backgroundColor = .black
            transitionShadow.alpha = 0
            containerView.addSubview(transitionShadow)
            let toCrl = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)
            let toView = toCrl!.view!
            toView.transform = .identity
            toView.frame = containerBounds.offsetBy(dx: 0, dy: containerBounds.height)
            containerView.addSubview(toCrl!.view)
            UIView.animate(withDuration: self.transitionDuration(using: transitionContext), delay: 0, options: .curveEaseOut) {
                toView.frame = containerBounds
                self.transitionBack?.layer.setAffineTransform(CGAffineTransform(scaleX: transitionBackScale, y: transitionBackScale))
                self.transitionShadow?.alpha = transitionShadowAlpha
            } completion: { completed in
                toView.transform = .identity
                toView.frame = containerBounds
                
                transitionContext.completeTransition(true)
                tempLayer.removeFromSuperlayer()
                self.completion?(.present, true)
            }
        } else if self.transType == .dismiss {
            if !(interactive?.isInteractive ?? false) {
                
                let fromCrl = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from)
                fromCrl!.view.frame = CGRect(x: 0,
                                            y: 0,
                                            width: UIScreen.main.bounds.size.width,
                                            height: UIScreen.main.bounds.size.height)
                containerView.addSubview(fromCrl!.view)
                UIView.animate(withDuration: self.transitionDuration(using: transitionContext), delay: 0, options: .curveEaseOut) {
                    fromCrl!.view.frame = CGRect(x: 0,
                                                y: UIScreen.main.bounds.size.height,
                                                width: UIScreen.main.bounds.size.width,
                                                height: UIScreen.main.bounds.size.height)
                    self.transitionBack?.layer.setAffineTransform(CGAffineTransform(scaleX: 1, y: 1))
                    self.transitionShadow?.alpha = 0
                } completion: { completed in
                    let succeeded = !transitionContext.transitionWasCancelled
                    transitionContext.completeTransition(succeeded)
                    self.completion?(.dismiss, succeeded)
                }
            }
            else {
                
                let fromCrl = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from)
                fromCrl!.view.frame = CGRect(x: 0,
                                            y: 0,
                                            width: UIScreen.main.bounds.size.width,
                                            height: UIScreen.main.bounds.size.height)
                containerView.addSubview(fromCrl!.view)
                UIView.animate(withDuration: 0.6, delay: 0, options: .curveLinear) {
                    fromCrl!.view.frame = CGRect(x: 0,
                                                y: UIScreen.main.bounds.size.height,
                                                width: UIScreen.main.bounds.size.width,
                                                height: UIScreen.main.bounds.size.height)
                    self.transitionBack?.layer.setAffineTransform(CGAffineTransform(scaleX: 1, y: 1))
                    self.transitionShadow?.alpha = 0
                } completion: { completed in
                    let succeeded = !transitionContext.transitionWasCancelled
                    transitionContext.completeTransition(succeeded)
                    self.completion?(.dismiss, succeeded)
                }
            }
        }
    }
    
    func getCurrentCrl(crl: UIViewController) -> UIViewController {
        var currentCrl: UIViewController? = nil
        if (crl is UITabBarController) {
            currentCrl = (crl as! UITabBarController).selectedViewController
        }
        else {
            currentCrl = crl
        }
        if (currentCrl is UINavigationController) {
            currentCrl = (currentCrl as! UINavigationController).topViewController
        }
        return currentCrl!
    }
    
}
