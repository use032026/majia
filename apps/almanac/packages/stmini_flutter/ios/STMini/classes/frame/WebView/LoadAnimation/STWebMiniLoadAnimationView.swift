






import UIKit

class STWebMiniLoadAnimationView: UIView {
    
    let pointLayer = CAShapeLayer()
    private let trackLayer = CAShapeLayer()
    private let processingTrackColor = UIColor(red: 43/255, green: 43/255, blue: 43/255, alpha: 0.55).cgColor
    private let progressColor = UIColor(red: 10/255, green: 191/255, blue: 90/255, alpha: 1).cgColor

    private lazy var miniIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var miniNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = UIColor(red: 43/255, green: 43/255, blue: 43/255, alpha: 1)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        isOpaque = true
        // Start the determinate download ring at 12 o'clock. The processing
        // indicator reuses the same path, then rotates its short green arc.
        let trackPath = UIBezierPath(arcCenter: .zero, radius: 30, startAngle: -CGFloat.pi / 2, endAngle: CGFloat.pi * 1.5, clockwise: true)
        trackLayer.path = trackPath.cgPath
        trackLayer.strokeColor = processingTrackColor
        trackLayer.lineWidth = 0.8
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.lineCap = .round
        layer.addSublayer(trackLayer)
        
        let pointPath = UIBezierPath(arcCenter: .zero, radius: 30, startAngle: -CGFloat.pi / 2, endAngle: CGFloat.pi * 1.5, clockwise: true)
        pointLayer.path = pointPath.cgPath
        pointLayer.strokeColor = progressColor
        pointLayer.lineWidth = 6
        pointLayer.fillColor = UIColor.clear.cgColor
        pointLayer.lineCap = .round
        layer.addSublayer(pointLayer)

        addSubview(miniIconView)
        addSubview(miniNameLabel)
        NSLayoutConstraint.activate([
            miniIconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            // The identity belongs inside the loading ring. The label is
            // deliberately separate so an icon never replaces its text.
            miniIconView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -32),
            miniIconView.widthAnchor.constraint(equalToConstant: 42),
            miniIconView.heightAnchor.constraint(equalToConstant: 42),
            miniNameLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            miniNameLabel.topAnchor.constraint(equalTo: centerYAnchor, constant: 10),
            miniNameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 28),
            miniNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -28)
        ])
        
        beginPostDownloadProcessing()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let spinnerCenter = CGPoint(x: bounds.midX, y: bounds.midY - 32)
        trackLayer.position = spinnerCenter
        pointLayer.position = spinnerCenter
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension STWebMiniLoadAnimationView: STWebMiniLoadAnimate {

    func updateMiniIdentity(_ miniId: String, miniName: String?, icon: UIImage?) {
        let displayName = miniName?.trimmingCharacters(in: .whitespacesAndNewlines)
        miniIconView.image = icon ?? hostAppIcon()
        miniIconView.isHidden = miniIconView.image == nil
        miniNameLabel.isHidden = false
        miniNameLabel.text = (displayName?.isEmpty == false ? displayName : miniId)
    }

    /// App icons cannot be loaded through the asset-catalog name on every
    /// target. Resolve the actual icon filename exported in the host bundle.
    private func hostAppIcon() -> UIImage? {
        let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any]
        let primaryIcon = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        let iconFiles = primaryIcon?["CFBundleIconFiles"] as? [String]
        for fileName in iconFiles?.reversed() ?? [] {
            if let image = UIImage(named: fileName, in: .main, compatibleWith: nil) {
                return image
            }
        }
        // Kept for targets whose build settings expose the conventional icon
        // name but omit CFBundleIcons at runtime.
        return UIImage(named: "AppIcon60x60", in: .main, compatibleWith: nil)
    }
    
    func finished() {
        removeFromSuperview()
    }
    
    var progress: CGFloat {
        get {
            return pointLayer.strokeEnd
        }
        set {
            setDownloadProgress(newValue)
        }
    }

    /// Draw a true byte-progress ring. `strokeEnd` advances clockwise from
    /// the 12 o'clock path origin and never rotates while data is arriving.
    func setDownloadProgress(_ progress: CGFloat) {
        let clamped = min(max(progress, 0), 1)
        pointLayer.removeAnimation(forKey: "mini.processing.rotation")
        pointLayer.strokeStart = 0
        pointLayer.strokeEnd = clamped
        pointLayer.lineWidth = 4
        trackLayer.strokeColor = processingTrackColor
        trackLayer.lineWidth = 0.8
    }

    /// Archive bytes are complete; keep the user informed while the host is
    /// validating, unpacking and starting the Mini. Keep the compact arc
    /// visible without making it dominate the loading screen.
    func beginPostDownloadProcessing() {
        pointLayer.removeAnimation(forKey: "mini.processing.rotation")
        pointLayer.strokeStart = 0
        pointLayer.strokeEnd = 0.042
        pointLayer.lineWidth = 4.5
        trackLayer.strokeColor = processingTrackColor
        trackLayer.lineWidth = 0.8
        let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotateAnimation.fromValue = 0.0
        rotateAnimation.toValue = CGFloat.pi * 2
        rotateAnimation.duration = 1.2
        rotateAnimation.repeatCount = .infinity
        pointLayer.add(rotateAnimation, forKey: "mini.processing.rotation")
    }
    
}
