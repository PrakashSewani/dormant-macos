import CryptoKit
import Foundation

public enum Checksums {
  public static func sha256(ofFileAt url: URL) throws -> String {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var hasher = SHA256()
    while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
      hasher.update(data: chunk)
    }
    return hex(hasher.finalize())
  }

  public static func sha256(of data: Data) -> String {
    hex(SHA256.hash(data: data))
  }

  private static func hex(_ digest: SHA256Digest) -> String {
    digest.map { String(format: "%02x", $0) }.joined()
  }
}
