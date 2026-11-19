






import UIKit

public class STWebNavigationController: UINavigationController, UIGestureRecognizerDelegate {

    public override func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard isBeingDismissed,
              viewControllers.first is STWebMiniprogramCrl else {
            return
        }

        // Retaining a closed runtime must not retain queued native authority.
        // Invalidate every page at dismissal start, before a possible cache
        // reattachment makes the same controller/window usable again.
        viewControllers.forEach { controller in
            if let mini = controller as? STWebMiniprogramCrl { mini.webView?.invalidateBridgeDocumentSession() }
            if let h5 = controller as? STWebH5Crl { h5.webView?.invalidateBridgeDocumentSession() }
        }


    }
    
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if (viewControllers.count == 1) {
            // 根页没有可 pop 的控制器。这里必须让系统的边缘返回手势失败，
            // 由 STWebMiniprogramCrl 的自定义边缘手势接管并执行 dismiss。
            return false
        }
        else {
            return true
        }
    }
    
}
