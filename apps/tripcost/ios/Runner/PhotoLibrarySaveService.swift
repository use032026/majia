import Flutter
import Photos
import UniformTypeIdentifiers

final class PhotoLibrarySaveService {
  private static let channelName = "trip_cost/photos"

  static func register(binaryMessenger: FlutterBinaryMessenger) -> PhotoLibrarySaveService {
    let service = PhotoLibrarySaveService()
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { [weak service] call, result in
      service?.handle(call, result: result)
    }
    return service
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "savePng" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard
      let typedData = call.arguments as? FlutterStandardTypedData,
      !typedData.data.isEmpty
    else {
      result(
        FlutterError(
          code: "invalid-image",
          message: "A PNG image is required.",
          details: nil
        )
      )
      return
    }
    authorizeAndSave(typedData.data, result: result)
  }

  private func authorizeAndSave(_ data: Data, result: @escaping FlutterResult) {
    switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
    case .authorized, .limited:
      save(data, result: result)
    case .notDetermined:
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
        guard status == .authorized || status == .limited else {
          self?.complete(
            result,
            error: FlutterError(
              code: "photo-permission-denied",
              message: "Permission to add photos was not granted.",
              details: nil
            )
          )
          return
        }
        self?.save(data, result: result)
      }
    case .denied, .restricted:
      complete(
        result,
        error: FlutterError(
          code: "photo-permission-denied",
          message: "Permission to add photos was not granted.",
          details: nil
        )
      )
    @unknown default:
      complete(
        result,
        error: FlutterError(
          code: "photo-save-unavailable",
          message: "The photo library is unavailable.",
          details: nil
        )
      )
    }
  }

  private func save(_ data: Data, result: @escaping FlutterResult) {
    PHPhotoLibrary.shared().performChanges {
      let options = PHAssetResourceCreationOptions()
      options.originalFilename = "roamsum-trip-summary-\(UUID().uuidString).png"
      options.uniformTypeIdentifier = UTType.png.identifier
      PHAssetCreationRequest.forAsset().addResource(
        with: .photo,
        data: data,
        options: options
      )
    } completionHandler: { [weak self] saved, error in
      guard saved, error == nil else {
        self?.complete(
          result,
          error: FlutterError(
            code: "photo-save-failed",
            message: "The trip summary could not be saved.",
            details: error?.localizedDescription
          )
        )
        return
      }
      self?.complete(result)
    }
  }

  private func complete(_ result: @escaping FlutterResult, error: FlutterError? = nil) {
    DispatchQueue.main.async {
      if let error {
        result(error)
      } else {
        result(nil)
      }
    }
  }
}
