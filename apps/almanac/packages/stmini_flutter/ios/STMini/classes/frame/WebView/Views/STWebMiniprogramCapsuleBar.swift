






import UIKit

let ST_CapsuleBarLineColor = UIColor.ST_hex("#929292") 
let ST_CapsuleBarItemWidth = CGFloat(44)
let ST_CapsuleBarItemHeight = CGFloat(32)
let ST_CapsuleBarItemInsetHorizontalOutside = CGFloat(ST_CapsuleBarItemHeight/2)
let ST_CapsuleBarItemInsetHorizontal = CGFloat(10)
let ST_CapsuleBarItemInsetVertical = CGFloat(7)
let ST_CapsuleBarRightGap = CGFloat(8)
let ST_CapsuleBarCornerRadius = CGFloat(ST_CapsuleBarItemHeight/2)


protocol STWebMiniprogramCapsuleBarDelegate: NSObjectProtocol {
    
    func close()
    
    func more()
}


class STWebMiniprogramCapsuleBar: UIView {
    
    weak var delegate: STWebMiniprogramCapsuleBarDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)
        let capsuleBack = UIView.init(frame: CGRectMake(0, 0, ST_CapsuleBarItemWidth*2, ST_CapsuleBarItemHeight))
        capsuleBack.layer.borderColor = ST_CapsuleBarLineColor.cgColor
        capsuleBack.layer.borderWidth = 0.3
        capsuleBack.layer.cornerRadius = ST_CapsuleBarCornerRadius
        
        let btnMore = UIButton.init(type: .custom)
        btnMore.frame = CGRectMake(0, 0, ST_CapsuleBarItemWidth, ST_CapsuleBarItemHeight)
        
        let highLightBack = UIView()
        highLightBack.backgroundColor = .ST_hex("#AFAFAF")
        highLightBack.frame = btnMore.bounds
        btnMore.setBackgroundImage(STScreenHelper.screenShotIn(view: highLightBack), for: .highlighted)
        addResourceIcon(named: "icon_more", to: btnMore, frame: CGRectMake(16, 7, 18, 18))
        btnMore.addTarget(self, action: #selector(more), for: .touchUpInside)
        btnMore.ST_setCorner([UIRectCorner.bottomLeft,UIRectCorner.topLeft], radii: ST_CapsuleBarCornerRadius)
        
        let btnClose = UIButton.init(type: .custom)
        btnClose.frame = CGRectMake(ST_CapsuleBarItemWidth,0, ST_CapsuleBarItemWidth, ST_CapsuleBarItemHeight)
        btnClose.setBackgroundImage(STScreenHelper.screenShotIn(view: highLightBack), for: .highlighted)
        addResourceIcon(named: "icon_close", to: btnClose, frame: CGRectMake(10, 7, 18, 18))
        btnClose.addTarget(self, action: #selector(close), for: .touchUpInside)
        btnClose.ST_setCorner([UIRectCorner.bottomRight,UIRectCorner.topRight], radii: ST_CapsuleBarCornerRadius)
        
        let middleLine = CALayer()
        middleLine.backgroundColor = ST_CapsuleBarLineColor.cgColor
        middleLine.frame = CGRectMake((capsuleBack.ST_right - capsuleBack.ST_left)/2 + capsuleBack.ST_left - 0.2, capsuleBack.ST_top + ST_CapsuleBarItemHeight/6, 0.5, capsuleBack.ST_height - ST_CapsuleBarItemHeight/3)
        layer.addSublayer(middleLine)
        
        addSubview(capsuleBack)
        addSubview(btnMore)
        addSubview(btnClose)
    }

    private func addResourceIcon(named name: String, to button: UIButton, frame: CGRect) {
        guard let image = STWebResourceManager.imageNamed(name: name) else { return }
        let imageView = UIImageView(image: image)
        imageView.frame = frame
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        button.addSubview(imageView)
    }
    
    @objc func close() {
        delegate?.close()
    }
    
    @objc func more() {
        delegate?.more()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        STProjectHelper.Log("capsuleBar释放")
    }
    
}
