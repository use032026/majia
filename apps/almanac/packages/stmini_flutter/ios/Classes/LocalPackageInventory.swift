import Foundation

/// Read-only, derived extraction of pinned STWebResourceManager's manifest,
/// installed-record and registry checks. No WebKit, ZIP, installer or cache.
public final class LocalPackageInventory {
  public enum Failure: Error { case unavailable, invalid, identityInvalid }
  private let home: URL
  private let manager = FileManager.default

  /// The plugin passes only its system home. Independent native tests may use
  /// a private temporary home; no MethodChannel argument can select this URL.
  public init(home: URL) { self.home = home }

  public func read(check: () throws -> Void) throws -> [[String: String]] {
    try check()
    let base = home.standardizedFileURL.resolvingSymlinksInPath()
    try check()
    guard try attributes(base)?[.type] as? FileAttributeType == .typeDirectory else { throw Failure.unavailable }
    // Anchor in the trusted home before examining Documents. Resolving an
    // untrusted parent first would silently re-anchor outside the container.
    let documents = base.appendingPathComponent("Documents", isDirectory: true)
    guard let parent = try attributes(documents) else { try check(); return [] }
    guard parent[.type] as? FileAttributeType == .typeDirectory,
          documents.resolvingSymlinksInPath().path == documents.path else { throw Failure.unavailable }
    let root = documents.appendingPathComponent("STMini", isDirectory: true)
    guard let rootAttributes = try attributes(root) else { try check(); return [] }
    guard rootAttributes[.type] as? FileAttributeType == .typeDirectory,
          root.resolvingSymlinksInPath().path == root.path else { throw Failure.unavailable }
    try check()
    let children: [URL]
    do { children = try manager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: []).filter { !$0.lastPathComponent.hasPrefix(".") } }
    catch { throw Failure.unavailable }
    guard children.count <= 256 else { throw Failure.unavailable }
    var result = [[String: String]]()
    for directory in children {
      try check()
      do {
        if let item = try readPackage(directory, check: check) { result.append(item) }
      } catch let failure as Failure {
        if case .unavailable = failure { throw failure }
        // Malformed local candidates are absent from the validated inventory.
      } catch { /* A candidate that cannot be read is invalid, never repaired. */ }
    }
    try check()
    return result.sorted { $0["miniId"]! < $1["miniId"]! }
  }

  /// Shared renderer boundary; a native factory supplies the trusted system home.
  public func verifiedPackage(miniId: String, version: String, entry: String? = nil,
                              check: () throws -> Void) throws -> [String: String] {
    guard let item = try read(check: check).first(where: { $0["miniId"] == miniId && $0["version"] == version }),
          entry == nil || Self.exact(item["entry"] ?? "", entry!) else { throw Failure.unavailable }
    return item
  }

  public func verifiedResource(miniId: String, version: String, entry: String,
                               path: String, check: () throws -> Void) throws -> URL {
    do { _ = try verifiedPackage(miniId: miniId, version: version, entry: entry, check: check) }
    catch {
      // A cancelled/expired request cannot invalidate a later view generation.
      try check()
      throw Failure.identityInvalid
    }
    let directory = home.standardizedFileURL.resolvingSymlinksInPath()
      .appendingPathComponent("Documents/STMini", isDirectory: true).appendingPathComponent(miniId, isDirectory: true)
    guard try regularPath(directory, path, check: check) else { throw Failure.invalid }
    try check()
    return directory.appendingPathComponent(path)
  }

  private func readPackage(_ directory: URL, check: () throws -> Void) throws -> [String: String]? {
    let id = directory.lastPathComponent
    guard Self.matches(id, "[a-z0-9][a-z0-9_-]{0,63}"),
          try attributes(directory)?[.type] as? FileAttributeType == .typeDirectory,
          directory.resolvingSymlinksInPath().path == directory.path else { return nil }
    let record = try json(directory.appendingPathComponent(".st-mini-package.json"), check: check)
    let manifest = try json(directory.appendingPathComponent("mini-manifest.json"), check: check)
    guard try string(record, "miniId") == id, try string(manifest, "miniId") == id else { throw Failure.invalid }
    let version = try string(manifest, "version")
    guard Self.matches(version, "[0-9]{1,9}(\\.[0-9]{1,9}){0,7}"),
          try string(record, "version") == version else { throw Failure.invalid }
    let entry = try string(manifest, "entry")
    guard try Self.exact(string(record, "entry"), entry), try regularPath(directory, entry, check: check) else { throw Failure.invalid }
    let icon = try string(manifest, "icon", missing: "")
    guard try icon.isEmpty || regularPath(directory, icon, check: check) else { throw Failure.invalid }
    let channel = try string(manifest, "channel", missing: "")
    guard channel.utf16.count <= 128, try Self.exact(string(record, "channel", missing: ""), channel) else { throw Failure.invalid }
    for key in ["updateself", "ishome"] {
      guard ["", "0", "1"].contains(try string(manifest, key, missing: "")) else { throw Failure.invalid }
    }
    let declaredName = try string(manifest, "miniName", missing: "")
    let name = declaredName.isEmpty ? id : declaredName
    guard name.utf16.count <= 256 else { throw Failure.invalid }
    try check()
    return ["miniId": id, "miniName": name, "version": version, "entry": entry, "icon": icon]
  }

  private func attributes(_ url: URL) throws -> [FileAttributeKey: Any]? {
    do { return try manager.attributesOfItem(atPath: url.path) }
    catch let error as NSError {
      if error.domain == NSCocoaErrorDomain && [NSFileReadNoSuchFileError, NSFileNoSuchFileError].contains(error.code) { return nil }
      throw error
    }
  }

  private func json(_ url: URL, check: () throws -> Void) throws -> [String: Any] {
    try check()
    guard let info = try attributes(url), info[.type] as? FileAttributeType == .typeRegular,
          url.resolvingSymlinksInPath().path == url.path,
          let size = info[.size] as? NSNumber, size.uint64Value <= 65536 else { throw Failure.invalid }
    guard let stream = InputStream(url: url) else { throw Failure.invalid }
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while true {
      try check()
      let count = stream.read(&buffer, maxLength: buffer.count)
      guard count >= 0 else { throw Failure.invalid }
      if count == 0 { break }
      data.append(contentsOf: buffer.prefix(count))
      guard data.count <= 65536 else { throw Failure.invalid }
    }
    try check()
    guard try attributes(url)?[.type] as? FileAttributeType == .typeRegular,
          url.resolvingSymlinksInPath().path == url.path,
          String(data: data, encoding: .utf8) != nil,
          let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Failure.invalid }
    return object
  }

  private func string(_ json: [String: Any], _ key: String, missing: String? = nil) throws -> String {
    if let value = json[key] {
      guard let text = value as? String else { throw Failure.invalid }
      return text
    }
    if let fallback = missing { return fallback }
    throw Failure.invalid
  }

  private func regularPath(_ directory: URL, _ path: String, check: () throws -> Void) throws -> Bool {
    guard Self.safePath(path) else { return false }
    let parts = path.split(separator: "/", omittingEmptySubsequences: false)
    var current = directory
    for (index, part) in parts.enumerated() {
      try check()
      current.appendPathComponent(String(part))
      let expected: FileAttributeType = index == parts.count - 1 ? .typeRegular : .typeDirectory
      guard try attributes(current)?[.type] as? FileAttributeType == expected,
            current.resolvingSymlinksInPath().path == current.path else { return false }
    }
    return current.resolvingSymlinksInPath().path.hasPrefix(directory.path + "/")
  }

  public static func safePath(_ path: String) -> Bool {
    guard !path.isEmpty, path.utf16.count <= 1024,
          !path.unicodeScalars.contains(where: { $0.value < 32 || (127...159).contains($0.value) || "\\:%?#".unicodeScalars.contains($0) }) else { return false }
    let parts = path.split(separator: "/", omittingEmptySubsequences: false)
    return parts.count <= 16 && parts.allSatisfy { !$0.isEmpty && $0.utf16.count <= 128 && $0 != "." && $0 != ".." }
  }

  /// Contract identity fields compare UTF-16 code units, not Swift's Unicode
  /// canonical-equivalence equality. This matches Kotlin/Dart wire semantics.
  private static func exact(_ left: String, _ right: String) -> Bool {
    left.utf16.elementsEqual(right.utf16)
  }

  private static func matches(_ text: String, _ pattern: String) -> Bool {
    guard let range = text.range(of: pattern, options: .regularExpression) else { return false }
    return range == text.startIndex..<text.endIndex
  }
}
