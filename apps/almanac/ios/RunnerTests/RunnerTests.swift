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

  func testExistingRegionalLanguageResourcesAreSelected() {
    let preferences = UserDefaults.standard
    let previous = preferences.object(forKey: "STLanguageCode")
    defer {
      if let previous = previous { preferences.set(previous, forKey: "STLanguageCode") }
      else { preferences.removeObject(forKey: "STLanguageCode") }
    }
    for (language, expected) in [
      ("en-US", "Close"), ("pt-BR", "Fechar"), ("pt-PT", "Fechar"),
      ("pt_BR", "Fechar"), ("zh-TW", "關閉"), ("zh_HK", "關閉"),
      ("zh-CN", "关闭"), ("zh_CN", "关闭"), ("unknown-LANG", "Close")
    ] {
      preferences.set(language, forKey: "STLanguageCode")
      let plugin = StminiFlutterPlugin()
      XCTAssertNil(invoke(plugin, "initialize", configuration))
      let state = invoke(plugin, "foundationState") as! [String: Any]
      XCTAssertEqual(state["localizedClose"] as? String, expected, language)
    }
  }

  func testListenBeforeAndAfterInitializationAndCancelReplayCurrentState() {
    let early = StminiFlutterPlugin()
    var earlyEvents: [[String: Any]] = []
    XCTAssertNil(early.onListen(withArguments: nil) { earlyEvents.append($0 as! [String: Any]) })
    XCTAssertTrue(earlyEvents.isEmpty)
    XCTAssertNil(invoke(early, "initialize", configuration))
    XCTAssertEqual(earlyEvents.count, 1)
    XCTAssertEqual(earlyEvents[0]["name"] as? String, "foundation_initialized")
    let earlyPayload = earlyEvents[0]["payload"] as! [String: Any]
    XCTAssertEqual(earlyPayload["initialized"] as? Bool, true)
    XCTAssertEqual(earlyPayload["packageName"] as? String, "com.almanac.lite")

    let late = StminiFlutterPlugin()
    XCTAssertNil(invoke(late, "initialize", configuration))
    var oldEvents: [[String: Any]] = []
    XCTAssertNil(late.onListen(withArguments: nil) { oldEvents.append($0 as! [String: Any]) })
    XCTAssertEqual(oldEvents.count, 1)
    XCTAssertNil(late.onCancel(withArguments: nil))
    XCTAssertNil(invoke(late, "initialize", configuration))
    XCTAssertEqual(oldEvents.count, 1)
    var currentEvents: [[String: Any]] = []
    XCTAssertNil(late.onListen(withArguments: nil) { currentEvents.append($0 as! [String: Any]) })
    XCTAssertEqual(currentEvents.count, 1)
    let replay = currentEvents[0]["payload"] as! NSDictionary
    XCTAssertEqual(replay, invoke(late, "foundationState") as! NSDictionary)
  }

  func testCancellingOneNativeInstanceDoesNotCancelAnotherInstance() {
    let first = StminiFlutterPlugin()
    let second = StminiFlutterPlugin()
    var firstCount = 0
    var secondCount = 0
    XCTAssertNil(first.onListen(withArguments: nil) { _ in firstCount += 1 })
    XCTAssertNil(second.onListen(withArguments: nil) { _ in secondCount += 1 })
    XCTAssertNil(invoke(first, "initialize", configuration))
    XCTAssertNil(first.onCancel(withArguments: nil))
    XCTAssertNil(invoke(second, "initialize", configuration))
    XCTAssertEqual(firstCount, 1)
    XCTAssertEqual(secondCount, 1)
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
