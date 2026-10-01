import Foundation
import Testing

@testable import DormantCore

@Suite struct CloneEngineTests {
  @Test func folderNameStripsGitSuffix() {
    #expect(CloneEngine.folderName(fromRemote: "https://github.com/user/repo.git") == "repo")
  }

  @Test func folderNameWithoutGitSuffix() {
    #expect(CloneEngine.folderName(fromRemote: "https://github.com/user/repo") == "repo")
  }

  @Test func folderNameFromSSHStyleRemote() {
    #expect(CloneEngine.folderName(fromRemote: "git@github.com:user/repo.git") == "repo")
  }

  @Test func folderNameFromSSHURL() {
    #expect(CloneEngine.folderName(fromRemote: "ssh://git@github.com/user/repo.git") == "repo")
  }

  @Test func folderNameFromTrailingSlashURL() {
    #expect(CloneEngine.folderName(fromRemote: "https://github.com/user/repo/") == "repo")
  }

  @Test func folderNameFromFileURL() {
    #expect(CloneEngine.folderName(fromRemote: "file:///tmp/example/source.git") == "source")
  }

  @Test func folderNameRejectsBareHost() {
    #expect(CloneEngine.folderName(fromRemote: "git@github.com") == nil)
  }

  @Test func normalizedRemoteAcceptsKnownSchemes() {
    #expect(CloneEngine.normalizedRemote("https://github.com/user/repo.git") != nil)
    #expect(CloneEngine.normalizedRemote("http://example.com/repo") != nil)
    #expect(CloneEngine.normalizedRemote("ssh://git@github.com/user/repo.git") != nil)
    #expect(CloneEngine.normalizedRemote("git://github.com/user/repo.git") != nil)
    #expect(CloneEngine.normalizedRemote("git@github.com:user/repo.git") != nil)
    #expect(CloneEngine.normalizedRemote("file:///tmp/repo.git") != nil)
  }

  @Test func normalizedRemoteRejectsGarbage() {
    #expect(CloneEngine.normalizedRemote("") == nil)
    #expect(CloneEngine.normalizedRemote("   ") == nil)
    #expect(CloneEngine.normalizedRemote("not a url") == nil)
    #expect(CloneEngine.normalizedRemote("ftp://example.com/repo") == nil)
    #expect(CloneEngine.normalizedRemote("git@github.com") == nil)
  }

  @Test func normalizedRemoteTrimsWhitespace() {
    #expect(
      CloneEngine.normalizedRemote("  https://github.com/user/repo.git \n")
        == "https://github.com/user/repo.git")
  }

  @Test func cloneCreatesDestinationFromLocalRemote() throws {
    let base = FileManager.default.temporaryDirectory
      .appendingPathComponent("dormant-clone-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: base) }

    let source = base.appendingPathComponent("source")
    let git = URL(fileURLWithPath: "/usr/bin/git")
    _ = try ProcessRunner().run(
      executable: git, arguments: ["init", "--bare", "--quiet", source.path])

    let target = base.appendingPathComponent("target")
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

    let destination = try CloneEngine().clone(remote: source.path, into: target)
    #expect(destination.lastPathComponent == "source")
    #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent(".git").path))
  }

  @Test func cloneFailsWhenDestinationExists() throws {
    let base = FileManager.default.temporaryDirectory
      .appendingPathComponent("dormant-clone-tests-\(UUID().uuidString)")
    let target = base.appendingPathComponent("target/thing")
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: base) }

    #expect(throws: DormantError.self) {
      try CloneEngine().clone(
        remote: "https://github.com/user/thing.git", into: base.appendingPathComponent("target"))
    }
  }
}
