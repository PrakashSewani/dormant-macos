import Foundation

struct TempProject {
  let root: URL

  init() throws {
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent("dormant-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  }

  func directory(_ relative: String) throws {
    try FileManager.default.createDirectory(
      at: root.appendingPathComponent(relative),
      withIntermediateDirectories: true
    )
  }

  func file(_ relative: String, contents: String = "") throws {
    let url = root.appendingPathComponent(relative)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data(contents.utf8).write(to: url)
  }

  func file(_ relative: String, byteCount: Int) throws {
    let url = root.appendingPathComponent(relative)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data(repeating: 0, count: byteCount).write(to: url)
  }

  func symlink(_ relative: String, to destination: URL) throws {
    let url = root.appendingPathComponent(relative)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try FileManager.default.createSymbolicLink(at: url, withDestinationURL: destination)
  }

  func destroy() {
    try? FileManager.default.removeItem(at: root)
  }
}
