import Foundation

public struct CloneEngine {
  private let gitExecutable: URL

  public init(gitExecutable: URL = URL(fileURLWithPath: "/usr/bin/git")) {
    self.gitExecutable = gitExecutable
  }

  public static func normalizedRemote(_ text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !trimmed.contains(where: { $0.isWhitespace }) else {
      return nil
    }
    if trimmed.hasPrefix("git@") {
      let rest = trimmed.dropFirst(4)
      guard let colon = rest.firstIndex(of: ":"), colon < rest.index(before: rest.endIndex) else {
        return nil
      }
      return trimmed
    }
    guard let url = URL(string: trimmed),
      let scheme = url.scheme?.lowercased(),
      ["http", "https", "ssh", "git", "file"].contains(scheme),
      url.host != nil || scheme == "file"
    else {
      return nil
    }
    return trimmed
  }

  public static func folderName(fromRemote remote: String) -> String? {
    var path: String
    if remote.hasPrefix("git@") {
      let rest = remote.dropFirst(4)
      guard let colon = rest.firstIndex(of: ":") else { return nil }
      path = String(rest[rest.index(after: colon)...])
    } else {
      path = URL(string: remote)?.path ?? remote
    }
    while path.hasSuffix("/") {
      path = String(path.dropLast())
    }
    if path.hasSuffix(".git") {
      path = String(path.dropLast(4))
    }
    guard let name = path.split(separator: "/").last, !name.isEmpty else { return nil }
    return String(name)
  }

  public func clone(remote: String, into folder: URL) throws -> URL {
    guard let name = Self.folderName(fromRemote: remote) else {
      throw DormantError.cloneFailed(stderr: "Could not derive a folder name from \(remote)")
    }
    let destination = folder.appendingPathComponent(name)
    guard !FileManager.default.fileExists(atPath: destination.path) else {
      throw DormantError.cloneFailed(stderr: "\(destination.path) already exists")
    }
    let result = try ProcessRunner().run(
      executable: gitExecutable,
      arguments: ["clone", "--", remote],
      cwd: folder)
    guard result.exitCode == 0 else {
      let detail = result.stderr.isEmpty ? result.stdout : result.stderr
      throw DormantError.cloneFailed(stderr: detail.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    return destination
  }
}
