import Flutter
import Foundation

/// Foundation initialization plus an explicit local-only PlatformView; full link loaders remain unsupported.
public final class StminiFlutterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private let inventoryQueue = DispatchQueue(label: "stmini.local-inventory")
  private var detached = false
  private var inventoryQuery: InventoryQuery?
  private final class InventoryQuery {
    var result: FlutterResult?
    var work: DispatchWorkItem?
    private let lock = NSLock()
    private var cancelled = false
    private let deadline = ProcessInfo.processInfo.systemUptime + 4
    init(result: @escaping FlutterResult) { self.result = result }
    func cancel() { lock.lock(); cancelled = true; lock.unlock(); work?.cancel() }
    func check() throws {
      lock.lock(); let invalid = cancelled; lock.unlock()
      if invalid || ProcessInfo.processInfo.systemUptime >= deadline { throw LocalPackageInventory.Failure.unavailable }
    }
  }
  private var localViews: LocalMiniViewFactory?
  private var initialized = false
  private var packageName: String?
  private var localizedClose: String?
  private var eventSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = StminiFlutterPlugin()
    let methods = FlutterMethodChannel(name: "stmini_flutter/methods", binaryMessenger: registrar.messenger())
    let events = FlutterEventChannel(name: "stmini_flutter/events", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    registrar.publish(instance)
    events.setStreamHandler(instance)
    let factory = LocalMiniViewFactory(messenger: registrar.messenger()) { [weak instance] in
      instance?.initialized == true && instance?.detached == false
    }
    instance.localViews = factory
    registrar.register(factory, withId: "stmini_flutter/local_view")
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
    case "installedPackages":
      readInventory(call.arguments, result: result)
    default:
      result(FlutterError(code: "unsupported_capability", message: "This capability is not included in the foundation stage.", details: nil))
    }
  }

  private func readInventory(_ arguments: Any?, result: @escaping FlutterResult) {
    guard arguments == nil else {
      result(FlutterError(code: "invalid_inventory_arguments", message: "Inventory accepts no arguments.", details: nil)); return
    }
    guard initialized, !detached else {
      result(FlutterError(code: "not_initialized", message: "Initialize the foundation first.", details: nil)); return
    }
    guard inventoryQuery == nil else {
      result(FlutterError(code: "inventory_busy", message: "Inventory query already in progress.", details: nil)); return
    }
    let query = InventoryQuery(result: result)
    inventoryQuery = query
    let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    let work = DispatchWorkItem { [weak self, query] in
      let outcome = Result { try LocalPackageInventory(home: home).read(check: query.check) }
      DispatchQueue.main.async { [weak self, query] in
        query.work = nil
        guard let owner = self, owner.inventoryQuery === query, !owner.detached else {
          let cancelled = query.result; query.result = nil
          cancelled?(FlutterError(code: "inventory_cancelled", message: "Inventory query cancelled.", details: nil)); return
        }
        owner.inventoryQuery = nil
        let completion = query.result; query.result = nil
        switch outcome {
        case .success(let packages): completion?(packages)
        case .failure: completion?(FlutterError(code: "inventory_unavailable", message: "Local inventory could not be read.", details: nil))
        }
      }
    }
    query.work = work
    inventoryQueue.async(execute: work)
  }

  private func state() -> [String: Any] {
    return [
      "stage": "foundation", "initialized": initialized,
      "packageName": packageName as Any? ?? NSNull(),
      "localizedClose": localizedClose as Any? ?? NSNull(),
      "capabilities": ["host_configuration", "language_resolution", "runtime_events", "local_inventory", "local_renderer"],
      "localRendererAvailable": true,
      "miniLoadingAvailable": false, "webLoadingAvailable": false
    ]
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    // A late listener receives this instance's current state, not an old event.
    if initialized { events(["name": "foundation_initialized", "payload": state()]) }
    return nil
  }
  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    detached = true
    localViews?.detach(); localViews = nil
    initialized = false
    if let query = inventoryQuery {
      inventoryQuery = nil
      query.cancel()
      query.work = nil
      let completion = query.result; query.result = nil
      completion?(FlutterError(code: "inventory_cancelled", message: "Inventory query cancelled.", details: nil))
    }
    eventSink = nil
  }
}
