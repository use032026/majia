






import Foundation
import UIKit

@objc public protocol STWebMiniLoadAnimate {
    
    
    @objc var progress: CGFloat { get set }

    /// Downloading has a determinate, byte-based state. Once the archive has
    /// arrived the view changes back to the indeterminate processing spinner
    /// while validation, installation and WebView startup continue.
    @objc func setDownloadProgress(_ progress: CGFloat)
    @objc func beginPostDownloadProcessing()

    /// The download screen can be rendered before an archive exists. Prefer a
    /// supplied icon; otherwise show the mini name, falling back to its ID.
    @objc func updateMiniIdentity(_ miniId: String, miniName: String?, icon: UIImage?)
    
    @objc func finished()
    
}
