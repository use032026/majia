import Flutter
import Foundation

/// Explicit foundation adapter; the Mini/Web container is not part of this stage.
public final class StminiFlutterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var initialized = false
  private var packageName: String?
  private var localizedClose: String?
  private var eventSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = StminiFlutterPlugin()
    let methods = FlutterMethodChannel(name: "stmini_flutter/methods", binaryMessenger: registrar.messenger())
    let events = FlutterEventChannel(name: "stmini_flutter/events", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    events.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      guard let args = call.arguments as? [String: Any],
            Set(args.keys) == ["bridgeContext"],
            let context = args["bridgeContext"] as? [String: Any],
            Set(context.keys) == ["packageName"],
            let requestedPackage = context["packageName"] as? String,
            requestedPackage == "com.almanac.lite",
            Bundle.main.bundleIdentifier == requestedPackage else {
        result(FlutterError(code: "unsupported_foundation_configuration", message: "Stage one supports only the Deynu packageName.", details: nil))
        return
      }
      // Execute main's real localization resolver/cache; never open a page.
      localizedClose = STMiniLocalized("mini.close", "Close")
      packageName = requestedPackage
      initialized = true
      eventSink?(["name": "foundation_initialized", "payload": state()])
      result(nil)
    case "foundationState":
      result(state())
    default:
      result(FlutterError(code: "unsupported_capability", message: "This capability is not included in the foundation stage.", details: nil))
    }
  }

  private func state() -> [String: Any] {
    return [
      "stage": "foundation", "initialized": initialized,
      "packageName": packageName as Any? ?? NSNull(),
      "localizedClose": localizedClose as Any? ?? NSNull(),
      "capabilities": ["host_configuration", "language_resolution", "runtime_events"],
      "miniLoadingAvailable": false, "webLoadingAvailable": false
    ]
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }
  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}
