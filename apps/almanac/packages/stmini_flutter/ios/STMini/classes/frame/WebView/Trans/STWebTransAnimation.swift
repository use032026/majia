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
        // For custom presentations UIKit may keep the presenting view in
        // place and return nil from view(forKey:). Only the two controllers
        // owned by this exact transition may supply the fallback views.
        guard let fromView = transitionContext.view(forKey: .from) ?? transitionContext.viewController(forKey: .from)?.view,
              let toView = transitionContext.view(forKey: .to) ?? transitionContext.viewController(forKey: .to)?.view else {
            transitionContext.completeTransition(false)
            return
        }
        if self.transType == .present {
            // Capture this transition's real presenting owner. No process-wide
            // or Scanner screenshot can leak into another scene/operation.
            let image = UIGraphicsImageRenderer(bounds: fromView.bounds).image { _ in
                fromView.drawHierarchy(in: fromView.bounds, afterScreenUpdates: false)
            }
            let transitionBack = UIImageView(image: image)
            self.transitionBack = transitionBack
            transitionBack.frame = containerBounds
            containerView.addSubview(transitionBack)
            let transitionShadow = UIView(frame: containerBounds)
            self.transitionShadow = transitionShadow
            transitionShadow.backgroundColor = .black
            transitionShadow.alpha = 0
            containerView.addSubview(transitionShadow)
            toView.transform = .identity
            toView.frame = containerBounds.offsetBy(dx: 0, dy: containerBounds.height)
            containerView.addSubview(toView)
            UIView.animate(withDuration: self.transitionDuration(using: transitionContext), delay: 0, options: .curveEaseOut) {
                toView.frame = containerBounds
                self.transitionBack?.layer.setAffineTransform(CGAffineTransform(scaleX: transitionBackScale, y: transitionBackScale))
                self.transitionShadow?.alpha = transitionShadowAlpha
            } completion: { finished in
                let succeeded = finished && !transitionContext.transitionWasCancelled
                toView.transform = .identity
                toView.frame = containerBounds
                transitionContext.completeTransition(succeeded)
                if !succeeded { self.clearSnapshot() }
                self.completion?(.present, succeeded)
            }
        } else {
            let originalFrame = fromView.frame
            // A custom presentation may leave its presenting owner in the
            // original window and omit .to from the context. Such a fallback
            // is for ownership/geometry only; moving it would remove the host
            // from its window when UIKit tears down the transition container.
            if transitionContext.view(forKey: .to) != nil, toView.superview !== containerView {
                containerView.insertSubview(toView, belowSubview: fromView)
            }
            UIView.animate(withDuration: self.transitionDuration(using: transitionContext), delay: 0, options: .curveEaseOut) {
                fromView.frame = containerBounds.offsetBy(dx: 0, dy: containerBounds.height)
                self.transitionBack?.layer.setAffineTransform(CGAffineTransform(scaleX: 1, y: 1))
                self.transitionShadow?.alpha = 0
            } completion: { finished in
                let succeeded = finished && !transitionContext.transitionWasCancelled
                fromView.transform = .identity
                fromView.frame = originalFrame
                if !succeeded {
                    self.transitionBack?.layer.setAffineTransform(CGAffineTransform(scaleX: transitionBackScale, y: transitionBackScale))
                    self.transitionShadow?.alpha = transitionShadowAlpha
                }
                transitionContext.completeTransition(succeeded)
                if succeeded { self.clearSnapshot() }
                self.completion?(.dismiss, succeeded)
            }
        }
    }

    func clearSnapshot() {
        transitionBack?.removeFromSuperview(); transitionBack = nil
        transitionShadow?.removeFromSuperview(); transitionShadow = nil
    }
}
