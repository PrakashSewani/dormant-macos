import Foundation
import Testing

@testable import DormantCore

@Suite struct RestoreTests {
  private func makeRegistry() throws -> (TempProject, Registry) {
    let sandbox = try TempProject()
    let registry = try Registry(path: sandbox.root.appendingPathComponent("registry.sqlite"))
    return (sandbox, registry)
  }

  private func tarCreate(tarball: URL, from dir: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
    process.arguments = ["-czf", tarball.path, "-C", dir.path, "."]
    process.standardOutput = Pipe()
    process.standardError = Pipe()
    try process.run()
    process.waitUntilExit()
  }

  private func makeHandmadeArchive(
    registry: Registry,
    projectID: String,
    sandbox: TempProject,
    goodChecksum: Bool,
    includeManifest: Bool = true
  ) throws -> URL {
    let fm = FileManager.default
    let projectStore = sandbox.root
      .appendingPathComponent("store")
      .appendingPathComponent(projectID)
    try fm.createDirectory(at: projectStore, withIntermediateDirectories: true)
    let staging = sandbox.root.appendingPathComponent("staging-\(UUID().uuidString)")
    try fm.createDirectory(at: staging, withIntermediateDirectories: true)
    try Data("hello".utf8).write(to: staging.appendingPathComponent("a.txt"))
    let tarball = projectStore.appendingPathComponent("core.tar.gz")
    try tarCreate(tarball: tarball, from: staging)
    let manifestURL = projectStore.appendingPathComponent("manifest.json")
    if includeManifest {
      let manifest = ArchiveManifest(
        manifestVersion: 1,
        project: ManifestProjectInfo(
          id: projectID,
          name: "proj",
          originalPath: "/tmp/original",
          ecosystems: [],
          archivedAt: "2026-09-26T00:00:00Z"
        ),
        git: ManifestGitInfo(
          isRepo: false,
          head: nil,
          branch: nil,
          remote: nil,
          dirty: false,
          modifiedCount: 0,
          untrackedCount: 0
        ),
        tarball: ManifestTarballInfo(
          name: "core.tar.gz",
          size: 0,
          sha256: "",
          fileCount: 1,
          uncompressedSize: 5
        ),
        files: [
          ManifestFile(
            path: "a.txt",
            size: 5,
            sha256: goodChecksum ? Checksums.sha256(of: Data("hello".utf8)) : "deadbeef",
            kind: .core
          )
        ]
      )
      try JSONEncoder().encode(manifest).write(to: manifestURL)
    }
    _ = try registry.recordArchive(
      projectID: projectID,
      storePath: tarball.path,
      size: 1,
      manifestPath: manifestURL.path
    )
    return projectStore
  }

  @Test func roundTripRestoresFilesAndState() throws {
    let workspace = try TempProject()
    defer { workspace.destroy() }
    let (sandbox, registry) = try makeRegistry()
    defer { sandbox.destroy() }
    let projectDir = workspace.root.appendingPathComponent("proj")
    try workspace.file("proj/package.json", contents: "{}")
    try workspace.file("proj/src/main.js", contents: "hello")
    try workspace.file("proj/notes.pdf", byteCount: 7)
    try workspace.file("proj/node_modules/junk.js", byteCount: 4)
    let record = try registry.upsertProject(
      name: "proj",
      path: projectDir.path,
      ecosystem: .node,
      gitRemote: nil
    )
    let store = sandbox.root.appendingPathComponent("store")
    _ = try ArchiveEngine(storeDirectory: store).archive(project: record, registry: registry)
    let dormant = try registry.project(id: record.id)
    let project = try #require(dormant)

    let outcome = try RestoreEngine(storeDirectory: store)
      .restore(project: project, registry: registry)

    let fm = FileManager.default
    #expect(outcome.destination.path == record.path)
    #expect(outcome.verifiedFileCount == 3)
    #expect(fm.fileExists(atPath: projectDir.appendingPathComponent("package.json").path))
    #expect(fm.fileExists(atPath: projectDir.appendingPathComponent("notes.pdf").path))
    let mainJS = projectDir.appendingPathComponent("src/main.js")
    let mainContents = try Data(contentsOf: mainJS)
    #expect(mainContents == Data("hello".utf8))
    #expect(!fm.fileExists(atPath: projectDir.appendingPathComponent("node_modules").path))
    let after = try registry.project(id: record.id)
    #expect(after?.state == .active)
    let row = try registry.archive(projectID: record.id)
    #expect(row == nil)
    #expect(!fm.fileExists(atPath: store.appendingPathComponent(record.id).path))
  }

  @Test func nonEmptyDestinationIsRefused() throws {
    let workspace = try TempProject()
    defer { workspace.destroy() }
    let (sandbox, registry) = try makeRegistry()
    defer { sandbox.destroy() }
    let record = try registry.upsertProject(
      name: "proj",
      path: workspace.root.appendingPathComponent("proj").path,
      ecosystem: .node,
      gitRemote: nil
    )
    _ = try makeHandmadeArchive(
      registry: registry,
      projectID: record.id,
      sandbox: sandbox,
      goodChecksum: true
    )
    try workspace.file("occupied/keep.txt", contents: "x")
    let destination = workspace.root.appendingPathComponent("occupied")

    var caught: DormantError?
    do {
      _ = try RestoreEngine(storeDirectory: sandbox.root.appendingPathComponent("store"))
        .restore(project: record, registry: registry, to: destination)
    } catch let error as DormantError {
      caught = error
    }
    guard let caught, case .targetNotEmpty = caught else {
      Issue.record("expected targetNotEmpty, got \(String(describing: caught))")
      return
    }
    let row = try registry.archive(projectID: record.id)
    #expect(row != nil)
  }

  @Test func checksumMismatchKeepsArchiveAndTree() throws {
    let workspace = try TempProject()
    defer { workspace.destroy() }
    let (sandbox, registry) = try makeRegistry()
    defer { sandbox.destroy() }
    let destination = workspace.root.appendingPathComponent("proj")
    let record = try registry.upsertProject(
      name: "proj",
      path: destination.path,
      ecosystem: .unknown,
      gitRemote: nil
    )
    let store = sandbox.root.appendingPathComponent("store")
    let projectStore = try makeHandmadeArchive(
      registry: registry,
      projectID: record.id,
      sandbox: sandbox,
      goodChecksum: false
    )
    try registry.setState(.dormant, id: record.id)

    var caught: DormantError?
    do {
      _ = try RestoreEngine(storeDirectory: store).restore(project: record, registry: registry)
    } catch let error as DormantError {
      caught = error
    }
    guard let caught, case .verificationFailed = caught else {
      Issue.record("expected verificationFailed, got \(String(describing: caught))")
      return
    }

    let fm = FileManager.default
    #expect(fm.fileExists(atPath: projectStore.path))
    #expect(fm.fileExists(atPath: destination.appendingPathComponent("a.txt").path))
    let row = try registry.archive(projectID: record.id)
    #expect(row != nil)
    let after = try registry.project(id: record.id)
    #expect(after?.state == .dormant)
  }

  @Test func missingTarballFails() throws {
    let (sandbox, registry) = try makeRegistry()
    defer { sandbox.destroy() }
    let record = try registry.upsertProject(
      name: "proj",
      path: sandbox.root.appendingPathComponent("proj").path,
      ecosystem: .unknown,
      gitRemote: nil
    )
    _ = try registry.recordArchive(
      projectID: record.id,
      storePath: sandbox.root.appendingPathComponent("gone.tar.gz").path,
      size: 1,
      manifestPath: sandbox.root.appendingPathComponent("gone.json").path
    )

    var caught: DormantError?
    do {
      _ = try RestoreEngine(storeDirectory: sandbox.root.appendingPathComponent("store"))
        .restore(project: record, registry: registry)
    } catch let error as DormantError {
      caught = error
    }
    guard let caught, case .tarFailed = caught else {
      Issue.record("expected tarFailed, got \(String(describing: caught))")
      return
    }
  }

  @Test func corruptTarballFails() throws {
    let (sandbox, registry) = try makeRegistry()
    defer { sandbox.destroy() }
    let record = try registry.upsertProject(
      name: "proj",
      path: sandbox.root.appendingPathComponent("proj").path,
      ecosystem: .unknown,
      gitRemote: nil
    )
    let projectStore = try makeHandmadeArchive(
      registry: registry,
      projectID: record.id,
      sandbox: sandbox,
      goodChecksum: true
    )
    try Data("not a tarball".utf8).write(
      to: projectStore.appendingPathComponent("core.tar.gz")
    )

    var caught: DormantError?
    do {
      _ = try RestoreEngine(storeDirectory: sandbox.root.appendingPathComponent("store"))
        .restore(project: record, registry: registry)
    } catch let error as DormantError {
      caught = error
    }
    guard let caught, case .tarFailed = caught else {
      Issue.record("expected tarFailed, got \(String(describing: caught))")
      return
    }
  }

  @Test func missingManifestFails() throws {
    let (sandbox, registry) = try makeRegistry()
    defer { sandbox.destroy() }
    let record = try registry.upsertProject(
      name: "proj",
      path: sandbox.root.appendingPathComponent("proj").path,
      ecosystem: .unknown,
      gitRemote: nil
    )
    _ = try makeHandmadeArchive(
      registry: registry,
      projectID: record.id,
      sandbox: sandbox,
      goodChecksum: true,
      includeManifest: false
    )

    var caught: DormantError?
    do {
      _ = try RestoreEngine(storeDirectory: sandbox.root.appendingPathComponent("store"))
        .restore(project: record, registry: registry)
    } catch let error as DormantError {
      caught = error
    }
    guard let caught, case .verificationFailed = caught else {
      Issue.record("expected verificationFailed, got \(String(describing: caught))")
      return
    }
    let row = try registry.archive(projectID: record.id)
    #expect(row != nil)
  }
}
