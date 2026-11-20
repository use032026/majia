






import UIKit

public class STWebNavigationController: UINavigationController, UIGestureRecognizerDelegate {
    private weak var retirementRoot: STWebMiniprogramCrl?
    private var retirementTimer: Timer?

    var hasForeignPresentedOwner: Bool {
        if presentedViewController != nil || viewControllers.contains(where: { $0.presentedViewController != nil }) { return true }
        if let window = viewIfLoaded?.window, let visibleViewController {
            return STWebH5Crl.topVisibleController(in: window) !== visibleViewController
        }
        return false
    }

    /// Engine teardown has already revoked and released this exact runtime.
    /// A foreign presentation above it remains the foreground owner's UI;
    /// retire only this bound Mini after that presentation leaves itself.
    func retireWhenUncovered(root: STWebMiniprogramCrl) {
        guard viewControllers.first === root else { return }
        if let retirementRoot, retirementRoot !== root { return }
        retirementRoot = root
        guard retirementTimer == nil else { return }
        if finishRetirementIfUncovered() { return }
        retirementTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            _ = self?.finishRetirementIfUncovered()
        }
    }

    @discardableResult private func finishRetirementIfUncovered() -> Bool {
        guard let retirementRoot, viewControllers.first === retirementRoot else {
            retirementTimer?.invalidate(); retirementTimer = nil
            return true
        }
        guard presentingViewController != nil else {
            retirementTimer?.invalidate(); retirementTimer = nil
            return true
        }
        guard !isBeingPresented, !isBeingDismissed, !hasForeignPresentedOwner,
              let window = viewIfLoaded?.window,
              STWebH5Crl.topVisibleController(in: window) === visibleViewController else { return false }
        retirementTimer?.invalidate(); retirementTimer = nil
        dismiss(animated: false)
        return true
    }

    deinit { retirementTimer?.invalidate() }

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

        (viewControllers.first as? STWebMiniprogramCrl)?.prepareForNativeDismissal()


    }
    
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard presentingViewController == nil, view.window == nil,
              let mini = viewControllers.first as? STWebMiniprogramCrl else { return }
        STWebMiniProgramKeepAliveStore.shared.cache(mini, navigationController: self)
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
