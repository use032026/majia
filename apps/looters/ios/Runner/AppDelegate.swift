import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var privacyPolicyChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "PaceJarPrivacyPolicy") {
      let channel = FlutterMethodChannel(
        name: "pace_jar/privacy_policy",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "openPrivacyPolicy" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard
          let arguments = call.arguments as? [String: Any],
          let address = arguments["url"] as? String,
          let url = URL(string: address),
          url.scheme == "https", let host = url.host, !host.isEmpty,
          let chinese = arguments["chinese"] as? Bool,
          let presenter = self?.window?.rootViewController,
          presenter.presentedViewController == nil
        else {
          result(false)
          return
        }
        let policy = PrivacyPolicyViewController(url: url, chinese: chinese)
        let navigation = UINavigationController(rootViewController: policy)
        navigation.modalPresentationStyle = .fullScreen
        presenter.present(navigation, animated: true) { result(true) }
      }
      privacyPolicyChannel = channel
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
