import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // Keep native window/view backgrounds continuous with the launch asset.
    // This does not add a delay or replace Flutter's first-frame handoff.
    if let background = UIColor(named: "LaunchBackground") {
      window?.backgroundColor = background
      window?.rootViewController?.view.backgroundColor = background
    }
    return launched
  }
}
