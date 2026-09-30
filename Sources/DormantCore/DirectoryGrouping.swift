import Foundation

/// Groups projects under the deepest imported directory that contains them (D-017).
public enum DirectoryGrouping {
  public static func deepestDirectory(
    for path: String,
    in directories: [DirectoryRecord]
  ) -> DirectoryRecord? {
    let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
    var deepest: DirectoryRecord?
    for directory in directories {
      let root = directory.path.hasSuffix("/") ? directory.path : directory.path + "/"
      guard standardized.hasPrefix(root) || standardized == directory.path else { continue }
      if let current = deepest, current.path.count >= directory.path.count { continue }
      deepest = directory
    }
    return deepest
  }
}
