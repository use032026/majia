import Foundation
import WebKit

/// Derived local-resource origin/MIME/cancellation subset of pinned STWebResourceManager
/// and STWebSchemeHandler. No positive cache, downloader, file URL or remote fallback.
public final class LocalMiniResource: NSObject, WKURLSchemeHandler {
  public let miniId: String
  public let version: String
  public let entry: String
  private let inventory: LocalPackageInventory
  private let queue: OperationQueue = {
    let value = OperationQueue(); value.name = "stmini.local-renderer.resources"
    value.maxConcurrentOperationCount = 4; return value
  }()
  private final class Request {
    let task: WKURLSchemeTask
    private let lock = NSLock()
    private var cancelled = false
    init(_ task: WKURLSchemeTask) { self.task = task }
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    func check() throws {
      lock.lock(); let stopped = cancelled; lock.unlock()
      if stopped { throw LocalPackageInventory.Failure.unavailable }
    }
  }
  // Main queue is the sole owner of task state and every WebKit callback.
  private var active = [ObjectIdentifier: Request]()
  private var closed = false
  public var origin: String { "stmini://\(miniId).stmini.local" }
  public var entryURL: URL { url(entry)! }
  public var mainResourceDelivered: ((URL) -> Void)?
  public var identityInvalid: (() -> Void)?

  public init(inventory: LocalPackageInventory, miniId: String, version: String, entry: String) {
    self.inventory = inventory; self.miniId = miniId; self.version = version; self.entry = entry
  }
  public func url(_ path: String) -> URL? {
    var value = URLComponents(); value.scheme = "stmini"; value.host = "\(miniId).stmini.local"; value.path = "/" + path
    return value.url
  }
  public func path(_ url: URL) -> String? {
    Self.decodePath(url, scheme: "stmini", host: "\(miniId).stmini.local")
  }
  public func isHTML(_ url: URL) -> Bool {
    guard let value = path(url) else { return false }
    return ["html", "htm"].contains((value as NSString).pathExtension.lowercased())
  }
  public static func decodePath(_ url: URL, scheme: String, host: String) -> String? {
    guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
          parts.scheme == scheme, parts.host == host, parts.user == nil, parts.password == nil,
          parts.port == nil, parts.query == nil, parts.percentEncodedPath.hasPrefix("/"),
          !parts.percentEncodedPath.hasPrefix("//") else { return nil }
    let encoded = String(parts.percentEncodedPath.dropFirst())
    guard encoded.range(of: "%2[fF]|%5[cC]|%25", options: .regularExpression) == nil,
          let decoded = encoded.removingPercentEncoding,
          LocalPackageInventory.safePath(decoded) else { return nil }
    return decoded
  }
  public func beginNavigation() {
    dispatchPrecondition(condition: .onQueue(.main))
    active.values.forEach { $0.cancel() }
  }
  public func close() {
    dispatchPrecondition(condition: .onQueue(.main))
    closed = true; active.values.forEach { $0.cancel() }; mainResourceDelivered = nil; identityInvalid = nil
  }
  public func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
    if !Thread.isMainThread {
      DispatchQueue.main.async { self.webView(webView, start: urlSchemeTask) }; return
    }
    guard !closed, active.count < 4, let url = urlSchemeTask.request.url,
          urlSchemeTask.request.httpMethod == "GET", let path = path(url) else {
      urlSchemeTask.didFailWithError(Self.failure()); return
    }
    let key = ObjectIdentifier(urlSchemeTask as AnyObject), request = Request(urlSchemeTask)
    active[key] = request
    queue.addOperation { [weak self, request] in
      guard let self else { return }
      let outcome = Result { () throws -> Data in
        return try STWebResourceManager.withPackageTransaction(self.miniId) {
        let deadline = ProcessInfo.processInfo.systemUptime + 4
        let check = {
          try request.check()
          if ProcessInfo.processInfo.systemUptime >= deadline { throw LocalPackageInventory.Failure.unavailable }
        }
        let file = try self.inventory.verifiedResource(miniId: self.miniId, version: self.version,
                                                     entry: self.entry, path: path, check: check)
        let info = try FileManager.default.attributesOfItem(atPath: file.path)
        guard let size = info[.size] as? NSNumber, size.int64Value >= 0, size.int64Value <= 8 * 1024 * 1024,
              let input = InputStream(url: file) else { throw LocalPackageInventory.Failure.invalid }
        let count = size.intValue
        var bytes = Data(count: count)
        input.open(); defer { input.close() }
        try bytes.withUnsafeMutableBytes { raw in
          var offset = 0
          while offset < count {
            try check()
            guard let pointer = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { throw Self.failure() }
            let read = input.read(pointer.advanced(by: offset), maxLength: min(65536, count - offset))
            guard read > 0 else { throw Self.failure() }
            offset += read
          }
        }
        var extra: UInt8 = 0
        guard input.read(&extra, maxLength: 1) == 0 else { throw Self.failure() }
        let after = try self.inventory.verifiedResource(miniId: self.miniId, version: self.version,
                                                       entry: self.entry, path: path, check: check)
        guard after == file,
              (try FileManager.default.attributesOfItem(atPath: file.path)[.size] as? NSNumber)?.intValue == count else { throw Self.failure() }
        try check(); return bytes
        }
      }
      DispatchQueue.main.async { [self, request] in
        // Delivery, stop and terminal are serialized here. A cancelled task
        // retains its slot until its worker and immutable bytes are released.
        defer { self.active.removeValue(forKey: key) }
        guard self.active[key] === request, !self.closed, (try? request.check()) != nil else { return }
        guard (try? self.inventory.verifiedPackage(miniId: self.miniId, version: self.version, entry: self.entry, check: { try request.check() })) != nil else {
          request.task.didFailWithError(Self.failure()); self.identityInvalid?(); return
        }
        switch outcome {
        case .success(let bytes):
          let mime = Self.mime(path)
          let headers = ["Content-Type": mime + (Self.isText(mime) ? "; charset=utf-8" : ""),
                         "Content-Length": String(bytes.count), "Content-Security-Policy": Self.csp(self.origin),
                         "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff"]
          guard let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers) else {
            request.task.didFailWithError(Self.failure()); return
          }
          request.task.didReceive(response); request.task.didReceive(bytes); request.task.didFinish()
          self.mainResourceDelivered?(url)
        case .failure(let error):
          request.task.didFailWithError(Self.failure())
          if case LocalPackageInventory.Failure.identityInvalid = error { self.identityInvalid?() }
        }
      }
    }
  }
  public func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
    if !Thread.isMainThread { DispatchQueue.main.async { self.webView(webView, stop: urlSchemeTask) }; return }
    active[ObjectIdentifier(urlSchemeTask as AnyObject)]?.cancel()
  }
  public static func csp(_ origin: String) -> String {
    "default-src stmini:; script-src stmini:; style-src stmini:; img-src stmini:; font-src stmini:; connect-src 'none'; frame-src 'none'; child-src 'none'; worker-src 'none'; object-src 'none'; form-action 'none'; base-uri 'none'"
  }
  public static func mime(_ path: String) -> String {
    switch (path as NSString).pathExtension.lowercased() {
    case "html", "htm": return "text/html"
    case "css": return "text/css"
    case "js", "mjs": return "application/javascript"
    case "json": return "application/json"
    case "svg": return "image/svg+xml"
    case "png": return "image/png"
    case "jpg", "jpeg": return "image/jpeg"
    case "gif": return "image/gif"
    case "webp": return "image/webp"
    case "ico": return "image/x-icon"
    case "woff": return "font/woff"
    case "woff2": return "font/woff2"
    case "ttf": return "font/ttf"
    case "otf": return "font/otf"
    default: return "application/octet-stream"
    }
  }
  private static func isText(_ mime: String) -> Bool {
    mime.hasPrefix("text/") || ["application/javascript", "application/json", "image/svg+xml"].contains(mime)
  }
  private static func failure() -> NSError {
    NSError(domain: "STMini.LocalResource", code: 403, userInfo: [NSLocalizedDescriptionKey: "Local resource unavailable"])
  }
}
