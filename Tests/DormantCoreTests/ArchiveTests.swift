import Foundation
import Testing

@testable import DormantCore

@Suite struct ArchiveTests {
  private func makeRegistry() throws -> (TempProject, Registry) {
    let sandbox = try TempProject()
    let registry = try Registry(path: sandbox.root.appendingPathComponent("registry.sqlite"))
    return (sandbox, registry)
  }

  @discardableResult
  private func git(_ args: [String], cwd: URL) throws -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = args
    process.currentDirectoryURL = cwd
    process.standardOutput = Pipe()
    process.standardError = Pipe()
    try process.run()
    process.waitUntilExit()
    return process.terminationStatus
  }

  private func tarList(_ tarball: URL) throws -> Set<String> {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
    process.arguments = ["-tzf", tarball.path]
    let stdout = Pipe()
    process.standardOutput = stdout
    process.standardError = Pipe()
    try process.run()
    process.waitUntilExit()
    let data = stdout.fileHandleForReading.readDataToEndOfFile()
    var entries = Set<String>()
    for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
      var entry = String(line)
      while entry.hasPrefix("./") { entry.removeFirst(2) }
      while entry.hasSuffix("/") { entry.removeLast() }
      if !entry.isEmpty {
        entries.insert(entry)
      }
    }
    return entries
  }

  @Test func archiveEndToEndPreservesEverythingAndCleansUp() throws {
    let workspace = try TempProject()
    defer { workspace.destroy() }
    let (sandbox, registry) = try makeRegistry()
    defer { sandbox.destroy() }
    let projectDir = workspace.root.appendingPathComponent("proj")
    try workspace.file("proj/package.json", contents: "{}")
    try workspace.file("proj/node_modules/junk.js", byteCount: 4)
    try workspace.file("proj/src/main.js", contents: "hello")
    try workspace.file("proj/notes.pdf", byteCount: 7)
    let record = try registry.upsertProject(
      name: "proj",
      path: projectDir.path,
      ecosystem: .node,
      gitRemote: nil
    )
    let store = sandbox.root.appendingPathComponent("store")
    let engine = ArchiveEngine(storeDirectory: store)

    let outcome = try engine.archive(project: record, registry: registry)

    let fm = FileManager.default
    #expect(outcome.workingCopyRemoved)
    #expect(!fm.fileExists(atPath: projectDir.path))
    #expect(outcome.reclaimedBytes == 4)
    #expect(outcome.archiveSizeBytes > 0)

    let after = try registry.project(id: record.id)
    #expect(after?.state == .dormant)
    let archiveRow = try registry.archive(projectID: record.id)
    #expect(archiveRow?.storePath == outcome.storePath.path)
    #expect(archiveRow?.manifestPath == outcome.manifestPath.path)
    #expect(archiveRow?.size == outcome.archiveSizeBytes)

    let data = try Data(contentsOf: outcome.manifestPath)
    let manifest = try JSONDecoder().decode(ArchiveManifest.self, from: data)
    #expect(manifest.manifestVersion == 1)
    #expect(manifest.project.id == record.id)
    #expect(manifest.project.originalPath == record.path)
    #expect(manifest.project.ecosystems == ["node"])
    #expect(!manifest.git.isRepo)
    let filesByPath = Dictionary(
      uniqueKeysWithValues: manifest.files.map { ($0.path, $0) }
    )
    #expect(Set(filesByPath.keys) == ["notes.pdf", "package.json", "src/main.js"])
    #expect(filesByPath["src/main.js"]?.kind == .core)
    #expect(filesByPath["package.json"]?.kind == .core)
    #expect(filesByPath["notes.pdf"]?.kind == .unclassified)
    #expect(filesByPath["src/main.js"]?.sha256 == Checksums.sha256(of: Data("hello".utf8)))

    let listing = try tarList(outcome.storePath)
    #expect(listing.contains("src/main.js"))
    #expect(listing.contains("notes.pdf"))
    #expect(!listing.contains("node_modules"))
  }

  @Test func gitWarningReportsDirtyCounts() throws {
    let workspace = try TempProject()
    defer { workspace.destroy() }
    let (sandbox, _) = try makeRegistry()
    defer { sandbox.destroy() }
    try workspace.file("a.txt", contents: "one")
    try git(["init"], cwd: workspace.root)
    try git(["add", "."], cwd: workspace.root)
    try git(
      ["-c", "user.email=t@dormant.local", "-c", "user.name=Dormant", "commit", "-m", "init"],
      cwd: workspace.root
    )
    try workspace.file("a.txt", contents: "changed")
    try workspace.file("untracked.txt", contents: "new")

    let warning = ArchiveEngine(storeDirectory: sandbox.root)
      .gitWarning(root: workspace.root)

    let expected = try #require(warning)
    #expect(expected.modifiedCount == 1)
    #expect(expected.untrackedCount == 1)
    #expect(!expected.gitStateUnknown)
  }

  @Test func gitWarningIsNilForCleanAndNonRepositories() throws {
    let workspace = try TempProject()
    defer { workspace.destroy() }
    let (sandbox, _) = try makeRegistry()
    defer { sandbox.destroy() }
    let clean = workspace.root.appendingPathComponent("clean")
    try workspace.file("clean/a.txt", contents: "one")
    try git(["init"], cwd: clean)
    try git(["add", "."], cwd: clean)
    try git(
      ["-c", "user.email=t@dormant.local", "-c", "user.name=Dormant", "commit", "-m", "init"],
      cwd: clean
    )
    try workspace.file("plain/notes.txt", contents: "hi")
    let engine = ArchiveEngine(storeDirectory: sandbox.root)

    #expect(engine.gitWarning(root: clean) == nil)
    #expect(engine.gitWarning(root: workspace.root.appendingPathComponent("plain")) == nil)
  }

  @Test func gitWarningFlagsUnknownGitState() throws {
    let workspace = try TempProject()
    defer { workspace.destroy() }
    let (sandbox, _) = try makeRegistry()
    defer { sandbox.destroy() }
    try workspace.file("proj/a.txt", contents: "one")
    let engine = ArchiveEngine(
      gitInspector: GitInspector(gitExecutable: URL(fileURLWithPath: "/nonexistent/git")),
      storeDirectory: sandbox.root
    )

    let warning = try #require(
      engine.gitWarning(root: workspace.root.appendingPathComponent("proj"))
    )

    #expect(warning.gitStateUnknown)
  }

  @Test func verificationFailureKeepsWorkingCopyAndLeavesNoArchive() throws {
    let workspace = try TempProject()
    defer { workspace.destroy() }
    let (sandbox, registry) = try makeRegistry()
    defer { sandbox.destroy() }
    let projectDir = workspace.root.appendingPathComponent("proj")
    try workspace.file("proj/package.json", contents: "{}")
    try workspace.file("proj/src/main.js", contents: "hello")
    let record = try registry.upsertProject(
      name: "proj",
      path: projectDir.path,
      ecosystem: .node,
      gitRemote: nil
    )
    try sandbox.file(
      "fake-tar",
      contents: """
        #!/bin/sh
        if [ "$1" = "-czf" ]; then
          : > "$2"
          exit 0
        fi
        echo "./bogus-entry"
        exit 0
        """
    )
    let fakeTar = sandbox.root.appendingPathComponent("fake-tar")
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: fakeTar.path
    )
    let store = sandbox.root.appendingPathComponent("store")
    let engine = ArchiveEngine(storeDirectory: store, tarExecutable: fakeTar)

    var caught: DormantError?
    do {
      _ = try engine.archive(project: record, registry: registry)
    } catch let error as DormantError {
      caught = error
    }
    guard let caught else {
      Issue.record("expected a DormantError")
      return
    }
    guard case .verificationFailed = caught else {
      Issue.record("expected verificationFailed, got \(caught)")
      return
    }

    let fm = FileManager.default
    #expect(fm.fileExists(atPath: projectDir.path))
    let row = try registry.archive(projectID: record.id)
    #expect(row == nil)
    let after = try registry.project(id: record.id)
    #expect(after?.state == .active)
    let projectStore = store.appendingPathComponent(record.id)
    #expect(!fm.fileExists(atPath: projectStore.path))
  }

  @Test func archivingTwiceIsRefused() throws {
    let workspace = try TempProject()
    defer { workspace.destroy() }
    let (sandbox, registry) = try makeRegistry()
    defer { sandbox.destroy() }
    let projectDir = workspace.root.appendingPathComponent("proj")
    try workspace.file("proj/package.json", contents: "{}")
    let record = try registry.upsertProject(
      name: "proj",
      path: projectDir.path,
      ecosystem: .node,
      gitRemote: nil
    )
    let store = sandbox.root.appendingPathComponent("store")
    let engine = ArchiveEngine(storeDirectory: store)
    _ = try engine.archive(project: record, registry: registry)

    var caught: DormantError?
    do {
      _ = try engine.archive(project: record, registry: registry)
    } catch let error as DormantError {
      caught = error
    }
    guard let caught, case .archiveExists = caught else {
      Issue.record("expected archiveExists, got \(String(describing: caught))")
      return
    }
  }
}
