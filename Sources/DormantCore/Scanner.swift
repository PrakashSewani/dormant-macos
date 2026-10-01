import Foundation

public struct ScanReport: Sendable {
  public let added: [ProjectRecord]
  public let updated: [ProjectRecord]
  public let missing: [ProjectRecord]
  public let reappeared: [ProjectRecord]
}

public struct Scanner {
  private let registry: Registry
  private let gitInspector: GitInspector
  private let excludedDirectories: [String]

  public init(
    registry: Registry,
    gitInspector: GitInspector = GitInspector(),
    excludedDirectories: [URL] = [DormantPaths().store]
  ) {
    self.registry = registry
    self.gitInspector = gitInspector
    self.excludedDirectories = excludedDirectories.map { $0.standardizedFileURL.path }
  }

  public func scan(roots: [URL], maxDepth: Int = 3) throws -> ScanReport {
    var added: [ProjectRecord] = []
    var updated: [ProjectRecord] = []
    var reappeared: [ProjectRecord] = []
    for root in roots {
      try visit(
        root.standardizedFileURL,
        depth: 0,
        maxDepth: maxDepth,
        added: &added,
        updated: &updated,
        reappeared: &reappeared
      )
    }
    let missing = try registry.allProjects().filter {
      $0.state == .active && !FileManager.default.fileExists(atPath: $0.path)
    }
    return ScanReport(added: added, updated: updated, missing: missing, reappeared: reappeared)
  }

  @discardableResult
  public func register(projectAt dir: URL) throws -> ProjectRecord? {
    let dir = dir.standardizedFileURL
    guard let manifests = detectProject(at: dir) else { return nil }
    return try upsert(at: dir, manifests: manifests).record
  }

  @discardableResult
  public func importDirectory(at dir: URL) throws -> ScanReport {
    let dir = dir.standardizedFileURL
    _ = try registry.upsertDirectory(path: dir.path, name: dir.lastPathComponent)
    try registry.markDirectoryScanned(path: dir.path)
    return try scan(roots: [dir])
  }

  private func visit(
    _ dir: URL,
    depth: Int,
    maxDepth: Int,
    added: inout [ProjectRecord],
    updated: inout [ProjectRecord],
    reappeared: inout [ProjectRecord]
  ) throws {
    let manifests = detectProject(at: dir)
    if let manifests {
      let record = try upsert(at: dir, manifests: manifests)
      switch record.kind {
      case .added: added.append(record.record)
      case .updated: updated.append(record.record)
      case .reappeared: reappeared.append(record.record)
      }
      return
    }
    guard depth < maxDepth else { return }
    for child in childDirectories(of: dir) {
      try visit(
        child,
        depth: depth + 1,
        maxDepth: maxDepth,
        added: &added,
        updated: &updated,
        reappeared: &reappeared
      )
    }
  }

  private func detectProject(at dir: URL) -> [String]? {
    let children =
      (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
    var manifests: [String] = []
    var hasGit = false
    for child in children {
      let name = child.lastPathComponent
      if name == ".git" {
        hasGit = true
        continue
      }
      guard fileType(at: child) == .typeRegular else { continue }
      if ClassificationRules.all.contains(where: { $0.detects(fileName: name) }) {
        manifests.append(name)
      }
    }
    if hasGit || !manifests.isEmpty {
      return manifests
    }
    return nil
  }

  private func upsert(
    at dir: URL,
    manifests: [String]
  ) throws -> (kind: Bucket, record: ProjectRecord) {
    let path = dir.standardizedFileURL.path
    let existing = try registry.project(path: path)
    let remote: String?
    if case .repository(let status) = gitInspector.check(root: dir) {
      remote = status.remote
    } else {
      remote = nil
    }
    var record = try registry.upsertProject(
      name: dir.lastPathComponent,
      path: path,
      ecosystem: primaryEcosystem(manifestNames: manifests),
      gitRemote: remote
    )
    try registry.markScanned(id: record.id)
    if existing?.state == .dormant {
      try registry.setState(.active, id: record.id)
      record = (try registry.project(id: record.id)) ?? record
      return (.reappeared, record)
    }
    return existing == nil ? (.added, record) : (.updated, record)
  }

  private enum Bucket {
    case added
    case updated
    case reappeared
  }

  private func primaryEcosystem(manifestNames: [String]) -> ProjectEcosystem {
    let classifier = Classifier()
    var best: (rank: Int, ecosystem: ProjectEcosystem)?
    for name in manifestNames {
      let ecosystem = classifier.ecosystem(forManifestNamed: name)
      let rank: Int
      switch ecosystem {
      case .rust: rank = 0
      case .node: rank = 1
      case .python: rank = 2
      case .dotnet: rank = 3
      case .go: rank = 4
      case .unknown: rank = 5
      }
      if best == nil || rank < (best?.rank ?? Int.max) {
        best = (rank, ecosystem)
      }
    }
    return best?.ecosystem ?? .unknown
  }

  private func childDirectories(of dir: URL) -> [URL] {
    let children =
      (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
    var result: [URL] = []
    for child in children {
      let name = child.lastPathComponent
      if name.hasPrefix(".") || ClassificationRules.discoverySkipNames.contains(name) { continue }
      let standardized = child.standardizedFileURL
      if excludedDirectories.contains(standardized.path) { continue }
      if fileType(at: child) == .typeDirectory {
        result.append(standardized)
      }
    }
    return result
  }

  private func fileType(at url: URL) -> FileAttributeType? {
    let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
    return attrs?[.type] as? FileAttributeType
  }
}
