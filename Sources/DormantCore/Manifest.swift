import Foundation

public enum ManifestFileKind: String, Codable, Sendable {
  case core
  case unclassified

  static func classify(path: String) -> ManifestFileKind {
    let components = path.split(separator: "/")
    if components.contains(".git") {
      return .core
    }
    let fileName = components.last.map(String.init) ?? path
    if ClassificationRules.all.contains(where: { $0.detects(fileName: fileName) }) {
      return .core
    }
    let lowered = fileName.lowercased()
    if coreNames.contains(lowered) || lockfileNames.contains(lowered) {
      return .core
    }
    if lowered.hasPrefix("readme") || lowered.hasPrefix("license")
      || lowered.hasPrefix("changelog") || lowered.hasPrefix("contributing")
    {
      return .core
    }
    let ext = (fileName as NSString).pathExtension.lowercased()
    return coreExtensions.contains(ext) ? .core : .unclassified
  }

  private static let coreNames: Set<String> = [
    "copying", "notice", "authors", "codeowners", "makefile", "dockerfile", "gemfile", "rakefile",
    "procfile", "brewfile", ".gitignore", ".gitattributes", ".editorconfig", ".npmrc", ".nvmrc",
    ".python-version", ".ruby-version", ".tool-versions", ".env", ".env.example",
  ]

  private static let lockfileNames: Set<String> = [
    "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock",
    "npm-shrinkwrap.json", "poetry.lock", "uv.lock", "pipfile.lock", "cargo.lock", "gemfile.lock",
    "go.sum", "packages.lock.json", "podfile.lock", "composer.lock", "flake.lock",
  ]

  private static let coreExtensions: Set<String> = [
    "swift", "m", "h", "mm", "c", "cpp", "cc", "hpp", "cs", "fs", "fsx", "vb", "java", "kt",
    "kts", "scala", "go", "rs", "py", "pyi", "rb", "php", "js", "mjs", "cjs", "jsx", "ts", "tsx",
    "vue", "svelte", "html", "htm", "css", "scss", "sass", "less", "json", "yaml", "yml", "toml",
    "xml", "plist", "md", "markdown", "rst", "adoc", "txt", "tex", "sql", "graphql", "gql",
    "proto", "sh", "bash", "zsh", "fish", "ps1", "bat", "cmd", "lua", "r", "jl", "cmake", "mk",
    "gradle", "sbt", "ini", "cfg", "conf", "properties",
  ]
}

public struct ManifestFile: Codable, Sendable {
  public let path: String
  public let size: Int
  public let sha256: String
  public let kind: ManifestFileKind
}

public struct ManifestProjectInfo: Codable, Sendable {
  public let id: String
  public let name: String
  public let originalPath: String
  public let ecosystems: [String]
  public let archivedAt: String
}

public struct ManifestGitInfo: Codable, Sendable {
  public let isRepo: Bool
  public let head: String?
  public let branch: String?
  public let remote: String?
  public let dirty: Bool
  public let modifiedCount: Int
  public let untrackedCount: Int
}

public struct ManifestTarballInfo: Codable, Sendable {
  public let name: String
  public let size: Int
  public let sha256: String
  public let fileCount: Int
  public let uncompressedSize: Int
}

public struct ArchiveManifest: Codable, Sendable {
  public let manifestVersion: Int
  public let project: ManifestProjectInfo
  public let git: ManifestGitInfo
  public let tarball: ManifestTarballInfo
  public let files: [ManifestFile]
}
