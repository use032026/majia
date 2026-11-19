






import UIKit

let ST_ToolViewItemWidth = CGFloat(55)
let ST_ToolViewItemIconHeight = CGFloat(55)
let ST_ToolViewItemTitleHeight = CGFloat(30)
let ST_ToolViewItemGap = CGFloat(15)
let ST_ToolViewItemtitleGap = CGFloat(5)
let ST_ToolViewCancelHeight = CGFloat(60)


typealias tapHandler = (_ title: String) -> ()

class STWebToolItemView: UIView {
    
    private var btn: UIButton!
    private var titleLbl: UILabel!
    private var itemModel: [String: String] = [:]
    fileprivate var tapHandler: tapHandler?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        btn = UIButton.init(frame: CGRectMake(0, 0, ST_ToolViewItemWidth, ST_ToolViewItemIconHeight))
        btn.backgroundColor = .white
        btn.layer.cornerRadius = ST_ToolViewItemWidth/6
        btn.addTarget(self, action: #selector(tapTool), for: .touchUpInside)
        addSubview(btn)
        titleLbl = UILabel.init(frame: CGRectMake(btn.ST_left, btn.ST_bottom + ST_ToolViewItemtitleGap, btn.ST_width, ST_ToolViewItemTitleHeight))
        titleLbl.font = UIFont.systemFont(ofSize: 11)
        titleLbl.numberOfLines = 2
        titleLbl.lineBreakMode = .byTruncatingTail
        titleLbl.textAlignment = .center
        titleLbl.textColor = .ST_hex("#696969")
        titleLbl.backgroundColor = .clear
        addSubview(titleLbl)
    }
    
    convenience init(frame: CGRect, itemModel: [String: String]) {
        self.init(frame: frame)
        self.itemModel = itemModel
        titleLbl.text = itemModel["title"]
        addResourceIcon(named: itemModel["imgStr"] ?? "")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func setTapHandler(handler: @escaping tapHandler) {
        tapHandler = handler;
    }

    private func addResourceIcon(named name: String) {
        guard let image = STWebResourceManager.imageNamed(name: name) else { return }
        let imageView = UIImageView(image: image)
        imageView.frame = CGRectMake(14, 14, ST_ToolViewItemIconHeight - 28, ST_ToolViewItemIconHeight - 28)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        btn.addSubview(imageView)
    }
    
    @objc func tapTool() {
        if tapHandler != nil {
            tapHandler!(itemModel["key"] ?? "")
        }
    }
    
}


class STWebToolView: HLPopView {

    var scrollview: UIScrollView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        scrollview = UIScrollView()
        scrollview.frame = CGRectMake(0, 10, frame.width, frame.height - 10 - ST_ToolViewCancelHeight)
        scrollview.backgroundColor = .clear
        addSubview(scrollview)
        let cancelBtn = UIButton()
        cancelBtn.frame = CGRectMake(0, ST_height - ST_ToolViewCancelHeight, ST_width, ST_ToolViewCancelHeight)
        cancelBtn.backgroundColor = .white
        cancelBtn.setTitle(STMiniLocalized("mini.cancel", "取消"), for: .normal)
        cancelBtn.setTitleColor(.black, for: .normal)
        cancelBtn.titleLabel?.font = UIFont.systemFont(ofSize: 15)
        cancelBtn.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        addSubview(cancelBtn)
    }

    convenience init(frame: CGRect, items: [[String: String]]) {
        self.init(frame: frame)
        scrollview.contentSize = CGSize(width: ST_ToolViewItemWidth*CGFloat(items.count), height: frame.height - 10 - ST_ToolViewCancelHeight)
        for (index, value) in items.enumerated() {
            let toolItem = STWebToolItemView.init(frame: CGRectMake((ST_ToolViewItemGap + ST_ToolViewItemWidth)*CGFloat(index) + ST_ToolViewItemGap, 0, ST_ToolViewItemWidth, ST_ToolViewItemTitleHeight + ST_ToolViewItemIconHeight), itemModel: value)
            toolItem.setTapHandler { [weak self] key in
                self!.delegate?.disMissPopView(["key": key])
            }
            scrollview.addSubview(toolItem)
        }
    }
    
    @objc func cancel() {
        self.delegate?.disMissPopView([:])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        STProjectHelper.Log("toolView释放")
    }

}
