import Flutter
import UIKit
import receive_sharing_intent

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var shareImportChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "filepeek/share_import", binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        if call.method == "pendingSharedFile" {
          self?.pendingSharedFile(result: result)
          return
        }
        guard call.method == "consumeSharedFile",
              let arguments = call.arguments as? [String: Any],
              let path = arguments["path"] as? String else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.consumeSharedFile(at: path, result: result)
      }
      shareImportChannel = channel
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func pendingSharedFile(result: FlutterResult) {
    guard let group = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String,
          let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: group
          ),
          let defaults = UserDefaults(suiteName: group) else {
      result(FlutterError(code: "share_group_unavailable", message: nil, details: nil))
      return
    }
    guard let data = defaults.data(forKey: "ShareKey"),
          let payload = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
          let encodedPath = payload.first?["path"] as? String,
          encodedPath.hasPrefix("file://") else {
      result(nil)
      return
    }
    let fileURL = URL(fileURLWithPath: String(encodedPath.dropFirst("file://".count)))
    let inbox = container.appendingPathComponent("FilePeekShareInbox", isDirectory: true)
      .standardizedFileURL
    let file = fileURL.standardizedFileURL
    let importFolder = file.deletingLastPathComponent()
    guard importFolder.deletingLastPathComponent() == inbox,
          UUID(uuidString: importFolder.lastPathComponent) != nil,
          FileManager.default.fileExists(atPath: file.path) else {
      defaults.removeObject(forKey: "ShareKey")
      result(nil)
      return
    }
    result(file.path)
  }

  private func consumeSharedFile(at path: String, result: FlutterResult) {
    guard let group = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String,
          let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: group
          ) else {
      result(FlutterError(code: "share_group_unavailable", message: nil, details: nil))
      return
    }
    let inbox = container.appendingPathComponent("FilePeekShareInbox", isDirectory: true)
      .standardizedFileURL
    let file = URL(fileURLWithPath: path).standardizedFileURL
    let importFolder = file.deletingLastPathComponent()
    guard importFolder.deletingLastPathComponent() == inbox,
          UUID(uuidString: importFolder.lastPathComponent) != nil else {
      result(FlutterError(code: "invalid_share_path", message: nil, details: nil))
      return
    }
    do {
      if FileManager.default.fileExists(atPath: file.path) {
        try FileManager.default.removeItem(at: file)
      }
      if FileManager.default.fileExists(atPath: importFolder.path),
         try FileManager.default.contentsOfDirectory(atPath: importFolder.path).isEmpty {
        try FileManager.default.removeItem(at: importFolder)
      }
      let defaults = UserDefaults(suiteName: group)
      if let data = defaults?.data(forKey: "ShareKey"),
         let payload = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
         payload.first?["path"] as? String == "file://" + file.path {
        defaults?.removeObject(forKey: "ShareKey")
        defaults?.removeObject(forKey: "ShareMessageKey")
      }
      result(nil)
    } catch {
      result(FlutterError(code: "share_cleanup_failed", message: error.localizedDescription, details: nil))
    }
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    let sharingIntent = SwiftReceiveSharingIntentPlugin.instance
    if sharingIntent.hasMatchingSchemePrefix(url: url) {
      return sharingIntent.application(app, open: url, options: options)
    }
    return super.application(app, open: url, options: options)
  }
}
