import Foundation
import Testing

@testable import DormantCore

@Suite struct IdleSuggestionsTests {
  private func record(
    _ id: String, name: String, path: String, state: ProjectState = .active
  ) -> ProjectRecord {
    ProjectRecord(
      id: id, name: name, path: path, ecosystem: .node, state: state, gitRemote: nil,
      createdAt: Date(), updatedAt: Date(), lastScannedAt: nil)
  }

  private func status(lastCommit: Date?) -> GitState {
    .repository(
      GitStatus(
        head: "abc123", branch: "main", remote: nil, isDirty: false, modifiedCount: 0,
        untrackedCount: 0, committerDate: lastCommit))
  }

  @Test func includesOnlyStaleActiveProjects() throws {
    let project = try TempProject()
    defer { project.destroy() }
    for name in ["stale", "fresh", "no-date", "dormant", "nonrepo", "gone-missing"] {
      try project.directory(name)
    }
    let now = Date()
    let old = now.addingTimeInterval(-86_400 * 40)
    let fresh = now.addingTimeInterval(-86_400 * 5)

    let records = [
      record("stale", name: "stale", path: project.root.appendingPathComponent("stale").path),
      record("fresh", name: "fresh", path: project.root.appendingPathComponent("fresh").path),
      record("no-date", name: "no-date", path: project.root.appendingPathComponent("no-date").path),
      record(
        "dormant", name: "dormant", path: project.root.appendingPathComponent("dormant").path,
        state: .dormant),
      record("nonrepo", name: "nonrepo", path: project.root.appendingPathComponent("nonrepo").path),
      record(
        "missing", name: "missing",
        path: project.root.appendingPathComponent("never-created").path),
    ]

    let candidates = IdleSuggestions.candidates(in: records, now: now) { url in
      switch url.lastPathComponent {
      case "stale": return self.status(lastCommit: old)
      case "fresh": return self.status(lastCommit: fresh)
      case "no-date": return self.status(lastCommit: nil)
      case "dormant": return self.status(lastCommit: old)
      case "nonrepo": return .notARepository
      default: return .unavailable
      }
    }

    #expect(candidates.map { $0.id } == ["stale"])
  }
}
