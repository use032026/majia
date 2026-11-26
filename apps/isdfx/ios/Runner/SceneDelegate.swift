import Flutter
import UIKit

@objc class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    guard let window else { return }

    // file_selector_ios uses the app delegate's window to present the document picker.
    (UIApplication.shared.delegate as? AppDelegate)?.window = window

    if let background = UIColor(named: "LaunchBackground") {
      window.backgroundColor = background
      window.rootViewController?.viewIfLoaded?.backgroundColor = background
    }
  }

  override func sceneDidDisconnect(_ scene: UIScene) {
    guard let window,
          let appDelegate = UIApplication.shared.delegate as? AppDelegate,
          appDelegate.window === window else { return }
    appDelegate.window = nil
  }
}
