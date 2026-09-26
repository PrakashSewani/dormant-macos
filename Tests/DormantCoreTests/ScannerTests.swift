import Foundation
import Testing

@testable import DormantCore

@Suite struct ScannerTests {
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

  @Test func findsProjectsAndSkipsPlainDirectories() throws {
    let workspace = try TempProject()
    defer { workspace.destroy() }
    let (sandbox, registry) = try makeRegistry()
    defer { sandbox.destroy() }
    try workspace.file("a/package.json", contents: "{}")
    try workspace.file("b/Cargo.toml", contents: "")
    try workspace.file("c/notes.txt", contents: "")

    let report = try Scanner(registry: registry).scan(roots: [workspace.root])

    #expect(report.added.count == 2)
    #expect(Set(report.added.map { $0.name }) == ["a", "b"])
    let aPath = workspace.root.appendingPathComponent("a").path
    let aRecord = try registry.project(path: aPath)
    let a = try #require(aRecord)
    #expect(a.ecosystem == .node)
    #expect(a.state == .active)
    let bPath = workspace.root.appendingPathComponent("b").path
    let bRecord = try registry.project(path: bPath)
    let b = try #require(bRecord)
    #expect(b.ecosystem == .rust)
  }

  @Test func scannedRootItselfCanBeAProject() throws {
    let project = try TempProject()
    defer { project.destroy() }
    let (sandbox, registry) = try makeRegistry()
    defer { sandbox.destroy() }
    try project.file("package.json", contents: "{}")

    let report = try Scanner(registry: registry).scan(roots: [project.root])

    #expect(report.added.count == 1)
    #expect(report.added.first?.path == project.root.standardizedFileURL.path)
  }

  @Test func topmostProjectWins() throws {
    let workspace = try TempProject()
    defer { workspace.destroy() }
    let (sandbox, registry) = try makeRegistry()
    defer { sandbox.destroy() }
    try workspace.file("mono/package.json", contents: "{}")
    try workspace.file("mono/packages/x/package.json", contents: "{}")

    let report = try Scanner(registry: registry).scan(roots: [workspace.root])

    #expect(report.added.map { $0.name } == ["mono"])
    let nested = workspace.root.appendingPathComponent("mono/packages/x").path
    let nestedRecord = try registry.project(path: nested)
    #expect(nestedRecord == nil)
  }

  @Test func depthLimitIsRespected() throws {
    let deep = try TempProject()
    defer { deep.destroy() }
    let (sandbox, registry) = try makeRegistry()
    defer { sandbox.destroy() }
    try deep.file("l1/l2/l3/proj/package.json", contents: "{}")

    let shallow = try Scanner(registry: registry).scan(roots: [deep.root], maxDepth: 3)
    #expect(shallow.added.isEmpty)

    let deepEnough = try Scanner(registry: registry).scan(roots: [deep.root], maxDepth: 4)
    #expect(deepEnough.added.map { $0.name } == ["proj"])
  }

  @Test func regenerableDirectoriesAreNotScanned() throws {
    let workspace = try TempProject()
    defer { workspace.destroy() }
    let (sandbox, registry) = try makeRegistry()
    defer { sandbox.destroy() }
    try workspace.file("node_modules/fake/package.json", contents: "{}")
    try workspace.file("real/package.json", contents: "{}")

    let report = try Scanner(registry: registry).scan(roots: [workspace.root])

    #expect(report.added.map { $0.name } == ["real"])
  }

  @Test func rescanUpdatesAndReappearsDormantProjects() throws {
    let workspace = try TempProject()
    defer { workspace.destroy() }
    let (sandbox, registry) = try makeRegistry()
    defer { sandbox.destroy() }
    try workspace.file("a/package.json", contents: "{}")
    let scanner = Scanner(registry: registry)

    let first = try scanner.scan(roots: [workspace.root])
    let added = try #require(first.added.first)
    try registry.setState(.dormant, id: added.id)

    let second = try scanner.scan(roots: [workspace.root])
    let reappeared = try #require(second.reappeared.first)
    #expect(reappeared.id == added.id)
    #expect(reappeared.state == .active)

    let third = try scanner.scan(roots: [workspace.root])
    #expect(third.updated.map { $0.id } == [added.id])
    #expect(third.added.isEmpty)
    #expect(third.reappeared.isEmpty)
  }

  @Test func missingProjectsAreReportedNotDeleted() throws {
    let workspace = try TempProject()
    defer { workspace.destroy() }
    let (sandbox, registry) = try makeRegistry()
    defer { sandbox.destroy() }
    try workspace.file("a/package.json", contents: "{}")
    let scanner = Scanner(registry: registry)

    let first = try scanner.scan(roots: [workspace.root])
    let added = try #require(first.added.first)
    try FileManager.default.removeItem(at: workspace.root.appendingPathComponent("a"))

    let second = try scanner.scan(roots: [workspace.root])
    #expect(second.missing.map { $0.id } == [added.id])
    let survivor = try registry.project(id: added.id)
    #expect(survivor != nil)
  }

  @Test func storeDirectoryIsExcluded() throws {
    let workspace = try TempProject()
    defer { workspace.destroy() }
    let (sandbox, registry) = try makeRegistry()
    defer { sandbox.destroy() }
    try workspace.file("store/some-id/core.tar.gz", byteCount: 1)
    try workspace.file("store/some-id/package.json", contents: "{}")

    let scanner = Scanner(
      registry: registry,
      excludedDirectories: [workspace.root.appendingPathComponent("store")]
    )
    let report = try scanner.scan(roots: [workspace.root])

    #expect(report.added.isEmpty)
  }

  @Test func gitRemoteIsCaptured() throws {
    let workspace = try TempProject()
    defer { workspace.destroy() }
    let (sandbox, registry) = try makeRegistry()
    defer { sandbox.destroy() }
    let project = workspace.root.appendingPathComponent("a")
    try workspace.directory("a")
    try workspace.file("a/package.json", contents: "{}")
    try git(["init"], cwd: project)
    try git(["remote", "add", "origin", "git@example.com:x/y.git"], cwd: project)

    let report = try Scanner(registry: registry).scan(roots: [workspace.root])

    #expect(report.added.first?.gitRemote == "git@example.com:x/y.git")
  }
}
