






import Foundation

public class STNavigationController: UINavigationController, UIGestureRecognizerDelegate {

    public override func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if (viewControllers.count == 1) {
            return false
        }
        else {
            return true
        }
    }
    
}
