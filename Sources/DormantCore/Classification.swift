import Foundation

public enum ProjectEcosystem: Sendable {
  case node
  case python
  case rust
  case dotnet
  case go
  case unknown

  public var slug: String {
    switch self {
    case .node: return "node"
    case .python: return "python"
    case .rust: return "rust"
    case .dotnet: return "dotnet"
    case .go: return "go"
    case .unknown: return "unknown"
    }
  }
}

public struct RegenerablePath: Sendable {
  public let url: URL
  public let relativePath: String
  public let matchedRule: String
  public let sizeBytes: Int
}

public struct ProjectClassification: Sendable {
  public let root: URL
  public let ecosystems: Set<ProjectEcosystem>
  public let regenerable: [RegenerablePath]

  public var totalRegenerableBytes: Int {
    regenerable.reduce(0) { $0 + $1.sizeBytes }
  }
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

  public func classify(projectAt root: URL) -> ProjectClassification {
    let root = root.standardizedFileURL
    var manifestNames = Set<String>()
    Self.discoverManifests(in: root, found: &manifestNames)

    var activeRules: [ClassificationRule] = []
    var ecosystems = Set<ProjectEcosystem>()
    for rule in ClassificationRules.all where manifestNames.contains(where: rule.detects) {
      activeRules.append(rule)
      ecosystems.insert(rule.ecosystem)
    }
    if ecosystems.isEmpty {
      ecosystems.insert(.unknown)
    }

    var regenerable: [RegenerablePath] = []
    Self.collect(in: root, root: root, activeRules: activeRules, into: &regenerable)
    return ProjectClassification(root: root, ecosystems: ecosystems, regenerable: regenerable)
  }

  public func revalidate(_ path: RegenerablePath, projectAt root: URL) -> Bool {
    let root = root.standardizedFileURL
    let url = path.url.standardizedFileURL
    guard Self.relativePath(of: url, to: root) == path.relativePath else { return false }
    guard let (rule, pattern) = ClassificationRules.pattern(withID: path.matchedRule) else {
      return false
    }
    guard pattern.matches(fileName: url.lastPathComponent) else { return false }
    let parent = url.deletingLastPathComponent()
    let rootResolved = root.resolvingSymlinksInPath()
    let parentResolved = parent.resolvingSymlinksInPath()
    guard Self.isInside(root: rootResolved, child: parentResolved) else { return false }
    guard Self.kindMatches(pattern, at: url) else { return false }
    return Self.matchesScope(
      pattern,
      rule: rule,
      parentFileNames: Self.fileNames(in: parent),
      parentURL: parent,
      root: root
    )
  }

  private static func discoverManifests(in dir: URL, found: inout Set<String>) {
    let fm = FileManager.default
    let children = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
    for child in children {
      let name = child.lastPathComponent
      guard let type = Self.fileType(at: child) else { continue }
      if type == .typeDirectory {
        if name.hasPrefix(".") || ClassificationRules.discoverySkipNames.contains(name) { continue }
        discoverManifests(in: child, found: &found)
      } else if type == .typeRegular {
        if ClassificationRules.all.contains(where: { $0.detects(fileName: name) }) {
          found.insert(name)
        }
      }
    }
  }

  private static func collect(
    in dir: URL,
    root: URL,
    activeRules: [ClassificationRule],
    into result: inout [RegenerablePath]
  ) {
    let fm = FileManager.default
    let children = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []

    var candidates: [(url: URL, type: FileAttributeType)] = []
    var fileNames = Set<String>()
    for child in children {
      guard let type = Self.fileType(at: child) else { continue }
      switch type {
      case .typeDirectory, .typeSymbolicLink:
        candidates.append((child.standardizedFileURL, type))
      case .typeRegular:
        candidates.append((child.standardizedFileURL, type))
        fileNames.insert(child.lastPathComponent)
      default:
        continue
      }
    }

    for candidate in candidates {
      let name = candidate.url.lastPathComponent
      if name == ".git" { continue }
      var matched = false
      for rule in activeRules {
        for pattern in rule.patterns {
          guard pattern.matches(fileName: name),
            matchesScope(
              pattern,
              rule: rule,
              parentFileNames: fileNames,
              parentURL: dir,
              root: root
            ),
            kindMatches(pattern, at: candidate.url)
          else { continue }
          result.append(
            RegenerablePath(
              url: candidate.url,
              relativePath: relativePath(of: candidate.url, to: root),
              matchedRule: ClassificationRules.patternID(rule: rule, pattern: pattern),
              sizeBytes: SizeAccounting.totalBytes(at: candidate.url)
            )
          )
          matched = true
          break
        }
        if matched { break }
      }
      if !matched, candidate.type == .typeDirectory {
        collect(in: candidate.url, root: root, activeRules: activeRules, into: &result)
      }
    }
  }

  private static func matchesScope(
    _ pattern: RegenerablePattern,
    rule: ClassificationRule,
    parentFileNames: Set<String>,
    parentURL: URL,
    root: URL
  ) -> Bool {
    switch pattern.scope {
    case .anywhereInProject:
      return true
    case .projectRoot:
      return parentURL.standardizedFileURL.path == root.standardizedFileURL.path
    case .manifestSibling:
      return parentFileNames.contains(where: rule.anchors)
    }
  }

  private static func kindMatches(_ pattern: RegenerablePattern, at url: URL) -> Bool {
    guard let type = fileType(at: url) else { return false }
    switch type {
    case .typeDirectory, .typeSymbolicLink:
      return true
    case .typeRegular:
      return pattern.isSuffix
    default:
      return false
    }
  }

  private static func fileType(at url: URL) -> FileAttributeType? {
    let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
    return attrs?[.type] as? FileAttributeType
  }

  private static func fileNames(in dir: URL) -> Set<String> {
    let fm = FileManager.default
    let children = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
    var names = Set<String>()
    for child in children {
      guard let type = fileType(at: child) else { continue }
      if type == .typeDirectory { continue }
      names.insert(child.lastPathComponent)
    }
    return names
  }

  private static func relativePath(of url: URL, to root: URL) -> String {
    let rootComponents = root.standardizedFileURL.pathComponents
    let urlComponents = url.standardizedFileURL.pathComponents
    guard urlComponents.count >= rootComponents.count else { return "" }
    return urlComponents.dropFirst(rootComponents.count).joined(separator: "/")
  }

  private static func isInside(root: URL, child: URL) -> Bool {
    let rootComponents = root.standardizedFileURL.pathComponents
    let childComponents = child.standardizedFileURL.pathComponents
    guard childComponents.count >= rootComponents.count else { return false }
    return Array(childComponents.prefix(rootComponents.count)) == rootComponents
  }
}
