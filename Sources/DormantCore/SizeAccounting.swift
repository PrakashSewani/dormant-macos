import Foundation

public enum SizeAccounting {
  public static func totalBytes(at url: URL) -> Int {
    guard let type = fileType(at: url) else { return 0 }
    switch type {
    case .typeRegular:
      let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
      return attrs?[.size] as? Int ?? 0
    case .typeDirectory:
      let fm = FileManager.default
      let children = (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
      return children.reduce(0) { $0 + totalBytes(at: $1) }
    default:
      return 0
    }
  }

  private static func fileType(at url: URL) -> FileAttributeType? {
    let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
    return attrs?[.type] as? FileAttributeType
  }
}
