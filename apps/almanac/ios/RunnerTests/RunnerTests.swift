import Flutter
import XCTest
import UIKit
import WebKit
import Network
import Photos
import ObjectiveC.runtime
@testable import stmini_flutter

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
    XCTAssertEqual(state["stage"] as? String, "mini")
    XCTAssertEqual(state["initialized"] as? Bool, true)
    XCTAssertEqual(state["packageName"] as? String, Bundle.main.bundleIdentifier)
    XCTAssertFalse((state["localizedClose"] as? String ?? "").isEmpty)
    XCTAssertEqual(state["miniLoadingAvailable"] as? Bool, true)
    XCTAssertEqual(state["webLoadingAvailable"] as? Bool, true)
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
    XCTAssertEqual(earlyEvents[0]["name"] as? String, "runtime_initialized")
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

  func testCompleteRuntimeRejectsUninitializedOpeningAndInvalidDispatch() {
    let plugin = StminiFlutterPlugin()
    for method in ["openMini", "openWeb"] {
      let error = invoke(plugin, method, ["link": "mini://not-opened"]) as? FlutterError
      XCTAssertEqual(error?.code, "not_initialized", method)
    }
    XCTAssertEqual(invoke(plugin, "isAvailable") as? Bool, true)
    XCTAssertEqual((invoke(plugin, "notifyWebSessionChanged", [:]) as? FlutterError)?.code, "invalid_reason")
    XCTAssertTrue((invoke(plugin, "unknownCapability") as AnyObject?) === FlutterMethodNotImplemented)
    let state = invoke(plugin, "foundationState") as! [String: Any]
    XCTAssertEqual(state["initialized"] as? Bool, false)
  }

  func testWrongIdentityAndUnsupportedConfigurationDoNotInitialize() {
    let plugin = StminiFlutterPlugin()
    let invalid: [[String: Any]] = [
      ["bridgeContext": ["packageName": "com.other.app"]],
      ["bridgeContext": ["packageName": "com.almanac.lite", "storageReset": ["version": "x"]]],
      ["bridgeContext": ["packageName": "com.almanac.lite"], "loadingImage": 123],
      [:]
    ]
    for arguments in invalid {
      let error = invoke(plugin, "initialize", arguments) as? FlutterError
      XCTAssertEqual(error?.code, "unsupported_host_configuration")
    }
    let state = invoke(plugin, "foundationState") as! [String: Any]
    XCTAssertEqual(state["initialized"] as? Bool, false)
    XCTAssertTrue(state["packageName"] is NSNull)
  }
  // Inventory calls complete asynchronously; never use the synchronous foundation helper.
  private func inventoryResult(_ plugin: StminiFlutterPlugin, arguments: Any? = nil) -> Any? {
    let completed = expectation(description: "Inventory completes exactly once")
    completed.assertForOverFulfill = true
    var value: Any?
    plugin.handle(FlutterMethodCall(methodName: "installedPackages", arguments: arguments)) { result in
      XCTAssertTrue(Thread.isMainThread)
      value = result
      completed.fulfill()
    }
    wait(for: [completed], timeout: 5)
    return value
  }

  func testInventoryRequiresInitializationAndRejectsEveryNonNullArgument() {
    let plugin = StminiFlutterPlugin()
    XCTAssertEqual((inventoryResult(plugin) as? FlutterError)?.code, "not_initialized")
    XCTAssertNil(invoke(plugin, "initialize", configuration))
    let invalid: [Any] = [[:], ["root": "/unused"], "", 0, NSNull()]
    for arguments in invalid {
      XCTAssertEqual((inventoryResult(plugin, arguments: arguments) as? FlutterError)?.code, "invalid_inventory_arguments")
    }
  }

  func testInventoryNativePluginUsesMainThreadSingleFlightAndReadsRealEmptyRoot() {
    let plugin = StminiFlutterPlugin()
    XCTAssertNil(invoke(plugin, "initialize", configuration))
    let root = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents/STMini")
    let existedBefore = FileManager.default.fileExists(atPath: root.path)
    XCTAssertFalse(existedBefore, "Run this case in the task-owned fresh simulator.")
    let completed = expectation(description: "First inventory callback")
    completed.assertForOverFulfill = true
    var calls = 0
    plugin.handle(FlutterMethodCall(methodName: "installedPackages", arguments: nil)) { value in
      XCTAssertTrue(Thread.isMainThread)
      calls += 1
      XCTAssertEqual((value as? [[String: String]])?.count, 0)
      completed.fulfill()
    }
    XCTAssertEqual((inventoryResult(plugin) as? FlutterError)?.code, "inventory_busy")
    wait(for: [completed], timeout: 5)
    XCTAssertEqual(calls, 1)
    XCTAssertEqual(FileManager.default.fileExists(atPath: root.path), existedBefore)
    let state = invoke(plugin, "foundationState") as! [String: Any]
    XCTAssertTrue((state["capabilities"] as? [String])?.contains("local_inventory") == true)
  }

  func testInventoryDetachCancelsOnceAndDiscardsLateCompletion() {
    XCTAssertTrue(Thread.isMainThread)
    // FlutterPlugin.h declares registrarForPlugin on FlutterPluginRegistry;
    // the actual Runner FlutterAppDelegate supplies the runtime registrar.
    guard let registry = UIApplication.shared.delegate as? FlutterPluginRegistry,
          let registrar = registry.registrar(forPlugin: "DeynuInventoryDetachTest-" + UUID().uuidString) else {
      XCTFail("The native Runner must provide its Flutter registry.")
      return
    }
    let plugin = StminiFlutterPlugin()
    XCTAssertNil(invoke(plugin, "initialize", configuration))
    let cancelled = expectation(description: "Detach completes the owned query once")
    cancelled.assertForOverFulfill = true
    let late = expectation(description: "No late duplicate result")
    late.isInverted = true
    var callbacks = 0
    plugin.handle(FlutterMethodCall(methodName: "installedPackages", arguments: nil)) { result in
      XCTAssertTrue(Thread.isMainThread)
      callbacks += 1
      if callbacks == 1 {
        XCTAssertEqual((result as? FlutterError)?.code, "inventory_cancelled")
        cancelled.fulfill()
      } else { late.fulfill() }
    }
    plugin.detachFromEngine(for: registrar)
    plugin.detachFromEngine(for: registrar)
    wait(for: [cancelled], timeout: 1)
    XCTAssertEqual((inventoryResult(plugin) as? FlutterError)?.code, "not_initialized")
    // Drain the main queue while the cancelled, read-only background work exits.
    wait(for: [late], timeout: 0.5)
    XCTAssertEqual(callbacks, 1)
  }

  private final class InventoryFixture {
    let container: URL
    let home: URL
    let manager = FileManager.default
    var root: URL { home.appendingPathComponent("Documents/STMini", isDirectory: true) }
    init() throws {
      container = FileManager.default.temporaryDirectory.appendingPathComponent("deynu-inventory-" + UUID().uuidString, isDirectory: true)
      home = container.appendingPathComponent("home", isDirectory: true)
      try manager.createDirectory(at: home, withIntermediateDirectories: true)
    }
    deinit { try? manager.removeItem(at: container) }
    func read(check: () throws -> Void = {}) throws -> [[String: String]] {
      try LocalPackageInventory(home: home).read(check: check)
    }
    func write(_ url: URL, _ text: String) throws {
      try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try Data(text.utf8).write(to: url)
    }
    func json(_ url: URL, _ object: [String: Any]) throws {
      try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]).write(to: url)
    }
    @discardableResult func pack(_ id: String = "alpha", manifest changes: [String: Any] = [:], record recordChanges: [String: Any] = [:]) throws -> URL {
      let directory = root.appendingPathComponent(id, isDirectory: true)
      try write(directory.appendingPathComponent("pages/index.html"), "local test entry")
      try write(directory.appendingPathComponent("images/icon.png"), "local test icon")
      var manifest: [String: Any] = ["miniId": id, "miniName": "Local test", "version": "1.2", "entry": "pages/index.html", "icon": "images/icon.png"]
      var record: [String: Any] = ["miniId": id, "version": "1.2", "entry": "pages/index.html"]
      manifest.merge(changes) { _, new in new }; record.merge(recordChanges) { _, new in new }
      try json(directory.appendingPathComponent("mini-manifest.json"), manifest)
      try json(directory.appendingPathComponent(".st-mini-package.json"), record)
      return directory
    }
    func snapshot() throws -> [String] {
      let canonicalHome = home.resolvingSymlinksInPath()
      let enumerator = manager.enumerator(at: canonicalHome, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey])!
      var items = [String]()
      while let url = enumerator.nextObject() as? URL {
        let relative = String(url.path.dropFirst(canonicalHome.path.count))
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        if values.isSymbolicLink == true { items.append("link:" + relative) }
        else if values.isRegularFile == true { items.append("file:" + relative + ":" + (try Data(contentsOf: url)).base64EncodedString()) }
        else { items.append("dir:" + relative) }
      }
      return items.sorted()
    }
    func remove(_ url: URL) throws { try manager.removeItem(at: url) }
    func link(_ original: URL, target: URL) throws {
      try remove(original)
      try manager.createSymbolicLink(at: original, withDestinationURL: target)
    }
  }

  private func assertCount(_ fixture: InventoryFixture, _ count: Int, file: StaticString = #filePath, line: UInt = #line) throws {
    XCTAssertEqual(try fixture.read().count, count, file: file, line: line)
  }
  private func assertUnavailable(_ action: () throws -> Void, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertThrowsError(try action(), file: file, line: line) { error in
      guard case LocalPackageInventory.Failure.unavailable = error else {
        XCTFail("Expected inventory unavailable", file: file, line: line); return
      }
    }
  }

  func testInventoryFilesystemAbsentEmptyValidSortedAndZeroWrites() throws {
    let missing = try InventoryFixture()
    let beforeMissing = try missing.snapshot()
    try assertCount(missing, 0)
    XCTAssertEqual(try missing.snapshot(), beforeMissing)
    XCTAssertFalse(missing.manager.fileExists(atPath: missing.root.path))
    let empty = try InventoryFixture()
    try empty.manager.createDirectory(at: empty.root, withIntermediateDirectories: true)
    let beforeEmpty = try empty.snapshot(); try assertCount(empty, 0)
    XCTAssertEqual(try empty.snapshot(), beforeEmpty)
    let valid = try InventoryFixture()
    try valid.pack("zeta"); try valid.pack("alpha")
    let beforeValid = try valid.snapshot(); let packages = try valid.read()
    XCTAssertEqual(packages.compactMap { $0["miniId"] }, ["alpha", "zeta"])
    XCTAssertTrue(packages.allSatisfy { Set($0.keys) == Set(["miniId", "miniName", "version", "entry", "icon"]) && $0["version"] == "1.2" })
    XCTAssertEqual(try valid.snapshot(), beforeValid)
    let fallback = try InventoryFixture()
    try fallback.pack(manifest: ["miniName": "", "icon": ""])
    XCTAssertEqual(try fallback.read().first?["miniName"], "alpha")
    XCTAssertEqual(try fallback.read().first?["icon"], "")
  }

  func testInventoryFilesystemRecordTypesIdentityAndVersionBounds() throws {
    for (field, value) in [("miniId", "other"), ("version", "1.3"), ("entry", "other.html")] {
      let fixture = try InventoryFixture(); try fixture.pack(record: [field: value]); try assertCount(fixture, 0)
    }
    for field in ["miniId", "version", "entry", "icon", "miniName", "channel", "updateself", "ishome"] {
      let fixture = try InventoryFixture(); try fixture.pack(manifest: [field: 7]); try assertCount(fixture, 0)
    }
    for field in ["miniId", "version", "entry", "channel"] {
      let fixture = try InventoryFixture(); try fixture.pack(record: [field: false]); try assertCount(fixture, 0)
    }
    for version in ["", "1.", ".1", "1..2", "-1", "1e2", "1-beta", "1_2", "1\n", "1234567890", Array(repeating: "1", count: 9).joined(separator: ".")] {
      let fixture = try InventoryFixture(); try fixture.pack(manifest: ["version": version], record: ["version": version]); try assertCount(fixture, 0)
    }
    let boundary = try InventoryFixture(); let version = Array(repeating: "123456789", count: 8).joined(separator: ".")
    try boundary.pack(manifest: ["version": version], record: ["version": version]); try assertCount(boundary, 1)
    try boundary.pack("zero", manifest: ["version": "000.01"], record: ["version": "000.01"]); try assertCount(boundary, 2)
    for id in ["Alpha", "_alpha", String(repeating: "a", count: 65)] {
      let fixture = try InventoryFixture(); try fixture.pack(id); try assertCount(fixture, 0)
    }
  }

  func testInventoryFilesystemUTF16ChannelAndPathBounds() throws {
    for (length, expected) in [(128, 1), (129, 0)] {
      let fixture = try InventoryFixture(); try fixture.pack(manifest: ["miniName": String(repeating: "😀", count: length)]); try assertCount(fixture, expected)
    }
    for (manifest, record) in [("one", "two"), (String(repeating: "x", count: 129), String(repeating: "x", count: 129))] {
      let fixture = try InventoryFixture(); try fixture.pack(manifest: ["channel": manifest], record: ["channel": record]); try assertCount(fixture, 0)
    }
    for path in ["", "/index.html", "a//b", "a/", ".", "..", "a/../b", "a\\b", "https:x", "a?b", "a#b", "a%b", "a\0b", "a\u{1f}b", "a\u{7f}b", "a\u{85}b", String(repeating: "a", count: 129), Array(repeating: "a", count: 17).joined(separator: "/"), Array(repeating: String(repeating: "a", count: 128), count: 8).joined(separator: "/")] {
      let fixture = try InventoryFixture(); try fixture.pack(manifest: ["entry": path], record: ["entry": path]); try assertCount(fixture, 0)
      if !path.isEmpty {
        let icon = try InventoryFixture(); try icon.pack(manifest: ["icon": path]); try assertCount(icon, 0)
      }
    }
    let deep = try InventoryFixture(); let path = Array(repeating: "a", count: 16).joined(separator: "/")
    let directory = try deep.pack(manifest: ["entry": path], record: ["entry": path])
    try deep.write(directory.appendingPathComponent(path), "deep entry"); try assertCount(deep, 1)
    let maximumPath = (Array(repeating: String(repeating: "a", count: 128), count: 7) + [String(repeating: "a", count: 121)]).joined(separator: "/")
    XCTAssertEqual(maximumPath.utf16.count, 1024); XCTAssertTrue(LocalPackageInventory.safePath(maximumPath))
  }

  func testInventoryFilesystemMissingDirectoryMetadataAndRevalidation() throws {
    for relative in ["pages/index.html", "images/icon.png", "mini-manifest.json", ".st-mini-package.json"] {
      let missing = try InventoryFixture(); let directory = try missing.pack()
      try missing.remove(directory.appendingPathComponent(relative)); try assertCount(missing, 0)
      let folder = try InventoryFixture(); let folderDirectory = try folder.pack(); let target = folderDirectory.appendingPathComponent(relative)
      try folder.remove(target); try folder.manager.createDirectory(at: target, withIntermediateDirectories: true); try assertCount(folder, 0)
    }
    for name in ["mini-manifest.json", ".st-mini-package.json"] {
      for contents in [Data("{broken".utf8), Data(repeating: 32, count: 65537), Data([0xc3, 0x28])] {
        let fixture = try InventoryFixture(); let directory = try fixture.pack()
        try contents.write(to: directory.appendingPathComponent(name)); try assertCount(fixture, 0)
      }
    }
    let deleted = try InventoryFixture(); let directory = try deleted.pack(); try assertCount(deleted, 1)
    try deleted.remove(directory.appendingPathComponent("pages/index.html")); try assertCount(deleted, 0)
    let changed = try InventoryFixture(); let changedDirectory = try changed.pack(); try assertCount(changed, 1)
    try changed.write(changedDirectory.appendingPathComponent("mini-manifest.json"), "{}"); try assertCount(changed, 0)
  }

  func testInventoryFilesystemRejectsEverySymlinkLayerInsideOutsideAndBroken() throws {
    for layer in ["documents", "root", "package", "record", "manifest", "intermediate", "entry", "icon"] {
      for location in ["inside", "outside", "broken"] {
        let fixture = try InventoryFixture(); let directory = try fixture.pack()
        let original: URL
        switch layer {
        case "documents": original = fixture.home.appendingPathComponent("Documents")
        case "root": original = fixture.root
        case "package": original = directory
        case "record": original = directory.appendingPathComponent(".st-mini-package.json")
        case "manifest": original = directory.appendingPathComponent("mini-manifest.json")
        case "intermediate": original = directory.appendingPathComponent("pages")
        case "entry": original = directory.appendingPathComponent("pages/index.html")
        default: original = directory.appendingPathComponent("images/icon.png")
        }
        let inside: URL
        if layer == "documents" || layer == "root" { inside = fixture.home }
        else if layer == "package" { inside = fixture.root }
        else { inside = directory }
        let target = (location == "inside" ? inside : fixture.container).appendingPathComponent("target")
        if location != "broken" { try fixture.manager.copyItem(at: original, to: target) }
        try fixture.link(original, target: target)
        if layer == "documents" || layer == "root" { assertUnavailable { _ = try fixture.read() } }
        else { try assertCount(fixture, 0) }
      }
    }
  }

  func testInventoryFilesystemRootLimitAndCancellationDeadline() throws {
    let fileRoot = try InventoryFixture(); try fileRoot.write(fileRoot.root, "not a directory")
    assertUnavailable { _ = try fileRoot.read() }
    let excessive = try InventoryFixture()
    for index in 0..<257 { try excessive.manager.createDirectory(at: excessive.root.appendingPathComponent("p\(index)"), withIntermediateDirectories: true) }
    assertUnavailable { _ = try excessive.read() }
    let hidden = try InventoryFixture(); try hidden.pack(".staging"); try assertCount(hidden, 0)
    let cancelled = try InventoryFixture()
    assertUnavailable { _ = try cancelled.read { throw LocalPackageInventory.Failure.unavailable } }
    let missingDeadline = try InventoryFixture(); var missingChecks = 0
    assertUnavailable { _ = try missingDeadline.read { missingChecks += 1; if missingChecks == 2 { throw LocalPackageInventory.Failure.unavailable } } }
    XCTAssertEqual(missingChecks, 2)
    let deadline = try InventoryFixture(); try deadline.pack(); var checks = 0
    assertUnavailable { _ = try deadline.read { checks += 1; if checks == 5 { throw LocalPackageInventory.Failure.unavailable } } }
    XCTAssertEqual(checks, 5)
  }
}

// Independent real WKWebView fixture tests. The messenger below is test glue;
// FlutterEngine→registered factory is exercised separately by the test-only target.
private final class RendererMessenger: NSObject, FlutterBinaryMessenger {
  var handlers = [String: FlutterBinaryMessageHandler]()
  func send(onChannel channel: String, message: Data?) {}
  func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply?) { callback?(nil) }
  func setMessageHandlerOnChannel(_ channel: String, binaryMessageHandler handler: FlutterBinaryMessageHandler?) -> FlutterBinaryMessengerConnection {
    handlers[channel] = handler; return 1
  }
  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
}

final class LocalRendererTests: XCTestCase {
  private func until(_ timeout: TimeInterval = 10, _ condition: @escaping () -> Bool) {
    let expectation = expectation(description: "real WKWebView condition")
    let deadline = Date().addingTimeInterval(timeout)
    func poll() {
      if condition() { expectation.fulfill(); return }
      if Date() >= deadline { expectation.fulfill(); XCTFail("Native renderer condition timed out"); return }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: poll)
    }
    poll(); wait(for: [expectation], timeout: timeout + 1)
  }
  private func js(_ view: WKWebView, _ source: String) -> Any? {
    let expectation = expectation(description: "native DOM probe")
    var value: Any?
    view.evaluateJavaScript(source) { result, error in
      XCTAssertNil(error); value = result; expectation.fulfill()
    }
    wait(for: [expectation], timeout: 5); return value
  }
  private func fixture() throws -> URL {
    let home = FileManager.default.temporaryDirectory.appendingPathComponent("stmini-renderer-\(UUID().uuidString)")
    let package = home.appendingPathComponent("Documents/STMini/renderer_fixture")
    try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
    for (name, data) in RendererFixture.files { try data.write(to: package.appendingPathComponent(name)) }
    return home
  }
  private func waitJS(_ view: WKWebView, _ expression: String, timeout: TimeInterval = 8) {
    let done = expectation(description: "local JavaScript terminal")
    let deadline = Date().addingTimeInterval(timeout)
    func poll() {
      view.evaluateJavaScript(expression) { value, error in
        if value as? Bool == true { done.fulfill(); return }
        if error != nil || Date() >= deadline { XCTFail("Local JS did not reach terminal"); done.fulfill(); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: poll)
      }
    }
    poll(); wait(for: [done], timeout: timeout + 1)
  }
  func testRealWKRemoteResourceAttemptsHavePositiveControlAndNoConnections() throws {
    let home = try fixture(); defer { try? FileManager.default.removeItem(at: home) }
    let listener = try RendererLoopback()
    until { listener.port != nil }
    let port = try XCTUnwrap(listener.port)
    let positive = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
    positive.start(queue: DispatchQueue(label: "stmini.test.loopback.positive"))
    until { listener.count == 1 }; positive.cancel(); listener.reset()
    defer { listener.stop() }
    let local = LocalMiniView(frame: UIScreen.main.bounds, messenger: RendererMessenger(), viewId: 909,
      arguments: ["miniId": "renderer_fixture", "version": "1.0"], allowed: { true }, home: home)
    let window = UIWindow(frame: UIScreen.main.bounds); window.rootViewController = UIViewController()
    window.rootViewController!.view.addSubview(local.view()); window.makeKeyAndVisible()
    defer { local.close(); window.isHidden = true }
    until { local.state()["phase"] as? String == "ready" }
    let view = try XCTUnwrap(local.webView); until { !view.isLoading }
    XCTAssertEqual(js(view, "window.__rendererProbe.ran") as? Bool, true)
    _ = js(view, "window.runNetworkProbe(\(port)); true")
    waitJS(view, "window.__rendererProbe.done === true")
    let raw = try XCTUnwrap(js(view, "JSON.stringify(window.__rendererProbe)") as? String)
    let result = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as! [String: Any]
    let attempts = try XCTUnwrap(result["attempts"] as? [String: String])
    XCTAssertEqual(attempts.count, 12)
    XCTAssertFalse(attempts.values.contains("attempted"))
    XCTAssertFalse(attempts.values.contains("open")); XCTAssertFalse(attempts.values.contains("opened"))
    XCTAssertNotEqual(attempts["remoteScript"], "load"); XCTAssertNotEqual(attempts["dataScript"], "load")
    XCTAssertNotEqual(attempts["blobScript"], "load"); XCTAssertNotEqual(attempts["fetch"], "resolved")
    XCTAssertEqual(result["remoteCodeExecuted"] as? Bool, false)
    XCTAssertEqual(listener.count, 0)
    XCTAssertEqual(view.url?.host, "renderer_fixture.stmini.local")
    _ = js(view, "location.href = 'http://127.0.0.1:\(port)/main'; true")
    let settle = expectation(description: "rejected main navigation settles")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settle.fulfill() }; wait(for: [settle], timeout: 2)
    XCTAssertEqual(view.url?.host, "renderer_fixture.stmini.local"); XCTAssertEqual(listener.count, 0)
    let report: [String: Any] = ["passed": testRun?.failureCount == 0, "positiveControlConnections": 1, "attempts": attempts,
      "localJSRan": result["ran"]!, "remoteCodeExecuted": false, "loopbackConnections": listener.count,
      "uncovered": ["WebRTC", "UDP", "DNS", "physical device"]]
    let reportData = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
    print("STMINI_LOCAL_WK_NETWORK_RESULT " + String(data: reportData, encoding: .utf8)!)
  }
  @discardableResult
  private func control(_ messenger: RendererMessenger, _ viewId: Int, _ method: String) -> Any? {
    let expectation = expectation(description: "production control channel")
    let codec = FlutterStandardMethodCodec.sharedInstance()
    var value: Any?
    messenger.handlers["stmini_flutter/local_view/\(viewId)"]?(codec.encode(FlutterMethodCall(methodName: method, arguments: nil))) { data in
      if let data { value = codec.decodeEnvelope(data) }
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 5); return value
  }
  func testRealSchemeHandlerReaderBoundsCancellationAndOversize() throws {
    let home = try fixture(); defer { try? FileManager.default.removeItem(at: home) }
    let inventory = LocalPackageInventory(home: home)
    let resource = LocalMiniResource(inventory: inventory, miniId: "renderer_fixture", version: "1.0", entry: "index.html")
    let web = WKWebView(frame: .zero)
    let tasks = (0..<5).map { _ in RendererSchemeTask(resource.url("probe.js")!) }
    for task in tasks { resource.webView(web, start: task) }
    XCTAssertEqual(tasks[4].failed, 1) // no waiting queue beyond the four slots
    resource.webView(web, stop: tasks[0])
    until { tasks[1...3].allSatisfy { $0.finished == 1 } }
    XCTAssertEqual(tasks[0].callbacks, 0)
    for task in tasks[1...3] { XCTAssertEqual(task.failed, 0); XCTAssertGreaterThan(task.bytes, 0); XCTAssertEqual(task.finished, 1) }
    let large = home.appendingPathComponent("Documents/STMini/renderer_fixture/large.bin")
    FileManager.default.createFile(atPath: large.path, contents: Data())
    let handle = try FileHandle(forWritingTo: large); try handle.truncate(atOffset: 8 * 1024 * 1024 + 1); try handle.close()
    let oversized = RendererSchemeTask(resource.url("large.bin")!); resource.webView(web, start: oversized)
    until { oversized.failed == 1 }; XCTAssertEqual(oversized.bytes, 0)
    let closed = RendererSchemeTask(resource.url("probe.js")!); resource.webView(web, start: closed); resource.close()
    let settles = expectation(description: "cancelled scheme work drains")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settles.fulfill() }; wait(for: [settles], timeout: 2)
    XCTAssertEqual(closed.callbacks, 0)
  }
  func testInventoryUnicodeWireFieldsAndBoundEntryUseExactUTF16() throws {
    let home = try fixture(); defer { try? FileManager.default.removeItem(at: home) }
    let package = home.appendingPathComponent("Documents/STMini/renderer_fixture")
    let inventory = LocalPackageInventory(home: home)
    let nfc = "caf\u{e9}.html", nfd = "cafe\u{301}.html"
    try FileManager.default.copyItem(at: package.appendingPathComponent("index.html"), to: package.appendingPathComponent(nfc))
    var manifest: [String: String] = ["miniId": "renderer_fixture", "miniName": "Fixture", "version": "1.0", "entry": nfc, "icon": "pixel.png", "channel": ""]
    var record = manifest
    func write() throws {
      try JSONSerialization.data(withJSONObject: manifest).write(to: package.appendingPathComponent("mini-manifest.json"))
      try JSONSerialization.data(withJSONObject: record).write(to: package.appendingPathComponent(".st-mini-package.json"))
    }
    record["entry"] = nfd; try write(); XCTAssertEqual(try inventory.read(check: {}).count, 0)
    record["entry"] = nfc; manifest["channel"] = "\u{e9}"; record["channel"] = "e\u{301}"
    try write(); XCTAssertEqual(try inventory.read(check: {}).count, 0)
    manifest["channel"] = ""; record["channel"] = ""; try write()
    XCTAssertEqual(try inventory.read(check: {}).count, 1)
    XCTAssertThrowsError(try inventory.verifiedPackage(miniId: "renderer_fixture", version: "1.0", entry: nfd, check: {}))
  }
  func testRendererURLBoundariesMIMEAndIdentityRevalidation() throws {
    let home = try fixture(); defer { try? FileManager.default.removeItem(at: home) }
    let inventory = LocalPackageInventory(home: home)
    let resource = LocalMiniResource(inventory: inventory, miniId: "renderer_fixture", version: "1.0", entry: "index.html")
    XCTAssertEqual(resource.path(URL(string: "stmini://renderer_fixture.stmini.local/index.html#local")!), "index.html")
    for raw in ["stmini://other.stmini.local/index.html", "stmini://renderer_fixture.stmini.local:80/index.html",
                "stmini://user@renderer_fixture.stmini.local/index.html", "https://renderer_fixture.stmini.local/index.html",
                "stmini://renderer_fixture.stmini.local/index.html?q=x", "stmini://renderer_fixture.stmini.local/a//b",
                "stmini://renderer_fixture.stmini.local/%2e%2e/index.html", "stmini://renderer_fixture.stmini.local/%252e%252e/index.html",
                "stmini://renderer_fixture.stmini.local/a%2fb", "stmini://renderer_fixture.stmini.local/a%5cb",
                "stmini://renderer_fixture.stmini.local/%C3%28", "file:///etc/passwd"] {
      XCTAssertNil(resource.path(URL(string: raw)!), raw)
    }
    XCTAssertEqual(LocalMiniResource.mime("probe.js"), "application/javascript")
    XCTAssertEqual(LocalMiniResource.mime("style.css"), "text/css")
    XCTAssertEqual(LocalMiniResource.mime("pixel.png"), "image/png")
    XCTAssertEqual(LocalMiniResource.mime("unknown.xyz"), "application/octet-stream")
    _ = try inventory.verifiedResource(miniId: "renderer_fixture", version: "1.0", entry: "index.html", path: "probe.js", check: {})
    let package = home.appendingPathComponent("Documents/STMini/renderer_fixture")
    var manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: package.appendingPathComponent("mini-manifest.json"))) as! [String: String]
    manifest["entry"] = "second.html"
    for name in ["mini-manifest.json", ".st-mini-package.json"] { try JSONSerialization.data(withJSONObject: manifest).write(to: package.appendingPathComponent(name)) }
    XCTAssertThrowsError(try inventory.verifiedResource(miniId: "renderer_fixture", version: "1.0", entry: "index.html", path: "probe.js", check: {}))
  }
  func testRealEightSecondWatchdogLateIdentityAndReload() throws {
    let home = try fixture(); defer { try? FileManager.default.removeItem(at: home) }
    let messenger = RendererMessenger()
    let local = LocalMiniView(frame: UIScreen.main.bounds, messenger: messenger, viewId: 908,
      arguments: ["miniId": "renderer_fixture", "version": "1.0"], allowed: { true }, home: home)
    defer { local.close() }
    until { local.state()["phase"] as? String == "ready" }
    // Test-only scheduler control over the existing private serial queue. No
    // product hook/channel or fake timer: the production eight-second timer runs.
    let queue = try XCTUnwrap(Mirror(reflecting: local).children.first(where: { $0.label == "queue" })?.value as? DispatchQueue)
    let entered = expectation(description: "background identity blocker entered")
    let release = DispatchSemaphore(value: 0)
    queue.async { entered.fulfill(); _ = release.wait(timeout: .now() + 15) }
    wait(for: [entered], timeout: 2)
    var released = false; defer { if !released { release.signal() } }
    let started = Date(); control(messenger, 908, "reload")
    until(10) { local.state()["phase"] as? String == "failed" }
    XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(started), 7.8)
    XCTAssertEqual(local.state()["errorCode"] as? String, "render_timeout")
    release.signal(); released = true
    let oldWorkSettles = expectation(description: "late old identity settles")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { oldWorkSettles.fulfill() }
    wait(for: [oldWorkSettles], timeout: 2)
    XCTAssertEqual(local.state()["errorCode"] as? String, "render_timeout"); XCTAssertNil(local.webView)
    control(messenger, 908, "reload")
    until { local.state()["phase"] as? String == "ready" }
    print("STMINI_LOCAL_WK_WATCHDOG_RESULT {\"actualEightSecondTimer\":true,\"testControlledIdentityQueue\":true,\"lateIgnored\":true,\"reloadRecovered\":true}")
  }
  func testRealPagePermissionDenialAndControlledRendererLossReload() throws {
    let home = try fixture(); defer { try? FileManager.default.removeItem(at: home) }
    let messenger = RendererMessenger()
    let local = LocalMiniView(frame: UIScreen.main.bounds, messenger: messenger, viewId: 908,
      arguments: ["miniId": "renderer_fixture", "version": "1.0"], allowed: { true }, home: home)
    let window = UIWindow(frame: UIScreen.main.bounds); let controller = UIViewController()
    window.rootViewController = controller; controller.view.addSubview(local.view()); window.makeKeyAndVisible()
    defer { local.close(); window.isHidden = true }
    until { local.state()["phase"] as? String == "ready" && local.webView?.isLoading == false }
    let view = try XCTUnwrap(local.webView)
    _ = js(view, "window.__permissionProbe='pending'; if(!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia){window.__permissionProbe='unavailable'}else{navigator.mediaDevices.getUserMedia({video:true,audio:true}).then(function(stream){stream.getTracks().forEach(function(track){track.stop()});window.__permissionProbe='granted'},function(){window.__permissionProbe='rejected'})}; true")
    waitJS(view, "window.__permissionProbe!=='pending'")
    let permission = js(view, "window.__permissionProbe") as? String
    XCTAssertTrue(["rejected", "unavailable"].contains(permission ?? ""))
    // Invoke the real production delegate deterministically; do not claim an
    // actual WebKit process crash or OS kill.
    local.webViewWebContentProcessDidTerminate(view)
    XCTAssertEqual(local.state()["errorCode"] as? String, "renderer_terminated"); XCTAssertNil(local.webView)
    control(messenger, 908, "reload")
    until { local.state()["phase"] as? String == "ready" }
    let result: [String: Any] = ["mediaPermission": permission ?? "unknown", "controlledProductionLossDelegate": true, "reloadRecovered": true]
    let encoded = String(data: try JSONSerialization.data(withJSONObject: result), encoding: .utf8)!
    print("STMINI_LOCAL_WK_PERMISSION_LOSS_RESULT \(encoded)")
  }
  func testReadyIdentityMutationFailsButMissingImageDoesNot() throws {
    for field in ["version", "entry"] {
      let home = try fixture(); defer { try? FileManager.default.removeItem(at: home) }
      let package = home.appendingPathComponent("Documents/STMini/renderer_fixture")
      try RendererFixture.files["pixel.png"]!.write(to: package.appendingPathComponent("identity-probe.png"))
      let messenger = RendererMessenger()
      let local = LocalMiniView(frame: UIScreen.main.bounds, messenger: messenger, viewId: 908,
        arguments: ["miniId": "renderer_fixture", "version": "1.0"], allowed: { true }, home: home)
      let window = UIWindow(frame: UIScreen.main.bounds); let controller = UIViewController()
      window.rootViewController = controller; controller.view.addSubview(local.view()); window.makeKeyAndVisible()
      defer { local.close(); window.isHidden = true }
      until { local.state()["phase"] as? String == "ready" && local.webView?.isLoading == false }
      let view = try XCTUnwrap(local.webView)
      _ = js(view, "window.__missingDone=false; var missing=new Image(); missing.onerror=function(){window.__missingDone=true}; missing.src='missing.png'; document.body.appendChild(missing); true")
      waitJS(view, "window.__missingDone===true")
      XCTAssertEqual(local.state()["phase"] as? String, "ready")
      for name in ["mini-manifest.json", ".st-mini-package.json"] {
        let url = package.appendingPathComponent(name)
        var wire = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: String]
        wire[field] = field == "version" ? "2.0" : "second.html"
        try JSONSerialization.data(withJSONObject: wire).write(to: url)
      }
      _ = js(view, "var changed=new Image(); changed.src='identity-probe.png'; document.body.appendChild(changed); true")
      until { local.state()["phase"] as? String == "failed" }
      XCTAssertEqual(local.state()["errorCode"] as? String, "package_unavailable")
      control(messenger, 908, "reload")
      until { local.state()["phase"] as? String == "failed" }
      XCTAssertEqual(local.state()["errorCode"] as? String, "package_unavailable")
      local.close()
      let reopened = LocalMiniView(frame: UIScreen.main.bounds, messenger: messenger, viewId: 909,
        arguments: ["miniId": "renderer_fixture", "version": field == "version" ? "2.0" : "1.0"], allowed: { true }, home: home)
      controller.view.addSubview(reopened.view()); defer { reopened.close() }
      until { reopened.state()["phase"] as? String == "ready" && reopened.webView?.isLoading == false }
      XCTAssertEqual(reopened.webView?.url?.lastPathComponent, field == "entry" ? "second.html" : "index.html")
    }
  }
  func testRealWKDOMAssetsNavigationReloadAndClose() throws {
    let home = try fixture(); defer { try? FileManager.default.removeItem(at: home) }
    let messenger = RendererMessenger()
    let local = LocalMiniView(frame: UIScreen.main.bounds, messenger: messenger, viewId: 908,
      arguments: ["miniId": "renderer_fixture", "version": "1.0"], allowed: { true }, home: home)
    let window = UIWindow(frame: UIScreen.main.bounds); let controller = UIViewController()
    window.rootViewController = controller; controller.view.addSubview(local.view()); window.makeKeyAndVisible()
    defer { local.close(); window.isHidden = true }
    until { local.state()["phase"] as? String == "ready" }
    let view = try XCTUnwrap(local.webView)
    until { !view.isLoading }
    let payload = js(view, "JSON.stringify({ran:window.__rendererProbe&&window.__rendererProbe.ran,text:document.getElementById('content').textContent,color:getComputedStyle(document.getElementById('content')).color,width:document.getElementById('pixel').naturalWidth,bridge:typeof window.CMSScriptMessageChannel})") as? String
    let data = try XCTUnwrap(payload?.data(using: .utf8))
    let result = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    XCTAssertEqual(result["ran"] as? Bool, true)
    XCTAssertEqual(result["text"] as? String, "Verified local Mini DOM from probe.js")
    XCTAssertEqual(result["color"] as? String, "rgb(13, 47, 83)")
    XCTAssertEqual(result["width"] as? Int, 1)
    XCTAssertEqual(result["bridge"] as? String, "undefined")
    _ = js(view, "document.getElementById('action').click(); window.__rendererProbe.clicked")
    XCTAssertEqual(js(view, "document.getElementById('result').textContent") as? String, "Local interaction completed")
    let snapshot = expectation(description: "real WK rendered snapshot")
    view.takeSnapshot(with: nil) { image, error in
      XCTAssertNil(error); if let image { let attachment = XCTAttachment(image: image); attachment.name = "real-local-mini-dom"; attachment.lifetime = .keepAlways; self.add(attachment) }
      snapshot.fulfill()
    }
    wait(for: [snapshot], timeout: 5)
    _ = js(view, "document.getElementById('second').click()")
    until { local.state()["phase"] as? String == "ready" && local.webView?.url?.lastPathComponent == "second.html" && local.webView?.isLoading == false }
    XCTAssertEqual(js(try XCTUnwrap(local.webView), "document.getElementById('second-content').textContent") as? String, "Verified second local document")
    XCTAssertEqual(local.state()["canGoBack"] as? Bool, true)
    XCTAssertEqual(control(messenger, 908, "goBack") as? Bool, true)
    until { local.state()["phase"] as? String == "ready" && local.webView?.url?.lastPathComponent == "index.html" && local.webView?.isLoading == false }
    let restored = try XCTUnwrap(local.webView)
    XCTAssertEqual(js(restored, "window.__rendererProbe.ran") as? Bool, true)
    _ = js(restored, "location.hash='fixture-anchor'; true")
    let anchorSettles = expectation(description: "anchor has no launch timeout")
    DispatchQueue.main.asyncAfter(deadline: .now() + 8.3) { anchorSettles.fulfill() }; wait(for: [anchorSettles], timeout: 10)
    XCTAssertEqual(local.state()["phase"] as? String, "ready")
    control(messenger, 908, "reload")
    until { local.state()["phase"] as? String == "ready" && local.webView?.isLoading == false }
    XCTAssertEqual(js(try XCTUnwrap(local.webView), "window.__rendererProbe.ran") as? Bool, true)
    for _ in 0..<12 { control(messenger, 908, "reload") }
    until { local.state()["phase"] as? String == "ready" && local.webView?.isLoading == false }
    control(messenger, 908, "close"); control(messenger, 908, "close")
    XCTAssertEqual(local.state()["phase"] as? String, "closed"); XCTAssertNil(local.webView)
    print("STMINI_LOCAL_WK_DOM_RESULT {\"passed\":\(testRun?.failureCount == 0),\"localJS\":true,\"css\":true,\"image\":true,\"interaction\":true,\"secondPageBack\":true,\"closed\":true}")
  }
}

private enum RendererFixture {
  static let files: [String: Data] = [
    ".st-mini-package.json": Data(base64Encoded: "eyJtaW5pSWQiOiAicmVuZGVyZXJfZml4dHVyZSIsICJtaW5pTmFtZSI6ICJMb2NhbCByZW5kZXJlciBmaXh0dXJlIiwgInZlcnNpb24iOiAiMS4wIiwgImVudHJ5IjogImluZGV4Lmh0bWwiLCAiaWNvbiI6ICJwaXhlbC5wbmciLCAiY2hhbm5lbCI6ICJmaXh0dXJlIn0K")!,
    "index.html": Data(base64Encoded: "PCFkb2N0eXBlIGh0bWw+PGh0bWw+PGhlYWQ+PG1ldGEgY2hhcnNldD0idXRmLTgiPjx0aXRsZT5Mb2NhbCBNaW5pIGZpeHR1cmU8L3RpdGxlPjxsaW5rIHJlbD0ic3R5bGVzaGVldCIgaHJlZj0ic3R5bGUuY3NzIj48c2NyaXB0IGRlZmVyIHNyYz0icHJvYmUuanMiPjwvc2NyaXB0PjwvaGVhZD48Ym9keT48aDEgaWQ9ImNvbnRlbnQiPldhaXRpbmcgZm9yIGxvY2FsIHNjcmlwdDwvaDE+PGltZyBpZD0icGl4ZWwiIHNyYz0icGl4ZWwucG5nIiBhbHQ9IkxvY2FsIHBpeGVsIj48YnV0dG9uIGlkPSJhY3Rpb24iPlRhcCBmaXh0dXJlPC9idXR0b24+PGEgaWQ9InNlY29uZCIgaHJlZj0ic2Vjb25kLmh0bWwiPlNlY29uZCBsb2NhbCBwYWdlPC9hPjxkaXYgaWQ9InJlc3VsdCI+PC9kaXY+PC9ib2R5PjwvaHRtbD4K")!,
    "mini-manifest.json": Data(base64Encoded: "eyJtaW5pSWQiOiAicmVuZGVyZXJfZml4dHVyZSIsICJtaW5pTmFtZSI6ICJMb2NhbCByZW5kZXJlciBmaXh0dXJlIiwgInZlcnNpb24iOiAiMS4wIiwgImVudHJ5IjogImluZGV4Lmh0bWwiLCAiaWNvbiI6ICJwaXhlbC5wbmciLCAiY2hhbm5lbCI6ICJmaXh0dXJlIn0K")!,
    "pixel.png": Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jr1sAAAAASUVORK5CYII=")!,
    "probe.js": Data(base64Encoded: "J3VzZSBzdHJpY3QnOwp3aW5kb3cuX19yZW5kZXJlclByb2JlID0geyByYW46IHRydWUsIGNsaWNrZWQ6IGZhbHNlLCByZW1vdGVDb2RlRXhlY3V0ZWQ6IGZhbHNlLCBhdHRlbXB0czoge30gfTsKZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ2NvbnRlbnQnKS50ZXh0Q29udGVudCA9ICdWZXJpZmllZCBsb2NhbCBNaW5pIERPTSBmcm9tIHByb2JlLmpzJzsKZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ2FjdGlvbicpLmFkZEV2ZW50TGlzdGVuZXIoJ2NsaWNrJywgZnVuY3Rpb24gKCkgewogIHdpbmRvdy5fX3JlbmRlcmVyUHJvYmUuY2xpY2tlZCA9IHRydWU7CiAgZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ3Jlc3VsdCcpLnRleHRDb250ZW50ID0gJ0xvY2FsIGludGVyYWN0aW9uIGNvbXBsZXRlZCc7Cn0pOwp3aW5kb3cucnVuTmV0d29ya1Byb2JlID0gYXN5bmMgZnVuY3Rpb24gKHBvcnQpIHsKICBjb25zdCBwcm9iZSA9IHdpbmRvdy5fX3JlbmRlcmVyUHJvYmU7CiAgY29uc3QgYmFzZSA9ICdodHRwOi8vMTI3LjAuMC4xOicgKyBwb3J0ICsgJy8nOwogIGNvbnN0IGpvYnMgPSBbXTsKICBmdW5jdGlvbiByZXNvdXJjZShuYW1lLCBlbGVtZW50LCB1cmwpIHsKICAgIGpvYnMucHVzaChuZXcgUHJvbWlzZShmdW5jdGlvbiAocmVzb2x2ZSkgewogICAgICBsZXQgZW5kZWQgPSBmYWxzZTsKICAgICAgZnVuY3Rpb24gZW5kKHZhbHVlKSB7IGlmIChlbmRlZCkgcmV0dXJuOyBlbmRlZCA9IHRydWU7IHByb2JlLmF0dGVtcHRzW25hbWVdID0gdmFsdWU7IGVsZW1lbnQucmVtb3ZlKCk7IHJlc29sdmUoKTsgfQogICAgICBlbGVtZW50Lm9ubG9hZCA9IGZ1bmN0aW9uICgpIHsgZW5kKCdsb2FkJyk7IH07CiAgICAgIGVsZW1lbnQub25lcnJvciA9IGZ1bmN0aW9uICgpIHsgZW5kKCdlcnJvcicpOyB9OwogICAgICBwcm9iZS5hdHRlbXB0c1tuYW1lXSA9ICdhdHRlbXB0ZWQnOwogICAgICBlbGVtZW50LnNyYyA9IHVybDsKICAgICAgZG9jdW1lbnQuYm9keS5hcHBlbmRDaGlsZChlbGVtZW50KTsKICAgICAgc2V0VGltZW91dChmdW5jdGlvbiAoKSB7IGVuZCgndGltZW91dCcpOyB9LCAxMjAwKTsKICAgIH0pKTsKICB9CiAgcmVzb3VyY2UoJ2ltYWdlJywgbmV3IEltYWdlKCksIGJhc2UgKyAnaW1hZ2UnKTsKICByZXNvdXJjZSgncmVtb3RlU2NyaXB0JywgZG9jdW1lbnQuY3JlYXRlRWxlbWVudCgnc2NyaXB0JyksIGJhc2UgKyAnc2NyaXB0Jyk7CiAgcmVzb3VyY2UoJ2lmcmFtZScsIGRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoJ2lmcmFtZScpLCBiYXNlICsgJ2ZyYW1lJyk7CiAgcmVzb3VyY2UoJ2ZpbGUnLCBuZXcgSW1hZ2UoKSwgJ2ZpbGU6Ly8vZXRjL3Bhc3N3ZCcpOwogIHJlc291cmNlKCdjb250ZW50JywgbmV3IEltYWdlKCksICdjb250ZW50Oi8vc3RtaW5pLmludmFsaWQvcHJpdmF0ZScpOwogIHJlc291cmNlKCdkYXRhU2NyaXB0JywgZG9jdW1lbnQuY3JlYXRlRWxlbWVudCgnc2NyaXB0JyksICdkYXRhOnRleHQvamF2YXNjcmlwdCx3aW5kb3cuX19yZW5kZXJlclByb2JlLnJlbW90ZUNvZGVFeGVjdXRlZD10cnVlJyk7CiAgY29uc3QgYmxvYiA9IFVSTC5jcmVhdGVPYmplY3RVUkwobmV3IEJsb2IoWyd3aW5kb3cuX19yZW5kZXJlclByb2JlLnJlbW90ZUNvZGVFeGVjdXRlZD10cnVlJ10sIHsgdHlwZTogJ2FwcGxpY2F0aW9uL2phdmFzY3JpcHQnIH0pKTsKICByZXNvdXJjZSgnYmxvYlNjcmlwdCcsIGRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoJ3NjcmlwdCcpLCBibG9iKTsKICBwcm9iZS5hdHRlbXB0cy5mZXRjaCA9ICdhdHRlbXB0ZWQnOwogIGpvYnMucHVzaChmZXRjaChiYXNlICsgJ2ZldGNoJykudGhlbihmdW5jdGlvbiAoKSB7IHByb2JlLmF0dGVtcHRzLmZldGNoID0gJ3Jlc29sdmVkJzsgfSwgZnVuY3Rpb24gKCkgeyBwcm9iZS5hdHRlbXB0cy5mZXRjaCA9ICdyZWplY3RlZCc7IH0pKTsKICBqb2JzLnB1c2gobmV3IFByb21pc2UoZnVuY3Rpb24gKHJlc29sdmUpIHsKICAgIGNvbnN0IHhociA9IG5ldyBYTUxIdHRwUmVxdWVzdCgpOyBwcm9iZS5hdHRlbXB0cy54aHIgPSAnYXR0ZW1wdGVkJzsKICAgIHhoci5vbmxvYWQgPSBmdW5jdGlvbiAoKSB7IHByb2JlLmF0dGVtcHRzLnhociA9ICdsb2FkJzsgcmVzb2x2ZSgpOyB9OwogICAgeGhyLm9uZXJyb3IgPSBmdW5jdGlvbiAoKSB7IHByb2JlLmF0dGVtcHRzLnhociA9ICdlcnJvcic7IHJlc29sdmUoKTsgfTsKICAgIHhoci5vbnRpbWVvdXQgPSBmdW5jdGlvbiAoKSB7IHByb2JlLmF0dGVtcHRzLnhociA9ICd0aW1lb3V0JzsgcmVzb2x2ZSgpOyB9OwogICAgdHJ5IHsgeGhyLm9wZW4oJ0dFVCcsIGJhc2UgKyAneGhyJyk7IHhoci50aW1lb3V0ID0gMTIwMDsgeGhyLnNlbmQoKTsgfQogICAgY2F0Y2ggKF8pIHsgcHJvYmUuYXR0ZW1wdHMueGhyID0gJ3JlamVjdGVkJzsgcmVzb2x2ZSgpOyB9CiAgfSkpOwogIGpvYnMucHVzaChuZXcgUHJvbWlzZShmdW5jdGlvbiAocmVzb2x2ZSkgewogICAgcHJvYmUuYXR0ZW1wdHMud2Vic29ja2V0ID0gJ2F0dGVtcHRlZCc7IGxldCBzb2NrZXQ7CiAgICB0cnkgewogICAgICBzb2NrZXQgPSBuZXcgV2ViU29ja2V0KCd3czovLzEyNy4wLjAuMTonICsgcG9ydCArICcvc29ja2V0Jyk7CiAgICAgIHNvY2tldC5vbmVycm9yID0gZnVuY3Rpb24gKCkgeyBwcm9iZS5hdHRlbXB0cy53ZWJzb2NrZXQgPSAnZXJyb3InOyByZXNvbHZlKCk7IH07CiAgICAgIHNvY2tldC5vbm9wZW4gPSBmdW5jdGlvbiAoKSB7IHByb2JlLmF0dGVtcHRzLndlYnNvY2tldCA9ICdvcGVuJzsgc29ja2V0LmNsb3NlKCk7IHJlc29sdmUoKTsgfTsKICAgICAgc2V0VGltZW91dChmdW5jdGlvbiAoKSB7IGlmIChwcm9iZS5hdHRlbXB0cy53ZWJzb2NrZXQgPT09ICdhdHRlbXB0ZWQnKSB7IHByb2JlLmF0dGVtcHRzLndlYnNvY2tldCA9ICd0aW1lb3V0Jzsgc29ja2V0LmNsb3NlKCk7IHJlc29sdmUoKTsgfSB9LCAxMjAwKTsKICAgIH0gY2F0Y2ggKF8pIHsgcHJvYmUuYXR0ZW1wdHMud2Vic29ja2V0ID0gJ3JlamVjdGVkJzsgcmVzb2x2ZSgpOyB9CiAgfSkpOwogIHByb2JlLmF0dGVtcHRzLnBvcHVwID0gd2luZG93Lm9wZW4oYmFzZSArICdwb3B1cCcsICdfYmxhbmsnKSA9PT0gbnVsbCA/ICdyZWplY3RlZCcgOiAnb3BlbmVkJzsKICBjb25zdCBmb3JtID0gZG9jdW1lbnQuY3JlYXRlRWxlbWVudCgnZm9ybScpOyBmb3JtLmFjdGlvbiA9IGJhc2UgKyAnZm9ybSc7IGZvcm0ubWV0aG9kID0gJ1BPU1QnOwogIHByb2JlLmF0dGVtcHRzLmZvcm0gPSAnYXR0ZW1wdGVkJzsgZG9jdW1lbnQuYm9keS5hcHBlbmRDaGlsZChmb3JtKTsgZm9ybS5zdWJtaXQoKTsgZm9ybS5yZW1vdmUoKTsKICBqb2JzLnB1c2gobmV3IFByb21pc2UoZnVuY3Rpb24gKHJlc29sdmUpIHsgc2V0VGltZW91dChmdW5jdGlvbiAoKSB7IHByb2JlLmF0dGVtcHRzLmZvcm0gPSAnc2V0dGxlZF93aXRob3V0X25hdmlnYXRpb24nOyByZXNvbHZlKCk7IH0sIDEyMDApOyB9KSk7CiAgYXdhaXQgUHJvbWlzZS5hbGwoam9icyk7IFVSTC5yZXZva2VPYmplY3RVUkwoYmxvYik7IHByb2JlLmRvbmUgPSB0cnVlOwogIHJldHVybiBwcm9iZTsKfTsKCi8vIEVuYWJsZWQgb25seSBpbiB0aGUgZXh0ZXJuYWxseSBpbnN0YWxsZWQgRW5naW5lIGZpeHR1cmUsIG5ldmVyIHByb2R1Y3QgYXNzZXRzLgpjb25zdCBlbmdpbmVBdXRvTmF2aWdhdGlvbiA9IGZhbHNlOwppZiAoZW5naW5lQXV0b05hdmlnYXRpb24pIHsgc2V0VGltZW91dChmdW5jdGlvbiAoKSB7IGRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdzZWNvbmQnKS5jbGljaygpOyB9LCA1MDAwKTsgfQo=")!,
    "second.html": Data(base64Encoded: "PCFkb2N0eXBlIGh0bWw+PGh0bWw+PGhlYWQ+PG1ldGEgY2hhcnNldD0idXRmLTgiPjx0aXRsZT5TZWNvbmQgbG9jYWwgTWluaTwvdGl0bGU+PGxpbmsgcmVsPSJzdHlsZXNoZWV0IiBocmVmPSJzdHlsZS5jc3MiPjwvaGVhZD48Ym9keT48aDEgaWQ9InNlY29uZC1jb250ZW50Ij5WZXJpZmllZCBzZWNvbmQgbG9jYWwgZG9jdW1lbnQ8L2gxPjxhIGhyZWY9ImluZGV4Lmh0bWwiPkZpcnN0IGxvY2FsIHBhZ2U8L2E+PC9ib2R5PjwvaHRtbD4K")!,
    "style.css": Data(base64Encoded: "Ym9keSB7IGJhY2tncm91bmQ6IHJnYigyNDUsIDI0OCwgMjUyKTsgY29sb3I6IHJnYigxMywgNDcsIDgzKTsgZm9udC1mYW1pbHk6IHNhbnMtc2VyaWY7IH0gI2NvbnRlbnQgeyBjb2xvcjogcmdiKDEzLCA0NywgODMpOyB9IGJ1dHRvbiB7IG1pbi1oZWlnaHQ6IDQ4cHg7IH0K")!,
  ]
}

private final class RendererLoopback {
  private let listener: NWListener
  private let queue = DispatchQueue(label: "stmini.test.loopback.listener")
  private let lock = NSLock()
  private var connections = 0
  private var bound: UInt16?
  var count: Int { lock.lock(); defer { lock.unlock() }; return connections }
  var port: UInt16? { lock.lock(); defer { lock.unlock() }; return bound }
  init() throws {
    listener = try NWListener(using: .tcp, on: .any)
    listener.stateUpdateHandler = { [weak self] state in
      guard let self else { return }
      if case .ready = state { self.lock.lock(); self.bound = self.listener.port?.rawValue; self.lock.unlock() }
    }
    listener.newConnectionHandler = { [weak self] connection in
      guard let self else { connection.cancel(); return }
      self.lock.lock(); self.connections += 1; self.lock.unlock()
      connection.start(queue: self.queue)
      let body = "window.__rendererProbe.remoteCodeExecuted=true"
      let response = "HTTP/1.1 200 OK\r\nContent-Type: application/javascript\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n" + body
      connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
    }
    listener.start(queue: queue)
  }
  func reset() { lock.lock(); connections = 0; lock.unlock() }
  func stop() { listener.cancel() }
}

private final class RendererSchemeTask: NSObject, WKURLSchemeTask {
  let request: URLRequest
  var callbacks = 0, finished = 0, failed = 0, bytes = 0
  init(_ url: URL) { request = URLRequest(url: url) }
  func didReceive(_ response: URLResponse) { callbacks += 1 }
  func didReceive(_ data: Data) { callbacks += 1; bytes += data.count }
  func didFinish() { callbacks += 1; finished += 1 }
  func didFailWithError(_ error: Error) { callbacks += 1; failed += 1 }
}


/// Native SDK safety checks use synthetic data in the runner's fresh simulator.
final class FullRuntimeBridgeSafetyTests: XCTestCase {
  private func session(_ method: String, _ params: [String: Any], scope: String?) -> [String: Any] {
    STOnlineWebSessionBridge.handle(method: method, params: params,
      bridgeContext: ["packageName": "com.almanac.lite"], deviceType: "ios",
      darkMode: false, languageCode: "en-US", storageScope: scope) ?? [:]
  }

  func testSDKStorageCannotReadWriteOrRemoveHostSchema() throws {
    let key = "flutter.almanac_state_v1"
    let syntheticHostValue = "synthetic-host-schema-sentinel"
    UserDefaults.standard.set(syntheticHostValue, forKey: key)
    defer { UserDefaults.standard.removeObject(forKey: key) }
    let a = "mini:full_fixture|local", b = "mini:other_fixture|local"
    let origin = "web:https://fixture.invalid"
    defer {
      for scope in [a, b, origin] { STMiniScopedStorage.defaults(for: scope)?.removeObject(forKey: key) }
    }
    XCTAssertEqual(session("getStorage", ["key": key], scope: a)["code"] as? String, "0")
    XCTAssertEqual(session("setStorage", ["key": key, "data": "{\"synthetic\":true}"], scope: a)["code"] as? String, "1")
    XCTAssertEqual((session("getStorage", ["key": key], scope: a)["data"] as? [String: Any])?["synthetic"] as? Bool, true)
    for scope in [b, origin] {
      XCTAssertEqual(session("getStorage", ["key": key], scope: scope)["code"] as? String, "0")
    }
    XCTAssertEqual(session("getStorage", ["key": key, "scope": a], scope: nil)["code"] as? String, "0")
    XCTAssertEqual(session("removeStorage", ["key": key], scope: a)["code"] as? String, "1")
    XCTAssertEqual(UserDefaults.standard.string(forKey: key), syntheticHostValue)
    print("STMINI_FULL_NATIVE_STORAGE_RESULT {\"passed\":true,\"scope\":\"synthetic_only_sdk_domains_host_schema_mini_origin\"}")
  }

  func testLongVerifiedSubjectUsesBoundedCollisionResistantDomain() throws {
    let subject = "web:https://" + String(repeating: "a", count: 200) + ".invalid"
    let storage = try XCTUnwrap(STMiniScopedStorage.defaults(for: subject))
    storage.set("synthetic", forKey: "probe")
    defer { storage.removeObject(forKey: "probe") }
    XCTAssertEqual(storage.string(forKey: "probe"), "synthetic")
    XCTAssertNil(STMiniScopedStorage.defaults(for: subject + "b")?.string(forKey: "probe"))
  }

  func testMalformedBridgeModelAndCapturedDocumentEpochAreSafe() {
    let malformed = STWebApiModel(dict: ["method": 123, "params": ["methodId": 456]])
    XCTAssertEqual(malformed.method, "")
    XCTAssertEqual(malformed.methodId, "")
    let web = STMiniWebView(frame: .zero, bindCrl: nil)
    defer { web.cleanup() }
    var request = STWebApiModel(dict: ["method": "synthetic", "params": ["methodId": "captured"]])
    request.webview = web
    let original = request.documentGeneration
    web.invalidateBridgeDocumentSession()
    XCTAssertNotEqual(request.documentGeneration, web.bridgeDocumentGeneration)
    XCTAssertEqual(request.documentGeneration, original)
    STWebApiManager.dealWithApiMessage(["method": "setStorage", "params": ["methodId": 1]], webView: web)
    XCTAssertFalse(STOnlineWebCore.allowsBridgeMessage(documentURL: URL(string: "https://fixture.invalid"), isMainFrame: false))
    XCTAssertFalse(STOnlineWebCore.matchesCurrentDocumentOrigin(messageDocumentURL: URL(string: "https://old.invalid"), currentDocumentURL: URL(string: "https://new.invalid")))
  }

  func testCompleteRuntimeRevalidatesModifiedPackageRatherThanPositiveCache() throws {
    let manager = FileManager.default
    let root = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents/STMini", isDirectory: true)
    let folder = root.appendingPathComponent("full_policy_fixture", isDirectory: true)
    XCTAssertFalse(manager.fileExists(atPath: folder.path))
    try manager.createDirectory(at: folder, withIntermediateDirectories: true)
    defer {
      try? manager.removeItem(at: folder)
      if (try? manager.contentsOfDirectory(atPath: root.path).isEmpty) == true { try? manager.removeItem(at: root) }
    }
    for (name, bytes) in RendererFixture.files {
      let output: Data
      if name == "mini-manifest.json" || name == ".st-mini-package.json" {
        output = Data(String(decoding: bytes, as: UTF8.self).replacingOccurrences(of: "renderer_fixture", with: "full_policy_fixture").utf8)
      } else { output = bytes }
      try output.write(to: folder.appendingPathComponent(name))
    }
    XCTAssertTrue(STWebResourceManager.isInstalledMiniPackageUsable(name: "full_policy_fixture"))
    for raw in ["stmini://user@full_policy_fixture.stmini.local/index.html", "stmini://full_policy_fixture.stmini.local:443/index.html", "stmini://full_policy_fixture.stmini.local//index.html", "stmini://full_policy_fixture.stmini.local/%2findex.html"] {
      XCTAssertNil(STWebResourceManager.installedMiniPackageResourceURL(forInternalURL: try XCTUnwrap(URL(string: raw))))
    }
    XCTAssertNotNil(STWebResourceManager.installedMiniPackageResourceURL(forInternalURL: try XCTUnwrap(URL(string: "stmini://full_policy_fixture.stmini.local/index.html?synthetic=1"))))
    let manifest = folder.appendingPathComponent("mini-manifest.json")
    let original = try Data(contentsOf: manifest)
    var json = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
    json["version"] = "2.0"
    try JSONSerialization.data(withJSONObject: json).write(to: manifest)
    XCTAssertFalse(STWebResourceManager.isInstalledMiniPackageUsable(name: "full_policy_fixture"))
    try original.write(to: manifest)
    XCTAssertTrue(STWebResourceManager.isInstalledMiniPackageUsable(name: "full_policy_fixture"))
    let alias = folder.appendingPathComponent("alias.html")
    try manager.createSymbolicLink(at: alias, withDestinationURL: folder.appendingPathComponent("index.html"))
    XCTAssertNil(STWebResourceManager.installedMiniPackageLocalPageURL(name: "full_policy_fixture", path: "alias.html"))
  }
}


/// These are real ZIPFoundation installs of synthetic, test-only archives.
/// They prove installer/rollback logic, not HTTPS downloading or physical media.
final class FullRuntimeInstallerTests: XCTestCase {
  private func install(_ fixture: String, minimum: String? = nil, force: Bool = false) throws -> STDirectMiniPackageInstallOutcome {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("full-install-\(UUID().uuidString).zip")
    try XCTUnwrap(Data(base64Encoded: FullInstallArchive.bytes[fixture]!)).write(to: file)
    let done = expectation(description: "real native archive install")
    var outcome: Result<STDirectMiniPackageInstallOutcome, Error>?
    STWebResourceManager.installDirectMiniPackage(archivePath: file.path, name: "full_install_fixture",
      minimumVersion: minimum, requiresNewerVersion: force) { result in outcome = result; done.fulfill() }
    wait(for: [done], timeout: 12)
    XCTAssertFalse(FileManager.default.fileExists(atPath: file.path), "Archive inputs are removed at every terminal outcome.")
    return try XCTUnwrap(outcome).get()
  }

  func testLiveFullWKCannotReadAReplacementInstalledIdentity() throws {
    let manager = FileManager.default
    let root = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents/STMini", isDirectory: true)
    let target = root.appendingPathComponent("full_install_fixture", isDirectory: true)
    XCTAssertFalse(manager.fileExists(atPath: target.path))
    defer {
      try? manager.removeItem(at: target)
      if (try? manager.contentsOfDirectory(atPath: root.path).isEmpty) == true { try? manager.removeItem(at: root) }
    }
    _ = try install("v1")
    let config = STWebConfig(webMode: .online)
    let controller = STWebMiniprogramCrl(name: "full_install_fixture", config: config, isChild: false)
    let web = STMiniWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), bindCrl: controller)
    controller.webView = web
    web.configureBridgePolicy(.localMini)
    defer { web.stopLoading(); web.cleanup() }
    let url = try XCTUnwrap(STWebResourceManager.installedMiniPackageRootURL(name: "full_install_fixture", entry: "index.html"))
    _ = web.load(URLRequest(url: url))
    let deadline = Date().addingTimeInterval(10)
    while web.verifiedBoundResource(url) == nil && Date() < deadline {
      RunLoop.current.run(until: Date().addingTimeInterval(0.02))
    }
    XCTAssertNotNil(web.verifiedBoundResource(url), "The real WK policy must bind the original installed identity.")
    web.stopLoading()
    _ = try install("v2")
    XCTAssertTrue(STWebResourceManager.isInstalledMiniPackageUsable(name: "full_install_fixture"))
    XCTAssertNil(web.verifiedBoundResource(url), "The old WK must not silently consume the new version.")
    print("STMINI_FULL_BOUND_IDENTITY_RESULT {\"passed\":true,\"originalBound\":true,\"replacementRejectedByOldWK\":true}")
  }

  private func waitUntil(_ condition: () -> Bool, timeout: TimeInterval = 10) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }
    return condition()
  }

  func testMinOnlyActualColdOpenAndRetainedReuseRespectRuntimeFloor() throws {
    let manager = FileManager.default
    let root = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents/STMini", isDirectory: true)
    let target = root.appendingPathComponent("full_install_fixture", isDirectory: true)
    XCTAssertFalse(manager.fileExists(atPath: target.path))
    defer {
      try? manager.removeItem(at: target)
      if (try? manager.contentsOfDirectory(atPath: root.path).isEmpty) == true { try? manager.removeItem(at: root) }
    }
    // min-only still supplies the real installer's minimumVersion; a missing
    // currentVersion must never erase that requirement.
    let floor = STWebResourceManager.requiredMiniDownloadVersion(currentVersion: nil, minSupportVersion: "2.0")
    XCTAssertThrowsError(try install("v1", minimum: floor))
    XCTAssertNil(STWebResourceManager.installedMiniPackageVersion(name: "full_install_fixture"))
    _ = try install("v1")
    XCTAssertThrowsError(try install("v1", minimum: floor))
    XCTAssertEqual(STWebResourceManager.installedMiniPackageVersion(name: "full_install_fixture"), "1.0")
    XCTAssertEqual(STWebResourceManager.requiredMiniDownloadVersion(currentVersion: "3.0", minSupportVersion: "2.0"), "3.0")
    XCTAssertEqual(STWebResourceManager.requiredMiniDownloadVersion(currentVersion: "1.0", minSupportVersion: "2.0"), "2.0")

    var controllers: [STWebMiniprogramCrl] = []
    func cold(_ params: [String: String]) -> (STWebMiniprogramCrl, STWebNavigationController) {
      let config = STWebConfig(webMode: .online, params: params)
      let controller = STWebMiniprogramCrl(name: "full_install_fixture", config: config, isChild: false)
      let navigation = STWebNavigationController(rootViewController: controller)
      controllers.append(controller)
      controller.loadViewIfNeeded()
      controller.viewDidAppear(false) // actual asynchronous production cold-load path
      return (controller, navigation)
    }
    defer { controllers.forEach { $0.webView.stopLoading(); $0.webView.cleanup() } }
    let below = cold(["minSupportVersion": "2.0"])
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    XCTAssertNil(below.0.webView.url)
    XCTAssertFalse(below.0.isKeepAliveRuntimeUsable)
    let currentOnly = cold(["currentVersion": "2.0"])
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    XCTAssertNil(currentOnly.0.webView.url)

    let compatible = cold(["currentVersion": "2.0", "minSupportVersion": "1.0"])
    XCTAssertTrue(waitUntil { compatible.0.isKeepAliveRuntimeUsable })
    XCTAssertNotNil(compatible.0.webView.url)
    STWebMiniProgramKeepAliveStore.shared.cache(compatible.0, navigationController: compatible.1)
    XCTAssertNil(STWebMiniProgramKeepAliveStore.shared.take(miniId: "full_install_fixture",
      config: STWebConfig(webMode: .online, params: ["minSupportVersion": "2.0"])))

    let bare = cold([:])
    XCTAssertTrue(waitUntil { bare.0.isKeepAliveRuntimeUsable })
    STWebMiniProgramKeepAliveStore.shared.cache(bare.0, navigationController: bare.1)
    let weakConfig = STWebConfig(webMode: .online, params: ["currentVersion": "2.0", "minSupportVersion": "1.0"])
    XCTAssertTrue(STWebMiniProgramKeepAliveStore.shared.take(miniId: "full_install_fixture", config: weakConfig) === bare.1)
    STWebMiniProgramKeepAliveStore.shared.cache(bare.0, navigationController: bare.1)
    XCTAssertTrue(STWebMiniProgramKeepAliveStore.shared.take(miniId: "full_install_fixture",
      config: STWebConfig(webMode: .online, params: ["minSupportVersion": "1.0"])) === bare.1)

    _ = try install("v2", minimum: floor)
    let upgraded = cold(["minSupportVersion": "2.0"])
    XCTAssertTrue(waitUntil { upgraded.0.isKeepAliveRuntimeUsable })
    XCTAssertEqual(upgraded.0.loadedMiniPackageVersion, "2.0")
    print("STMINI_FULL_MIN_ONLY_RESULT {\"passed\":true,\"realZIP\":true,\"coldOpen\":true,\"warmReuse\":true,\"weakCompatibility\":true}")
  }

  func testMinOnlyDownloadFailureDoesNotOpenBelowFloor() throws {
    let manager = FileManager.default
    let root = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents/STMini", isDirectory: true)
    let target = root.appendingPathComponent("full_install_fixture", isDirectory: true)
    XCTAssertFalse(manager.fileExists(atPath: target.path))
    _ = try install("v1")
    FullRuntimeRejectedDownloadProtocol.requests = 0
    XCTAssertTrue(URLProtocol.registerClass(FullRuntimeRejectedDownloadProtocol.self))
    defer { URLProtocol.unregisterClass(FullRuntimeRejectedDownloadProtocol.self) }
    // registerClass alone does not add this protocol to the production
    // downloader's fresh ephemeral configuration. Intercept only this test's
    // configuration factory; never add a provider/hook to production source.
    let original = try XCTUnwrap(class_getClassMethod(URLSessionConfiguration.self,
      NSSelectorFromString("ephemeralSessionConfiguration")))
    let replacement = try XCTUnwrap(class_getClassMethod(URLSessionConfiguration.self,
      #selector(URLSessionConfiguration.stmini_fixtureEphemeralSessionConfiguration)))
    method_exchangeImplementations(original, replacement)
    defer { method_exchangeImplementations(original, replacement) }
    let controlled = URLSessionConfiguration.ephemeral
    XCTAssertTrue(controlled.protocolClasses?.contains {
      ObjectIdentifier($0) == ObjectIdentifier(FullRuntimeRejectedDownloadProtocol.self)
    } == true, "The configuration actually used by the production factory must contain the test interceptor.")
    let config = STWebConfig(webMode: .online, params: ["minSupportVersion": "2.0", "downloadUrl": "https://fixture.invalid/min-only-failure.zip"])
    let controller = STWebMiniprogramCrl(name: "full_install_fixture", config: config, isChild: false)
    let navigation = STWebNavigationController(rootViewController: controller)
    defer {
      withExtendedLifetime(navigation) {}
      controller.webView.stopLoading(); controller.webView.cleanup()
      try? manager.removeItem(at: target)
      if (try? manager.contentsOfDirectory(atPath: root.path).isEmpty) == true { try? manager.removeItem(at: root) }
    }
    controller.loadViewIfNeeded(); controller.viewDidAppear(false)
    XCTAssertTrue(waitUntil({ FullRuntimeRejectedDownloadProtocol.requests > 0 }, timeout: 4), "The synthetic protocol must actually intercept the production URLSession request.")
    // This is controlled transport failure, not real HTTPS/TLS evidence.
    RunLoop.current.run(until: Date().addingTimeInterval(2.5))
    XCTAssertNil(controller.webView.url)
    XCTAssertNil(controller.loadedMiniPackageVersion)
    XCTAssertFalse(controller.isKeepAliveRuntimeUsable)
    XCTAssertEqual(STWebResourceManager.installedMiniPackageVersion(name: "full_install_fixture"), "1.0")
  }

  /// Gate the actual serial transaction owner, submit both real asynchronous
  /// installer calls, then release them without timing/sleep-based ordering.
  private func concurrentInstalls(_ requests: [(fixture: String, miniId: String)]) throws -> [Result<STDirectMiniPackageInstallOutcome, Error>] {
    var inputs: [URL] = []
    for request in requests {
      let file = FileManager.default.temporaryDirectory.appendingPathComponent("full-concurrent-\(UUID().uuidString).zip")
      try XCTUnwrap(Data(base64Encoded: FullInstallArchive.bytes[request.fixture]!)).write(to: file)
      inputs.append(file)
    }
    defer { inputs.forEach { try? FileManager.default.removeItem(at: $0) } }
    let entered = expectation(description: "real install transaction queue held")
    let release = DispatchSemaphore(value: 0)
    STWebResourceManager.directMiniPackageInstallQueue.async {
      entered.fulfill()
      if release.wait(timeout: .now() + 10) != .success { XCTFail("Test did not release the transaction barrier") }
    }
    wait(for: [entered], timeout: 4)
    var released = false
    defer { if !released { release.signal() } }
    let completed = expectation(description: "all real concurrent installer outcomes")
    completed.expectedFulfillmentCount = requests.count
    completed.assertForOverFulfill = true
    var answers: [Int: Result<STDirectMiniPackageInstallOutcome, Error>] = [:]
    for (index, request) in requests.enumerated() {
      STWebResourceManager.installDirectMiniPackage(archivePath: inputs[index].path, name: request.miniId) { result in
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertNil(answers[index], "One terminal outcome per installation")
        answers[index] = result
        completed.fulfill()
      }
    }
    XCTAssertTrue(answers.isEmpty, "No installer may commit/complete across the held transaction barrier")
    release.signal(); released = true
    wait(for: [completed], timeout: 15)
    // Completion is enqueued on main before the transaction's defer removes
    // staging. Drain its owner rather than guessing a cleanup delay.
    STWebResourceManager.directMiniPackageInstallQueue.sync {}
    XCTAssertEqual(answers.count, requests.count)
    XCTAssertTrue(inputs.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
    return try requests.indices.map { try XCTUnwrap(answers[$0]) }
  }

  func testConcurrentHigherThenLowerInstallKeepsVerifiedHighestAndIndependentMini() throws {
    let manager = FileManager.default
    let root = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents/STMini", isDirectory: true)
    let target = root.appendingPathComponent("full_install_fixture", isDirectory: true)
    let other = root.appendingPathComponent("other_install_fixture", isDirectory: true)
    XCTAssertFalse(manager.fileExists(atPath: target.path)); XCTAssertFalse(manager.fileExists(atPath: other.path))
    defer {
      try? manager.removeItem(at: target); try? manager.removeItem(at: other)
      if (try? manager.contentsOfDirectory(atPath: root.path).isEmpty) == true { try? manager.removeItem(at: root) }
    }
    _ = try install("v1")
    let outcomes = try concurrentInstalls([("v3", "full_install_fixture"), ("v2", "full_install_fixture"), ("other", "other_install_fixture")])
    if case .installed(let version) = try outcomes[0].get() { XCTAssertEqual(version, "3.0") }
    else { XCTFail("The higher candidate must actually commit") }
    if case .keptInstalled(let version) = try outcomes[1].get() { XCTAssertEqual(version, "3.0") }
    else { XCTFail("The later lower candidate must read the current disk version inside its transaction") }
    if case .installed(let version) = try outcomes[2].get() { XCTAssertEqual(version, "1.0") }
    else { XCTFail("Another Mini must retain its independent package") }
    XCTAssertEqual(STWebResourceManager.installedMiniPackageVersion(name: "full_install_fixture"), "3.0")
    XCTAssertTrue(STWebResourceManager.isInstalledMiniPackageUsable(name: "full_install_fixture"))
    XCTAssertEqual(STWebResourceManager.installedMiniPackageVersion(name: "other_install_fixture"), "1.0")
    STWebResourceManager.rememberInstalledMiniPackageLaunchLink(name: "full_install_fixture", launchLink: "mini://full_install_fixture?currentVersion=3.0")
    XCTAssertEqual(STWebResourceManager.installedMiniPackageLaunchLink(name: "full_install_fixture"), "mini://full_install_fixture?currentVersion=3.0", "Synchronous metadata visibility is preserved")
    let reentrant = expectation(description: "metadata update inside install owner does not deadlock")
    STWebResourceManager.directMiniPackageInstallQueue.async {
      STWebResourceManager.rememberInstalledMiniPackageLaunchLink(name: "full_install_fixture", launchLink: "mini://full_install_fixture?minSupportVersion=3.0")
      let recorded = STWebResourceManager.installedMiniPackageLaunchLink(name: "full_install_fixture")
      DispatchQueue.main.async {
        XCTAssertEqual(recorded, "mini://full_install_fixture?minSupportVersion=3.0")
        reentrant.fulfill()
      }
    }
    wait(for: [reentrant], timeout: 4)
    XCTAssertFalse(try manager.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix(".staging-") || $0.hasPrefix(".backup-") })
    print("STMINI_FULL_CONCURRENT_INSTALL_RESULT {\"passed\":true,\"higherThenLower\":true,\"verifiedHighest\":true,\"independentMini\":true,\"exactlyOnce\":true}")
  }

  func testConcurrentPostMoveRollbackCannotRemoveAnotherSuccessfulCommit() throws {
    let manager = FileManager.default
    let root = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents/STMini", isDirectory: true)
    let target = root.appendingPathComponent("full_install_fixture", isDirectory: true)
    XCTAssertFalse(manager.fileExists(atPath: target.path))
    defer {
      try? manager.removeItem(at: target)
      if (try? manager.contentsOfDirectory(atPath: root.path).isEmpty) == true { try? manager.removeItem(at: root) }
    }
    // Both are outstanding together. Exercise failure before and after the
    // successful3.0 transaction, using the real strict post-move rejection.
    for failureFirst in [true, false] {
      _ = try install("v1")
      let requests: [(fixture: String, miniId: String)] = failureFirst
        ? [("rollback4", "full_install_fixture"), ("v3", "full_install_fixture")]
        : [("v3", "full_install_fixture"), ("rollback4", "full_install_fixture")]
      let outcomes = try concurrentInstalls(requests)
      XCTAssertThrowsError(try outcomes[failureFirst ? 0 : 1].get())
      if case .installed(let version) = try outcomes[failureFirst ? 1 : 0].get() { XCTAssertEqual(version, "3.0") }
      else { XCTFail("The independent successful transaction must remain installed") }
      XCTAssertEqual(STWebResourceManager.installedMiniPackageVersion(name: "full_install_fixture"), "3.0")
      XCTAssertTrue(STWebResourceManager.isInstalledMiniPackageUsable(name: "full_install_fixture"))
      XCTAssertFalse(try manager.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix(".staging-") || $0.hasPrefix(".backup-") })
      try manager.removeItem(at: target)
    }
    print("STMINI_FULL_CONCURRENT_ROLLBACK_RESULT {\"passed\":true,\"bothCommitOrders\":true,\"verifiedHighestPreserved\":true,\"stagingAndBackupClean\":true}")
  }

  func testRealAtomicInstallVersionRejectionAndRollbackKeepVerifiedPackage() throws {
    let manager = FileManager.default
    let root = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents/STMini", isDirectory: true)
    let target = root.appendingPathComponent("full_install_fixture", isDirectory: true)
    XCTAssertFalse(manager.fileExists(atPath: target.path))
    defer {
      try? manager.removeItem(at: target)
      if (try? manager.contentsOfDirectory(atPath: root.path).isEmpty) == true { try? manager.removeItem(at: root) }
    }
    if case .installed(let version) = try install("v1") { XCTAssertEqual(version, "1.0") } else { XCTFail("First install must install.") }
    XCTAssertEqual(STWebResourceManager.installedMiniPackageVersion(name: "full_install_fixture"), "1.0")
    for invalid in ["wrongID", "traversal", "symlink"] {
      XCTAssertThrowsError(try install(invalid))
      XCTAssertEqual(STWebResourceManager.installedMiniPackageVersion(name: "full_install_fixture"), "1.0")
    }
    XCTAssertThrowsError(try install("v1", minimum: "2.0", force: true))
    XCTAssertEqual(STWebResourceManager.installedMiniPackageVersion(name: "full_install_fixture"), "1.0")
    if case .installed(let version) = try install("v2") { XCTAssertEqual(version, "2.0") } else { XCTFail("New version must install.") }
    XCTAssertThrowsError(try install("v1", force: true))
    for force in [false, true] {
      if case .keptInstalled(let version) = try install("v2", force: force) { XCTAssertEqual(version, "2.0") }
      else { XCTFail("Same version must keep the verified disk package; force may cold-reload it.") }
    }
    if case .keptInstalled(let version) = try install("v1") { XCTAssertEqual(version, "2.0") }
    else { XCTFail("Weak lower archive must keep the verified package.") }
    XCTAssertEqual(STWebResourceManager.installedMiniPackageVersion(name: "full_install_fixture"), "2.0")
    // The source's legacy path check accepts dir//index.html; the final
    // strict installed-record check rejects it after move and restores backup.
    XCTAssertThrowsError(try install("rollback"))
    XCTAssertEqual(STWebResourceManager.installedMiniPackageVersion(name: "full_install_fixture"), "2.0")
    XCTAssertTrue(STWebResourceManager.isInstalledMiniPackageUsable(name: "full_install_fixture"))
    let leftovers = try manager.contentsOfDirectory(atPath: root.path)
    XCTAssertFalse(leftovers.contains { $0.hasPrefix(".staging-") || $0.hasPrefix(".backup-") })
    print("STMINI_FULL_INSTALL_RESULT {\"passed\":true,\"realZipInstall\":true,\"traversalSymlinkIDReject\":true,\"minimumAndForcedVersionReject\":true,\"postMoveRollback\":true}")
  }
}

private extension URLSessionConfiguration {
  /// After the exchange this name invokes the original ephemeral factory.
  /// The exchange is scoped to one serial XCTest and always reversed.
  @objc(stmini_fixtureEphemeralSessionConfiguration)
  dynamic class func stmini_fixtureEphemeralSessionConfiguration() -> URLSessionConfiguration {
    let configuration = self.stmini_fixtureEphemeralSessionConfiguration()
    configuration.protocolClasses = [FullRuntimeRejectedDownloadProtocol.self] +
      (configuration.protocolClasses ?? []).filter {
        ObjectIdentifier($0) != ObjectIdentifier(FullRuntimeRejectedDownloadProtocol.self)
      }
    return configuration
  }
}

/// Only synthetic fixture.invalid requests are intercepted. No account,
/// provider, system opener, or production TLS implementation is used.
private final class FullRuntimeRejectedDownloadProtocol: URLProtocol {
  private static let lock = NSLock()
  private static var requestCount = 0
  static var requests: Int {
    get { lock.lock(); defer { lock.unlock() }; return requestCount }
    set { lock.lock(); defer { lock.unlock() }; requestCount = newValue }
  }
  override class func canInit(with request: URLRequest) -> Bool {
    request.url?.scheme?.lowercased() == "https" && request.url?.host == "fixture.invalid"
  }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    Self.lock.lock(); Self.requestCount += 1; Self.lock.unlock()
    client?.urlProtocol(self, didFailWithError: NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost))
  }
  override func stopLoading() {}
}


/// Controlled native effect tests. WK policy/document and UI/Photos endpoints
/// are explicit spies; real OS frame/DOM and package evidence is kept separate.
private final class EffectWebView: STMiniWebView {
  var syntheticURL = URL(string: "https://fixture.invalid/current")!
  var scripts: [String] = []
  var reloads = 0
  var cleanupCalls = 0
  override func cleanup() { cleanupCalls += 1; super.cleanup() }
  var holdJavaScriptCompletions = false
  var pendingJavaScriptCompletions: [() -> Void] = []
  override var url: URL? { XCTAssertTrue(Thread.isMainThread); return syntheticURL }
  override var allowsHostSensitiveBridge: Bool { true }
  override var allowsLocalMiniBridge: Bool { true }
  override func evaluateJavaScript(_ javaScriptString: String, completionHandler: (@MainActor @Sendable (Any?, (any Error)?) -> Void)? = nil) {
    XCTAssertTrue(Thread.isMainThread)
    scripts.append(javaScriptString)
    if holdJavaScriptCompletions { pendingJavaScriptCompletions.append { completionHandler?(true, nil) } }
    else { completionHandler?(true, nil) }
  }
  override func reload() -> WKNavigation? { XCTAssertTrue(Thread.isMainThread); reloads += 1; return nil }
}

private final class EffectMiniRoot: STWebMiniprogramCrl {
  var presentations = 0
  var recordedPresentation: UIViewController?
  override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
    presentations += 1; recordedPresentation = viewControllerToPresent; completion?()
  }
}

private final class EffectNavigation: STWebNavigationController {
  var pushes = 0, pops = 0
  var syntheticDismissal = false
  override var isBeingDismissed: Bool { syntheticDismissal || super.isBeingDismissed }
  override func pushViewController(_ viewController: UIViewController, animated: Bool) { pushes += 1 }
  override func popViewController(animated: Bool) -> UIViewController? { pops += 1; return super.popViewController(animated: false) }
}


private final class UnloadedLifecycleRootProbe: STWebMiniprogramCrl {
  var didLoad: (() -> Void)?
  override func viewDidLoad() { didLoad?(); super.viewDidLoad() }
}

final class FullRuntimeRootTeardownTests: XCTestCase {
  func testRealRootCanReleaseBeforeItsViewLoads() {
    weak var released: STWebMiniprogramCrl?
    autoreleasepool {
      let controller = STWebMiniprogramCrl(name: "lifecycle_fixture", config: STWebConfig(webMode: .online), isChild: false)
      released = controller
      XCTAssertFalse(controller.isViewLoaded)
      XCTAssertNil(controller.webView)
    }
    XCTAssertNil(released, "A real unpresented root must deallocate without unwrapping its absent WebView")
    var loads = 0
    weak var probeReleased: UnloadedLifecycleRootProbe?
    autoreleasepool {
      let controller = UnloadedLifecycleRootProbe(name: "lifecycle_fixture", config: STWebConfig(webMode: .online), isChild: false)
      controller.didLoad = { loads += 1 }
      probeReleased = controller
      XCTAssertFalse(controller.isViewLoaded)
    }
    XCTAssertNil(probeReleased)
    XCTAssertEqual(loads, 0, "Teardown must not repair nil by forcing view loading")
  }

  func testCanceledUnpresentedNavigationRootReleasesWithoutLoading() {
    var loads = 0
    weak var released: UnloadedLifecycleRootProbe?
    weak var navigationReleased: STWebNavigationController?
    autoreleasepool {
      let controller = UnloadedLifecycleRootProbe(name: "lifecycle_fixture", config: STWebConfig(webMode: .online), isChild: false)
      controller.didLoad = { loads += 1 }
      let navigation = STWebNavigationController(rootViewController: controller)
      released = controller; navigationReleased = navigation
      XCTAssertFalse(controller.isViewLoaded)
      // Cancel ownership before any UIKit presentation; no asynchronous retain,
      // synthetic load, or network request is used to hide the nil lifecycle.
    }
    XCTAssertNil(navigationReleased)
    XCTAssertNil(released)
    XCTAssertEqual(loads, 0)
  }

  func testLoadedRootRepeatedCleanupAndNormalReleaseRemainSafe() throws {
    weak var released: STWebMiniprogramCrl?
    var retainedWebView: STMiniWebView?
    var originalGeneration: UInt64 = 0
    autoreleasepool {
      let controller = STWebMiniprogramCrl(name: "lifecycle_fixture", config: STWebConfig(webMode: .online), isChild: false)
      controller.loadViewIfNeeded()
      XCTAssertTrue(controller.isViewLoaded)
      retainedWebView = controller.webView
      released = controller
      if let webView = retainedWebView {
        originalGeneration = webView.bridgeDocumentGeneration
        webView.cleanup(); webView.cleanup()
        XCTAssertEqual(webView.bridgeDocumentGeneration, originalGeneration + 2)
      } else { XCTFail("Loaded root must own its real native WebView") }
    }
    XCTAssertNil(released)
    let webView = try XCTUnwrap(retainedWebView)
    XCTAssertGreaterThan(webView.bridgeDocumentGeneration, originalGeneration + 2, "Root release invalidates the document; UIKit may perform additional idempotent cleanup")
    XCTAssertNil(webView.navigationDelegate)
    XCTAssertNil(webView.uiDelegate)
    retainedWebView = nil
    print("STMINI_ROOT_TEARDOWN_RESULT {\"completed\":true,\"officialXCTestRequired\":true}")
  }
}

final class FullRuntimeQueuedEffectTests: XCTestCase {
  private let miniId = "async_effect_fixture"
  private var directory: URL!
  private var ownsFixture = false
  override func setUpWithError() throws {
    ownsFixture = false
    directory = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents/STMini/\(miniId)", isDirectory: true)
    if FileManager.default.fileExists(atPath: directory.path) {
      // Recover only this exact synthetic task fixture after an unexpected
      // test-process exit. Never silently delete an unrecognized package.
      let manifestURL = directory.appendingPathComponent("mini-manifest.json")
      let recordURL = directory.appendingPathComponent(".st-mini-package.json")
      let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: Any])
      let record = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: recordURL)) as? [String: Any])
      XCTAssertEqual(manifest["miniId"] as? String, miniId)
      XCTAssertEqual(record["miniId"] as? String, miniId)
      XCTAssertEqual(manifest["channel"] as? String, "synthetic")
      XCTAssertEqual(record["channel"] as? String, "synthetic")
      guard manifest["miniId"] as? String == miniId, record["miniId"] as? String == miniId,
            manifest["channel"] as? String == "synthetic", record["channel"] as? String == "synthetic",
            try Data(contentsOf: directory.appendingPathComponent("index.html")) == Data("<html>synthetic async effect</html>".utf8) else {
        throw NSError(domain: "DeynuSyntheticFixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Refuse unrecognized fixture recovery"])
      }
      try FileManager.default.removeItem(at: directory)
      print("STMINI_ASYNC_FIXTURE_RECOVERY {\"syntheticOwnedFixtureRemoved\":true}")
    }
    XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    ownsFixture = true
    try Data("<html>synthetic async effect</html>".utf8).write(to: directory.appendingPathComponent("index.html"))
    try Data([1]).write(to: directory.appendingPathComponent("icon.png"))
    try JSONSerialization.data(withJSONObject: ["miniId": miniId, "version": "1.0", "entry": "index.html", "icon": "icon.png", "channel": "synthetic", "updateself": "1", "ishome": "0"])
      .write(to: directory.appendingPathComponent("mini-manifest.json"))
    try JSONSerialization.data(withJSONObject: ["miniId": miniId, "version": "1.0", "entry": "index.html", "channel": "synthetic"])
      .write(to: directory.appendingPathComponent(".st-mini-package.json"))
    XCTAssertTrue(STWebResourceManager.isInstalledMiniPackageUsable(name: miniId))
  }
  override func tearDownWithError() throws {
    guard ownsFixture else { return }
    try? FileManager.default.removeItem(at: directory)
    ownsFixture = false
    let root = directory.deletingLastPathComponent()
    if (try? FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty) == true { try? FileManager.default.removeItem(at: root) }
  }
  private func drainMain(_ turns: Int = 4) {
    for _ in 0..<turns {
      let drained = expectation(description: "native main queue turn")
      DispatchQueue.main.async { drained.fulfill() }
      wait(for: [drained], timeout: 2)
    }
  }
  private func context(child: Bool = false) -> (EffectMiniRoot, EffectNavigation, EffectWebView, EffectWebView?) {
    let root = EffectMiniRoot(name: miniId, config: STWebConfig(webMode: .online), isChild: false)
    let rootWeb = EffectWebView(frame: .zero, configuration: WKWebViewConfiguration())
    rootWeb.bindCrl = root
    rootWeb.syntheticURL = URL(string: "stmini://\(miniId).stmini.local/index.html")!
    root.webView = rootWeb
    let navigation = EffectNavigation(rootViewController: root)
    navigation.setViewControllers([root], animated: false)
    var childWeb: EffectWebView?
    if child {
      let controller = STWebH5Crl(url: "https://fixture.invalid/current", config: STWebConfig(webMode: .h5), isChild: true)
      controller.isMiniInternalPage = true
      let web = EffectWebView(frame: .zero, configuration: WKWebViewConfiguration())
      web.bindCrl = controller
      controller.webView = web
      navigation.setViewControllers([root, controller], animated: false)
      controller.webView = web
      childWeb = web
    }
    root.webView = rootWeb
    navigation.pushes = 0; navigation.pops = 0
    XCTAssertTrue(root.webView === rootWeb)
    if let childWeb { XCTAssertTrue((childWeb.bindCrl as? STWebH5Crl)?.webView === childWeb) }
    return (root, navigation, rootWeb, childWeb)
  }
  private func model(_ method: String, _ params: [String: Any], _ web: EffectWebView) -> STWebApiModel {
    var value = STWebApiModel(dict: ["method": method, "params": params.merging(["methodId": "synthetic-effect"], uniquingKeysWith: { first, _ in first })])
    value.webview = web
    return value
  }
  private func invalidate(_ kind: String, web: EffectWebView, navigation: EffectNavigation) {
    switch kind {
    case "epoch": web.invalidateBridgeDocumentSession()
    case "url": web.syntheticURL = URL(string: "https://fixture.invalid/replacement")!
    case "close": web.cleanup()
    case "navclose":
      navigation.syntheticDismissal = true
      navigation.viewWillDisappear(false)
      navigation.syntheticDismissal = false
    case "stack": navigation.setViewControllers([UIViewController()], animated: false)
    default: break
    }
  }

  func testAllFourQueuedRoutesRejectObsoleteAuthorityAndKeepCurrentPositive() {
    for route in 0..<4 {
      for mutation in ["epoch", "url", "close", "navclose", "stack", "current"] {
        let (root, navigation, rootWeb, childWeb) = context(child: route == 3)
        let web = childWeb ?? rootWeb
        defer { rootWeb.cleanup(); childWeb?.cleanup() }
        let router = STWebRouterApi()
        let result: [String: Any]?
        switch route {
        case 0: result = router.navigateTo(model: model("mini_navigateTo", ["path": "index.html"], web))
        case 1: result = router.openInternalWebIfNeeded(model: model("open", ["router": "/web", "link": "https://fixture.invalid/next"], web))
        case 2: result = router.openInternalMiniIfNeeded(model: model("open", ["router": "/mini", "link": "mini://synthetic_other"], web))
        default: result = router.forwardMiniRouteOpenIfNeeded(model: model("open", ["router": "/login"], web))
        }
        XCTAssertEqual(result?["code"] as? String, "1", "The request must be valid before invalidation, route\(route)/\(mutation)")
        invalidate(mutation, web: web, navigation: navigation)
        drainMain()
        let effects = navigation.pushes + root.presentations
        XCTAssertEqual(effects, mutation == "current" ? 1 : 0, "route\(route)/\(mutation)")
      }
    }
    print("STMINI_QUEUED_ROUTES_RESULT {\"passed\":true,\"fourFamilies\":true,\"epochURLCloseStackReject\":true,\"currentPositive\":true,\"endpointSpies\":true}")
  }

  func testQueuedSessionAndFrameworkFallbackCloseHaveNoStaleSideEffects() throws {
    let personal = STWebPersonalHandle.sharedInstance()
    let saved = personal.apiHandle; personal.apiHandle = nil
    defer { personal.apiHandle = saved }
    for mutation in ["epoch", "url", "close", "navclose", "stack", "current"] {
      let (_, navigation, rootWeb, maybeTarget) = context(child: true)
      let target = try XCTUnwrap(maybeTarget)
      XCTAssertTrue((target.bindCrl as? STWebH5Crl)?.webView === target, "session/\(mutation): current controller must own the exact target spy")
      STWebApiManager.dealWithApiMessage(["method": "mini_notifySessionChanged", "params": ["methodId": "synthetic-session", "reason": "synthetic"]], webView: rootWeb)
      invalidate(mutation, web: rootWeb, navigation: navigation)
      // navclose deliberately invalidates epochs; stack detach may legitimately
      // clean up controllers. Measure queued-request deltas after that action.
      let baselineGeneration = target.bridgeDocumentGeneration
      let baselineCleanups = target.cleanupCalls
      let baselineSession = target.scripts.filter { $0.contains("miniSessionChanged") }.count
      let baselineMirror = target.scripts.filter { $0.contains("localStorage") }.count
      let baselinePop = navigation.pops
      let targetBound = (target.bindCrl as? STWebH5Crl)?.webView === target
      drainMain()
      let cleanupDelta = target.cleanupCalls - baselineCleanups
      let expectedSessionDelta = mutation == "current" ? 1 : 0
      XCTAssertEqual(target.bridgeDocumentGeneration, baselineGeneration + UInt64(cleanupDelta + expectedSessionDelta), "session/\(mutation): distinguish owned cleanup from stale session invalidation")
      XCTAssertEqual(target.scripts.filter { $0.contains("miniSessionChanged") }.count, baselineSession + expectedSessionDelta, "session/\(mutation): notification delta")
      XCTAssertEqual(target.scripts.filter { $0.contains("localStorage") }.count, baselineMirror, "session/\(mutation): Deynu has no legacy mirror provider")
      XCTAssertEqual(navigation.pops, baselinePop, "session/\(mutation): no queued route mutation")
      if mutation == "current" { XCTAssertEqual(cleanupDelta, 0, "current session target remains live") }
      print("STMINI_ASYNC_MUTATION " + String(data: try JSONSerialization.data(withJSONObject: ["kind": "session", "mutation": mutation, "baselineGeneration": baselineGeneration, "generationAfterDrain": target.bridgeDocumentGeneration, "cleanupDelta": cleanupDelta, "sessionDelta": expectedSessionDelta, "targetBoundAfterInvalidation": targetBound]), encoding: .utf8)!)
      rootWeb.cleanup(); target.cleanup()
    }
    for mutation in ["epoch", "url", "close", "navclose", "stack", "current"] {
      let (_, navigation, rootWeb, maybeChild) = context(child: true)
      let child = try XCTUnwrap(maybeChild)
      (child.bindCrl as? STWebH5Crl)?.isMiniRouteChild = true
      STWebApiManager.dealWithApiMessage(["method": "close", "params": ["methodId": "synthetic-close"]], webView: child)
      invalidate(mutation, web: child, navigation: navigation)
      let baselinePop = navigation.pops
      let baselineGeneration = child.bridgeDocumentGeneration
      let baselineCleanups = child.cleanupCalls
      let baselineSession = child.scripts.filter { $0.contains("miniSessionChanged") }.count
      let baselineMirror = child.scripts.filter { $0.contains("localStorage") }.count
      drainMain()
      let expectedPopDelta = mutation == "current" ? 1 : 0
      XCTAssertEqual(navigation.pops, baselinePop + expectedPopDelta, "fallback/\(mutation): queued pop delta")
      let cleanupDelta = child.cleanupCalls - baselineCleanups
      XCTAssertEqual(child.bridgeDocumentGeneration, baselineGeneration + UInt64(cleanupDelta), "fallback/\(mutation): only native cleanup may invalidate the child")
      XCTAssertEqual(child.scripts.filter { $0.contains("miniSessionChanged") }.count, baselineSession, "fallback/\(mutation): no session signal")
      XCTAssertEqual(child.scripts.filter { $0.contains("localStorage") }.count, baselineMirror, "fallback/\(mutation): no mirror")
      rootWeb.cleanup(); child.cleanup()
    }
  }

  func testActualMirrorEndpointChecksSourceTargetMembershipAndLateReloadLease() throws {
    let (_, navigation, rootWeb, maybeTarget) = context(child: true)
    let target = try XCTUnwrap(maybeTarget)
    defer { rootWeb.cleanup(); target.cleanup() }
    let defaults = try XCTUnwrap(STMiniScopedStorage.defaults(for: "host-configured-auth"))
    defaults.set("{\"synthetic_session\":\"fixture\"}", forKey: "async-effect-auth")
    defer { defaults.removeObject(forKey: "async-effect-auth") }
    let config: [String: Any] = ["legacyWebStorageMirror": ["origins": ["https://fixture.invalid"], "keys": ["synthetic_session"], "storageKey": "async-effect-auth", "reloadOnChange": true]]
    let stale = try XCTUnwrap(STWebBridgeEffectLease(webView: rootWeb, generation: rootWeb.bridgeDocumentGeneration, requiresMiniRoot: true))
    rootWeb.invalidateBridgeDocumentSession()
    STWebApiManager.mirrorSessionToLegacyWebStorage(targets: [target], sourceLease: stale, bridgeContext: config)
    XCTAssertTrue(target.scripts.isEmpty)
    let current = try XCTUnwrap(STWebBridgeEffectLease(webView: rootWeb, generation: rootWeb.bridgeDocumentGeneration, requiresMiniRoot: true))
    STWebApiManager.mirrorSessionToLegacyWebStorage(targets: [target], sourceLease: current, bridgeContext: config)
    XCTAssertEqual(target.scripts.filter { $0.contains("localStorage") }.count, 1); XCTAssertEqual(target.reloads, 1)
    target.holdJavaScriptCompletions = true
    STWebApiManager.mirrorSessionToLegacyWebStorage(targets: [target], sourceLease: current, bridgeContext: config)
    target.syntheticURL = URL(string: "https://fixture.invalid/new-document")!
    target.pendingJavaScriptCompletions.forEach { $0() }; target.pendingJavaScriptCompletions.removeAll()
    XCTAssertEqual(target.reloads, 1, "An old mirror callback must not reload the replacement document")
    navigation.setViewControllers([navigation.viewControllers[0]], animated: false)
    let before = target.scripts.count
    STWebApiManager.mirrorSessionToLegacyWebStorage(targets: [target], sourceLease: current, bridgeContext: config)
    XCTAssertEqual(target.scripts.count, before, "Detached sibling is no longer a session target")
  }

  func testPhotoDelayedGrantRejectsEpochURLDetachAndCurrentWritesOnce() throws {
    guard let registry = UIApplication.shared.delegate as? FlutterPluginRegistry,
          let registrar = registry.registrar(forPlugin: "DeynuPhotoEffect-" + UUID().uuidString) else { XCTFail("Runner registrar required"); return }
    for mutation in ["epoch", "url", "detach", "current", "denied"] {
      let (root, navigation, web, _) = context()
      _ = root; _ = navigation // retain native owner during the delayed grant
      let plugin = StminiFlutterPlugin()
      var grant: ((PHAuthorizationStatus) -> Void)?
      var writes = 0
      plugin.photoLibraryAccess = STMiniPhotoLibraryAccess(authorizationStatus: { .notDetermined },
        requestAuthorization: { grant = $0 }, writeImage: { _, completed in writes += 1; completed(true); completed(true) })
      plugin.saveImageToPhotoLibrary(UIImage(), params: ["methodId": "synthetic-photo"], webView: web)
      XCTAssertNotNil(grant, "The controlled permission request must actually be pending")
      if mutation == "epoch" { web.invalidateBridgeDocumentSession() }
      if mutation == "url" { web.syntheticURL = URL(string: "https://fixture.invalid/other")! }
      if mutation == "detach" { plugin.detachFromEngine(for: registrar) }
      let granted = try XCTUnwrap(grant)
      let delivered = expectation(description: "background permission callback")
      DispatchQueue.global().async { granted(mutation == "denied" ? .denied : .authorized); granted(mutation == "denied" ? .denied : .authorized); delivered.fulfill() }
      wait(for: [delivered], timeout: 2)
      drainMain(6)
      XCTAssertEqual(writes, mutation == "current" ? 1 : 0, mutation)
      let callbacks = web.scripts.filter { $0.contains("saveImageToPhotosAlbum") }
      XCTAssertEqual(callbacks.count, (mutation == "current" || mutation == "denied") ? 1 : 0, mutation)
      if mutation == "denied" { XCTAssertTrue(callbacks.first?.contains("\"code\":\"0\"") == true) }
      web.cleanup()
      withExtendedLifetime((root, navigation, plugin)) {}
    }
    print("STMINI_PHOTO_EFFECT_RESULT {\"passed\":true,\"delayedGrantEpochURLDetachReject\":true,\"currentOnceAndDenied\":true,\"OSWriteSeamOnly\":true}")
  }
}

private enum FullInstallArchive {
  static let bytes: [String: String] = [
    "v3": "UEsDBBQAAAAIADpTc10+acWkOQAAAEIAAAAKAAAAaW5kZXguaHRtbLNRTMlPLqksSFXIKMnNsbOBkEn5KZV2xZV5JRmpJZnJCpl5xSWJOTkKaZkVJaVFqTb6YHkbfbBiAFBLAwQUAAAACAA6U3NdUUKDrjkAAABCAAAADgAAAGRpci9pbmRleC5odG1ss1FMyU8uqSxIVcgoyc2xs4GQSfkplXbFlXklGaklmckKiTklqUV5iSWpCql5JUWVNvpgeRt9sGIAUEsDBBQAAAAIADpTc13TpPQCPwAAAEQAAAAJAAAAcGl4ZWwucG5n6wzwc+flkuJiYGDg9fRwCQLSjCDMwQIkt8rwMAEpbk8Xx5CKW8l//sszMDMzMbxfvD4aKMzg6ernss4poQkAUEsDBBQAAAAIADpTc135BvREfgAAAKoAAAASAAAAbWluaS1tYW5pZmVzdC5qc29uPY1BCgMhDEWvUlwXmdJdb9BNNz1AEY1jQDOisTiU3r1Rhq7C/++F/1EJCe9O3ZRvMb6QKhu5Hju3Auo8+cMkEOO5EwdgtKdDE/yGUnEjoVe9SAbisktCctB14DQktNPI2CHqTKtUNhgiiGP3P9WyMwwVopf6Mv5q2Obyor4/UEsBAhQDFAAAAAgAOlNzXT5pxaQ5AAAAQgAAAAoAAAAAAAAAAAAAAIABAAAAAGluZGV4Lmh0bWxQSwECFAMUAAAACAA6U3NdUUKDrjkAAABCAAAADgAAAAAAAAAAAAAAgAFhAAAAZGlyL2luZGV4Lmh0bWxQSwECFAMUAAAACAA6U3Nd06T0Aj8AAABEAAAACQAAAAAAAAAAAAAAgAHGAAAAcGl4ZWwucG5nUEsBAhQDFAAAAAgAOlNzXfkG9ER+AAAAqgAAABIAAAAAAAAAAAAAAIABLAEAAG1pbmktbWFuaWZlc3QuanNvblBLBQYAAAAABAAEAOsAAADaAQAAAAA=",
    "rollback4": "UEsDBBQAAAAIADpTc10+acWkOQAAAEIAAAAKAAAAaW5kZXguaHRtbLNRTMlPLqksSFXIKMnNsbOBkEn5KZV2xZV5JRmpJZnJCpl5xSWJOTkKaZkVJaVFqTb6YHkbfbBiAFBLAwQUAAAACAA6U3NdUUKDrjkAAABCAAAADgAAAGRpci9pbmRleC5odG1ss1FMyU8uqSxIVcgoyc2xs4GQSfkplXbFlXklGaklmckKiTklqUV5iSWpCql5JUWVNvpgeRt9sGIAUEsDBBQAAAAIADpTc13TpPQCPwAAAEQAAAAJAAAAcGl4ZWwucG5n6wzwc+flkuJiYGDg9fRwCQLSjCDMwQIkt8rwMAEpbk8Xx5CKW8l//sszMDMzMbxfvD4aKMzg6ernss4poQkAUEsDBBQAAAAIADpTc132LVRbggAAAK8AAAASAAAAbWluaS1tYW5pZmVzdC5qc29uPY3BCkIhEEV/JVyH7wWt+oM2bfqAEB1zQOeJjuEj+vdGiVbDvecM960SEl6duijfYnwgVTZyPXZuBdRx8ptJIMZ9Jw7AaA8/TfALSsWNhJ71KhmIyy7JYVkWJAddB07DRDu1jB2izvSUygZDBHGM//dadoahQvRSn8ZfDducX9XnC1BLAQIUAxQAAAAIADpTc10+acWkOQAAAEIAAAAKAAAAAAAAAAAAAACAAQAAAABpbmRleC5odG1sUEsBAhQDFAAAAAgAOlNzXVFCg645AAAAQgAAAA4AAAAAAAAAAAAAAIABYQAAAGRpci9pbmRleC5odG1sUEsBAhQDFAAAAAgAOlNzXdOk9AI/AAAARAAAAAkAAAAAAAAAAAAAAIABxgAAAHBpeGVsLnBuZ1BLAQIUAxQAAAAIADpTc132LVRbggAAAK8AAAASAAAAAAAAAAAAAACAASwBAABtaW5pLW1hbmlmZXN0Lmpzb25QSwUGAAAAAAQABADrAAAA3gEAAAAA",
    "other": "UEsDBBQAAAAIADpTc10+acWkOQAAAEIAAAAKAAAAaW5kZXguaHRtbLNRTMlPLqksSFXIKMnNsbOBkEn5KZV2xZV5JRmpJZnJCpl5xSWJOTkKaZkVJaVFqTb6YHkbfbBiAFBLAwQUAAAACAA6U3NdUUKDrjkAAABCAAAADgAAAGRpci9pbmRleC5odG1ss1FMyU8uqSxIVcgoyc2xs4GQSfkplXbFlXklGaklmckKiTklqUV5iSWpCql5JUWVNvpgeRt9sGIAUEsDBBQAAAAIADpTc13TpPQCPwAAAEQAAAAJAAAAcGl4ZWwucG5n6wzwc+flkuJiYGDg9fRwCQLSjCDMwQIkt8rwMAEpbk8Xx5CKW8l//sszMDMzMbxfvD4aKMzg6ernss4poQkAUEsDBBQAAAAIADpTc125e3qFfgAAAKsAAAASAAAAbWluaS1tYW5pZmVzdC5qc29uRY3BCgMhDER/pXgusr32D3rppR+wiGZrIEbRbHEp/fdGKfQ4M29m3iYh4y2Yq8kSoa7ITRzRumGXvYI5T+DuEijyOFghQX/6YRq/oDbMrOnFLqqBpR6qkAN0GyUNCP0kCnYgW/iplo+OGUjd/9VeghNoQNuYG70W83xezOcLUEsBAhQDFAAAAAgAOlNzXT5pxaQ5AAAAQgAAAAoAAAAAAAAAAAAAAIABAAAAAGluZGV4Lmh0bWxQSwECFAMUAAAACAA6U3NdUUKDrjkAAABCAAAADgAAAAAAAAAAAAAAgAFhAAAAZGlyL2luZGV4Lmh0bWxQSwECFAMUAAAACAA6U3Nd06T0Aj8AAABEAAAACQAAAAAAAAAAAAAAgAHGAAAAcGl4ZWwucG5nUEsBAhQDFAAAAAgAOlNzXbl7eoV+AAAAqwAAABIAAAAAAAAAAAAAAIABLAEAAG1pbmktbWFuaWZlc3QuanNvblBLBQYAAAAABAAEAOsAAADaAQAAAAA=",
    "v1": "UEsDBBQAAAAIADpTc10+acWkOQAAAEIAAAAKAAAAaW5kZXguaHRtbLNRTMlPLqksSFXIKMnNsbOBkEn5KZV2xZV5JRmpJZnJCpl5xSWJOTkKaZkVJaVFqTb6YHkbfbBiAFBLAwQUAAAACAA6U3NdUUKDrjkAAABCAAAADgAAAGRpci9pbmRleC5odG1ss1FMyU8uqSxIVcgoyc2xs4GQSfkplXbFlXklGaklmckKiTklqUV5iSWpCql5JUWVNvpgeRt9sGIAUEsDBBQAAAAIADpTc13TpPQCPwAAAEQAAAAJAAAAcGl4ZWwucG5n6wzwc+flkuJiYGDg9fRwCQLSjCDMwQIkt8rwMAEpbk8Xx5CKW8l//sszMDMzMbxfvD4aKMzg6ernss4poQkAUEsDBBQAAAAIADpTc12A2gL2gQAAALkAAAASAAAAbWluaS1tYW5pZmVzdC5qc29uRY5BDgIhDEWvQlgbMm69gRs3HsAQKNIEOgSKYTLx7lrGxFXT3/f7/64zEl69vigdekoPpMb2OwMO7hX0SU3iZjMIc9+IIzA69QMFeEFtuJLcz2YRBYjrJjuSh2Ei5wmiO6iCA5Ip9BTRRUsEaTb4h/biLUODFObb6W5xPVos+v0BUEsBAhQDFAAAAAgAOlNzXT5pxaQ5AAAAQgAAAAoAAAAAAAAAAAAAAIABAAAAAGluZGV4Lmh0bWxQSwECFAMUAAAACAA6U3NdUUKDrjkAAABCAAAADgAAAAAAAAAAAAAAgAFhAAAAZGlyL2luZGV4Lmh0bWxQSwECFAMUAAAACAA6U3Nd06T0Aj8AAABEAAAACQAAAAAAAAAAAAAAgAHGAAAAcGl4ZWwucG5nUEsBAhQDFAAAAAgAOlNzXYDaAvaBAAAAuQAAABIAAAAAAAAAAAAAAIABLAEAAG1pbmktbWFuaWZlc3QuanNvblBLBQYAAAAABAAEAOsAAADdAQAAAAA=",
    "v2": "UEsDBBQAAAAIADpTc10+acWkOQAAAEIAAAAKAAAAaW5kZXguaHRtbLNRTMlPLqksSFXIKMnNsbOBkEn5KZV2xZV5JRmpJZnJCpl5xSWJOTkKaZkVJaVFqTb6YHkbfbBiAFBLAwQUAAAACAA6U3NdUUKDrjkAAABCAAAADgAAAGRpci9pbmRleC5odG1ss1FMyU8uqSxIVcgoyc2xs4GQSfkplXbFlXklGaklmckKiTklqUV5iSWpCql5JUWVNvpgeRt9sGIAUEsDBBQAAAAIADpTc13TpPQCPwAAAEQAAAAJAAAAcGl4ZWwucG5n6wzwc+flkuJiYGDg9fRwCQLSjCDMwQIkt8rwMAEpbk8Xx5CKW8l//sszMDMzMbxfvD4aKMzg6ernss4poQkAUEsDBBQAAAAIADpTc13OvKpOgQAAALkAAAASAAAAbWluaS1tYW5pZmVzdC5qc29uRY5BDkIhDESvQlgb8nXpDdy48QCGQJEm0E+gGH6Md9fyTVxNOvOamZfOSHjx+qx06CndkRrbrwYc3Cvog5rE1WYQ5rYRR2B06gcK8ITacCXJT2YRB4jrJjeSh2Ei5wmi26mCA5Ip9BDTRUsEaS74l/biLUODFCQ4zu8W133Fot8fUEsBAhQDFAAAAAgAOlNzXT5pxaQ5AAAAQgAAAAoAAAAAAAAAAAAAAIABAAAAAGluZGV4Lmh0bWxQSwECFAMUAAAACAA6U3NdUUKDrjkAAABCAAAADgAAAAAAAAAAAAAAgAFhAAAAZGlyL2luZGV4Lmh0bWxQSwECFAMUAAAACAA6U3Nd06T0Aj8AAABEAAAACQAAAAAAAAAAAAAAgAHGAAAAcGl4ZWwucG5nUEsBAhQDFAAAAAgAOlNzXc68qk6BAAAAuQAAABIAAAAAAAAAAAAAAIABLAEAAG1pbmktbWFuaWZlc3QuanNvblBLBQYAAAAABAAEAOsAAADdAQAAAAA=",
    "wrongID": "UEsDBBQAAAAIADpTc10+acWkOQAAAEIAAAAKAAAAaW5kZXguaHRtbLNRTMlPLqksSFXIKMnNsbOBkEn5KZV2xZV5JRmpJZnJCpl5xSWJOTkKaZkVJaVFqTb6YHkbfbBiAFBLAwQUAAAACAA6U3NdUUKDrjkAAABCAAAADgAAAGRpci9pbmRleC5odG1ss1FMyU8uqSxIVcgoyc2xs4GQSfkplXbFlXklGaklmckKiTklqUV5iSWpCql5JUWVNvpgeRt9sGIAUEsDBBQAAAAIADpTc13TpPQCPwAAAEQAAAAJAAAAcGl4ZWwucG5n6wzwc+flkuJiYGDg9fRwCQLSjCDMwQIkt8rwMAEpbk8Xx5CKW8l//sszMDMzMbxfvD4aKMzg6ernss4poQkAUEsDBBQAAAAIADpTc10egACofgAAALIAAAASAAAAbWluaS1tYW5pZmVzdC5qc29uTY4xDsMgDAC/gpgrlKpbf5ClSx9QIXCCJTAInIoo6t9bk6Wj786yD52QcPb6rnTmAPW1YOetgr6ooR42gcjnTj/N6BRSYxujBG+oDTOJv5lJCBDXXWYkD90ETiNEd1YFO0RTaBXogiWCKPzv6Fa8ZWgQFxHXsd1CPr+Y9OcLUEsBAhQDFAAAAAgAOlNzXT5pxaQ5AAAAQgAAAAoAAAAAAAAAAAAAAIABAAAAAGluZGV4Lmh0bWxQSwECFAMUAAAACAA6U3NdUUKDrjkAAABCAAAADgAAAAAAAAAAAAAAgAFhAAAAZGlyL2luZGV4Lmh0bWxQSwECFAMUAAAACAA6U3Nd06T0Aj8AAABEAAAACQAAAAAAAAAAAAAAgAHGAAAAcGl4ZWwucG5nUEsBAhQDFAAAAAgAOlNzXR6AAKh+AAAAsgAAABIAAAAAAAAAAAAAAIABLAEAAG1pbmktbWFuaWZlc3QuanNvblBLBQYAAAAABAAEAOsAAADaAQAAAAA=",
    "rollback": "UEsDBBQAAAAIADpTc10+acWkOQAAAEIAAAAKAAAAaW5kZXguaHRtbLNRTMlPLqksSFXIKMnNsbOBkEn5KZV2xZV5JRmpJZnJCpl5xSWJOTkKaZkVJaVFqTb6YHkbfbBiAFBLAwQUAAAACAA6U3NdUUKDrjkAAABCAAAADgAAAGRpci9pbmRleC5odG1ss1FMyU8uqSxIVcgoyc2xs4GQSfkplXbFlXklGaklmckKiTklqUV5iSWpCql5JUWVNvpgeRt9sGIAUEsDBBQAAAAIADpTc13TpPQCPwAAAEQAAAAJAAAAcGl4ZWwucG5n6wzwc+flkuJiYGDg9fRwCQLSjCDMwQIkt8rwMAEpbk8Xx5CKW8l//sszMDMzMbxfvD4aKMzg6ernss4poQkAUEsDBBQAAAAIADpTc10+UkzRhgAAAL4AAAASAAAAbWluaS1tYW5pZmVzdC5qc29uRY7BCgIxDER/ZelZuive/AMvXvwAKW1qA222tKl0Ef9d0xU8DZl5YealEhJenDpPyrcY70iVzVc9dm4F1GEaxNUkEOa2EQdgtNMPFOAJpeJKkp/0Ig4Ql01uh2WekRx0HTgNGu2OZuwQdaaHmDYYIohjxr+5ZWcYKkQvwXF817DuUxb1/gBQSwECFAMUAAAACAA6U3NdPmnFpDkAAABCAAAACgAAAAAAAAAAAAAAgAEAAAAAaW5kZXguaHRtbFBLAQIUAxQAAAAIADpTc11RQoOuOQAAAEIAAAAOAAAAAAAAAAAAAACAAWEAAABkaXIvaW5kZXguaHRtbFBLAQIUAxQAAAAIADpTc13TpPQCPwAAAEQAAAAJAAAAAAAAAAAAAACAAcYAAABwaXhlbC5wbmdQSwECFAMUAAAACAA6U3NdPlJM0YYAAAC+AAAAEgAAAAAAAAAAAAAAgAEsAQAAbWluaS1tYW5pZmVzdC5qc29uUEsFBgAAAAAEAAQA6wAAAOIBAAAAAA==",
    "traversal": "UEsDBBQAAAAIADpTc10+acWkOQAAAEIAAAAKAAAAaW5kZXguaHRtbLNRTMlPLqksSFXIKMnNsbOBkEn5KZV2xZV5JRmpJZnJCpl5xSWJOTkKaZkVJaVFqTb6YHkbfbBiAFBLAwQUAAAACAA6U3NdUUKDrjkAAABCAAAADgAAAGRpci9pbmRleC5odG1ss1FMyU8uqSxIVcgoyc2xs4GQSfkplXbFlXklGaklmckKiTklqUV5iSWpCql5JUWVNvpgeRt9sGIAUEsDBBQAAAAIADpTc13TpPQCPwAAAEQAAAAJAAAAcGl4ZWwucG5n6wzwc+flkuJiYGDg9fRwCQLSjCDMwQIkt8rwMAEpbk8Xx5CKW8l//sszMDMzMbxfvD4aKMzg6ernss4poQkAUEsDBBQAAAAIADpTc13LnB2QggAAALkAAAASAAAAbWluaS1tYW5pZmVzdC5qc29uRY5BCkIxDESvUrqW8sWdN3DjxgNIaVMbaPNLm0o/4t01/YKrITMvzLx0RsKL12elQ0/pjtTYfjXg4F5BH9QkrjaDMLeNOAKjUz9QgCfUhitJfjKLOEBcN7mRPAwTOU8Q3U4VHJBMoYeYLloiSHPBv7QXbxkapCDBcX63uO4rFv3+AFBLAwQUAAAACAA6U3NdVwLEQQsAAAAJAAAAEwAAAC4uL3N5bnRoZXRpYy1lc2NhcGUrrswryUgtyUwGAFBLAQIUAxQAAAAIADpTc10+acWkOQAAAEIAAAAKAAAAAAAAAAAAAACAAQAAAABpbmRleC5odG1sUEsBAhQDFAAAAAgAOlNzXVFCg645AAAAQgAAAA4AAAAAAAAAAAAAAIABYQAAAGRpci9pbmRleC5odG1sUEsBAhQDFAAAAAgAOlNzXdOk9AI/AAAARAAAAAkAAAAAAAAAAAAAAIABxgAAAHBpeGVsLnBuZ1BLAQIUAxQAAAAIADpTc13LnB2QggAAALkAAAASAAAAAAAAAAAAAACAASwBAABtaW5pLW1hbmlmZXN0Lmpzb25QSwECFAMUAAAACAA6U3NdVwLEQQsAAAAJAAAAEwAAAAAAAAAAAAAAgAHeAQAALi4vc3ludGhldGljLWVzY2FwZVBLBQYAAAAABQAFACwBAAAaAgAAAAA=",
    "symlink": "UEsDBBQAAAAIADpTc10+acWkOQAAAEIAAAAKAAAAaW5kZXguaHRtbLNRTMlPLqksSFXIKMnNsbOBkEn5KZV2xZV5JRmpJZnJCpl5xSWJOTkKaZkVJaVFqTb6YHkbfbBiAFBLAwQUAAAACAA6U3NdUUKDrjkAAABCAAAADgAAAGRpci9pbmRleC5odG1ss1FMyU8uqSxIVcgoyc2xs4GQSfkplXbFlXklGaklmckKiTklqUV5iSWpCql5JUWVNvpgeRt9sGIAUEsDBBQAAAAIADpTc13TpPQCPwAAAEQAAAAJAAAAcGl4ZWwucG5n6wzwc+flkuJiYGDg9fRwCQLSjCDMwQIkt8rwMAEpbk8Xx5CKW8l//sszMDMzMbxfvD4aKMzg6ernss4poQkAUEsDBBQAAAAIADpTc13LnB2QggAAALkAAAASAAAAbWluaS1tYW5pZmVzdC5qc29uRY5BCkIxDESvUrqW8sWdN3DjxgNIaVMbaPNLm0o/4t01/YKrITMvzLx0RsKL12elQ0/pjtTYfjXg4F5BH9QkrjaDMLeNOAKjUz9QgCfUhitJfjKLOEBcN7mRPAwTOU8Q3U4VHJBMoYeYLloiSHPBv7QXbxkapCDBcX63uO4rFv3+AFBLAwQUAAAAAAAAACEAyelLdwoAAAAKAAAACgAAAGFsaWFzLmh0bWxpbmRleC5odG1sUEsBAhQDFAAAAAgAOlNzXT5pxaQ5AAAAQgAAAAoAAAAAAAAAAAAAAIABAAAAAGluZGV4Lmh0bWxQSwECFAMUAAAACAA6U3NdUUKDrjkAAABCAAAADgAAAAAAAAAAAAAAgAFhAAAAZGlyL2luZGV4Lmh0bWxQSwECFAMUAAAACAA6U3Nd06T0Aj8AAABEAAAACQAAAAAAAAAAAAAAgAHGAAAAcGl4ZWwucG5nUEsBAhQDFAAAAAgAOlNzXcucHZCCAAAAuQAAABIAAAAAAAAAAAAAAIABLAEAAG1pbmktbWFuaWZlc3QuanNvblBLAQIUAxQAAAAAAAAAIQDJ6Ut3CgAAAAoAAAAKAAAAAAAAAAAAAAD/od4BAABhbGlhcy5odG1sUEsFBgAAAAAFAAUAIwEAABACAAAAAA==",
  ]
}
