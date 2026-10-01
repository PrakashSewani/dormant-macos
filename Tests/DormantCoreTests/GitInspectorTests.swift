import Foundation
import Testing

@testable import DormantCore

@Suite struct GitInspectorTests {
  @Test("captures head, branch and clean state of a committed repository")
  func cleanRepository() throws {
    let root = try makeRepository()
    try commitFile(named: "a.txt", contents: "one\n", root: root)
    let expectedHead = try gitOutput(["rev-parse", "HEAD"], root: root)
    let expectedBranch = try gitOutput(["rev-parse", "--abbrev-ref", "HEAD"], root: root)

    guard case .repository(let status) = GitInspector().check(root: root) else {
      Issue.record("expected repository state")
      return
    }
    #expect(status.head == expectedHead)
    #expect(status.branch == expectedBranch)
    #expect(status.remote == nil)
    #expect(!status.isDirty)
    #expect(status.modifiedCount == 0)
    #expect(status.untrackedCount == 0)
  }

  @Test("counts an unstaged modification and an untracked file")
  func dirtyCounts() throws {
    let root = try makeRepository()
    try commitFile(named: "a.txt", contents: "one\n", root: root)
    try Data("changed\n".utf8).write(to: root.appendingPathComponent("a.txt"))
    try Data("new\n".utf8).write(to: root.appendingPathComponent("b.txt"))

    guard case .repository(let status) = GitInspector().check(root: root) else {
      Issue.record("expected repository state")
      return
    }
    #expect(status.isDirty)
    #expect(status.modifiedCount == 1)
    #expect(status.untrackedCount == 1)
  }

  @Test("counts staged changes as modified")
  func stagedChanges() throws {
    let root = try makeRepository()
    try commitFile(named: "a.txt", contents: "one\n", root: root)
    try Data("staged\n".utf8).write(to: root.appendingPathComponent("b.txt"))
    try git(["add", "b.txt"], root: root)

    guard case .repository(let status) = GitInspector().check(root: root) else {
      Issue.record("expected repository state")
      return
    }
    #expect(status.isDirty)
    #expect(status.modifiedCount == 1)
    #expect(status.untrackedCount == 0)
  }

  @Test("counts every untracked file individually")
  func untrackedCounts() throws {
    let root = try makeRepository()
    for name in ["a.txt", "b.txt", "c.txt"] {
      try Data("x\n".utf8).write(to: root.appendingPathComponent(name))
    }

    guard case .repository(let status) = GitInspector().check(root: root) else {
      Issue.record("expected repository state")
      return
    }
    #expect(status.isDirty)
    #expect(status.modifiedCount == 0)
    #expect(status.untrackedCount == 3)
  }

  @Test("counts a rename as one modified line")
  func renameIsOneLine() throws {
    let root = try makeRepository()
    try commitFile(named: "old.txt", contents: "one\n", root: root)
    try git(["mv", "old.txt", "new.txt"], root: root)

    guard case .repository(let status) = GitInspector().check(root: root) else {
      Issue.record("expected repository state")
      return
    }
    #expect(status.isDirty)
    #expect(status.modifiedCount == 1)
    #expect(status.untrackedCount == 0)
  }

  @Test("reports no head on a repository without commits")
  func unbornHead() throws {
    let root = try makeRepository()

    guard case .repository(let status) = GitInspector().check(root: root) else {
      Issue.record("expected repository state")
      return
    }
    #expect(status.head == nil)
    #expect(!status.isDirty)
    #expect(status.modifiedCount == 0)
    #expect(status.untrackedCount == 0)
  }

  @Test("reports the origin remote when present")
  func originRemote() throws {
    let root = try makeRepository()
    try commitFile(named: "a.txt", contents: "one\n", root: root)
    try git(["remote", "add", "origin", "git@github.com:example/repo.git"], root: root)

    guard case .repository(let status) = GitInspector().check(root: root) else {
      Issue.record("expected repository state")
      return
    }
    #expect(status.remote == "git@github.com:example/repo.git")
  }

  @Test("falls back to the first remote without origin")
  func fallbackRemote() throws {
    let root = try makeRepository()
    try commitFile(named: "a.txt", contents: "one\n", root: root)
    try git(["remote", "add", "alpha", "https://github.com/example/alpha.git"], root: root)
    try git(["remote", "add", "omega", "https://github.com/example/omega.git"], root: root)

    guard case .repository(let status) = GitInspector().check(root: root) else {
      Issue.record("expected repository state")
      return
    }
    #expect(status.remote == "https://github.com/example/alpha.git")
  }

  @Test("reports no remote when none is configured")
  func noRemote() throws {
    let root = try makeRepository()
    try commitFile(named: "a.txt", contents: "one\n", root: root)

    guard case .repository(let status) = GitInspector().check(root: root) else {
      Issue.record("expected repository state")
      return
    }
    #expect(status.remote == nil)
  }

  @Test("reports a plain directory as not a repository")
  func nonRepository() throws {
    let root = try makeTempDirectory()
    #expect(GitInspector().check(root: root) == .notARepository)
  }

  @Test("reports unavailable when git cannot be run")
  func unavailable() throws {
    let root = try makeRepository()
    try commitFile(named: "a.txt", contents: "one\n", root: root)
    let inspector = GitInspector(gitExecutable: URL(fileURLWithPath: "/nonexistent/git"))
    #expect(inspector.check(root: root) == .unavailable)
  }
}

private func makeTempDirectory() throws -> URL {
  let dir = FileManager.default.temporaryDirectory
    .appendingPathComponent("DormantGitInspectorTests-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  return dir
}

private func makeRepository() throws -> URL {
  let root = try makeTempDirectory()
  try git(["init", "--quiet"], root: root)
  return root
}

private func commitFile(named name: String, contents: String, root: URL) throws {
  try Data(contents.utf8).write(to: root.appendingPathComponent(name))
  try git(["add", name], root: root)
  try git(
    ["-c", "user.name=Dormant", "-c", "user.email=dormant@example.com", "commit", "-m", name],
    root: root)
}

@discardableResult
private func git(_ arguments: [String], root: URL) throws -> ProcessResult {
  let result = try ProcessRunner().run(
    executable: URL(fileURLWithPath: "/usr/bin/git"),
    arguments: ["-C", root.path] + arguments)
  try #require(
    result.exitCode == 0,
    "git \(arguments.joined(separator: " ")) failed: \(result.stderr)")
  return result
}

private func gitOutput(_ arguments: [String], root: URL) throws -> String {
  let result = try git(arguments, root: root)
  return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
}
