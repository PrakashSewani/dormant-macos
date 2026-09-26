import Foundation

public struct GitStatus: Sendable, Equatable {
  public let head: String?
  public let branch: String?
  public let remote: String?
  public let isDirty: Bool
  public let modifiedCount: Int
  public let untrackedCount: Int
}

public enum GitState: Sendable, Equatable {
  case unavailable
  case notARepository
  case repository(GitStatus)
}

public struct GitInspector {
  private let gitExecutable: URL

  public init(gitExecutable: URL = URL(fileURLWithPath: "/usr/bin/git")) {
    self.gitExecutable = gitExecutable
  }

  public func check(root: URL) -> GitState {
    do {
      return try inspect(root: root)
    } catch {
      return .unavailable
    }
  }

  private func inspect(root: URL) throws -> GitState {
    let runner = ProcessRunner()
    func git(_ arguments: [String]) throws -> ProcessResult {
      try runner.run(
        executable: gitExecutable,
        arguments: ["--no-optional-locks", "-C", root.path] + arguments)
    }

    let workTree = try git(["rev-parse", "--is-inside-work-tree"])
    guard workTree.exitCode == 0, trimmed(workTree.stdout) == "true" else {
      return .notARepository
    }

    let status = try git(["status", "--porcelain=v1", "-uall"])
    guard status.exitCode == 0 else {
      return .unavailable
    }
    var modifiedCount = 0
    var untrackedCount = 0
    for line in status.stdout.split(separator: "\n", omittingEmptySubsequences: true) {
      if line.hasPrefix("??") {
        untrackedCount += 1
      } else {
        modifiedCount += 1
      }
    }

    let headResult = try git(["rev-parse", "HEAD"])
    let head = headResult.exitCode == 0 ? trimmed(headResult.stdout) : nil

    let branchResult = try git(["rev-parse", "--abbrev-ref", "HEAD"])
    let branch = branchResult.exitCode == 0 ? trimmed(branchResult.stdout) : nil

    var remote: String?
    let originResult = try git(["remote", "get-url", "origin"])
    if originResult.exitCode == 0 {
      remote = trimmed(originResult.stdout)
    } else {
      let remotesResult = try git(["remote", "-v"])
      if remotesResult.exitCode == 0 {
        remote = firstRemoteURL(remotesResult.stdout)
      }
    }

    return .repository(
      GitStatus(
        head: head,
        branch: branch,
        remote: remote,
        isDirty: modifiedCount + untrackedCount > 0,
        modifiedCount: modifiedCount,
        untrackedCount: untrackedCount))
  }

  private func trimmed(_ output: String) -> String? {
    let value = output.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
  }

  private func firstRemoteURL(_ output: String) -> String? {
    guard let line = output.split(separator: "\n", omittingEmptySubsequences: true).first else {
      return nil
    }
    var entry = String(line)
    if entry.hasSuffix(" (fetch)") {
      entry = String(entry.dropLast(" (fetch)".count))
    } else if entry.hasSuffix(" (push)") {
      entry = String(entry.dropLast(" (push)".count))
    }
    guard let separator = entry.firstIndex(where: { $0 == "\t" || $0 == " " }) else {
      return nil
    }
    return trimmed(String(entry[entry.index(after: separator)...]))
  }
}
