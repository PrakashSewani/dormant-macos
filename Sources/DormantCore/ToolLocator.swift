import Foundation

/// Hardcoded lookup of external executables (D-015). No user configuration; a tool outside
/// these locations is a hard error, never a fallback.
public enum ToolLocator {
  public static let visualStudioCodeDirectories = [
    URL(fileURLWithPath: "/Applications/Visual Studio Code.app/Contents/Resources/app/bin")
  ]

  public static func url(
    for name: String,
    home: URL = FileManager.default.homeDirectoryForCurrentUser,
    extraDirectories: [URL] = []
  ) -> URL? {
    for directory in extraDirectories + searchDirectories(home: home) {
      let candidate = directory.appendingPathComponent(name)
      if FileManager.default.isExecutableFile(atPath: candidate.path) {
        return candidate
      }
    }
    return nil
  }

  public static func searchDirectories(
    home: URL = FileManager.default.homeDirectoryForCurrentUser
  ) -> [URL] {
    var directories: [URL] = nvmNodeDirectories(home: home)
    directories += [
      home.appendingPathComponent(".volta/bin"),
      home.appendingPathComponent(".bun/bin"),
      home.appendingPathComponent(".cargo/bin"),
      home.appendingPathComponent(".asdf/shims"),
      home.appendingPathComponent(".local/bin"),
      home.appendingPathComponent("go/bin"),
    ]
    directories += [
      "/opt/homebrew/bin",
      "/opt/homebrew/sbin",
      "/usr/local/bin",
      "/usr/local/sbin",
      "/usr/local/share/dotnet",
      "/usr/bin",
      "/bin",
      "/usr/sbin",
      "/sbin",
    ].map { URL(fileURLWithPath: $0) }
    return directories.filter { isDirectory($0) }
  }

  public static func notFoundMessage(
    for name: String,
    home: URL = FileManager.default.homeDirectoryForCurrentUser
  ) -> String {
    let searched = searchDirectories(home: home).map(\.path).joined(separator: ", ")
    return "'\(name)' was not found. Searched: \(searched)"
  }

  private static func nvmNodeDirectories(home: URL) -> [URL] {
    let versions = home.appendingPathComponent(".nvm/versions/node")
    let entries =
      (try? FileManager.default.contentsOfDirectory(at: versions, includingPropertiesForKeys: nil))
      ?? []

    return
      entries
      .filter { $0.lastPathComponent.hasPrefix("v") }
      .sorted { versionKey($1).lexicographicallyPrecedes(versionKey($0)) }
      .map { $0.appendingPathComponent("bin") }
      .filter { isDirectory($0) }
  }

  private static func versionKey(_ url: URL) -> [Int] {
    url.lastPathComponent.dropFirst().split(separator: ".").compactMap { Int($0) }
  }

  private static func isDirectory(_ url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
      && isDirectory.boolValue
  }
}
