import Foundation

public struct RestoreOutcome: Sendable {
  public let destination: URL
  public let verifiedFileCount: Int
}

public struct RestoreEngine {
  private let storeDirectory: URL
  private let tarExecutable: URL

  public init(
    storeDirectory: URL = DormantPaths().store,
    tarExecutable: URL = URL(fileURLWithPath: "/usr/bin/tar")
  ) {
    self.storeDirectory = storeDirectory
    self.tarExecutable = tarExecutable
  }

  public func restore(
    project: ProjectRecord,
    registry: Registry,
    to destination: URL? = nil
  ) throws -> RestoreOutcome {
    let fm = FileManager.default
    guard let archiveRow = try registry.archive(projectID: project.id) else {
      throw DormantError.verificationFailed(details: "no archive recorded for this project")
    }
    let tarball = URL(fileURLWithPath: archiveRow.storePath)
    let manifestURL = URL(fileURLWithPath: archiveRow.manifestPath)
    guard fm.fileExists(atPath: tarball.path) else {
      throw DormantError.tarFailed(stderr: "archive missing at \(tarball.path)")
    }
    guard let manifestData = try? Data(contentsOf: manifestURL),
      let manifest = try? JSONDecoder().decode(ArchiveManifest.self, from: manifestData)
    else {
      throw DormantError.verificationFailed(
        details: "manifest missing or unreadable at \(manifestURL.path)"
      )
    }

    let target = (destination ?? URL(fileURLWithPath: project.path)).standardizedFileURL
    let existing = (try? fm.contentsOfDirectory(atPath: target.path)) ?? []
    guard existing.isEmpty else { throw DormantError.targetNotEmpty }
    try fm.createDirectory(at: target, withIntermediateDirectories: true)

    let extracted = try ProcessRunner().run(
      executable: tarExecutable,
      arguments: ["-xzf", tarball.path, "-C", target.path]
    )
    guard extracted.exitCode == 0 else {
      throw DormantError.tarFailed(stderr: extracted.stderr)
    }

    for file in manifest.files {
      guard verified(file: file, at: target.appendingPathComponent(file.path)) else {
        throw DormantError.verificationFailed(
          details: "restored file mismatch at \(file.path); archive kept for recovery"
        )
      }
    }

    try registry.db.transaction {
      try registry.setState(.active, id: project.id)
      try registry.removeArchive(projectID: project.id)
    }
    try? fm.removeItem(at: storeDirectory.appendingPathComponent(project.id))

    return RestoreOutcome(destination: target, verifiedFileCount: manifest.files.count)
  }

  private func verified(file: ManifestFile, at url: URL) -> Bool {
    let fm = FileManager.default
    guard fm.fileExists(atPath: url.path) else { return false }
    let attrs = try? fm.attributesOfItem(atPath: url.path)
    guard attrs?[.size] as? Int == file.size else { return false }
    guard let hash = try? Checksums.sha256(ofFileAt: url) else { return false }
    return hash == file.sha256
  }
}
