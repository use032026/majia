import Flutter
import XCTest
import UIKit
import WebKit
import Network
import Photos
import ZIPFoundation
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
    XCTAssertEqual(invoke(plugin, "notifyWebSessionChanged", [:]) as? Int, 0)
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


/// Package installation is intentionally not present in this runtime.




/// Only synthetic fixture.invalid requests are intercepted. No account,
/// provider, system opener, or production TLS implementation is used.



/// Controlled native effect tests. WK policy/document and UI/Photos endpoints
/// are explicit spies; real OS frame/DOM and package evidence is kept separate.
/// Existing packages are prepared out-of-band by the test, never installed by
/// the product. The real full WK container retains its local document gates.
final class FullRuntimeLocalOnlyPackageTests: XCTestCase {
  private var createdPackageRoot = false
  override func setUpWithError() throws {
    createdPackageRoot = !FileManager.default.fileExists(atPath: folder.deletingLastPathComponent().path)
  }
  private let id = "full_local_fixture"
  private var folder: URL { URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents/STMini/\(id)") }
  private func prepare(_ version: String = "1.0") throws {
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try Data("<html><body>Local only full Mini<script>window.localOnlyProbe=true</script></body></html>".utf8).write(to: folder.appendingPathComponent("index.html"))
    try XCTUnwrap(RendererFixture.files["pixel.png"]).write(to: folder.appendingPathComponent("pixel.png"))
    try JSONSerialization.data(withJSONObject: ["miniId": id, "version": version, "entry": "index.html", "icon": "pixel.png", "channel": "fixture", "updateself": "1", "ishome": "0"]).write(to: folder.appendingPathComponent("mini-manifest.json"))
    try JSONSerialization.data(withJSONObject: ["miniId": id, "version": version, "entry": "index.html", "channel": "fixture", "launchLink": "mini://\(id)?downloadUrl=https://fixture.invalid/old.zip"]).write(to: folder.appendingPathComponent(".st-mini-package.json"))
  }
  override func tearDownWithError() throws {
    STWebMiniProgramKeepAliveStore.shared.removeAll()
    try? FileManager.default.removeItem(at: folder)
    let root = folder.deletingLastPathComponent()
    if createdPackageRoot, (try? FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty) == true { try? FileManager.default.removeItem(at: root) }
  }
  private func invoke(_ plugin: StminiFlutterPlugin, _ name: String, _ arguments: Any? = nil) -> Any? {
    var called = false; var value: Any?
    plugin.handle(FlutterMethodCall(methodName: name, arguments: arguments)) { value = $0; called = true }
    XCTAssertTrue(called); return value
  }
  func testPackageCapabilitiesAndRejectedInsecureRequestsNeverMutatePackages() throws {
    try prepare()
    let listener = try RendererLoopback()
    defer { listener.stop() }
    let bindDeadline = Date().addingTimeInterval(5)
    while listener.port == nil && Date() < bindDeadline { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
    let port = try XCTUnwrap(listener.port)
    let positive = NWConnection(host: "127.0.0.1", port: try XCTUnwrap(NWEndpoint.Port(rawValue: port)), using: .tcp)
    positive.start(queue: DispatchQueue(label: "stmini.local-only.transport-positive"))
    let positiveDeadline = Date().addingTimeInterval(5)
    while listener.count < 1 && Date() < positiveDeadline { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
    XCTAssertEqual(listener.count, 1, "The observer must see a real connection on the exact tested port")
    positive.cancel(); listener.reset()
    let remote = "http://127.0.0.1:\(port)/forbidden.zip"
    let recordURL = folder.appendingPathComponent(".st-mini-package.json")
    var oldRecord = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: recordURL)) as? [String: Any])
    oldRecord["launchLink"] = "mini://\(id)?downloadUrl=\(remote)"
    try JSONSerialization.data(withJSONObject: oldRecord).write(to: recordURL) // out-of-band fixture only
    let before = try Data(contentsOf: recordURL)
    let beforeManifest = try Data(contentsOf: folder.appendingPathComponent("mini-manifest.json"))
    let beforeDirectories = try FileManager.default.contentsOfDirectory(atPath: folder.deletingLastPathComponent().path).sorted()
    guard let registry = UIApplication.shared.delegate as? FlutterPluginRegistry,
          let plugin = registry.valuePublished(byPlugin: "StminiFlutterPlugin") as? StminiFlutterPlugin else {
      XCTFail("The real Runner must publish its actual registered Mini plugin")
      return
    }
    var observedEvents: [String] = []
    XCTAssertNil(plugin.onListen(withArguments: nil, eventSink: { value in
      if let event = value as? [String: Any], let name = event["name"] as? String { observedEvents.append(name) }
    }))
    defer { _ = plugin.onCancel(withArguments: nil) }
    observedEvents.removeAll()
    XCTAssertNil(invoke(plugin, "initialize", ["bridgeContext": ["packageName": "com.almanac.lite"]]))
    XCTAssertTrue(observedEvents.contains("runtime_initialized"), "The actual plugin event observer must receive its positive control")
    observedEvents.removeAll()
    let state = try XCTUnwrap(invoke(plugin, "foundationState") as? [String: Any])
    XCTAssertEqual(state["miniPackageMode"] as? String, "download_install_update")
    XCTAssertEqual(state["webLoadingAvailable"] as? Bool, true)
    XCTAssertEqual(state["miniChildWebAvailable"] as? Bool, true)
    XCTAssertEqual(state["closedMiniCacheAvailable"] as? Bool, true)
    for flag in ["miniPackageDownloadAvailable", "miniPackageInstallAvailable", "miniPackageUpdateAvailable"] { XCTAssertEqual(state[flag] as? Bool, true) }
    func reject(_ link: String, code: String) throws {
      let error = invoke(plugin, "openMini", ["link": link]) as? FlutterError
      XCTAssertEqual(error?.code, code, link)
      XCTAssertFalse(error?.message?.isEmpty ?? true, "Rejection must explain its outcome: \(link)")
      XCTAssertEqual(try Data(contentsOf: recordURL), before, link)
      XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("mini-manifest.json")), beforeManifest, link)
      XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.deletingLastPathComponent().path).sorted(), beforeDirectories, link)
      XCTAssertTrue(observedEvents.isEmpty, "Rejected preflight must not emit opening/installed/progress events: \(link)")
    }
    for query in [
      "downloadUrl=\(remote)", "downloadURL=\(remote)", "download_url=\(remote)",
      "downloadUrl=&downloadUrl=\(remote)", "downloadUrl=\(remote)&downloadUrl=",
      "download_url=&download_url=\(remote)", "downloadUrl=&download_url=\(remote)",
      "__st_force_self_update=1", "isforce=1", "isForce=1", "forceUpdate=1",
      "forceUpdate=&forceUpdate=1", "forceUpdate=1&forceUpdate="
    ] {
      try reject("mini://\(id)?\(query)", code: query.contains("download") ? "invalid_download_url" : "invalid_mini_link")
    }
    try reject("mini://missing_fixture?download_url=\(remote)", code: "invalid_download_url")
    try reject("mini://missing_fixture", code: "mini_package_unavailable")
    for query in [
      "minSupportVersion=2.0", "currentVersion=2.0", "min_support_version=2.0", "current_version=2.0",
      "currentVersion=2.0&current_version=1.0", "minSupportVersion=2.0&min_support_version=1.0",
      "currentVersion=1.0&currentVersion=2.0", "currentVersion=2.0&currentVersion=",
      "minSupportVersion=&min_support_version=2.0", "currentVersion=%20&current_version=2.0"
    ] {
      try reject("mini://\(id)?\(query)", code: "mini_package_unavailable")
    }
    // Exercise the same read-only preflight used by the real plugin above.
    // Accepted full-container loading is exercised below without opening a
    // stack of synthetic modal presentations for every query spelling.
    for query in [
      "current_version=1.0", "min_support_version=1.0",
      "currentVersion=1.0&current_version=2.0", "minSupportVersion=1.0&min_support_version=2.0",
      "currentVersion=2.0&min_support_version=1.0", "currentVersion=2.0&currentVersion=1.0",
      "current_version=1.0&currentVersion=", "currentVersion=&currentVersion=1.0"
    ] {
      XCTAssertTrue(STWebResourceManager.isInstalledMiniPackageRunnable(link: "mini://\(id)?\(query)"), query)
    }
    let controller = STWebMiniprogramCrl(name: id, config: STWebConfig(webMode: .online), isChild: false)
    controller.loadViewIfNeeded(); controller.viewDidAppear(false)
    defer { controller.webView?.cleanup() }
    let readyDeadline = Date().addingTimeInterval(10)
    while !controller.isKeepAliveRuntimeUsable && Date() < readyDeadline { RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }
    XCTAssertTrue(controller.isKeepAliveRuntimeUsable, "The real existing local package must still load")
    let web = try XCTUnwrap(controller.webView)
    func script(_ value: String) -> Any? {
      let finished = expectation(description: "real local-only WK callback observation")
      var result: Any?
      web.evaluateJavaScript(value) { answer, error in XCTAssertNil(error); result = answer; finished.fulfill() }
      wait(for: [finished], timeout: 5)
      return result
    }
    _ = script("window.__localOnlyUpdates=[];window.CMSJsCallBack=function(r){window.__localOnlyUpdates.push(r)};true")
    for method in ["mini_checkMiniProgramUpdate", "mini_downloadMiniProgramUpdate"] {
      STWebApiManager.dealWithApiMessage(["method": method, "params": ["methodId": method, "downloadUrl": remote, "isforce": true]], webView: web)
    }
    let replyDeadline = Date().addingTimeInterval(5)
    while (script("window.__localOnlyUpdates.length") as? Int) != 2 && Date() < replyDeadline { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
    let replies = try XCTUnwrap(script("window.__localOnlyUpdates") as? [[String: Any]])
    XCTAssertEqual(replies.count, 2)
    for reply in replies {
      XCTAssertEqual(reply["code"] as? String, "0")
      XCTAssertFalse(((reply["data"] as? [String: Any])?["msg"] as? String)?.isEmpty ?? true)
    }
    XCTAssertEqual(Set(replies.compactMap { $0["methodId"] as? String }), Set(["mini_checkMiniProgramUpdate", "mini_downloadMiniProgramUpdate"]))
    // Bounded drain after all real native/WK completions; this endpoint
    // observation does not make any claim about all-device network traffic.
    let settleDeadline = Date().addingTimeInterval(0.2)
    while Date() < settleDeadline { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
    XCTAssertEqual(listener.count, 0, "No TCP/TLS connection to the positive-controlled package endpoint during completed rejection flows")
    let forbidden: Set<String> = ["mini_download_started", "mini_download_progress", "mini_download_completed", "mini_package_installed", "installed_packages_changed"]
    XCTAssertTrue(observedEvents.allSatisfy { !forbidden.contains($0) }, "No installed/progress success may be fabricated")
    XCTAssertEqual(try Data(contentsOf: recordURL), before)
    XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("mini-manifest.json")), beforeManifest)
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.deletingLastPathComponent().path).sorted(), beforeDirectories)
    XCTAssertFalse(FileManager.default.fileExists(atPath: folder.deletingLastPathComponent().appendingPathComponent("missing_fixture").path))
    XCTAssertEqual(STMiniPackageRegistry.installedPackages().first { $0.miniId == id }?.launchLink, "mini://\(id)?currentVersion=1.0")
    print("STMINI_LOCAL_ONLY_TRANSPORT_RESULT {\"completed\":true,\"officialXCTestRequired\":true,\"positiveConnections\":1,\"rejectedConnections\":\(listener.count),\"observerScope\":\"specified_loopback_port\"}")
  }
  func testActualCloseThenOpenReusesVerifiedMiniWithFreshAuthority() throws {
    try prepare()
    let previousKey = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }.first { $0.isKeyWindow }
    let window = UIWindow(frame: UIScreen.main.bounds)
    let host = UIViewController(); window.rootViewController = host; window.makeKeyAndVisible()
    defer { host.dismiss(animated: false); window.isHidden = true; previousKey?.makeKeyAndVisible() }
    func openedRoot() throws -> STWebMiniprogramCrl {
      STWebOpenHandler.openMiniprogram(name: id, config: STWebConfig(webMode: .online), crl: host)
      let deadline = Date().addingTimeInterval(10)
      while Date() < deadline {
        if let navigation = host.presentedViewController as? STWebNavigationController,
           let root = navigation.viewControllers.first as? STWebMiniprogramCrl,
           root.isKeepAliveRuntimeUsable,
           !navigation.isBeingPresented, !navigation.isBeingDismissed,
           navigation.presentingViewController != nil, navigation.viewIfLoaded?.window != nil,
           root.webView?.hasNativeEffectAuthority == true { return root }
        RunLoop.current.run(until: Date().addingTimeInterval(0.02))
      }
      throw NSError(domain: "FullRuntimeLocalOnlyPackageTests", code: 1)
    }
    func evaluate(_ root: STWebMiniprogramCrl, _ script: String) -> Any? {
      let done = expectation(description: "actual reopen document")
      var result: Any?
      root.webView.evaluateJavaScript(script) { value, error in XCTAssertNil(error); result = value; done.fulfill() }
      wait(for: [done], timeout: 5); return result
    }
    let first = try openedRoot()
    XCTAssertEqual(evaluate(first, "window.__closedDocumentSentinel=true;true") as? Bool, true)
    let oldGeneration = first.webView.bridgeDocumentGeneration
    let oldLease = try XCTUnwrap(STWebBridgeEffectLease(webView: first.webView, generation: oldGeneration))
    first.close()
    XCTAssertFalse(first.webView.hasNativeEffectAuthority)
    XCTAssertNil(STWebBridgeEffectLease(webView: first.webView, generation: first.webView.bridgeDocumentGeneration))
    let deadline = Date().addingTimeInterval(5)
    while host.presentedViewController != nil && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }
    XCTAssertNil(host.presentedViewController)
    let second = try openedRoot()
    XCTAssertTrue(first === second, "Only the exact verified local runtime may warm resume")
    XCTAssertTrue(first.webView === second.webView)
    XCTAssertGreaterThan(second.webView.bridgeDocumentGeneration, oldGeneration)
    XCTAssertTrue(second.webView.hasNativeEffectAuthority)
    XCTAssertFalse(oldLease.isCurrent(), "Waiting for a new grant must never revive the pre-close request")
    XCTAssertNotNil(STWebBridgeEffectLease(webView: second.webView, generation: second.webView.bridgeDocumentGeneration))
    XCTAssertEqual(evaluate(second, "window.__closedDocumentSentinel===true && window.localOnlyProbe===true") as? Bool, true)
    second.close()
  }

  func testExistingLocalMiniKeepsImmutableBytesAndRejectsSnapshotTampering() throws {
    try prepare()
    let controller = STWebMiniprogramCrl(name: id, config: STWebConfig(webMode: .online), isChild: false)
    controller.loadViewIfNeeded(); controller.viewDidAppear(false)
    let deadline = Date().addingTimeInterval(10)
    while !controller.isKeepAliveRuntimeUsable && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }
    XCTAssertTrue(controller.isKeepAliveRuntimeUsable)
    let web = try XCTUnwrap(controller.webView)
    let dom = expectation(description: "real local-only full WK DOM")
    web.evaluateJavaScript("window.localOnlyProbe===true && document.body.innerText.includes('Local only full Mini')") { result, error in XCTAssertNil(error); XCTAssertEqual(result as? Bool, true); dom.fulfill() }
    wait(for: [dom], timeout: 5)
    let originalURL = try XCTUnwrap(web.url)
    let snapshotFile = try XCTUnwrap(web.verifiedBoundResource(originalURL))
    let originalBytes = try Data(contentsOf: snapshotFile)
    try prepare("2.0") // out-of-band synthetic change, not product install
    XCTAssertEqual(STWebResourceManager.installedMiniPackageVersion(name: id), "2.0")
    XCTAssertEqual(try Data(contentsOf: XCTUnwrap(web.verifiedBoundResource(originalURL))), originalBytes)
    XCTAssertTrue(web.allowsLocalMiniBridge)
    let reply = expectation(description: "old document JavaScript remains live")
    web.evaluateJavaScript("window.localOnlyProbe === true") { value, error in XCTAssertNil(error); XCTAssertEqual(value as? Bool, true); reply.fulfill() }
    wait(for: [reply], timeout: 5)
    try Data("tampered snapshot resource".utf8).write(to: snapshotFile)
    XCTAssertNil(web.verifiedBoundResource(originalURL), "Tampering the actual immutable resource must fail closed")
    web.cleanup()
    let replacement = STWebMiniprogramCrl(name: id, config: STWebConfig(webMode: .online), isChild: false)
    replacement.loadViewIfNeeded(); replacement.viewDidAppear(false)
    let nextDeadline = Date().addingTimeInterval(10)
    while !replacement.isKeepAliveRuntimeUsable && Date() < nextDeadline { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
    XCTAssertTrue(replacement.isKeepAliveRuntimeUsable)
    XCTAssertEqual(replacement.loadedMiniPackageVersion, "2.0")
    replacement.webView.cleanup()
  }
}

private final class EffectWebView: STMiniWebView {
  var syntheticURL = URL(string: "https://fixture.invalid/current")!
  var scripts: [String] = []
  var reloads = 0
  var cleanupCalls = 0
  override func cleanup() { cleanupCalls += 1; super.cleanup() }
  var holdJavaScriptCompletions = false
  var pendingJavaScriptCompletions: [() -> Void] = []
  override var url: URL? { XCTAssertTrue(Thread.isMainThread); return syntheticURL }
  override var bridgeReplyDocumentToken: String? { "0123456789abcdef0123456789abcdef" }
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
  private let targetMiniId = "async_effect_target"
  private var targetDirectory: URL { directory.deletingLastPathComponent().appendingPathComponent(targetMiniId) }
  private var directory: URL!
  private var ownsFixture = false
  override func setUpWithError() throws {
    ownsFixture = false
    directory = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents/STMini/\(miniId)", isDirectory: true)
    for (fixtureDirectory, fixtureId) in [(directory!, miniId), (targetDirectory, targetMiniId)] {
      if FileManager.default.fileExists(atPath: fixtureDirectory.path) {
        // Recover only this exact synthetic task fixture after an unexpected
        // test-process exit. Never silently delete an unrecognized package.
        let manifestURL = fixtureDirectory.appendingPathComponent("mini-manifest.json")
        let recordURL = fixtureDirectory.appendingPathComponent(".st-mini-package.json")
        let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: Any])
        let record = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: recordURL)) as? [String: Any])
        XCTAssertEqual(manifest["miniId"] as? String, fixtureId)
        XCTAssertEqual(record["miniId"] as? String, fixtureId)
        XCTAssertEqual(manifest["channel"] as? String, "synthetic")
        XCTAssertEqual(record["channel"] as? String, "synthetic")
        guard manifest["miniId"] as? String == fixtureId, record["miniId"] as? String == fixtureId,
              manifest["channel"] as? String == "synthetic", record["channel"] as? String == "synthetic",
              try Data(contentsOf: fixtureDirectory.appendingPathComponent("index.html")) == Data("<html>synthetic async effect</html>".utf8) else {
          throw NSError(domain: "DeynuSyntheticFixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Refuse unrecognized fixture recovery"])
        }
        try FileManager.default.removeItem(at: fixtureDirectory)
        print("STMINI_ASYNC_FIXTURE_RECOVERY {\"syntheticOwnedFixtureRemoved\":true}")
      }
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
    try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
    for filename in ["index.html", "icon.png"] {
      try Data(contentsOf: directory.appendingPathComponent(filename)).write(to: targetDirectory.appendingPathComponent(filename))
    }
    for filename in ["mini-manifest.json", ".st-mini-package.json"] {
      var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent(filename))) as? [String: Any])
      json["miniId"] = targetMiniId
      try JSONSerialization.data(withJSONObject: json).write(to: targetDirectory.appendingPathComponent(filename))
    }
    XCTAssertTrue(STWebResourceManager.isInstalledMiniPackageUsable(name: targetMiniId))
  }
  override func tearDownWithError() throws {
    guard ownsFixture else { return }
    try? FileManager.default.removeItem(at: directory)
    try? FileManager.default.removeItem(at: targetDirectory)
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
    root.loadViewIfNeeded(); root.viewDidAppear(false)
    let qualifiedDeadline = Date().addingTimeInterval(10)
    while !root.isKeepAliveRuntimeUsable && Date() < qualifiedDeadline { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
    XCTAssertTrue(root.isKeepAliveRuntimeUsable, "Route fixtures must first load the production verified identity")
    let qualifiedRootView = root.webView
    let configuration = (qualifiedRootView?.configuration.copy() as? WKWebViewConfiguration) ?? WKWebViewConfiguration()
    // Retain the production scheme handler while giving this endpoint its
    // own script-handler registration and document-start user scripts.
    configuration.userContentController = WKUserContentController()
    let rootWeb = EffectWebView(frame: .zero, configuration: configuration)
    rootWeb.bindCrl = root
    rootWeb.syntheticURL = URL(string: "stmini://\(miniId).stmini.local/index.html")!
    rootWeb.load(URLRequest(url: rootWeb.syntheticURL))
    let bindingDeadline = Date().addingTimeInterval(10)
    while rootWeb.packageLocalPageURL(path: "index.html") == nil && Date() < bindingDeadline { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
    XCTAssertNotNil(rootWeb.packageLocalPageURL(path: "index.html"), "Production navigation must bind a real immutable snapshot")
    root.webView = rootWeb
    qualifiedRootView?.cleanup(); qualifiedRootView?.removeFromSuperview()
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
        case 2: result = router.openInternalMiniIfNeeded(model: model("open", ["router": "/mini", "link": "mini://\(targetMiniId)"], web))
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

  func testMissingOrRemoteMiniRouteRejectsBeforePresentation() throws {
    let (root, navigation, web, _) = context()
    defer { web.cleanup() }
    let before = try FileManager.default.contentsOfDirectory(atPath: directory.deletingLastPathComponent().path).sorted()
    for link in ["mini://missing_fixture", "mini://\(targetMiniId)?downloadUrl=https://127.0.0.1:1/rejected.zip"] {
      let result = STWebRouterApi().openInternalMiniIfNeeded(model: model("open", ["router": "/mini", "link": link], web))
      XCTAssertEqual(result?["code"] as? String, "0")
    }
    drainMain()
    XCTAssertEqual(root.presentations, 0); XCTAssertEqual(navigation.pushes, 0)
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.deletingLastPathComponent().path).sorted(), before)
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



  func testPhotoDelayedGrantRejectsEpochURLDetachAndCurrentWritesOnce() throws {
    guard let registry = UIApplication.shared.delegate as? FlutterPluginRegistry,
          let registrar = registry.registrar(forPlugin: "DeynuPhotoEffect-" + UUID().uuidString) else { XCTFail("Runner registrar required"); return }
    for mutation in ["epoch", "url", "detach", "hidden", "current", "denied"] {
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
      if mutation == "hidden" {
        root.prepareForNativeDismissal()
        XCTAssertNil(STWebBridgeEffectLease(webView: web, generation: web.bridgeDocumentGeneration))
        var newHiddenGrantRequested = false
        let hiddenPlugin = StminiFlutterPlugin()
        hiddenPlugin.photoLibraryAccess = STMiniPhotoLibraryAccess(authorizationStatus: { .notDetermined }, requestAuthorization: { _ in newHiddenGrantRequested = true }, writeImage: { _, _ in XCTFail("Hidden new request must never write") })
        hiddenPlugin.saveImageToPhotoLibrary(UIImage(), params: ["methodId": "hidden-new"], webView: web)
        XCTAssertFalse(newHiddenGrantRequested)
      }
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


/// Test-only observation after the real UIKit presentation completion calls
/// the production warm grant. The hook never changes production scheduling.
private final class WarmActivationCompletionHost: UIViewController {
  var afterMiniCompletion: ((STWebMiniprogramCrl) -> Void)?
  override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
    super.present(viewControllerToPresent, animated: flag) { [weak self] in
      completion?()
      if let root = (viewControllerToPresent as? STWebNavigationController)?.viewControllers.first as? STWebMiniprogramCrl,
         let hook = self?.afterMiniCompletion {
        self?.afterMiniCompletion = nil
        hook(root)
      }
    }
  }
}

/// Real UIKit/WK consumers of the fifth-batch cache. Every package is a
/// synthetic test-owned directory; no product entry or remote Mini is added.
final class FifthBatchWarmRuntimeTests: XCTestCase {
  private var owned: [URL] = []
  private var createdPackageRoot = false
  private var packageRoot: URL { URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents/STMini", isDirectory: true) }
  private var window: UIWindow!
  private var host: UIViewController!
  private weak var previousKey: UIWindow?
  private let store = STWebMiniProgramKeepAliveStore.shared

  override func setUpWithError() throws {
    store.removeAll()
    createdPackageRoot = !FileManager.default.fileExists(atPath: packageRoot.path)
    previousKey = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }.first { $0.isKeyWindow }
    window = UIWindow(frame: UIScreen.main.bounds)
    host = UIViewController(); window.rootViewController = host; window.makeKeyAndVisible()
  }
  override func tearDownWithError() throws {
    host.dismiss(animated: false)
    store.removeAll()
    owned.forEach { try? FileManager.default.removeItem(at: $0) }
    if createdPackageRoot, (try? FileManager.default.contentsOfDirectory(atPath: packageRoot.path).isEmpty) == true { try? FileManager.default.removeItem(at: packageRoot) }
    window.isHidden = true; previousKey?.makeKeyAndVisible()
    StminiFlutterPlugin.bridgeContextSnapshot = ["packageName": "com.almanac.lite"]
  }
  private func until(_ timeout: TimeInterval = 10, _ condition: () -> Bool) {
    let end = Date().addingTimeInterval(timeout)
    while !condition() && Date() < end { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
    XCTAssertTrue(condition())
  }
  private func makePackage(_ suffix: String) throws -> String {
    let id = "fifth_fixture_" + suffix
    let folder = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents/STMini/" + id)
    XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    owned.append(folder)
    try Data("<html><body>fifth fixture<script>window.warmCounter=41</script></body></html>".utf8).write(to: folder.appendingPathComponent("index.html"))
    try Data("<html><body>fifth child</body></html>".utf8).write(to: folder.appendingPathComponent("second.html"))
    for file in ["mini-manifest.json", ".st-mini-package.json"] {
      try JSONSerialization.data(withJSONObject: ["miniId": id, "version": "1.0", "entry": "index.html", "channel": "synthetic-fifth", "icon": "", "updateself": "0", "ishome": "0"])
        .write(to: folder.appendingPathComponent(file))
    }
    return id
  }
  private func open(_ id: String) throws -> STWebMiniprogramCrl {
    STWebOpenHandler.openMiniprogram(name: id, config: STWebConfig(webMode: .online), crl: host)
    until { (self.host.presentedViewController as? UINavigationController)?.viewControllers.first.flatMap { ($0 as? STWebMiniprogramCrl)?.isKeepAliveRuntimeUsable } == true && self.host.presentedViewController?.isBeingPresented == false }
    // UIKit's presentation completion grants warm authority after the animation.
    until { (self.host.presentedViewController as? UINavigationController)?.viewControllers.first.flatMap { ($0 as? STWebMiniprogramCrl)?.allowsNativeRuntimeEffects } == true }
    return try XCTUnwrap((host.presentedViewController as? UINavigationController)?.viewControllers.first as? STWebMiniprogramCrl)
  }
  private func close(_ root: STWebMiniprogramCrl) {
    root.close()
    until { self.host.presentedViewController == nil }
    // Drain the explicit completion and the navigation lifecycle callbacks.
    let done = expectation(description: "completed cache insertion")
    DispatchQueue.main.async { done.fulfill() }; wait(for: [done], timeout: 2)
    XCTAssertTrue(host.view.window === window, "A custom dismissal must preserve its presenting owner's original window")
  }
  private func js(_ web: WKWebView, _ script: String) -> Any? {
    let done = expectation(description: "real warm WK state")
    var result: Any?
    web.evaluateJavaScript(script) { value, error in XCTAssertNil(error); result = value; done.fulfill() }
    wait(for: [done], timeout: 5)
    return result
  }

  func testWarmStackReusesJSButRevokesNewAndOldNativeAuthorityWhileHidden() throws {
    let id = try makePackage("stack")
    let root = try open(id)
    let navigation = try XCTUnwrap(root.navigationController)
    let config = STWebConfig(webMode: .local); config.bridgePolicy = .localMini
    let child = STWebH5Crl(url: "stmini://\(id).stmini.local/second.html", config: config, isChild: true)
    child.isMiniInternalPage = true
    navigation.pushViewController(child, animated: false)
    until { child.webView?.url?.path == "/second.html" && child.webView?.isLoading == false }
    let rootWeb = try XCTUnwrap(root.webView), childWeb = try XCTUnwrap(child.webView)
    let old = try XCTUnwrap(STWebBridgeEffectLease(webView: childWeb, generation: childWeb.bridgeDocumentGeneration, requiresMiniRoot: true))
    let generation = childWeb.bridgeDocumentGeneration
    XCTAssertEqual(js(rootWeb, "window.warmCounter += 1; window.warmCounter") as? Int, 42)
    close(root)
    XCTAssertTrue(root.isRuntimeRetainedHidden)
    XCTAssertFalse(old.isCurrent())
    for web in [rootWeb, childWeb] {
      XCTAssertFalse(web.hasNativeEffectAuthority)
      XCTAssertNil(STWebBridgeEffectLease(webView: web, generation: web.bridgeDocumentGeneration))
      let before = web.bridgeDocumentGeneration
      STWebApiManager.dealWithApiMessage(["method": "mini_notifySessionChanged", "params": ["methodId": "hidden-new"]], webView: web)
      XCTAssertEqual(web.bridgeDocumentGeneration, before)
    }
    XCTAssertNotNil(navigation.view.window, "A hidden transparent host must not be mistaken for visible authority")
    let warm = try open(id)
    XCTAssertTrue(warm === root)
    XCTAssertTrue(warm.navigationController?.viewControllers.last === child)
    XCTAssertTrue(childWeb.hasNativeEffectAuthority)
    XCTAssertGreaterThan(childWeb.bridgeDocumentGeneration, generation)
    XCTAssertFalse(old.isCurrent(), "Fresh grant cannot revive an old asynchronous request")
    XCTAssertEqual(js(rootWeb, "window.warmCounter") as? Int, 42)
    close(warm)
  }

  func testFIFOEvictionMemoryWarningAndSessionChangeDestroyCachedAuthority() throws {
    let a = try open(try makePackage("a")); close(a)
    let b = try open(try makePackage("b")); close(b)
    let c = try open(try makePackage("c")); close(c)
    XCTAssertFalse(a.isKeepAliveRuntimeUsable)
    XCTAssertNil(a.webView.navigationDelegate)
    XCTAssertTrue(b.isKeepAliveRuntimeUsable); XCTAssertTrue(c.isKeepAliveRuntimeUsable)
    NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
    XCTAssertFalse(b.isKeepAliveRuntimeUsable); XCTAssertFalse(c.isKeepAliveRuntimeUsable)
    XCTAssertNil(store.take(miniId: b.miniProgramId, config: STWebConfig(webMode: .online)))
    let fresh = try open(b.miniProgramId); close(fresh)
    NotificationCenter.default.post(name: Notification.Name("kSTLogoutSuccessNotification"), object: nil)
    XCTAssertFalse(fresh.isKeepAliveRuntimeUsable)
    XCTAssertNil(store.take(miniId: fresh.miniProgramId, config: STWebConfig(webMode: .online)))
  }

  func testSameVersionByteReplacementEntryChangeAndTerminationRejectWarmReuse() throws {
    let id = try makePackage("identity")
    let original = try open(id); close(original)
    let folder = try XCTUnwrap(owned.first)
    let before = try XCTUnwrap(STWebMiniPackageIdentity.read(miniId: id))
    try Data("<html>different same-version bytes</html>".utf8).write(to: folder.appendingPathComponent("second.html"))
    XCTAssertNotEqual(STWebMiniPackageIdentity.read(miniId: id), before)
    XCTAssertNil(store.take(miniId: id, config: STWebConfig(webMode: .online)))
    XCTAssertFalse(original.isKeepAliveRuntimeUsable)
    let second = try open(id); close(second)
    second.webviewContentProcessDidTerminate()
    XCTAssertFalse(second.isKeepAliveRuntimeUsable)
    XCTAssertNil(store.take(miniId: id, config: STWebConfig(webMode: .online)))
    let third = try open(id); close(third)
    for file in ["mini-manifest.json", ".st-mini-package.json"] {
      let path = folder.appendingPathComponent(file)
      var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
      json["entry"] = "second.html"
      try JSONSerialization.data(withJSONObject: json).write(to: path)
    }
    XCTAssertNil(store.take(miniId: id, config: STWebConfig(webMode: .online)))
    XCTAssertFalse(third.isKeepAliveRuntimeUsable)
  }

  func testContinuousPolicyIsExplicitAndStillReleasesOnMemoryOrDetach() throws {
    let id = try makePackage("continuous")
    XCTAssertFalse(store.supportsContinuousKeepAlive(miniId: id))
    let plugin = StminiFlutterPlugin()
    let initialized = expectation(description: "controlled SDK whitelist")
    plugin.handle(FlutterMethodCall(methodName: "initialize", arguments: ["bridgeContext": ["packageName": "com.almanac.lite", "miniSecurity": ["continuousKeepAliveMiniIds": [id]]]])) { value in XCTAssertNil(value); initialized.fulfill() }
    wait(for: [initialized], timeout: 2)
    store.setContinuousKeepAlive(true, for: id)
    XCTAssertTrue(store.supportsContinuousKeepAlive(miniId: id))
    let root = try open(id); close(root)
    XCTAssertTrue(root.isKeepAliveRuntimeUsable)
    NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
    XCTAssertFalse(root.isKeepAliveRuntimeUsable)
    XCTAssertTrue(host.view.window === window, "Memory eviction must not detach the presenting host")
    let second = try open(id); close(second)
    guard let registry = UIApplication.shared.delegate as? FlutterPluginRegistry,
          let registrar = registry.registrar(forPlugin: "DeynuFifthDetach-" + UUID().uuidString) else { XCTFail("Runner registrar required"); return }
    plugin.detachFromEngine(for: registrar)
    XCTAssertFalse(second.isKeepAliveRuntimeUsable)
    store.setContinuousKeepAlive(false, for: id)
  }

  func testStandaloneWebRapidReplacementAndCloseUseActualUIKitAndRejectMiniIdentity() throws {
    let plugin = StminiFlutterPlugin()
    let initialized = expectation(description: "Web SDK initialize")
    plugin.handle(FlutterMethodCall(methodName: "initialize", arguments: ["bridgeContext": ["packageName": "com.almanac.lite"]])) { value in XCTAssertNil(value); initialized.fulfill() }
    wait(for: [initialized], timeout: 2)
    var results: [String: Any] = [:]
    let finished = expectation(description: "three Web results exactly once"); finished.expectedFulfillmentCount = 3; finished.assertForOverFulfill = true
    for marker in ["a", "b", "c"] {
      plugin.handle(FlutterMethodCall(methodName: "openWeb", arguments: ["url": "https://127.0.0.1:1/\(marker)", "title": marker])) { result in
        results[marker] = result ?? NSNull(); finished.fulfill()
      }
    }
    wait(for: [finished], timeout: 10)
    XCTAssertTrue(results["a"] is NSNull)
    XCTAssertEqual((results["b"] as? FlutterError)?.code, "superseded")
    XCTAssertTrue(results["c"] is NSNull)
    let navigation = try XCTUnwrap(host.presentedViewController as? UINavigationController)
    let page = try XCTUnwrap(navigation.viewControllers.first as? STWebH5Crl)
    XCTAssertEqual(page.url, "https://127.0.0.1:1/c")
    XCTAssertFalse(page.isMiniInternalPage)
    XCTAssertFalse(page.webView.allowsLocalMiniBridge)
    let closed = expectation(description: "Web SDK close")
    plugin.handle(FlutterMethodCall(methodName: "closeWeb", arguments: nil)) { value in XCTAssertNil(value); closed.fulfill() }
    wait(for: [closed], timeout: 5)
    XCTAssertNil(host.presentedViewController)
    XCTAssertFalse(page.webView?.hasNativeEffectAuthority ?? false)
    print("STMINI_FIFTH_WEB_RESULT {\"actualUIKit\":true,\"rapidReplacement\":true,\"miniPrivilegeDenied\":true}")
  }

  func testExplicitSessionNotificationWithoutStandaloneWebDestroysCachedRuntime() throws {
    let root = try open(try makePackage("session_api")); close(root)
    let generation = store.sessionGeneration
    let plugin = StminiFlutterPlugin()
    let done = expectation(description: "no-Web session notification")
    plugin.handle(FlutterMethodCall(methodName: "notifyWebSessionChanged", arguments: ["reason": "synthetic-logout"])) { result in
      XCTAssertEqual(result as? Int, 0); done.fulfill()
    }
    wait(for: [done], timeout: 2)
    XCTAssertGreaterThan(store.sessionGeneration, generation)
    XCTAssertFalse(root.isKeepAliveRuntimeUsable)
    XCTAssertNil(store.take(miniId: root.miniProgramId, config: STWebConfig(webMode: .online)))
  }

  func testCancelledDismissalNeedsFreshGrantAndCannotRestoreOldLease() throws {
    let root = try open(try makePackage("cancel"))
    let web = try XCTUnwrap(root.webView)
    let old = try XCTUnwrap(STWebBridgeEffectLease(webView: web, generation: web.bridgeDocumentGeneration))
    root.prepareForNativeDismissal()
    XCTAssertFalse(web.hasNativeEffectAuthority); XCTAssertFalse(old.isCurrent())
    // The real presentation remains attached, as it does after UIKit cancels
    // an interactive dismissal; only the explicit completion may grant anew.
    root.setKeepAliveRuntimeHidden(false)
    XCTAssertTrue(web.hasNativeEffectAuthority)
    XCTAssertFalse(old.isCurrent())
    XCTAssertNotNil(STWebBridgeEffectLease(webView: web, generation: web.bridgeDocumentGeneration))
    close(root)
  }

  func testCloseBeforeQueuedWebPresentationCancelsOriginalExactlyOnce() {
    let plugin = StminiFlutterPlugin()
    plugin.handle(FlutterMethodCall(methodName: "initialize", arguments: ["bridgeContext": ["packageName": "com.almanac.lite"]])) { XCTAssertNil($0) }
    let done = expectation(description: "queued Web cancellation exactly once")
    done.expectedFulfillmentCount = 2; done.assertForOverFulfill = true
    plugin.handle(FlutterMethodCall(methodName: "openWeb", arguments: ["url": "https://127.0.0.1:1/cancelled-before-dispatch"])) { value in
      XCTAssertEqual((value as? FlutterError)?.code, "cancelled"); done.fulfill()
    }
    plugin.handle(FlutterMethodCall(methodName: "closeWeb", arguments: nil)) { value in XCTAssertNil(value); done.fulfill() }
    wait(for: [done], timeout: 3)
    XCTAssertNil(host.presentedViewController)
  }


  func testDetachDuringWebCloseFinishesEveryPendingInvocationOnce() {
    guard let registry = UIApplication.shared.delegate as? FlutterPluginRegistry,
          let registrar = registry.registrar(forPlugin: "FifthWebDetach-" + UUID().uuidString) else { XCTFail("Runner registrar required"); return }
    let plugin = StminiFlutterPlugin()
    plugin.handle(FlutterMethodCall(methodName: "initialize", arguments: ["bridgeContext": ["packageName": "com.almanac.lite"]])) { XCTAssertNil($0) }
    let done = expectation(description: "open and in-flight close finish exactly once")
    done.expectedFulfillmentCount = 2; done.assertForOverFulfill = true
    plugin.handle(FlutterMethodCall(methodName: "openWeb", arguments: ["url": "https://127.0.0.1:1/detach"])) { result in
      XCTAssertTrue(result == nil || (result as? FlutterError)?.code == "cancelled")
      done.fulfill()
    }
    DispatchQueue.main.async {
      plugin.handle(FlutterMethodCall(methodName: "closeWeb", arguments: nil)) { result in
        XCTAssertTrue(result == nil || (result as? FlutterError)?.code == "cancelled")
        done.fulfill()
      }
      plugin.detachFromEngine(for: registrar)
    }
    wait(for: [done], timeout: 5)
    until { self.host.presentedViewController == nil }
  }


  func testDetachReleasesActuallyOwnedVisibleMiniAndH5Stack() throws {
    let id = try makePackage("active_detach")
    let plugin = StminiFlutterPlugin()
    plugin.handle(FlutterMethodCall(methodName: "initialize", arguments: ["bridgeContext": ["packageName": "com.almanac.lite"]])) { XCTAssertNil($0) }
    let requested = expectation(description: "actual SDK Mini open")
    plugin.handle(FlutterMethodCall(methodName: "openMini", arguments: ["link": "mini://\(id)"])) { value in XCTAssertNil(value); requested.fulfill() }
    wait(for: [requested], timeout: 3)
    until { (self.host.presentedViewController as? UINavigationController)?.viewControllers.first.flatMap { ($0 as? STWebMiniprogramCrl)?.isKeepAliveRuntimeUsable } == true && self.host.presentedViewController?.isBeingPresented == false }
    let navigation = try XCTUnwrap(host.presentedViewController as? STWebNavigationController)
    let root = try XCTUnwrap(navigation.viewControllers.first as? STWebMiniprogramCrl)
    let config = STWebConfig(webMode: .local); config.bridgePolicy = .localMini
    let child = STWebH5Crl(url: "stmini://\(id).stmini.local/second.html", config: config, isChild: true)
    child.isMiniInternalPage = true
    navigation.pushViewController(child, animated: false)
    until { child.webView?.url?.path == "/second.html" && child.webView?.isLoading == false }
    let rootWeb = try XCTUnwrap(root.webView), childWeb = try XCTUnwrap(child.webView)
    let lease = try XCTUnwrap(STWebBridgeEffectLease(webView: childWeb, generation: childWeb.bridgeDocumentGeneration))
    guard let registry = UIApplication.shared.delegate as? FlutterPluginRegistry,
          let registrar = registry.registrar(forPlugin: "FifthActiveDetach-" + UUID().uuidString) else { XCTFail("Runner registrar required"); return }
    plugin.detachFromEngine(for: registrar)
    XCTAssertFalse(root.isKeepAliveRuntimeUsable)
    XCTAssertFalse(lease.isCurrent())
    for web in [rootWeb, childWeb] {
      XCTAssertFalse(web.hasNativeEffectAuthority)
      XCTAssertNil(STWebBridgeEffectLease(webView: web, generation: web.bridgeDocumentGeneration))
      XCTAssertNil(web.navigationDelegate); XCTAssertNil(web.uiDelegate)
    }
    until { self.host.presentedViewController == nil }
    XCTAssertNil(child.webView)
  }


  func testCloseMiniCancelsQueuedOpenAndNeverDismissesStandaloneWeb() throws {
    let id = try makePackage("queued_close")
    let plugin = StminiFlutterPlugin()
    plugin.handle(FlutterMethodCall(methodName: "initialize", arguments: ["bridgeContext": ["packageName": "com.almanac.lite"]])) { XCTAssertNil($0) }
    let cancelled = expectation(description: "queued Mini open cancelled by close")
    cancelled.expectedFulfillmentCount = 2; cancelled.assertForOverFulfill = true
    plugin.handle(FlutterMethodCall(methodName: "openMini", arguments: ["link": "mini://\(id)"])) { result in
      XCTAssertEqual((result as? FlutterError)?.code, "cancelled"); cancelled.fulfill()
    }
    plugin.handle(FlutterMethodCall(methodName: "closeMini", arguments: nil)) { result in XCTAssertNil(result); cancelled.fulfill() }
    wait(for: [cancelled], timeout: 3)
    XCTAssertNil(host.presentedViewController)
    let opened = expectation(description: "standalone Web shown")
    plugin.handle(FlutterMethodCall(methodName: "openWeb", arguments: ["url": "https://127.0.0.1:1/not-mini"])) { result in XCTAssertNil(result); opened.fulfill() }
    wait(for: [opened], timeout: 5)
    let original = try XCTUnwrap(host.presentedViewController)
    plugin.handle(FlutterMethodCall(methodName: "closeMini", arguments: nil)) { XCTAssertNil($0) }
    XCTAssertTrue(host.presentedViewController === original)
    let closed = expectation(description: "explicit Web close")
    plugin.handle(FlutterMethodCall(methodName: "closeWeb", arguments: nil)) { result in XCTAssertNil(result); closed.fulfill() }
    wait(for: [closed], timeout: 5)
  }

  func testQueuedMiniCloseCannotTouchForeignUIAfterEngineDetach() throws {
    let id = try makePackage("stale_close")
    let plugin = StminiFlutterPlugin()
    plugin.handle(FlutterMethodCall(methodName: "initialize", arguments: ["bridgeContext": ["packageName": "com.almanac.lite"]])) { XCTAssertNil($0) }
    let requested = expectation(description: "owned Mini open")
    plugin.handle(FlutterMethodCall(methodName: "openMini", arguments: ["link": "mini://\(id)"])) { result in XCTAssertNil(result); requested.fulfill() }
    wait(for: [requested], timeout: 3)
    until { (self.host.presentedViewController as? UINavigationController)?.viewControllers.first.flatMap { ($0 as? STWebMiniprogramCrl)?.isKeepAliveRuntimeUsable } == true && self.host.presentedViewController?.isBeingPresented == false }
    guard let registry = UIApplication.shared.delegate as? FlutterPluginRegistry,
          let registrar = registry.registrar(forPlugin: "FifthQueuedClose-" + UUID().uuidString) else { XCTFail("Runner registrar required"); return }
    let originalNavigation = try XCTUnwrap(host.presentedViewController as? STWebNavigationController)
    let originalRoot = try XCTUnwrap(originalNavigation.viewControllers.first as? STWebMiniprogramCrl)
    let originalWeb = try XCTUnwrap(originalRoot.webView)
    let originalLease = try XCTUnwrap(STWebBridgeEffectLease(webView: originalWeb, generation: originalWeb.bridgeDocumentGeneration))
    let closed = expectation(description: "stale close terminal exactly once"); closed.assertForOverFulfill = true
    plugin.handle(FlutterMethodCall(methodName: "closeMini", arguments: nil)) { result in
      XCTAssertEqual((result as? FlutterError)?.code, "cancelled"); closed.fulfill()
    }
    plugin.detachFromEngine(for: registrar)
    XCTAssertFalse(originalWeb.hasNativeEffectAuthority)
    XCTAssertFalse(originalLease.isCurrent())
    XCTAssertNil(STWebBridgeEffectLease(webView: originalWeb, generation: originalWeb.bridgeDocumentGeneration))
    XCTAssertNil(originalWeb.navigationDelegate); XCTAssertNil(originalWeb.uiDelegate)
    // Security revocation is synchronous. UIKit presentation lifetime ends
    // at its actual transition completion, observed with a bounded predicate.
    until { self.host.presentedViewController == nil }
    XCTAssertNil(host.presentedViewController)
    let foreign = UIViewController()
    host.present(foreign, animated: false)
    wait(for: [closed], timeout: 3)
    let drained = expectation(description: "old queued close consumed")
    DispatchQueue.main.async { drained.fulfill() }; wait(for: [drained], timeout: 2)
    XCTAssertTrue(host.presentedViewController === foreign, "An old engine must never resample and dismiss a new owner")
    foreign.dismiss(animated: false)
  }

  func testWebSessionDuringPresentationAndCloseCannotGrantAuthority() throws {
    let plugin = StminiFlutterPlugin()
    plugin.handle(FlutterMethodCall(methodName: "initialize", arguments: ["bridgeContext": ["packageName": "com.almanac.lite"]])) { XCTAssertNil($0) }
    let cancelled = expectation(description: "in-flight Web and session terminal")
    cancelled.expectedFulfillmentCount = 2; cancelled.assertForOverFulfill = true
    plugin.handle(FlutterMethodCall(methodName: "openWeb", arguments: ["url": "https://127.0.0.1:1/in-flight"])) { result in
      XCTAssertEqual((result as? FlutterError)?.code, "cancelled"); cancelled.fulfill()
    }
    DispatchQueue.main.async {
      let page = (self.host.presentedViewController as? UINavigationController)?.viewControllers.first as? STWebH5Crl
      plugin.handle(FlutterMethodCall(methodName: "notifyWebSessionChanged", arguments: ["reason": "synthetic"])) { result in
        XCTAssertEqual(result as? Int, 0); cancelled.fulfill()
      }
      XCTAssertFalse(page?.webView?.hasNativeEffectAuthority ?? false)
    }
    wait(for: [cancelled], timeout: 5)
    until { self.host.presentedViewController == nil }
    let opened = expectation(description: "second Web presentation")
    plugin.handle(FlutterMethodCall(methodName: "openWeb", arguments: ["url": "https://127.0.0.1:1/closing"])) { result in XCTAssertNil(result); opened.fulfill() }
    wait(for: [opened], timeout: 5)
    let page = try XCTUnwrap((host.presentedViewController as? UINavigationController)?.viewControllers.first as? STWebH5Crl)
    let closed = expectation(description: "Web close remains terminal once"); closed.assertForOverFulfill = true
    plugin.handle(FlutterMethodCall(methodName: "closeWeb", arguments: nil)) { result in XCTAssertNil(result); closed.fulfill() }
    plugin.handle(FlutterMethodCall(methodName: "notifyWebSessionChanged", arguments: ["reason": "during-close"])) { result in XCTAssertEqual(result as? Int, 0) }
    XCTAssertFalse(page.webView?.hasNativeEffectAuthority ?? false)
    wait(for: [closed], timeout: 5)
    XCTAssertNil(host.presentedViewController)
  }


  private func makeStandalone(_ plugin: StminiFlutterPlugin, path: String = "owner") throws -> (UINavigationController, STWebH5Crl, EffectWebView) {
    plugin.handle(FlutterMethodCall(methodName: "initialize", arguments: ["bridgeContext": ["packageName": "com.almanac.lite"]])) { XCTAssertNil($0) }
    let shown = expectation(description: "actual standalone owner presentation")
    plugin.handle(FlutterMethodCall(methodName: "openWeb", arguments: ["url": "https://127.0.0.1:1/" + path])) { result in XCTAssertNil(result); shown.fulfill() }
    wait(for: [shown], timeout: 5)
    let navigation = try XCTUnwrap(host.presentedViewController as? UINavigationController)
    let page = try XCTUnwrap(navigation.visibleViewController as? STWebH5Crl)
    // Actual UIKit topology, controlled document/effect endpoint. Successful
    // HTTPS DOM transport is independently verified by the OS SDK fixture.
    page.webView?.cleanup(); page.webView?.removeFromSuperview()
    let spy = EffectWebView(frame: .zero, configuration: WKWebViewConfiguration())
    spy.bindCrl = page; page.webView = spy; page.view.addSubview(spy)
    return (navigation, page, spy)
  }

  private func notifyWeb(_ plugin: StminiFlutterPlugin) -> Int? {
    var count: Int?
    plugin.handle(FlutterMethodCall(methodName: "notifyWebSessionChanged", arguments: ["reason": "synthetic-owner"])) { count = $0 as? Int }
    return count
  }

  func testCoveredStandaloneRejectsEffectsAndReplacementUntilExplicitRevealGrant() throws {
    for style in [UIModalPresentationStyle.fullScreen, .overCurrentContext] {
      let plugin = StminiFlutterPlugin()
      let (navigation, page, web) = try makeStandalone(plugin, path: style == .fullScreen ? "full-cover" : "over-cover")
      let old = try XCTUnwrap(STWebBridgeEffectLease(webView: web, generation: web.bridgeDocumentGeneration))
      let overlay = UIViewController(); overlay.modalPresentationStyle = style
      let shown = expectation(description: "foreign UIKit cover")
      page.present(overlay, animated: false) { shown.fulfill() }
      wait(for: [shown], timeout: 3)
      XCTAssertTrue(STWebH5Crl.topVisibleController(in: window) === overlay)
      if style == .overCurrentContext { XCTAssertNotNil(navigation.view.window) }
      // Do not sample old.isCurrent while covered: the epoch must have been
      // revoked at coverage start, independent of later lease observation.
      XCTAssertFalse(web.hasNativeEffectAuthority)
      XCTAssertNil(STWebBridgeEffectLease(webView: web, generation: web.bridgeDocumentGeneration))
      let before = web.scripts.count
      STWebApiManager.dealWithApiMessage(["method": "showToast", "params": ["methodId": "covered-new"]], webView: web)
      XCTAssertEqual(web.scripts.count, before)
      XCTAssertEqual(notifyWeb(plugin), 0)
      let rejected = expectation(description: "covered replacement is explicit once")
      rejected.assertForOverFulfill = true
      plugin.handle(FlutterMethodCall(methodName: "openWeb", arguments: ["url": "https://127.0.0.1:1/c"])) { result in
        XCTAssertEqual((result as? FlutterError)?.code, "web_covered"); rejected.fulfill()
      }
      wait(for: [rejected], timeout: 3)
      plugin.handle(FlutterMethodCall(methodName: "closeWeb", arguments: nil)) { result in XCTAssertEqual((result as? FlutterError)?.code, "web_covered") }
      XCTAssertTrue(host.presentedViewController === navigation)
      XCTAssertTrue(STWebH5Crl.topVisibleController(in: window) === overlay)
      let revealed = expectation(description: "foreign owner leaves itself")
      overlay.dismiss(animated: false) { revealed.fulfill() }
      wait(for: [revealed], timeout: 3)
      XCTAssertFalse(old.isCurrent(), "An unobserved pre-cover lease must remain dead after reveal")
      XCTAssertFalse(web.hasNativeEffectAuthority, "Reveal alone cannot grant native authority")
      XCTAssertEqual(notifyWeb(plugin), 1)
      XCTAssertTrue(web.hasNativeEffectAuthority)
      XCTAssertFalse(old.isCurrent())
      XCTAssertNotNil(STWebBridgeEffectLease(webView: web, generation: web.bridgeDocumentGeneration))
      let closed = expectation(description: "original owner closes once")
      plugin.handle(FlutterMethodCall(methodName: "closeWeb", arguments: nil)) { result in XCTAssertNil(result); closed.fulfill() }
      wait(for: [closed], timeout: 5)
      XCTAssertNil(host.presentedViewController)
    }
  }

  func testActualCustomMiniCoverPreservesStandaloneOwnerAndOriginalLeasesStayDead() throws {
    let miniId = try makePackage("web_cover")
    let plugin = StminiFlutterPlugin()
    let (navigation, page, web) = try makeStandalone(plugin)
    let old = try XCTUnwrap(STWebBridgeEffectLease(webView: web, generation: web.bridgeDocumentGeneration))
    let opened = expectation(description: "actual custom Mini overlay")
    plugin.handle(FlutterMethodCall(methodName: "openMini", arguments: ["link": "mini://\(miniId)"])) { result in XCTAssertNil(result); opened.fulfill() }
    wait(for: [opened], timeout: 3)
    until { (STWebH5Crl.topVisibleController(in: self.window) as? STWebMiniprogramCrl)?.isKeepAliveRuntimeUsable == true }
    let mini = try XCTUnwrap(STWebH5Crl.topVisibleController(in: window) as? STWebMiniprogramCrl)
    XCTAssertNotNil(navigation.view.window)
    XCTAssertEqual(notifyWeb(plugin), 0)
    XCTAssertFalse(web.hasNativeEffectAuthority)
    let rejected = expectation(description: "custom-covered Web replacement rejected")
    plugin.handle(FlutterMethodCall(methodName: "openWeb", arguments: ["url": "https://127.0.0.1:1/no-orphan"])) { result in XCTAssertEqual((result as? FlutterError)?.code, "web_covered"); rejected.fulfill() }
    wait(for: [rejected], timeout: 3)
    XCTAssertTrue(host.presentedViewController === navigation)
    XCTAssertTrue(STWebH5Crl.topVisibleController(in: window) === mini)
    mini.close()
    until { STWebH5Crl.topVisibleController(in: self.window) === page }
    XCTAssertFalse(old.isCurrent())
    XCTAssertEqual(notifyWeb(plugin), 1)
    XCTAssertTrue(web.hasNativeEffectAuthority)
    let closed = expectation(description: "recovered standalone closes")
    plugin.handle(FlutterMethodCall(methodName: "closeWeb", arguments: nil)) { result in XCTAssertNil(result); closed.fulfill() }
    wait(for: [closed], timeout: 5)
  }

  func testCoveredDetachReleasesWebWithoutDismissingForeignOwner() throws {
    let plugin = StminiFlutterPlugin()
    let (navigation, _, web) = try makeStandalone(plugin)
    let overlay = UIViewController(); overlay.modalPresentationStyle = .overCurrentContext
    let shown = expectation(description: "nav-owned foreign overlay")
    navigation.present(overlay, animated: false) { shown.fulfill() }
    wait(for: [shown], timeout: 3)
    guard let registry = UIApplication.shared.delegate as? FlutterPluginRegistry,
          let registrar = registry.registrar(forPlugin: "FifthCoveredDetach-" + UUID().uuidString) else { XCTFail("Runner registrar required"); return }
    plugin.detachFromEngine(for: registrar)
    XCTAssertTrue(STWebH5Crl.topVisibleController(in: window) === overlay)
    XCTAssertTrue(host.presentedViewController === navigation)
    XCTAssertFalse(web.hasNativeEffectAuthority)
    XCTAssertNil(web.navigationDelegate); XCTAssertNil(web.uiDelegate)
    let left = expectation(description: "foreign overlay explicitly dismisses")
    overlay.dismiss(animated: false) { left.fulfill() }
    wait(for: [left], timeout: 3)
    until { self.host.presentedViewController == nil }
  }

  func testStandaloneDisplayOptionsDoNotRewriteSignedCallerURL() throws {
    let plugin = StminiFlutterPlugin()
    plugin.handle(FlutterMethodCall(methodName: "initialize", arguments: ["bridgeContext": ["packageName": "com.almanac.lite"]])) { XCTAssertNil($0) }
    let url = "https://127.0.0.1:1/signed?sig=a%2Fb&x=1&x=2#anchor"
    let shown = expectation(description: "signed URL is passed unchanged")
    plugin.handle(FlutterMethodCall(methodName: "openWeb", arguments: ["url": url, "title": "Native title", "showNavigationBar": false])) { result in XCTAssertNil(result); shown.fulfill() }
    wait(for: [shown], timeout: 5)
    let page = try XCTUnwrap((host.presentedViewController as? UINavigationController)?.visibleViewController as? STWebH5Crl)
    XCTAssertEqual(page.url, url)
    XCTAssertEqual(page.config.params?["title"], "Native title")
    XCTAssertEqual(page.config.params?["isNeedNavigationBar"], "false")
    let closed = expectation(description: "signed URL owner closes")
    plugin.handle(FlutterMethodCall(methodName: "closeWeb", arguments: nil)) { result in XCTAssertNil(result); closed.fulfill() }
    wait(for: [closed], timeout: 5)
  }

  func testReleasedH5LateLifecycleIsIdempotentAndNeverRecreatesAuthority() {
    let config = STWebConfig(webMode: .h5)
    let page = STWebH5Crl(url: "https://127.0.0.1:1/released", config: config)
    page.loadViewIfNeeded()
    let web = page.webView
    page.releaseAfterMiniCache()
    page.viewWillAppear(false); page.viewWillDisappear(false); page.viewDidDisappear(false)
    page.traitCollectionDidChange(UITraitCollection(userInterfaceStyle: .dark))
    page.webviewDidFinish()
    page.webviewDidFailNavigation(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet))
    page.webviewContentProcessDidTerminate()
    page.close(); page.back(); page.more(); page.releaseAfterMiniCache()
    XCTAssertNil(page.webView)
    XCTAssertFalse(web?.hasNativeEffectAuthority ?? true)
    XCTAssertNil(web?.navigationDelegate); XCTAssertNil(web?.uiDelegate)
  }


  func testCoveredMiniDetachPreservesForeignOwnerAndRetiresOnlyItsOriginalStack() throws {
    for style in [UIModalPresentationStyle.fullScreen, .overCurrentContext] {
      until { self.host.presentedViewController == nil && self.host.view.window === self.window && STWebH5Crl.topVisibleController(in: self.window) === self.host }
      XCTAssertNil(host.presentedViewController)
      XCTAssertTrue(host.view.window === window)
      XCTAssertTrue(STWebH5Crl.topVisibleController(in: window) === host)
      let id = try makePackage(style == .fullScreen ? "mini_foreign_full" : "mini_foreign_over")
      let plugin = StminiFlutterPlugin()
      plugin.handle(FlutterMethodCall(methodName: "initialize", arguments: ["bridgeContext": ["packageName": "com.almanac.lite"]])) { XCTAssertNil($0) }
      let opened = expectation(description: "owned SDK Mini before foreign overlay")
      plugin.handle(FlutterMethodCall(methodName: "openMini", arguments: ["link": "mini://\(id)"])) { result in XCTAssertNil(result); opened.fulfill() }
      wait(for: [opened], timeout: 3)
      until { (self.host.presentedViewController as? UINavigationController)?.viewControllers.first.flatMap { ($0 as? STWebMiniprogramCrl)?.isKeepAliveRuntimeUsable } == true && self.host.presentedViewController?.isBeingPresented == false }
      let navigation = try XCTUnwrap(host.presentedViewController as? STWebNavigationController)
      let root = try XCTUnwrap(navigation.viewControllers.first as? STWebMiniprogramCrl)
      let config = STWebConfig(webMode: .local); config.bridgePolicy = .localMini
      let child = STWebH5Crl(url: "stmini://\(id).stmini.local/second.html", config: config, isChild: true)
      child.isMiniInternalPage = true; navigation.pushViewController(child, animated: false)
      until { child.webView?.url?.path == "/second.html" && child.webView?.isLoading == false }
      let rootWeb = try XCTUnwrap(root.webView), childWeb = try XCTUnwrap(child.webView)
      let old = try XCTUnwrap(STWebBridgeEffectLease(webView: childWeb, generation: childWeb.bridgeDocumentGeneration))
      let foreign = UIViewController(); foreign.modalPresentationStyle = style
      let covered = expectation(description: "foreign owner covers actual Mini")
      navigation.present(foreign, animated: false) { covered.fulfill() }
      wait(for: [covered], timeout: 3)
      XCTAssertTrue(STWebH5Crl.topVisibleController(in: window) === foreign)
      guard let registry = UIApplication.shared.delegate as? FlutterPluginRegistry,
            let registrar = registry.registrar(forPlugin: "FifthMiniCoveredDetach-" + UUID().uuidString) else { XCTFail("Runner registrar required"); return }
      plugin.detachFromEngine(for: registrar)
      XCTAssertTrue(host.presentedViewController === navigation)
      XCTAssertTrue(STWebH5Crl.topVisibleController(in: window) === foreign, "Detach cannot dismiss a foreign descendant")
      XCTAssertFalse(root.isKeepAliveRuntimeUsable); XCTAssertFalse(old.isCurrent())
      for web in [rootWeb, childWeb] {
        XCTAssertFalse(web.hasNativeEffectAuthority)
        XCTAssertNil(STWebBridgeEffectLease(webView: web, generation: web.bridgeDocumentGeneration))
        XCTAssertNil(web.navigationDelegate); XCTAssertNil(web.uiDelegate)
      }
      let detachedClose = expectation(description: "old engine close is terminal without touching foreign UI")
      detachedClose.assertForOverFulfill = true
      plugin.handle(FlutterMethodCall(methodName: "closeMini", arguments: nil)) { result in
        XCTAssertEqual((result as? FlutterError)?.code, "cancelled"); detachedClose.fulfill()
      }
      wait(for: [detachedClose], timeout: 2)
      XCTAssertTrue(STWebH5Crl.topVisibleController(in: window) === foreign)
      let revealed = expectation(description: "foreign explicitly dismisses itself")
      foreign.dismiss(animated: false) { revealed.fulfill() }
      wait(for: [revealed], timeout: 3)
      until { self.host.presentedViewController == nil }
      XCTAssertNil(host.presentedViewController)
      XCTAssertFalse(old.isCurrent())
      // An expired retirement belongs to its captured nav/root, not whatever
      // foreground UI is presented after that original container is gone.
      let later = UIViewController(); host.present(later, animated: false)
      let drained = expectation(description: "retired owner callbacks drained")
      DispatchQueue.main.async { drained.fulfill() }; wait(for: [drained], timeout: 2)
      XCTAssertTrue(host.presentedViewController === later)
      let laterDismissed = expectation(description: "later foreign dismissal completes before next presentation style")
      later.dismiss(animated: false) { laterDismissed.fulfill() }
      wait(for: [laterDismissed], timeout: 3)
      until { self.host.presentedViewController == nil && self.host.view.window === self.window && STWebH5Crl.topVisibleController(in: self.window) === self.host }
      XCTAssertNil(host.presentedViewController)
      XCTAssertTrue(host.view.window === window)
      XCTAssertTrue(STWebH5Crl.topVisibleController(in: window) === host)
    }
  }


  func testQueuedMiniCloseRejectsForeignCoverageAddedBeforeConsumption() throws {
    let id = try makePackage("close_then_cover")
    let plugin = StminiFlutterPlugin()
    plugin.handle(FlutterMethodCall(methodName: "initialize", arguments: ["bridgeContext": ["packageName": "com.almanac.lite"]])) { XCTAssertNil($0) }
    let opened = expectation(description: "Mini is owned before queued close")
    plugin.handle(FlutterMethodCall(methodName: "openMini", arguments: ["link": "mini://\(id)"])) { result in XCTAssertNil(result); opened.fulfill() }
    wait(for: [opened], timeout: 3)
    until { (self.host.presentedViewController as? UINavigationController)?.viewControllers.first.flatMap { ($0 as? STWebMiniprogramCrl)?.isKeepAliveRuntimeUsable } == true && self.host.presentedViewController?.isBeingPresented == false }
    let navigation = try XCTUnwrap(host.presentedViewController as? STWebNavigationController)
    let root = try XCTUnwrap(navigation.viewControllers.first as? STWebMiniprogramCrl)
    let web = try XCTUnwrap(root.webView)
    let old = try XCTUnwrap(STWebBridgeEffectLease(webView: web, generation: web.bridgeDocumentGeneration))
    let rejected = expectation(description: "queued close expires once under newly added foreign owner")
    rejected.assertForOverFulfill = true
    plugin.handle(FlutterMethodCall(methodName: "closeMini", arguments: nil)) { result in
      XCTAssertEqual((result as? FlutterError)?.code, "cancelled"); rejected.fulfill()
    }
    XCTAssertFalse(web.hasNativeEffectAuthority)
    let foreign = UIViewController(); foreign.modalPresentationStyle = .overCurrentContext
    let covered = expectation(description: "foreign presentation added in original receipt turn")
    navigation.present(foreign, animated: false) { covered.fulfill() }
    wait(for: [covered, rejected], timeout: 3)
    XCTAssertTrue(host.presentedViewController === navigation)
    XCTAssertTrue(STWebH5Crl.topVisibleController(in: window) === foreign)
    XCTAssertFalse(old.isCurrent()); XCTAssertFalse(web.hasNativeEffectAuthority)
    XCTAssertNil(STWebBridgeEffectLease(webView: web, generation: web.bridgeDocumentGeneration))
    let left = expectation(description: "new foreign owner leaves itself")
    foreign.dismiss(animated: false) { left.fulfill() }
    wait(for: [left], timeout: 3)
    XCTAssertTrue(host.presentedViewController === navigation)
    XCTAssertFalse(old.isCurrent()); XCTAssertFalse(web.hasNativeEffectAuthority, "Cancelled close cannot silently fresh-grant the root")
    let explicitClose = expectation(description: "new explicit close may retire its now-uncovered original Mini")
    plugin.handle(FlutterMethodCall(methodName: "closeMini", arguments: nil)) { result in XCTAssertNil(result); explicitClose.fulfill() }
    wait(for: [explicitClose], timeout: 5)
    until { self.host.presentedViewController == nil }
  }


  private func installWarmEventRecorder(_ web: WKWebView) {
    XCTAssertEqual(js(web, "window.__warmEvents=[];window.CMSCallJsMessage=function(m){window.__warmEvents.push({method:m.method,params:m.params||{}})};true") as? Bool, true)
  }

  private func warmActivationEvents(_ web: WKWebView) throws -> [[String: Any]] {
    try XCTUnwrap(js(web, "window.__warmEvents.filter(m=>(m.method==='hostMiniRuntimeVisibilityChanged'&&m.params.hidden===false)||(m.method==='appShow'&&m.params.recoveryMode==='warm_reopen'))") as? [[String: Any]])
  }

  private func assertWarmPair(_ web: WKWebView, positiveDuration: Bool) throws {
    until { (self.js(web, "window.__warmEvents.filter(m=>(m.method==='hostMiniRuntimeVisibilityChanged'&&m.params.hidden===false)||(m.method==='appShow'&&m.params.recoveryMode==='warm_reopen')).length") as? Int) == 2 }
    let events = try warmActivationEvents(web)
    XCTAssertEqual(events.count, 2)
    XCTAssertEqual(events[0]["method"] as? String, "hostMiniRuntimeVisibilityChanged")
    XCTAssertEqual((events[0]["params"] as? [String: Any])?["hidden"] as? Bool, false)
    XCTAssertEqual(events[1]["method"] as? String, "appShow")
    let duration = try XCTUnwrap((events[1]["params"] as? [String: Any])?["backgroundDurationMs"] as? Int)
    if positiveDuration { XCTAssertGreaterThan(duration, 0, "Capture the hidden background interval before consuming it") }
    else { XCTAssertEqual(duration, 0, "An old visible-resume interval must never repeat on a foreground-only warm open") }
  }

  private func realFrameBoundary(_ web: WKWebView) {
    XCTAssertEqual(js(web, "window.__lifecycleFrame=false;requestAnimationFrame(function(){window.__lifecycleFrame=true});true") as? Bool, true)
    until { self.js(web, "window.__lifecycleFrame===true") as? Bool == true }
  }

  func testActualWarmLifecycleOrdersVisibilityBeforeResumeAndConsumesDurationOnce() throws {
    let id = try makePackage("warm_order")
    let first = try open(id)
    let web = try XCTUnwrap(first.webView)
    installWarmEventRecorder(web)
    let originalLease = try XCTUnwrap(STWebBridgeEffectLease(webView: web, generation: web.bridgeDocumentGeneration))
    NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
    // This native->WK query is submitted before another main-queue turn. It
    // proves appHide kept its immediate last-runnable-window submission.
    XCTAssertEqual(js(web, "window.__warmEvents.filter(m=>m.method==='appHide').length") as? Int, 1)
    NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
    realFrameBoundary(web)
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    until { (self.js(web, "window.__warmEvents.filter(m=>m.method==='appShow'&&m.params.recoveryMode==='visible_resume').length") as? Int) == 1 }
    let visibleDuration = try XCTUnwrap(js(web, "window.__warmEvents.find(m=>m.method==='appShow'&&m.params.recoveryMode==='visible_resume').params.backgroundDurationMs") as? Int)
    XCTAssertGreaterThan(visibleDuration, 0)
    XCTAssertEqual(js(web, "window.__warmEvents=[];true") as? Bool, true)
    close(first)
    XCTAssertFalse(web.hasNativeEffectAuthority); XCTAssertFalse(originalLease.isCurrent())
    let second = try open(id)
    XCTAssertTrue(second === first); XCTAssertTrue(second.webView === web)
    try assertWarmPair(web, positiveDuration: false)
    XCTAssertTrue(web.hasNativeEffectAuthority)
    XCTAssertNotNil(STWebBridgeEffectLease(webView: web, generation: web.bridgeDocumentGeneration))
    XCTAssertFalse(originalLease.isCurrent())

    // While A is cached, use B's actual visible WK animation frame as the
    // event-completion boundary for a real measured hidden background stay.
    XCTAssertEqual(js(web, "window.__warmEvents=[];true") as? Bool, true)
    close(second)
    let other = try open(try makePackage("warm_clock"))
    let clockWeb = try XCTUnwrap(other.webView)
    NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
    NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
    realFrameBoundary(clockWeb)
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    close(other)
    let third = try open(id)
    XCTAssertTrue(third === first); XCTAssertTrue(third.webView === web)
    try assertWarmPair(web, positiveDuration: true)
    XCTAssertEqual(js(web, "window.__warmEvents=[];true") as? Bool, true)
    close(third)
    let fourth = try open(id)
    XCTAssertTrue(fourth === first)
    try assertWarmPair(web, positiveDuration: false)
    XCTAssertFalse(originalLease.isCurrent())
    close(fourth)
  }

  func testActualQueuedWarmTicketRejectsCloseDocumentAndSessionExpiry() throws {
    let completionHost = WarmActivationCompletionHost()
    host = completionHost; window.rootViewController = completionHost; window.makeKeyAndVisible()
    for mutation in ["close", "document", "session"] {
      let id = try makePackage("warm_ticket_" + mutation)
      let first = try open(id)
      let web = try XCTUnwrap(first.webView)
      installWarmEventRecorder(web)
      let original = try XCTUnwrap(STWebBridgeEffectLease(webView: web, generation: web.bridgeDocumentGeneration))
      close(first)
      let intercepted = expectation(description: "real warm presentation completion before queued lifecycle delivery")
      completionHost.afterMiniCompletion = { root in
        XCTAssertTrue(root === first)
        XCTAssertTrue(root.webView === web)
        XCTAssertTrue(web.hasNativeEffectAuthority, "Positive native grant occurs only at the real completed presentation")
        let current = STWebBridgeEffectLease(webView: web, generation: web.bridgeDocumentGeneration)
        XCTAssertNotNil(current)
        if mutation == "close" { root.close() }
        if mutation == "document" { web.invalidateBridgeDocumentSession() }
        if mutation == "session" { NotificationCenter.default.post(name: Notification.Name("kSTLogoutSuccessNotification"), object: nil) }
        XCTAssertFalse(current?.isCurrent() ?? true)
        intercepted.fulfill()
      }
      STWebOpenHandler.openMiniprogram(name: id, config: STWebConfig(webMode: .online), crl: completionHost)
      wait(for: [intercepted], timeout: 5)
      let consumed = expectation(description: "original warm ticket consumed after invalidation")
      DispatchQueue.main.async { consumed.fulfill() }; wait(for: [consumed], timeout: 2)
      XCTAssertTrue(try warmActivationEvents(web).isEmpty, "Expired original context must not deliver either half of warm activation: \(mutation)")
      XCTAssertFalse(original.isCurrent())
      if mutation == "close" {
        XCTAssertFalse(web.hasNativeEffectAuthority)
        XCTAssertNil(STWebBridgeEffectLease(webView: web, generation: web.bridgeDocumentGeneration))
        until { self.host.presentedViewController == nil }
      } else {
        close(first)
      }
      store.removeAll()
      until { self.host.presentedViewController == nil }
    }
  }

}


private final class FifthTransitionContext: NSObject, UIViewControllerContextTransitioning {
  let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
  let from = UIViewController(), to = UIViewController()
  var cancelled = true
  var suppliesContextViews = false
  var didComplete: ((Bool) -> Void)?
  var isAnimated: Bool { true }
  var isInteractive: Bool { true }
  var transitionWasCancelled: Bool { cancelled }
  var presentationStyle: UIModalPresentationStyle { .custom }
  var targetTransform: CGAffineTransform { .identity }
  func updateInteractiveTransition(_ percentComplete: CGFloat) {}
  func finishInteractiveTransition() {}
  func cancelInteractiveTransition() { cancelled = true }
  func pauseInteractiveTransition() {}
  func completeTransition(_ didComplete: Bool) { self.didComplete?(didComplete) }
  func viewController(forKey key: UITransitionContextViewControllerKey) -> UIViewController? { key == .from ? from : to }
  func view(forKey key: UITransitionContextViewKey) -> UIView? { suppliesContextViews ? (key == .from ? from.view : to.view) : nil }
  func initialFrame(for vc: UIViewController) -> CGRect { containerView.bounds }
  func finalFrame(for vc: UIViewController) -> CGRect { containerView.bounds }
}

final class FifthBatchTransitionTests: XCTestCase {
  func testCustomPresentationUsesItsControllersWhenContextViewsAreAbsent() {
    let context = FifthTransitionContext()
    context.cancelled = false; context.suppliesContextViews = false
    let previousKey = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }.first { $0.isKeyWindow }
    let window = UIWindow(frame: UIScreen.main.bounds)
    let host = UIViewController(); window.rootViewController = host; window.makeKeyAndVisible()
    host.view.addSubview(context.containerView)
    context.from.view.frame = context.containerView.bounds
    context.to.view.frame = context.containerView.bounds
    context.containerView.addSubview(context.from.view)
    defer { window.isHidden = true; previousKey?.makeKeyAndVisible() }
    XCTAssertTrue(context.containerView.window === window)
    XCTAssertTrue(context.from.view.window === window)
    let animator = STWebTransAnimation(transType: .present)
    let done = expectation(description: "valid custom presentation without context views")
    context.didComplete = { succeeded in XCTAssertTrue(succeeded) }
    animator.completion = { type, succeeded in
      XCTAssertEqual(type, .present); XCTAssertTrue(succeeded)
      XCTAssertEqual(context.to.view.frame, context.containerView.bounds)
      done.fulfill()
    }
    animator.animateTransition(using: context)
    wait(for: [done], timeout: 3)
    animator.clearSnapshot()
    XCTAssertNil(animator.transitionBack); XCTAssertNil(animator.transitionShadow)
  }

  func testCancelledAnimationRestoresOwnerGeometryAndReportsCancellation() {
    let context = FifthTransitionContext()
    context.from.view.frame = context.containerView.bounds
    context.to.view.frame = context.containerView.bounds
    context.containerView.addSubview(context.to.view); context.containerView.addSubview(context.from.view)
    let originalFrame = context.from.view.frame
    let animator = STWebTransAnimation(transType: .dismiss)
    let done = expectation(description: "cancelled native animation")
    context.didComplete = { succeeded in XCTAssertFalse(succeeded) }
    animator.completion = { type, succeeded in
      XCTAssertEqual(type, .dismiss); XCTAssertFalse(succeeded)
      XCTAssertEqual(context.from.view.frame, originalFrame)
      XCTAssertEqual(context.from.view.transform, .identity)
      done.fulfill()
    }
    animator.animateTransition(using: context)
    wait(for: [done], timeout: 3)
    animator.clearSnapshot()
    XCTAssertNil(animator.transitionBack); XCTAssertNil(animator.transitionShadow)
  }
}

/// Real ZIPFoundation extraction and production installer, with synthetic data
/// only. The optional hooks inject cancellation/rename failure before commit;
/// they never choose the trusted installation directory.
final class SixthBatchPackageInstallTests: XCTestCase {
  private let miniId = "batch6_install_fixture"
  private var directory: URL { URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents/STMini/\(miniId)") }
  private var scratch: URL!
  override func setUpWithError() throws {
    scratch = FileManager.default.temporaryDirectory.appendingPathComponent("batch6-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
  }
  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: directory)
    try? FileManager.default.removeItem(at: scratch)
  }
  private func archive(_ version: String, id: String? = nil, entry: String = "index.html") throws -> URL {
    let source = scratch.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try JSONSerialization.data(withJSONObject: ["miniId": id ?? miniId, "version": version, "entry": entry, "icon": "pixel.png", "updateself": "1", "ishome": "0", "channel": "fixture"]).write(to: source.appendingPathComponent("mini-manifest.json"))
    try Data("<html>batch6 version \(version)</html>".utf8).write(to: source.appendingPathComponent("index.html"))
    try XCTUnwrap(RendererFixture.files["pixel.png"]).write(to: source.appendingPathComponent("pixel.png"))
    let zip = scratch.appendingPathComponent("\(UUID().uuidString).zip")
    try FileManager.default.zipItem(at: source, to: zip, shouldKeepParent: false)
    return zip
  }
  @discardableResult private func install(_ zip: URL, floor: String? = nil, force: Bool = false,
      operation: MiniPackageOperation = MiniPackageOperation(), before: (() -> Void)? = nil,
      move: ((URL, URL) throws -> Void)? = nil) throws -> STDirectMiniPackageInstallOutcome {
    let done = expectation(description: "production asynchronous ZIP install")
    var result: Result<STDirectMiniPackageInstallOutcome, Error>?
    STWebResourceManager.installDirectMiniPackage(archivePath: zip.path, name: miniId, minimumVersion: floor,
        requiresNewerVersion: force, operation: operation, beforeCommit: before, moveItem: move) {
      result = $0; done.fulfill()
    }
    wait(for: [done], timeout: 15)
    XCTAssertFalse(FileManager.default.fileExists(atPath: zip.path), "All archive outcomes dispose the transient input")
    return try XCTUnwrap(result).get()
  }
  func testFirstInstallUpgradeEqualAndOldArchivesNeverDowngrade() throws {
    try install(archive("1.0"))
    XCTAssertEqual(STWebResourceManager.installedMiniPackageVersion(name: miniId), "1.0")
    try install(archive("2.0"), floor: "2.0")
    XCTAssertEqual(STWebResourceManager.installedMiniPackageVersion(name: miniId), "2.0")
    let before = try Data(contentsOf: directory.appendingPathComponent(".st-mini-package.json"))
    for version in ["2.0", "1.0"] { try install(archive(version)) }
    XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent(".st-mini-package.json")), before)
    XCTAssertThrowsError(try install(archive("1.0"), force: true))
    XCTAssertEqual(STWebResourceManager.installedMiniPackageVersion(name: miniId), "2.0")
  }
  func testInvalidManifestFloorAndZipKeepVerifiedPackage() throws {
    try install(archive("1.0"))
    let before = try Data(contentsOf: directory.appendingPathComponent("index.html"))
    for zip in [try archive("2.0", id: "another_package"), try archive("NaN"), try archive("2.0", entry: "../outside.html")] {
      XCTAssertThrowsError(try install(zip))
    }
    XCTAssertThrowsError(try install(archive("2.0"), floor: "3.0"))
    let broken = scratch.appendingPathComponent("invalid.zip"); try Data("not a zip".utf8).write(to: broken)
    XCTAssertThrowsError(try install(broken))
    XCTAssertEqual(STWebResourceManager.installedMiniPackageVersion(name: miniId), "1.0")
    XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("index.html")), before)
  }
  func testCancelledUnpackAndFailedSecondRenameCannotReplacePackage() throws {
    try install(archive("1.0"))
    let operation = MiniPackageOperation()
    XCTAssertThrowsError(try install(archive("2.0"), operation: operation, before: { operation.cancel() }))
    var count = 0
    XCTAssertThrowsError(try install(archive("2.0"), move: { from, to in
      count += 1
      if count == 2 { throw URLError(.cannotWriteToFile) }
      try FileManager.default.moveItem(at: from, to: to)
    }))
    XCTAssertEqual(count, 2)
    XCTAssertEqual(STWebResourceManager.installedMiniPackageVersion(name: miniId), "1.0")
    XCTAssertThrowsError(try MiniPackageOperationCancelledProbe())
  }
  private func MiniPackageOperationCancelledProbe() throws {
    let operation = MiniPackageOperation(); operation.cancel()
    try operation.commit { XCTFail("cancelled owner may never enter commit") }
  }
  func testConcurrentSamePackageCommitRechecksWinnerAndPreservesNewest() throws {
    let first = try archive("1.0"), second = try archive("2.0")
    let ready = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
    let done = expectation(description: "overlapping per-package commits"); done.expectedFulfillmentCount = 2
    STWebResourceManager.installDirectMiniPackage(archivePath: first.path, name: miniId, beforeCommit: {
      ready.signal(); _ = release.wait(timeout: .now() + 10)
    }) { result in
      if case .failure(let error) = result { XCTFail("older validated transfer should retain newer package: \(error)") }
      done.fulfill()
    }
    XCTAssertEqual(ready.wait(timeout: .now() + 10), .success)
    STWebResourceManager.installDirectMiniPackage(archivePath: second.path, name: miniId) { result in
      if case .failure(let error) = result { XCTFail("newer install: \(error)") }
      release.signal(); done.fulfill()
    }
    wait(for: [done], timeout: 15)
    XCTAssertEqual(STWebResourceManager.installedMiniPackageVersion(name: miniId), "2.0")
  }
  private func archiveEntries(_ entries: [(String, Entry.EntryType)]) throws -> URL {
    let zip = scratch.appendingPathComponent("\(UUID().uuidString).zip")
    let archive = try XCTUnwrap(Archive(url: zip, accessMode: .create))
    for (path, type) in entries {
      let bytes = Data("synthetic".utf8)
      try archive.addEntry(with: path, type: type, uncompressedSize: Int64(bytes.count)) { position, count in
        Data(bytes.dropFirst(Int(position)).prefix(count))
      }
    }
    return zip
  }
  func testArchivePathsSymlinksDuplicateNamesAndByteBoundsRejectBeforeExtraction() throws {
    try install(archive("1.0"))
    let before = try Data(contentsOf: directory.appendingPathComponent("index.html"))
    let rejectedEntries: [[(String, Entry.EntryType)]] = [
      [("../outside.html", .file)], [("/absolute.html", .file)], [("link", .symlink)],
      [("same.html", .file), ("same.html", .file)], [("Case.html", .file), ("case.html", .file)]
    ]
    for entries in rejectedEntries {
      XCTAssertThrowsError(try install(archiveEntries(entries))) { error in
        XCTAssertEqual((error as NSError).code, 14)
      }
    }
    let huge = scratch.appendingPathComponent("sparse.zip")
    XCTAssertTrue(FileManager.default.createFile(atPath: huge.path, contents: nil))
    let handle = try FileHandle(forWritingTo: huge)
    try handle.truncate(atOffset: 80 * 1024 * 1024 + 1); try handle.close()
    XCTAssertThrowsError(try install(huge)) { XCTAssertEqual(($0 as NSError).code, 12) }
    let declared = try archiveEntries([("synthetic.bin", .file)])
    var bytes = try Data(contentsOf: declared)
    let header = try XCTUnwrap(bytes.range(of: Data([0x50, 0x4b, 0x01, 0x02])))
    var oversize = UInt32(80 * 1024 * 1024 + 1).littleEndian
    withUnsafeBytes(of: &oversize) { value in bytes.replaceSubrange((header.lowerBound + 24)..<(header.lowerBound + 28), with: value) }
    try bytes.write(to: declared)
    // Synthetic central-directory size declaration; no large decompression.
    XCTAssertThrowsError(try install(declared)) { XCTAssertEqual(($0 as NSError).code, 15) }
    XCTAssertEqual(STWebResourceManager.installedMiniPackageVersion(name: miniId), "1.0")
    XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("index.html")), before)
  }
  func testImmutableSnapshotRetainsOldBytesAcrossWeakInstallAndCleansLastConsumer() throws {
    try install(archive("1.0"))
    var root: MiniPackageSnapshot? = try MiniPackageSnapshot(miniId: miniId)
    let snapshotHome = try XCTUnwrap(root).home
    var child = root
    let oldFile = try XCTUnwrap(root?.resource("index.html"))
    let oldBytes = try Data(contentsOf: oldFile)
    try install(archive("2.0"))
    XCTAssertEqual(STWebResourceManager.installedMiniPackageVersion(name: miniId), "2.0")
    XCTAssertEqual(root?.version, "1.0")
    XCTAssertEqual(try Data(contentsOf: XCTUnwrap(child?.resource("index.html"))), oldBytes)
    var next: MiniPackageSnapshot? = try MiniPackageSnapshot(miniId: miniId)
    XCTAssertEqual(next?.version, "2.0")
    XCTAssertNotEqual(try Data(contentsOf: XCTUnwrap(next?.resource("index.html"))), oldBytes)
    var resourceLease = root?.resourceLease("index.html")
    XCTAssertNotNil(resourceLease)
    root = nil
    XCTAssertTrue(FileManager.default.fileExists(atPath: snapshotHome.path), "local child retains the original snapshot")
    child = nil
    XCTAssertTrue(FileManager.default.fileExists(atPath: snapshotHome.path), "an in-flight immutable resource lease retains its files")
    XCTAssertTrue(resourceLease?.isCurrent() == true)
    resourceLease = nil
    XCTAssertFalse(FileManager.default.fileExists(atPath: snapshotHome.path), "last native consumer or resource lease removes snapshot")
    let nextHome = try XCTUnwrap(next).home; next = nil
    XCTAssertFalse(FileManager.default.fileExists(atPath: nextHome.path))
    XCTAssertThrowsError(try MiniPackageSnapshot(miniId: "missing_snapshot_fixture"))
    try FileManager.default.removeItem(at: directory.appendingPathComponent("mini-manifest.json"))
    XCTAssertThrowsError(try MiniPackageSnapshot(miniId: miniId))
  }
  func testActualWKRetainsV1ResourceAndBridgeAfterWeakInstallThenColdLoadsV2() throws {
    try install(archive("1.0"))
    let prior = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }.first { $0.isKeyWindow }
    let window = UIWindow(frame: UIScreen.main.bounds), host = UIViewController()
    window.rootViewController = host; window.makeKeyAndVisible()
    defer { host.dismiss(animated: false); window.isHidden = true; prior?.makeKeyAndVisible() }
    func opened() throws -> STWebMiniprogramCrl {
      STWebOpenHandler.openMiniprogram(name: miniId, config: STWebConfig(webMode: .online), crl: host)
      let deadline = Date().addingTimeInterval(10)
      while Date() < deadline {
        if let navigation = host.presentedViewController as? STWebNavigationController,
           let root = navigation.viewControllers.first as? STWebMiniprogramCrl,
           root.isKeepAliveRuntimeUsable, root.webView?.hasNativeEffectAuthority == true, !navigation.isBeingPresented { return root }
        RunLoop.current.run(until: Date().addingTimeInterval(0.01))
      }
      throw URLError(.timedOut)
    }
    func evaluate(_ view: WKWebView, _ script: String) -> Any? {
      let done = expectation(description: "real WK snapshot bridge result"); var result: Any?
      view.evaluateJavaScript(script) { value, error in XCTAssertNil(error); result = value; done.fulfill() }
      wait(for: [done], timeout: 5); return result
    }
    let old = try opened(), oldView = try XCTUnwrap(old.webView)
    let oldURL = try XCTUnwrap(oldView.url)
    let oldResource = try XCTUnwrap(oldView.verifiedBoundResource(oldURL))
    let before = try Data(contentsOf: oldResource)
    try install(archive("2.0"))
    XCTAssertEqual(old.loadedMiniPackageVersion, "1.0")
    XCTAssertTrue(oldView.allowsLocalMiniBridge)
    XCTAssertEqual(try Data(contentsOf: XCTUnwrap(oldView.verifiedBoundResource(oldURL))), before)
    let fetched = expectation(description: "actual old WK reads immutable manifest after disk v2")
    if #available(iOS 14.0, *) {
      oldView.callAsyncJavaScript("return (await (await fetch('mini-manifest.json')).json()).version", arguments: [:], in: nil, in: .page) { result in
        switch result { case .success(let version): XCTAssertEqual(version as? String, "1.0"); case .failure(let error): XCTFail("\(error)") }
        fetched.fulfill()
      }
      wait(for: [fetched], timeout: 5)
    }
    _ = evaluate(oldView, "window.CMSJsCallBack=function(r){window.__snapshotReply=r};true")
    STWebApiManager.dealWithApiMessage(["method": "mini_getMiniPackageInfo", "params": ["methodId": "snapshot-v1"]], webView: oldView)
    let replyDeadline = Date().addingTimeInterval(5)
    var reply: [String: Any]?
    repeat { reply = evaluate(oldView, "window.__snapshotReply || null") as? [String: Any] } while reply == nil && Date() < replyDeadline
    XCTAssertEqual((reply?["data"] as? [String: Any])?["version"] as? String, "1.0")
    var route = STWebApiModel(dict: ["method": "mini_navigateTo", "params": ["path": "index.html", "methodId": "weak-child"]])
    route.webview = oldView
    XCTAssertEqual(STWebRouterApi().navigateTo(model: route)["code"] as? String, "1")
    let childDeadline = Date().addingTimeInterval(10)
    var localChild: STWebH5Crl?
    while Date() < childDeadline {
      if let child = old.navigationController?.topViewController as? STWebH5Crl,
         child.webView?.allowsLocalMiniBridge == true, child.webView.bridgeReplyDocumentToken != nil { localChild = child; break }
      RunLoop.current.run(until: Date().addingTimeInterval(0.01))
    }
    let child = try XCTUnwrap(localChild)
    XCTAssertEqual(child.webView.packageLocalPageURL(path: "index.html"), oldView.packageLocalPageURL(path: "index.html"))
    let childFetch = expectation(description: "real local child shares old snapshot after weak disk update")
    if #available(iOS 14.0, *) {
      child.webView.callAsyncJavaScript("return (await (await fetch('mini-manifest.json')).json()).version", arguments: [:], in: nil, in: .page) { result in
        switch result { case .success(let version): XCTAssertEqual(version as? String, "1.0"); case .failure(let error): XCTFail("\(error)") }
        childFetch.fulfill()
      }
      wait(for: [childFetch], timeout: 5)
    }
    _ = old.navigationController?.popToRootViewController(animated: false)
    let closed = expectation(description: "old root native close")
    old.close { closed.fulfill() }; wait(for: [closed], timeout: 10)
    let next = try opened()
    XCTAssertFalse(next === old); XCTAssertEqual(next.loadedMiniPackageVersion, "2.0")
  }
  func testPushedForceUpdateRejectsBeforePopAndAcceptsValidCurrentChild() throws {
    try install(archive("1.0"))
    let prior = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }.first { $0.isKeyWindow }
    let window = UIWindow(frame: UIScreen.main.bounds), host = UIViewController()
    window.rootViewController = host; window.makeKeyAndVisible()
    defer { host.dismiss(animated: false); window.isHidden = true; prior?.makeKeyAndVisible() }
    STWebOpenHandler.openMiniprogram(name: miniId, config: STWebConfig(webMode: .online), crl: host)
    let rootDeadline = Date().addingTimeInterval(10)
    var loaded: STWebMiniprogramCrl?
    while Date() < rootDeadline {
      if let navigation = host.presentedViewController as? STWebNavigationController,
         let root = navigation.viewControllers.first as? STWebMiniprogramCrl,
         root.isKeepAliveRuntimeUsable, root.webView?.allowsLocalMiniBridge == true,
         root.webView.bridgeReplyDocumentToken != nil, !navigation.isBeingPresented { loaded = root; break }
      RunLoop.current.run(until: Date().addingTimeInterval(0.01))
    }
    let root = try XCTUnwrap(loaded), navigation = try XCTUnwrap(root.navigationController)
    defer { root.prepareForNativeDismissal() }
    var route = STWebApiModel(dict: ["method": "mini_navigateTo", "params": ["path": "index.html"]]); route.webview = root.webView
    XCTAssertEqual(STWebRouterApi().navigateTo(model: route)["code"] as? String, "1")
    let childDeadline = Date().addingTimeInterval(10)
    var pushed: STWebH5Crl?
    while Date() < childDeadline {
      if let child = navigation.topViewController as? STWebH5Crl,
         child.webView?.allowsLocalMiniBridge == true, child.webView.bridgeReplyDocumentToken != nil,
         navigation.transitionCoordinator == nil { pushed = child; break }
      RunLoop.current.run(until: Date().addingTimeInterval(0.01))
    }
    let child = try XCTUnwrap(pushed), web = try XCTUnwrap(child.webView)
    func evaluate(_ script: String) -> Any? {
      let done = expectation(description: "pushed update result"); var answer: Any?
      web.evaluateJavaScript(script) { value, error in XCTAssertNil(error); answer = value; done.fulfill() }
      wait(for: [done], timeout: 5); return answer
    }
    _ = evaluate("window.CMSJsCallBack=r=>window.__forceUpdateReply=r;true")
    let stack = navigation.viewControllers.map(ObjectIdentifier.init)
    let parameters = (root.config.params ?? [:]) as NSDictionary
    let source = try XCTUnwrap(web.url), resource = try XCTUnwrap(web.verifiedBoundResource(source))
    let before = try Data(contentsOf: resource)
    for (index, invalid) in ["not a URL", "http://127.0.0.1:1/update.zip", "https://user:synthetic@foreign.invalid/update.zip", "https://foreign.invalid/update.zip#fragment"].enumerated() {
      _ = evaluate("window.__forceUpdateReply=null;true")
      STWebApiManager.dealWithApiMessage(["method": "mini_downloadMiniProgramUpdate", "params": ["methodId": "invalid-\(index)", "downloadUrl": invalid, "isforce": true]], webView: web)
      let deadline = Date().addingTimeInterval(5)
      var reply: [String: Any]?
      repeat { reply = evaluate("window.__forceUpdateReply || null") as? [String: Any] } while reply == nil && Date() < deadline
      XCTAssertEqual(reply?["code"] as? String, "0", invalid)
      XCTAssertEqual(navigation.viewControllers.map(ObjectIdentifier.init), stack, invalid)
      XCTAssertEqual((root.config.params ?? [:]) as NSDictionary, parameters, invalid)
      XCTAssertEqual(try Data(contentsOf: resource), before, invalid)
      XCTAssertFalse(root.skipsKeepAliveOnNextDismiss, invalid)
      XCTAssertTrue(web.allowsLocalMiniBridge, invalid)
    }
    let allowed = "https://127.0.0.1:1/update.zip"
    STWebApiManager.dealWithApiMessage(["method": "mini_downloadMiniProgramUpdate", "params": ["methodId": "valid-current-child", "downloadUrl": allowed, "isforce": true]], webView: web)
    XCTAssertTrue(navigation.topViewController === root, "Valid forced update may return to its own root")
    XCTAssertEqual(root.config.params?["downloadUrl"], allowed)
    XCTAssertTrue(root.skipsKeepAliveOnNextDismiss, "Valid original child must retain an actual acceptance positive")
    root.prepareForNativeDismissal() // cancels the controlled loopback transport immediately
  }
  func testResourceCallbacksReleasePackageLockBeforeMainMarkerValidation() throws {
    try install(archive("1.0"))
    let snapshot = try MiniPackageSnapshot(miniId: miniId)
    let lease = try XCTUnwrap(snapshot.resourceLease("index.html"))
    let url = try XCTUnwrap(URL(string: "stmini://\(miniId).stmini.local/index.html"))
    let view = BoundResourceLeaseWebView(lease: lease, url: url), task = ResourceCallbackProbeTask(url: url)
    defer { view.cleanup() }
    let handler = STWebSchemeHandler(), finished = expectation(description: "resource callback and main marker validation finish")
    var callbackChecks = 0, markerChecks = 0
    task.onCallback = {
      callbackChecks += 1
      XCTAssertTrue(Thread.isMainThread, "Delivery and WebKit stop must be serialized on main")
      // Probe from another worker first, with a finite wait. A regression that
      // holds the package lock across this callback fails here without ever
      // blocking main on that lock and disabling XCTest's own timeout.
      let available = DispatchSemaphore(value: 0)
      DispatchQueue.global(qos: .userInitiated).async {
        STWebResourceManager.withPackageTransaction(self.miniId) { () -> Void in
          _ = available.signal()
        }
      }
      let released = available.wait(timeout: .now() + 1) == .success
      XCTAssertTrue(released, "No package lock may cross a task callback")
      if released && Thread.isMainThread {
        XCTAssertNotNil(snapshot.resource("index.html"), "Equivalent main-thread marker identity validation remains live")
        markerChecks += 1
      }
    }
    task.onTerminal = { finished.fulfill() }
    handler.webView(view, start: task)
    wait(for: [finished], timeout: 10)
    XCTAssertEqual(task.responseCount, 1); XCTAssertEqual(task.dataCount, 1)
    XCTAssertEqual(task.finishCount, 1); XCTAssertEqual(task.failureCount, 0)
    XCTAssertEqual(callbackChecks, 3); XCTAssertEqual(markerChecks, 3)
    let responsive = expectation(description: "host main runloop remains responsive after delivery")
    DispatchQueue.main.async { responsive.fulfill() }; wait(for: [responsive], timeout: 2)
  }

  func testResourceStopDuringResponsePreventsLateDataAndTerminalWithoutAffectingNextTask() throws {
    try install(archive("1.0"))
    let snapshot = try MiniPackageSnapshot(miniId: miniId), handler = STWebSchemeHandler()
    let lease = try XCTUnwrap(snapshot.resourceLease("index.html"))
    let url = try XCTUnwrap(URL(string: "stmini://\(miniId).stmini.local/index.html"))
    let view = BoundResourceLeaseWebView(lease: lease, url: url)
    defer { view.cleanup() }
    let stopped = ResourceCallbackProbeTask(url: url), current = ResourceCallbackProbeTask(url: url)
    let stoppedAtBoundary = expectation(description: "original resource stopped at main response boundary")
    let nextFinished = expectation(description: "new resource task completes independently")
    stopped.onResponse = {
      XCTAssertTrue(Thread.isMainThread)
      handler.webView(view, stop: stopped)
      stoppedAtBoundary.fulfill()
      handler.webView(view, start: current)
    }
    stopped.onTerminal = { XCTFail("Stopped request must not receive any late terminal") }
    current.onTerminal = { nextFinished.fulfill() }
    handler.webView(view, start: stopped)
    wait(for: [stoppedAtBoundary, nextFinished], timeout: 10)
    XCTAssertEqual(stopped.responseCount, 1); XCTAssertEqual(stopped.dataCount, 0)
    XCTAssertEqual(stopped.finishCount, 0); XCTAssertEqual(stopped.failureCount, 0)
    XCTAssertEqual(current.responseCount, 1); XCTAssertEqual(current.dataCount, 1)
    XCTAssertEqual(current.finishCount, 1); XCTAssertEqual(current.failureCount, 0)
  }

  func testWarmExplicitUpdateIntentsKeepSameWKAndConsumeOnlyCurrentVisibleOwner() throws {
    try install(archive("1.0"))
    guard let registry = UIApplication.shared.delegate as? FlutterPluginRegistry,
          let plugin = registry.valuePublished(byPlugin: "StminiFlutterPlugin") as? StminiFlutterPlugin else { XCTFail("real registered plugin required"); return }
    var starts = 0
    XCTAssertNil(plugin.onListen(withArguments: nil) { value in
      if let event = value as? [String: Any], event["name"] as? String == "mini_download_started",
         (event["payload"] as? [String: Any])?["miniId"] as? String == self.miniId { starts += 1 }
    })
    defer { _ = plugin.onCancel(withArguments: nil) }
    let prior = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }.first { $0.isKeyWindow }
    let window = UIWindow(frame: UIScreen.main.bounds), host = UIViewController()
    window.rootViewController = host; window.makeKeyAndVisible()
    defer { STWebMiniProgramKeepAliveStore.shared.removeAll(); host.dismiss(animated: false); window.isHidden = true; prior?.makeKeyAndVisible() }
    func open(_ params: [String: String] = [:]) throws -> STWebMiniprogramCrl {
      STWebOpenHandler.openMiniprogram(name: miniId, config: STWebConfig(webMode: .online, params: params), crl: host)
      let deadline = Date().addingTimeInterval(10)
      while Date() < deadline {
        if let navigation = host.presentedViewController as? STWebNavigationController,
           let root = navigation.viewControllers.first as? STWebMiniprogramCrl,
           root.isKeepAliveRuntimeUsable, root.webView?.hasNativeEffectAuthority == true,
           !navigation.isBeingPresented, !navigation.isBeingDismissed { return root }
        RunLoop.current.run(until: Date().addingTimeInterval(0.01))
      }
      throw URLError(.timedOut)
    }
    func close(_ root: STWebMiniprogramCrl) {
      let done = expectation(description: "actual close before next warm intent")
      root.close { done.fulfill() }; wait(for: [done], timeout: 10)
      XCTAssertNil(host.presentedViewController)
    }
    func drain() {
      for _ in 0..<4 { let done = expectation(description: "bounded warm ticket/event queue drain"); DispatchQueue.main.async { done.fulfill() }; wait(for: [done], timeout: 2) }
    }
    let original = try open(), originalWK = try XCTUnwrap(original.webView)
    close(original)
    let endpoint = "https://127.0.0.1:1/controlled-update.zip"
    for (current, expectedDownload) in [("1.0", false), ("0.9", false), ("", true), ("2.0", true)] {
      var params = ["downloadUrl": endpoint, "minSupportVersion": "1.0"]
      if !current.isEmpty { params["currentVersion"] = current }
      let before = starts, resumed = try open(params)
      XCTAssertTrue(resumed === original); XCTAssertTrue(resumed.webView === originalWK)
      drain()
      XCTAssertEqual(starts - before, expectedDownload ? 1 : 0, "warm current=\(current)")
      XCTAssertEqual(resumed.loadedMiniPackageVersion, "1.0")
      XCTAssertTrue(resumed.webView.allowsLocalMiniBridge)
      close(resumed) // immediately cancels this exact loopback request/commit permission
      XCTAssertEqual(STWebResourceManager.installedMiniPackageVersion(name: miniId), "1.0")
    }
    // Use the real visible root but deterministically invalidate its original
    // queued activation before the main queue can consume the update intent.
    let resumed = try open(); drain()
    for boundary in ["close", "session"] {
      let before = starts
      resumed.prepareForKeepAliveReuse(config: STWebConfig(webMode: .online, params: ["downloadUrl": endpoint, "currentVersion": "2.0", "minSupportVersion": "1.0"]))
      resumed.setKeepAliveRuntimeHidden(false)
      if boundary == "close" { resumed.prepareForNativeDismissal() }
      else { STWebMiniProgramKeepAliveStore.shared.invalidateSession() }
      drain()
      XCTAssertEqual(starts, before, "expired queued warm intent must not start: \(boundary)")
      XCTAssertEqual(STWebResourceManager.installedMiniPackageVersion(name: miniId), "1.0")
      if boundary == "close" { resumed.setKeepAliveRuntimeHidden(false); drain() }
    }
  }

  func testSessionBoundaryCancelsEveryOriginalCommitPermission() throws {
    let old = MiniPackageOperation()
    STWebMiniProgramKeepAliveStore.shared.invalidateSession()
    XCTAssertThrowsError(try old.check())
    let fresh = MiniPackageOperation()
    XCTAssertNoThrow(try fresh.commit {})
  }
}

/// Holds a real native evaluator request at the final evaluator boundary. The
/// exact production script is later executed by real WK in a replacement
/// same-URL document. This is a controlled queue interleaving, not a claim that
/// an uninstrumented WebKit scheduler leak has been reproduced.
private final class HeldReplyDocumentWebView: STMiniWebView {
  var holdReplies = false
  var queuedReplies: [String] = []
  override var allowsHostSensitiveBridge: Bool { true }
  override func evaluateJavaScript(_ script: String, completionHandler: (@MainActor @Sendable (Any?, (any Error)?) -> Void)? = nil) {
    if holdReplies && script.contains("document.__stminiReplyDocument") && script.contains("CMSJsCallBack") {
      queuedReplies.append(script); completionHandler?(false, nil); return
    }
    super.evaluateJavaScript(script, completionHandler: completionHandler)
  }
  func executeQueuedReply(_ script: String, completion: @escaping @MainActor @Sendable (Any?, (any Error)?) -> Void) {
    super.evaluateJavaScript(script, completionHandler: completion)
  }
}

final class SixthBatchDocumentReplyTests: XCTestCase {
  func testActualWKOriginalDocumentReceivesAndSameURLReplacementRejectsQueuedReply() throws {
    let view = HeldReplyDocumentWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), configuration: WKWebViewConfiguration())
    // Only the test's inert HTML loading ignores navigation policy. Reply
    // generation and the injected document marker are production code.
    view.navigationDelegate = nil
    defer { view.cleanup() }
    func evaluate(_ script: String) throws -> Any? {
      let done = expectation(description: "actual WK reply document observation"); var answer: Any?; var failure: Error?
      view.evaluateJavaScript(script) { value, error in answer = value; failure = error; done.fulfill() }
      wait(for: [done], timeout: 5)
      if let failure { throw failure }; return answer
    }
    func load(_ name: String) throws -> String {
      view.loadHTMLString("<html><body>\(name)<script>window.replyDocumentName='\(name)';window.receivedReplies=[];window.CMSJsCallBack=r=>window.receivedReplies.push(r);</script></body></html>", baseURL: URL(string: "https://fixture.invalid/same-document"))
      let deadline = Date().addingTimeInterval(8)
      while Date() < deadline {
        if (try? evaluate("window.replyDocumentName")) as? String == name,
           let token = try? evaluate("document.__stminiReplyDocument"), let token = token as? String { return token }
        RunLoop.current.run(until: Date().addingTimeInterval(0.01))
      }
      throw URLError(.timedOut)
    }
    func drain() { let done = expectation(description: "queued native callback reached evaluator"); DispatchQueue.main.async { done.fulfill() }; wait(for: [done], timeout: 2) }
    let originalToken = try load("original")
    STWebApiManager.callBack(["code": "1", "data": ["synthetic": "original"]], method: "fixture_reply", methodId: "positive", webView: view, documentToken: originalToken)
    drain()
    XCTAssertEqual(try evaluate("window.receivedReplies.length") as? Int, 1)
    let originalURL = view.url
    view.holdReplies = true
    STWebApiManager.callBack(["code": "1", "data": ["synthetic": "old queued payload"]], method: "fixture_reply", methodId: "obsolete", webView: view, documentToken: originalToken)
    drain()
    let oldScript = try XCTUnwrap(view.queuedReplies.first)
    XCTAssertEqual(view.queuedReplies.count, 1)
    let replacementToken = try load("replacement")
    XCTAssertEqual(view.url, originalURL)
    XCTAssertNotEqual(replacementToken, originalToken, "Every real document must generate a fresh marker")
    let consumed = expectation(description: "exact production old script executed in replacement WK global")
    view.executeQueuedReply(oldScript) { value, error in XCTAssertNil(error); XCTAssertEqual(value as? Bool, false); consumed.fulfill() }
    wait(for: [consumed], timeout: 5)
    XCTAssertEqual(try evaluate("window.receivedReplies.length") as? Int, 0)
    view.holdReplies = false
    STWebApiManager.callBack(["code": "1", "data": ["synthetic": "fresh"]], method: "fixture_reply", methodId: "fresh-positive", webView: view, documentToken: replacementToken)
    drain()
    XCTAssertEqual(try evaluate("window.receivedReplies.length") as? Int, 1, "The new document must accept its own fresh response")
  }
}

/// Supplies a real verified immutable lease to the production resource handler.
/// Only the WebView binding is a controlled endpoint; reads, package locking,
/// stop state and all WebKit-task delivery code remain production code.
private final class BoundResourceLeaseWebView: STMiniWebView {
  private let suppliedLease: MiniPackageSnapshot.ResourceLease
  private let suppliedURL: URL
  init(lease: MiniPackageSnapshot.ResourceLease, url: URL) {
    suppliedLease = lease; suppliedURL = url
    super.init(frame: .zero, configuration: WKWebViewConfiguration())
  }
  required init?(coder: NSCoder) { fatalError("test endpoint") }
  override func boundResourceLease(_ target: URL) -> MiniPackageSnapshot.ResourceLease? {
    target == suppliedURL && suppliedLease.isCurrent() ? suppliedLease : nil
  }
  override func isCurrentBoundResourceLease(_ lease: MiniPackageSnapshot.ResourceLease) -> Bool {
    lease.fileURL == suppliedLease.fileURL && lease.isCurrent()
  }
}

private final class ResourceCallbackProbeTask: NSObject, WKURLSchemeTask {
  let request: URLRequest
  var responseCount = 0, dataCount = 0, finishCount = 0, failureCount = 0
  var onCallback: (() -> Void)?
  var onResponse: (() -> Void)?
  var onTerminal: (() -> Void)?
  init(url: URL) { request = URLRequest(url: url) }
  func didReceive(_ response: URLResponse) {
    responseCount += 1; onCallback?(); onResponse?()
  }
  func didReceive(_ data: Data) { dataCount += 1; onCallback?() }
  func didFinish() { finishCount += 1; onCallback?(); onTerminal?() }
  func didFailWithError(_ error: Error) { failureCount += 1; onCallback?(); onTerminal?() }
}
