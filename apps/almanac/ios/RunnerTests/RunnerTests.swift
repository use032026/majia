import Flutter
import XCTest
import stmini_flutter

final class RunnerTests: XCTestCase {
  private func invoke(_ plugin: StminiFlutterPlugin, _ method: String, _ arguments: Any? = nil) -> Any? {
    var invoked = false
    var value: Any?
    plugin.handle(FlutterMethodCall(methodName: method, arguments: arguments)) { result in
      invoked = true
      value = result
    }
    XCTAssertTrue(invoked, "The native foundation must complete its result.")
    return value
  }

  private let configuration: [String: Any] = [
    "bridgeContext": ["packageName": "com.almanac.lite"]
  ]

  func testRealMainLocalizationInitializationAndState() {
    let plugin = StminiFlutterPlugin()
    let before = invoke(plugin, "foundationState") as! [String: Any]
    XCTAssertEqual(before["initialized"] as? Bool, false)
    XCTAssertNil(invoke(plugin, "initialize", configuration))
    let state = invoke(plugin, "foundationState") as! [String: Any]
    XCTAssertEqual(state["stage"] as? String, "foundation")
    XCTAssertEqual(state["initialized"] as? Bool, true)
    XCTAssertEqual(state["packageName"] as? String, Bundle.main.bundleIdentifier)
    XCTAssertFalse((state["localizedClose"] as? String ?? "").isEmpty)
    XCTAssertEqual(state["miniLoadingAvailable"] as? Bool, false)
    XCTAssertEqual(state["webLoadingAvailable"] as? Bool, false)
    XCTAssertNil(invoke(plugin, "initialize", configuration))
    let repeated = invoke(plugin, "foundationState") as! NSDictionary
    XCTAssertEqual(repeated, state as NSDictionary)
  }

  func testUnsupportedCapabilitiesAreErrorsRatherThanFakeSuccess() {
    let plugin = StminiFlutterPlugin()
    for method in ["openMini", "openWeb", "closeMini", "closeWeb", "installedPackages", "notifyWebSessionChanged", "isAvailable"] {
      let error = invoke(plugin, method, ["link": "mini://not-opened"]) as? FlutterError
      XCTAssertEqual(error?.code, "unsupported_capability", method)
    }
    let state = invoke(plugin, "foundationState") as! [String: Any]
    XCTAssertEqual(state["initialized"] as? Bool, false)
  }

  func testWrongIdentityAndUnsupportedConfigurationDoNotInitialize() {
    let plugin = StminiFlutterPlugin()
    let invalid: [[String: Any]] = [
      ["bridgeContext": ["packageName": "com.other.app"]],
      ["bridgeContext": ["packageName": "com.almanac.lite", "storageReset": ["version": "x"]]],
      ["bridgeContext": ["packageName": "com.almanac.lite"], "loadingImage": "unsupported"],
      [:]
    ]
    for arguments in invalid {
      let error = invoke(plugin, "initialize", arguments) as? FlutterError
      XCTAssertEqual(error?.code, "unsupported_foundation_configuration")
    }
    let state = invoke(plugin, "foundationState") as! [String: Any]
    XCTAssertEqual(state["initialized"] as? Bool, false)
    XCTAssertTrue(state["packageName"] is NSNull)
  }
}
