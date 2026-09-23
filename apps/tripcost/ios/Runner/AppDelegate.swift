import Flutter
import AVFoundation
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterPluginRegistrant {
  private let platformApis = PlatformApiStubs()
  private let visionOcrApi = VisionOcrService()
  private var documentExportService: DocumentExportService?
  private var photoLibrarySaveService: PhotoLibrarySaveService?
  private var systemPermissionService: SystemPermissionService?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    pluginRegistrant = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func register(with registry: FlutterPluginRegistry) {
    GeneratedPluginRegistrant.register(with: registry)
    guard let registrar = registry.registrar(forPlugin: "TripCostPlatformServices") else {
      return
    }
    let messenger = registrar.messenger()
    VisionOcrApiSetup.setUp(binaryMessenger: messenger, api: visionOcrApi)
    CloudSyncApiSetup.setUp(binaryMessenger: messenger, api: platformApis)
    SharedSnapshotApiSetup.setUp(binaryMessenger: messenger, api: platformApis)
    WidgetControlApiSetup.setUp(binaryMessenger: messenger, api: platformApis)
    systemPermissionService = SystemPermissionService(binaryMessenger: messenger)
    documentExportService = DocumentExportService.register(
      binaryMessenger: messenger,
      presentingViewController: { [weak self] in self?.activeViewController() }
    )
    photoLibrarySaveService = PhotoLibrarySaveService.register(
      binaryMessenger: messenger
    )
  }

  private func activeViewController() -> UIViewController? {
    let root = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)?
      .rootViewController
    var current = root
    while let presented = current?.presentedViewController {
      current = presented
    }
    return current
  }
}

private final class SystemPermissionService {
  private enum Permission: String {
    case camera
    case photoLibrary
  }

  private enum Status: String {
    case notDetermined
    case granted
    case limited
    case denied
    case restricted
    case unavailable
  }

  private let channel: FlutterMethodChannel

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "trip_cost/permissions",
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "openSettings" {
      openSettings(result: result)
      return
    }

    guard
      let arguments = call.arguments as? [String: Any],
      let rawPermission = arguments["permission"] as? String,
      let permission = Permission(rawValue: rawPermission)
    else {
      result(
        FlutterError(
          code: "invalid-permission",
          message: "A supported system permission is required.",
          details: nil
        )
      )
      return
    }

    switch call.method {
    case "status":
      result(status(for: permission).rawValue)
    case "request":
      request(permission, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func status(for permission: Permission) -> Status {
    switch permission {
    case .camera:
      return cameraStatus(AVCaptureDevice.authorizationStatus(for: .video))
    case .photoLibrary:
      return photoLibraryStatus(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }
  }

  private func request(_ permission: Permission, result: @escaping FlutterResult) {
    let current = status(for: permission)
    guard current == .notDetermined else {
      result(current.rawValue)
      return
    }

    switch permission {
    case .camera:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
        self?.completeOnMain(result, status: self?.status(for: permission) ?? .unavailable)
      }
    case .photoLibrary:
      PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] _ in
        self?.completeOnMain(result, status: self?.status(for: permission) ?? .unavailable)
      }
    }
  }

  private func openSettings(result: @escaping FlutterResult) {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      result(false)
      return
    }
    DispatchQueue.main.async {
      UIApplication.shared.open(url, options: [:]) { opened in
        result(opened)
      }
    }
  }

  private func completeOnMain(_ result: @escaping FlutterResult, status: Status) {
    DispatchQueue.main.async {
      result(status.rawValue)
    }
  }

  private func cameraStatus(_ status: AVAuthorizationStatus) -> Status {
    switch status {
    case .notDetermined:
      return .notDetermined
    case .authorized:
      return .granted
    case .denied:
      return .denied
    case .restricted:
      return .restricted
    @unknown default:
      return .unavailable
    }
  }

  private func photoLibraryStatus(_ status: PHAuthorizationStatus) -> Status {
    switch status {
    case .notDetermined:
      return .notDetermined
    case .authorized:
      return .granted
    case .limited:
      return .limited
    case .denied:
      return .denied
    case .restricted:
      return .restricted
    @unknown default:
      return .unavailable
    }
  }
}
