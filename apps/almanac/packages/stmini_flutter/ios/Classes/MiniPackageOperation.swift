import Foundation

/// A transfer may unpack in the background, but only its original, uncancelled
/// owner may commit. Cancellation and the complete directory transaction share
/// one lock, so no partially checked operation can write after cancellation.
final class MiniPackageOperation: NSObject {
  private static let registryLock = NSLock()
  private static let active = NSHashTable<MiniPackageOperation>.weakObjects()
  override init() {
    super.init()
    Self.registryLock.lock(); defer { Self.registryLock.unlock() }
    Self.active.add(self)
  }

  static func cancelAll() {
    registryLock.lock(); let operations = active.allObjects; registryLock.unlock()
    operations.forEach { $0.cancel() }
  }
  private let lock = NSRecursiveLock()
  private var valid = true

  func cancel() {
    lock.lock(); defer { lock.unlock() }
    valid = false
  }

  func check() throws {
    lock.lock(); defer { lock.unlock() }
    guard valid else { throw URLError(.cancelled) }
  }

  func commit<T>(_ body: () throws -> T) throws -> T {
    lock.lock(); defer { lock.unlock() }
    try check()
    return try body()
  }
}
