import Foundation

/// Immutable files for one running Mini. A weak update changes the installed
/// package for the next launch, never the files served to an existing root or
/// its local child pages. The final native consumer removes this private copy.
final class MiniPackageSnapshot {
  let home: URL
  let miniId: String
  let version: String
  let entry: String
  private struct FileStamp: Equatable {
    let inode: UInt64
    let size: UInt64
    let modified: Date
  }
  private let resourceStamps: [String: FileStamp]
  private static func stamp(_ url: URL) -> FileStamp? {
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
          attributes[.type] as? FileAttributeType == .typeRegular,
          let inode = attributes[.systemFileNumber] as? NSNumber,
          let size = attributes[.size] as? NSNumber,
          let modified = attributes[.modificationDate] as? Date else { return nil }
    return FileStamp(inode: inode.uint64Value, size: size.uint64Value, modified: modified)
  }
  let identity: STWebMiniPackageIdentity

  init(miniId: String) throws {
    let sourceHome = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    let createdHome = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
      .appendingPathComponent("stmini-runtime-\(UUID().uuidString)", isDirectory: true)
    let identity = try STWebResourceManager.withPackageTransaction(miniId) { () throws -> STWebMiniPackageIdentity in
      guard let identity = STWebMiniPackageIdentity.read(miniId: miniId, home: sourceHome) else {
        throw LocalPackageInventory.Failure.invalid
      }
      let parent = createdHome.appendingPathComponent("Documents/STMini", isDirectory: true)
      do {
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: sourceHome.appendingPathComponent("Documents/STMini/\(miniId)"),
            to: parent.appendingPathComponent(miniId, isDirectory: true))
        guard STWebMiniPackageIdentity.read(miniId: miniId, home: createdHome) == identity,
              STWebMiniPackageIdentity.read(miniId: miniId, home: sourceHome) == identity else {
          throw LocalPackageInventory.Failure.invalid
        }
        return identity
      } catch {
        try? FileManager.default.removeItem(at: createdHome)
        throw error
      }
    }
    var stamps: [String: FileStamp] = [:]
    let directory = createdHome.appendingPathComponent("Documents/STMini/\(miniId)", isDirectory: true)
    guard let files = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
      try? FileManager.default.removeItem(at: createdHome); throw LocalPackageInventory.Failure.invalid
    }
    for case let url as URL in files {
      if let stamp = Self.stamp(url) { stamps[String(url.path.dropFirst(directory.path.count + 1))] = stamp }
    }
    home = createdHome; self.miniId = miniId; version = identity.version; entry = identity.entry; self.identity = identity
    resourceStamps = stamps
  }

  /// Retains the immutable directory without retaining any lock. A resource
  /// worker can therefore finish reading after its WebView starts teardown,
  /// while the separate current-owner check still prevents late delivery.
  struct ResourceLease {
    let snapshot: MiniPackageSnapshot
    let path: String
    let fileURL: URL
    func isCurrent() -> Bool { snapshot.resource(path) == fileURL }
  }

  func resourceLease(_ path: String) -> ResourceLease? {
    guard let file = resource(path) else { return nil }
    return ResourceLease(snapshot: self, path: path, fileURL: file)
  }

  func resource(_ path: String) -> URL? {
    guard let resource = try? LocalPackageInventory(home: home).verifiedResource(miniId: miniId,
        version: version, entry: entry, path: path, check: {}),
        let expected = resourceStamps[path], Self.stamp(resource) == expected else { return nil }
    return resource
  }

  deinit { try? FileManager.default.removeItem(at: home) }
}
