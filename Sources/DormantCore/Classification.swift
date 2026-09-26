import Foundation

public enum ProjectEcosystem: Sendable {
  case node
  case python
  case rust
  case dotnet
  case go
  case unknown
}

public struct Classifier {
  public init() {}

  public func ecosystem(forManifestNamed name: String) -> ProjectEcosystem {
    let lowered = name.lowercased()
    switch lowered {
    case "package.json":
      return .node
    case "pyproject.toml", "requirements.txt":
      return .python
    case "cargo.toml":
      return .rust
    case "go.mod":
      return .go
    default:
      if lowered.hasSuffix(".csproj") || lowered.hasSuffix(".sln") {
        return .dotnet
      }
      return .unknown
    }
  }
}
