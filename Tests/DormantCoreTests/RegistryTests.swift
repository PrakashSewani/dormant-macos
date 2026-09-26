import Foundation
import Testing

@testable import DormantCore

@Suite struct RegistryTests {
  private func withRegistry(_ body: (Registry, URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("dormant-registry-tests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let registryURL = directory.appendingPathComponent("registry.sqlite")
    let registry = try Registry(path: registryURL)
    try body(registry, registryURL)
  }

  @Test("fresh database is created and migrated to schema v1")
  func createsAndMigrates() throws {
    try withRegistry { registry, _ in
      let userVersion = try registry.db.query("PRAGMA user_version")
      #expect(intValue(userVersion.first, "user_version") == 1)
      let journalMode = try registry.db.query("PRAGMA journal_mode")
      #expect(textValue(journalMode.first, "journal_mode") == "wal")
      let foreignKeys = try registry.db.query("PRAGMA foreign_keys")
      #expect(intValue(foreignKeys.first, "foreign_keys") == 1)
      let busyTimeout = try registry.db.query("PRAGMA busy_timeout")
      #expect(intValue(busyTimeout.first, "timeout") == 2000)
      let tables = try registry.db.query("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map { textValue($0, "name") }
      #expect(tables.contains("projects"))
      #expect(tables.contains("archives"))
    }
  }

  @Test("reopening an existing database keeps data and schema version")
  func reopensExistingDatabase() throws {
    try withRegistry { registry, registryURL in
      try registry.upsertProject(
        name: "Kept", path: "/projects/kept", ecosystem: .go, gitRemote: nil)
      let reopened = try Registry(path: registryURL)
      let projects = try reopened.allProjects()
      #expect(projects.count == 1)
      #expect(projects.first?.name == "Kept")
      let userVersion = try reopened.db.query("PRAGMA user_version")
      #expect(intValue(userVersion.first, "user_version") == 1)
    }
  }

  @Test("upsert is keyed by path and updates the existing row in place")
  func upsertIdempotency() throws {
    try withRegistry { registry, _ in
      let first = try registry.upsertProject(
        name: "One", path: "/projects/one", ecosystem: .node, gitRemote: nil)
      let second = try registry.upsertProject(
        name: "One Renamed", path: "/projects/one", ecosystem: .rust,
        gitRemote: "git@example.com:one.git")
      let all = try registry.allProjects()
      #expect(all.count == 1)
      #expect(second.id == first.id)
      #expect(second.createdAt == first.createdAt)
      #expect(second.name == "One Renamed")
      #expect(second.ecosystem == .rust)
      #expect(second.gitRemote == "git@example.com:one.git")
      #expect(second.state == .active)
      let third = try registry.upsertProject(
        name: "Two", path: "/projects/two", ecosystem: .node, gitRemote: nil)
      #expect(third.id != first.id)
      let allAgain = try registry.allProjects()
      #expect(allAgain.count == 2)
    }
  }

  @Test("upsert preserves state, created_at and last_scanned_at on the existing row")
  func upsertPreservesUnchangedColumns() throws {
    try withRegistry { registry, _ in
      let project = try registry.upsertProject(
        name: "Stable", path: "/projects/stable", ecosystem: .node, gitRemote: nil)
      try registry.markScanned(id: project.id)
      try registry.setState(.dormant, id: project.id)
      let updated = try registry.upsertProject(
        name: "Stable", path: "/projects/stable", ecosystem: .node, gitRemote: nil)
      #expect(updated.id == project.id)
      #expect(updated.createdAt == project.createdAt)
      #expect(updated.state == .dormant)
      #expect(updated.lastScannedAt != nil)
    }
  }

  @Test("state column rejects values outside the CHECK constraint")
  func stateCheckConstraint() throws {
    try withRegistry { registry, _ in
      #expect(throws: RegistryError.self) {
        try registry.db.run(
          """
          INSERT INTO projects (id, name, path, ecosystem, state, created_at, updated_at)
          VALUES ('bad', 'Bad', '/projects/bad', 'unknown', 'zombie',
            '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z')
          """
        )
      }
    }
  }

  @Test("deleting a project cascades to its archive rows")
  func deleteProjectCascades() throws {
    try withRegistry { registry, _ in
      let project = try registry.upsertProject(
        name: "Cascade", path: "/projects/cascade", ecosystem: .go, gitRemote: nil)
      try registry.recordArchive(
        projectID: project.id, storePath: "/store/cascade/core.tar.gz", size: 10,
        manifestPath: "/store/cascade/manifest.json")
      try registry.deleteProject(id: project.id)
      let archive = try registry.archive(projectID: project.id)
      #expect(archive == nil)
      let rows = try registry.db.query("SELECT * FROM archives")
      #expect(rows.isEmpty)
    }
  }

  @Test("re-recording an archive replaces the single row for the project")
  func recordArchiveReplaces() throws {
    try withRegistry { registry, _ in
      let project = try registry.upsertProject(
        name: "Replace", path: "/projects/replace", ecosystem: .rust, gitRemote: nil)
      let first = try registry.recordArchive(
        projectID: project.id, storePath: "/store/first/core.tar.gz", size: 1,
        manifestPath: "/store/first/manifest.json")
      let second = try registry.recordArchive(
        projectID: project.id, storePath: "/store/second/core.tar.gz", size: 2,
        manifestPath: "/store/second/manifest.json")
      let rows = try registry.db.query("SELECT * FROM archives")
      #expect(rows.count == 1)
      let current = try registry.archive(projectID: project.id)
      #expect(current?.id == second.id)
      #expect(current?.storePath == "/store/second/core.tar.gz")
      #expect(current?.manifestPath == "/store/second/manifest.json")
      #expect(current?.size == 2)
      #expect(current?.storePath != first.storePath)
    }
  }

  @Test("markScanned stamps last_scanned_at and updated_at")
  func markScanned() throws {
    try withRegistry { registry, _ in
      let project = try registry.upsertProject(
        name: "Scan", path: "/projects/scan", ecosystem: .node, gitRemote: nil)
      #expect(project.lastScannedAt == nil)
      let before = Date()
      try registry.markScanned(id: project.id)
      let after = Date()
      let scanned = try registry.project(id: project.id)
      let lastScanned = try #require(scanned?.lastScannedAt)
      #expect(lastScanned >= before.addingTimeInterval(-1))
      #expect(lastScanned <= after)
      #expect(scanned?.updatedAt == lastScanned)
    }
  }

  @Test("project record round-trips every column")
  func projectRoundTrip() throws {
    try withRegistry { registry, _ in
      let inserted = try registry.upsertProject(
        name: "Round Trip", path: "/projects/round-trip", ecosystem: .dotnet,
        gitRemote: "git@github.com:me/round-trip.git")
      try registry.markScanned(id: inserted.id)
      try registry.setState(.dormant, id: inserted.id)
      try registry.setGitRemote(nil, id: inserted.id)
      let byID = try registry.project(id: inserted.id)
      let byPath = try registry.project(path: "/projects/round-trip")
      let record = try #require(byID)
      #expect(record.id == inserted.id)
      #expect(record.name == "Round Trip")
      #expect(record.path == "/projects/round-trip")
      #expect(record.ecosystem == .dotnet)
      #expect(record.state == .dormant)
      #expect(record.gitRemote == nil)
      #expect(record.createdAt == inserted.createdAt)
      #expect(record.lastScannedAt != nil)
      #expect(byPath?.id == record.id)
      #expect(byPath?.name == record.name)
      #expect(byPath?.path == record.path)
      #expect(byPath?.ecosystem == record.ecosystem)
      #expect(byPath?.state == record.state)
      #expect(byPath?.gitRemote == record.gitRemote)
      #expect(byPath?.createdAt == record.createdAt)
      #expect(byPath?.updatedAt == record.updatedAt)
      #expect(byPath?.lastScannedAt == record.lastScannedAt)
      let rows = try registry.db.query(
        "SELECT * FROM projects WHERE id = ?", binds: [.text(record.id)])
      let row = try #require(rows.first)
      #expect(textValue(row, "ecosystem") == "dotnet")
      #expect(textValue(row, "state") == "dormant")
      #expect(textValue(row, "git_remote") == nil)
      #expect(textValue(row, "created_at") != nil)
      #expect(textValue(row, "updated_at") != nil)
      #expect(textValue(row, "last_scanned_at") != nil)
    }
  }

  @Test("archive record round-trips every column")
  func archiveRoundTrip() throws {
    try withRegistry { registry, _ in
      let project = try registry.upsertProject(
        name: "Archived", path: "/projects/archived", ecosystem: .python, gitRemote: nil)
      let record = try registry.recordArchive(
        projectID: project.id, storePath: "/store/\(project.id)/core.tar.gz", size: 4242,
        manifestPath: "/store/\(project.id)/manifest.json")
      let fetched = try registry.archive(projectID: project.id)
      let archive = try #require(fetched)
      #expect(archive.id == record.id)
      #expect(archive.projectID == project.id)
      #expect(archive.storePath == record.storePath)
      #expect(archive.createdAt == record.createdAt)
      #expect(archive.size == 4242)
      #expect(archive.manifestPath == record.manifestPath)
      let rows = try registry.db.query(
        "SELECT * FROM archives WHERE project_id = ?", binds: [.text(project.id)])
      let row = try #require(rows.first)
      #expect(intValue(row, "size") == 4242)
      #expect(textValue(row, "store_path") == record.storePath)
      #expect(textValue(row, "manifest_path") == record.manifestPath)
    }
  }

  @Test("removeArchive deletes only the archive row")
  func removeArchiveKeepsProject() throws {
    try withRegistry { registry, _ in
      let project = try registry.upsertProject(
        name: "Restored", path: "/projects/restored", ecosystem: .node, gitRemote: nil)
      try registry.recordArchive(
        projectID: project.id, storePath: "/store/restored/core.tar.gz", size: 5,
        manifestPath: "/store/restored/manifest.json")
      try registry.removeArchive(projectID: project.id)
      let archive = try registry.archive(projectID: project.id)
      #expect(archive == nil)
      let projectAgain = try registry.project(id: project.id)
      #expect(projectAgain != nil)
    }
  }

  @Test(
    "ecosystem column stores the ecosystem slug",
    arguments: zip(
      [
        ProjectEcosystem.node, .python, .rust, .dotnet, .go, .unknown,
      ],
      ["node", "python", "rust", "dotnet", "go", "unknown"]
    )
  )
  func ecosystemSlug(ecosystem: ProjectEcosystem, slug: String) throws {
    try withRegistry { registry, _ in
      let project = try registry.upsertProject(
        name: "Slug", path: "/projects/slug-\(slug)", ecosystem: ecosystem, gitRemote: nil)
      let rows = try registry.db.query(
        "SELECT * FROM projects WHERE id = ?", binds: [.text(project.id)])
      #expect(textValue(rows.first, "ecosystem") == slug)
    }
  }

  @Test("separate connections to one database see each other's writes")
  func concurrentOpen() throws {
    try withRegistry { registry, registryURL in
      let other = try Registry(path: registryURL)
      let project = try registry.upsertProject(
        name: "Shared", path: "/projects/shared", ecosystem: .node, gitRemote: nil)
      let fromOther = try other.project(id: project.id)
      #expect(fromOther?.name == "Shared")
      try other.setState(.dormant, id: project.id)
      let reloaded = try registry.project(id: project.id)
      #expect(reloaded?.state == .dormant)
    }
  }
}

private func textValue(_ row: [String: SQLValue]?, _ column: String) -> String? {
  guard case .text(let value)? = row?[column] else {
    return nil
  }
  return value
}

private func intValue(_ row: [String: SQLValue]?, _ column: String) -> Int64? {
  guard case .int(let value)? = row?[column] else {
    return nil
  }
  return value
}
