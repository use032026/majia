






import Foundation
import UIKit

class STWebTransInteractive: UIPercentDrivenInteractiveTransition, UIGestureRecognizerDelegate {
    
    
    weak var target: STWebMiniprogramCrl?
    
    var isInteractive: Bool = false
    
    var isQuickInteractive: Bool = false

    private weak var screenPan: UIScreenEdgePanGestureRecognizer?
    
    override init() {
        super.init()
    }
    
    convenience init(target: STWebMiniprogramCrl) {
        self.init()
        self.target = target
        
        let screenPan = UIScreenEdgePanGestureRecognizer.init(target: self, action: #selector(pan(panGes:)))
        
        screenPan.edges = .left
        screenPan.delegate = self
        target.view.addGestureRecognizer(screenPan)
        self.screenPan = screenPan
    }

    /// A package may be replaced while its root controller is already on
    /// screen.  The replacement can opt into `ishome`, so remove the old
    /// root-only gesture instead of merely dropping its transition delegate.
    func invalidate() {
        isInteractive = false
        isQuickInteractive = false
        if let screenPan {
            screenPan.isEnabled = false
            screenPan.view?.removeGestureRecognizer(screenPan)
        }
        target = nil
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        
        return true
    }
    
    @objc func pan(panGes: UIPanGestureRecognizer) {
        let percent = panGes.translation(in: panGes.view).x/panGes.view!.ST_width
        switch panGes.state {
        case .began:
            isInteractive = true
            STProjectHelper.Log("手势返回---开始")
            target?.dismiss(animated: true)
        case .changed:
            isInteractive = true
            STProjectHelper.Log("手势返回---进度：x=\(panGes.translation(in: panGes.view).x) total=\(panGes.view!.ST_width) percent=\(percent)")
            
            if panGes.velocity(in: panGes.view).x > 250 {
                isQuickInteractive = true
            }
            else {
                isQuickInteractive = false
            }
            
            update(percent)
        case .ended:
            isInteractive = false
            STProjectHelper.Log("手势返回---结束，判断拖动距离是否满足转场")
            
            if percent > 0.5 || isQuickInteractive {
                STProjectHelper.Log("手势返回---触发转场")
                finish()
            }
            else {
                STProjectHelper.Log("手势返回---取消转场")
                cancel()
            }
        default:
            break
        }
    }
    
}
