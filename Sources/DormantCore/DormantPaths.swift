import Foundation

public struct DormantPaths {
  public let root: URL
  public let registry: URL
  public let store: URL

  public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
    root = home.appendingPathComponent(".dormant")
    registry = root.appendingPathComponent("registry.sqlite")
    store = root.appendingPathComponent("store")
  }
}
