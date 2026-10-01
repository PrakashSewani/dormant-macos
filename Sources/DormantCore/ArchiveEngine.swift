import Foundation

public struct ArchiveWarning: Sendable {
  public let modifiedCount: Int
  public let untrackedCount: Int
  public let gitStateUnknown: Bool
}

public struct ArchiveOutcome: Sendable {
  public let projectID: String
  public let storePath: URL
  public let manifestPath: URL
  public let archiveSizeBytes: Int
  public let reclaimedBytes: Int
  public let workingCopyRemoved: Bool
}

public struct ArchiveEngine {
  private let classifier: Classifier
  private let gitInspector: GitInspector
  private let storeDirectory: URL
  private let tarExecutable: URL

  public init(
    classifier: Classifier = Classifier(),
    gitInspector: GitInspector = GitInspector(),
    storeDirectory: URL = DormantPaths().store,
    tarExecutable: URL = URL(fileURLWithPath: "/usr/bin/tar")
  ) {
    self.classifier = classifier
    self.gitInspector = gitInspector
    self.storeDirectory = storeDirectory
    self.tarExecutable = tarExecutable
  }

  public func gitWarning(root: URL) -> ArchiveWarning? {
    switch gitInspector.check(root: root) {
    case .notARepository:
      return nil
    case .unavailable:
      return ArchiveWarning(modifiedCount: 0, untrackedCount: 0, gitStateUnknown: true)
    case .repository(let status):
      guard status.isDirty else { return nil }
      return ArchiveWarning(
        modifiedCount: status.modifiedCount,
        untrackedCount: status.untrackedCount,
        gitStateUnknown: false
      )
    }
  }

  public func archive(project: ProjectRecord, registry: Registry) throws -> ArchiveOutcome {
    let fm = FileManager.default
    let root = URL(fileURLWithPath: project.path).standardizedFileURL
    guard try registry.archive(projectID: project.id) == nil else {
      throw DormantError.archiveExists
    }
    guard fm.fileExists(atPath: root.path) else { throw DormantError.notAProject }

    let gitState = gitInspector.check(root: root)

    let cleaner = CleanEngine(classifier: classifier)
    let cleanPlan = cleaner.plan(root: root)
    _ = cleaner.execute(plan: cleanPlan)

    let walk = try collectTree(root: root)

    let projectStore = storeDirectory.appendingPathComponent(project.id, isDirectory: true)
    let tarball = projectStore.appendingPathComponent("core.tar.gz")
    let manifestURL = projectStore.appendingPathComponent("manifest.json")
    try fm.createDirectory(at: projectStore, withIntermediateDirectories: true)

    let runner = ProcessRunner()
    do {
      let created = try runner.run(
        executable: tarExecutable,
        arguments: ["-czf", tarball.path, "-C", root.path, "."]
      )
      guard created.exitCode == 0 else {
        throw DormantError.tarFailed(stderr: created.stderr)
      }
      try verifyArchive(tarball: tarball, expected: walk.entries, runner: runner)
    } catch {
      try? fm.removeItem(at: projectStore)
      throw error
    }

    let tarballSize = (try? fm.attributesOfItem(atPath: tarball.path))?[.size] as? Int ?? 0
    let tarballHash = try Checksums.sha256(ofFileAt: tarball)
    let manifest = ArchiveManifest(
      manifestVersion: 1,
      project: ManifestProjectInfo(
        id: project.id,
        name: project.name,
        originalPath: project.path,
        ecosystems: detectedEcosystems(in: root),
        archivedAt: ISO8601DateFormatter().string(from: Date())
      ),
      git: gitInfo(from: gitState),
      tarball: ManifestTarballInfo(
        name: "core.tar.gz",
        size: tarballSize,
        sha256: tarballHash,
        fileCount: walk.files.count,
        uncompressedSize: walk.files.reduce(0) { $0 + $1.size }
      ),
      files: walk.files
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(manifest).write(to: manifestURL)

    try registry.db.transaction {
      try registry.setState(.dormant, id: project.id)
      _ = try registry.recordArchive(
        projectID: project.id,
        storePath: tarball.path,
        size: tarballSize,
        manifestPath: manifestURL.path
      )
    }

    var workingCopyRemoved = true
    do {
      try fm.removeItem(at: root)
    } catch {
      workingCopyRemoved = false
    }

    return ArchiveOutcome(
      projectID: project.id,
      storePath: tarball,
      manifestPath: manifestURL,
      archiveSizeBytes: tarballSize,
      reclaimedBytes: cleanPlan.totalReclaim,
      workingCopyRemoved: workingCopyRemoved
    )
  }

  private func detectedEcosystems(in root: URL) -> [String] {
    classifier.classify(projectAt: root).ecosystems
      .filter { $0 != .unknown }
      .map { $0.slug }
      .sorted()
  }

  private func gitInfo(from state: GitState) -> ManifestGitInfo {
    switch state {
    case .unavailable, .notARepository:
      return ManifestGitInfo(
        isRepo: false,
        head: nil,
        branch: nil,
        remote: nil,
        dirty: false,
        modifiedCount: 0,
        untrackedCount: 0
      )
    case .repository(let status):
      return ManifestGitInfo(
        isRepo: true,
        head: status.head,
        branch: status.branch,
        remote: status.remote,
        dirty: status.isDirty,
        modifiedCount: status.modifiedCount,
        untrackedCount: status.untrackedCount
      )
    }
  }

  private struct TreeWalk {
    var files: [ManifestFile] = []
    var entries: Set<String> = []
  }

  private func collectTree(root: URL) throws -> TreeWalk {
    var walk = TreeWalk()
    try collect(into: &walk, dir: root, prefix: "")
    walk.files.sort { $0.path < $1.path }
    return walk
  }

  private func collect(into walk: inout TreeWalk, dir: URL, prefix: String) throws {
    let fm = FileManager.default
    let children = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
    for child in children {
      let name = child.lastPathComponent
      let relative = prefix.isEmpty ? name : prefix + "/" + name
      walk.entries.insert(relative)
      let attrs = try fm.attributesOfItem(atPath: child.path)
      switch attrs[.type] as? FileAttributeType {
      case .typeDirectory:
        try collect(into: &walk, dir: child, prefix: relative)
      case .typeRegular:
        walk.files.append(
          ManifestFile(
            path: relative,
            size: attrs[.size] as? Int ?? 0,
            sha256: try Checksums.sha256(ofFileAt: child),
            kind: ManifestFileKind.classify(path: relative)
          )
        )
      default:
        continue
      }
    }
  }

  private func verifyArchive(tarball: URL, expected: Set<String>, runner: ProcessRunner) throws {
    let listing = try runner.run(executable: tarExecutable, arguments: ["-tzf", tarball.path])
    guard listing.exitCode == 0 else {
      throw DormantError.tarFailed(stderr: listing.stderr)
    }
    var listed = Set<String>()
    for line in listing.stdout.split(separator: "\n", omittingEmptySubsequences: true) {
      var entry = String(line)
      while entry.hasPrefix("./") { entry.removeFirst(2) }
      while entry.hasSuffix("/") { entry.removeLast() }
      if !entry.isEmpty {
        listed.insert(entry)
      }
    }
    guard listed == expected else {
      let missing = expected.subtracting(listed).sorted()
      let extra = listed.subtracting(expected).sorted()
      throw DormantError.verificationFailed(
        details: "archive listing mismatch (missing: \(missing), unexpected: \(extra))"
      )
    }
  }
}
