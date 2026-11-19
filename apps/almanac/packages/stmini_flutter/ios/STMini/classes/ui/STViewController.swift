






import UIKit


public enum STCrlNaviBtnPosition {
    case left
    case right
}

open class STViewController: UIViewController {
    
    
    public var naviBarColor: UIColor = .white
    
    public var naviBarBottomLineIsHidden: Bool = true
    
    @objc open var currentStatusBarStyle: UIStatusBarStyle = .default
    public lazy var naviView: UIView = {
        let v = UIView.init()
        v.frame = CGRectMake(0, 0, view.ST_width, STScreenHelper.ST_navigationFullHeight());
        return v
    }()
    fileprivate lazy var leftBtn: UIButton = {
        let btn = UIButton.init()
        btn.imageEdgeInsets = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 10)
        btn.frame = CGRectMake(6, STScreenHelper.ST_statusBarHeight(), STScreenHelper.ST_navigationBarHeight(), STScreenHelper.ST_navigationBarHeight())
        naviView.addSubview(btn)
        return btn
    }()
    fileprivate lazy var rightBtn: UIButton = {
        let btn = UIButton.init()
        btn.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        btn.frame = CGRectMake(view.ST_width - STScreenHelper.ST_navigationBarHeight(), STScreenHelper.ST_statusBarHeight(), STScreenHelper.ST_navigationBarHeight(), STScreenHelper.ST_navigationBarHeight())
        naviView.addSubview(btn)
        return btn
    }()
    fileprivate lazy var titleLbl: UILabel = {
        let lbl  = UILabel.init(frame: CGRectMake(0, 0, 200, 40))
        lbl.textAlignment = .center;
        lbl.backgroundColor = .clear;
        lbl.font = UIFont.boldSystemFont(ofSize: 16)
        lbl.textColor = .black
        return lbl
    }()
    open override var title: String? {
        get {
            return self.titleLbl.text
        }
        set {
            self.titleLbl.text = newValue
        }
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.navigationBar.isHidden = true
        
        navigationController?.navigationBar.isTranslucent = false
        extendedLayoutIncludesOpaqueBars = true
        hidesBottomBarWhenPushed = true
    }
    
    open override var preferredStatusBarStyle: UIStatusBarStyle {
        return currentStatusBarStyle
    }
    
    
    
    
    
    
    
    
    
    public func addNaviBtn(title: String = "", image: UIImage?, position: STCrlNaviBtnPosition, action: Selector, tintColor: UIColor? = .black) {
        if position == .left {
            leftBtn.setTitle(title, for: .normal)
            leftBtn.tintColor = tintColor
            leftBtn.setImage(image, for: .normal)
            leftBtn.addTarget(self, action: action, for: .touchUpInside)
        }
        else {
            rightBtn.setTitle(title, for: .normal)
            rightBtn.tintColor = tintColor
            rightBtn.setImage(image, for: .normal)
            rightBtn.addTarget(self, action: action, for: .touchUpInside)
        }
    }
    
    public func darkModeChanged() {
        
    }
    
}
