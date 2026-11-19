import Foundation
import CryptoKit

/// SDK-only persistent domains. The subject is supplied by the native,
/// already-verified document dispatcher, never by a JavaScript parameter.
public enum STMiniScopedStorage {
  public static func defaults(for verifiedSubject: String) -> UserDefaults? {
    guard !verifiedSubject.isEmpty, verifiedSubject.utf8.count <= 1024 else { return nil }
    let encoded = SHA256.hash(data: Data(verifiedSubject.utf8)).map { String(format: "%02x", $0) }.joined()
    return UserDefaults(suiteName: "com.fsst.stmini.storage.v1.\(encoded)")
  }
}
