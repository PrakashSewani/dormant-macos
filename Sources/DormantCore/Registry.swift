import Foundation

public enum ProjectState: Sendable {
  case active
  case dormant
}

public struct ProjectRecord: Sendable, Identifiable {
  public let id: String
  public let name: String
  public let path: String
  public let ecosystem: ProjectEcosystem
  public let state: ProjectState
  public let gitRemote: String?
  public let createdAt: Date
  public let updatedAt: Date
  public let lastScannedAt: Date?
}

public struct ArchiveRecord: Sendable {
  public let id: String
  public let projectID: String
  public let storePath: String
  public let createdAt: Date
  public let size: Int
  public let manifestPath: String
}

public struct Registry {
  let db: SQLiteDB

  public init(path: URL) throws {
    try FileManager.default.createDirectory(
      at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
    let db = try SQLiteDB(path: path.path)
    try Registry.migrate(db)
    self.db = db
  }

  @discardableResult
  public func upsertProject(
    name: String,
    path: String,
    ecosystem: ProjectEcosystem,
    gitRemote: String?
  ) throws -> ProjectRecord {
    let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
    let timestamp = iso8601(Date())
    try db.run(
      """
      INSERT INTO projects
        (id, name, path, ecosystem, state, git_remote, created_at, updated_at, last_scanned_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)
      ON CONFLICT(path) DO UPDATE SET
        name = excluded.name,
        ecosystem = excluded.ecosystem,
        git_remote = excluded.git_remote,
        updated_at = excluded.updated_at
      """,
      binds: [
        .text(UUID().uuidString), .text(name), .text(standardized), .text(slug(ecosystem)),
        .text(slug(ProjectState.active)), gitRemote.map(SQLValue.text) ?? .null, .text(timestamp),
        .text(timestamp),
      ]
    )
    guard let record = try project(path: standardized) else {
      throw RegistryError(message: "project row missing after upsert at \(standardized)")
    }
    return record
  }

  public func project(id: String) throws -> ProjectRecord? {
    try firstProject("SELECT * FROM projects WHERE id = ?", binds: [.text(id)])
  }

  public func project(path: String) throws -> ProjectRecord? {
    let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
    return try firstProject("SELECT * FROM projects WHERE path = ?", binds: [.text(standardized)])
  }

  public func allProjects() throws -> [ProjectRecord] {
    try db.query("SELECT * FROM projects").map { try Self.projectRecord($0) }
  }

  public func setState(_ state: ProjectState, id: String) throws {
    try db.run(
      "UPDATE projects SET state = ?, updated_at = ? WHERE id = ?",
      binds: [.text(slug(state)), .text(iso8601(Date())), .text(id)])
  }

  public func setGitRemote(_ remote: String?, id: String) throws {
    try db.run(
      "UPDATE projects SET git_remote = ?, updated_at = ? WHERE id = ?",
      binds: [remote.map(SQLValue.text) ?? .null, .text(iso8601(Date())), .text(id)])
  }

  public func markScanned(id: String) throws {
    let timestamp = iso8601(Date())
    try db.run(
      "UPDATE projects SET last_scanned_at = ?, updated_at = ? WHERE id = ?",
      binds: [.text(timestamp), .text(timestamp), .text(id)])
  }

  @discardableResult
  public func recordArchive(
    projectID: String,
    storePath: String,
    size: Int,
    manifestPath: String
  ) throws -> ArchiveRecord {
    let timestamp = iso8601(Date())
    try db.run(
      """
      INSERT INTO archives (id, project_id, store_path, created_at, size, manifest_path)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(project_id) DO UPDATE SET
        id = excluded.id,
        store_path = excluded.store_path,
        created_at = excluded.created_at,
        size = excluded.size,
        manifest_path = excluded.manifest_path
      """,
      binds: [
        .text(UUID().uuidString), .text(projectID), .text(storePath), .text(timestamp),
        .int(Int64(size)), .text(manifestPath),
      ]
    )
    guard let record = try archive(projectID: projectID) else {
      throw RegistryError(message: "archive row missing after recordArchive for \(projectID)")
    }
    return record
  }

  public func archive(projectID: String) throws -> ArchiveRecord? {
    let rows = try db.query(
      "SELECT * FROM archives WHERE project_id = ?", binds: [.text(projectID)])
    guard let row = rows.first else {
      return nil
    }
    return try Self.archiveRecord(row)
  }

  public func removeArchive(projectID: String) throws {
    try db.run("DELETE FROM archives WHERE project_id = ?", binds: [.text(projectID)])
  }

  public func deleteProject(id: String) throws {
    try db.run("DELETE FROM projects WHERE id = ?", binds: [.text(id)])
  }

  private func firstProject(_ sql: String, binds: [SQLValue]) throws -> ProjectRecord? {
    let rows = try db.query(sql, binds: binds)
    guard let row = rows.first else {
      return nil
    }
    return try Self.projectRecord(row)
  }

  private static func migrate(_ db: SQLiteDB) throws {
    let rows = try db.query("PRAGMA user_version")
    let version: Int64
    if let row = rows.first, case .int(let int) = row["user_version"] ?? .null {
      version = int
    } else {
      version = 0
    }
    switch version {
    case 0:
      try db.transaction {
        try db.exec(Self.schemaV1)
        try db.exec("PRAGMA user_version = 1")
      }
    case 1:
      break
    default:
      throw RegistryError(message: "unsupported registry schema version \(version)")
    }
  }

  private static func projectRecord(_ row: [String: SQLValue]) throws -> ProjectRecord {
    ProjectRecord(
      id: try rowText(row, "id"),
      name: try rowText(row, "name"),
      path: try rowText(row, "path"),
      ecosystem: ecosystem(fromSlug: try rowText(row, "ecosystem")),
      state: try state(fromSlug: try rowText(row, "state")),
      gitRemote: rowOptionalText(row, "git_remote"),
      createdAt: try date(fromISO8601: try rowText(row, "created_at")),
      updatedAt: try date(fromISO8601: try rowText(row, "updated_at")),
      lastScannedAt: try rowOptionalText(row, "last_scanned_at").map {
        try date(fromISO8601: $0)
      }
    )
  }

  private static func archiveRecord(_ row: [String: SQLValue]) throws -> ArchiveRecord {
    ArchiveRecord(
      id: try rowText(row, "id"),
      projectID: try rowText(row, "project_id"),
      storePath: try rowText(row, "store_path"),
      createdAt: try date(fromISO8601: try rowText(row, "created_at")),
      size: Int(try rowInt(row, "size")),
      manifestPath: try rowText(row, "manifest_path")
    )
  }

  private static let schemaV1 = """
    CREATE TABLE projects (
      id          TEXT    PRIMARY KEY,
      name        TEXT    NOT NULL,
      path        TEXT    NOT NULL UNIQUE,
      ecosystem   TEXT    NOT NULL,
      state       TEXT    NOT NULL CHECK (state IN ('active','dormant')),
      git_remote  TEXT,
      created_at  TEXT    NOT NULL,
      updated_at  TEXT    NOT NULL,
      last_scanned_at TEXT
    );
    CREATE TABLE archives (
      id           TEXT    PRIMARY KEY,
      project_id   TEXT    NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
      store_path   TEXT    NOT NULL,
      created_at   TEXT    NOT NULL,
      size         INTEGER NOT NULL,
      manifest_path TEXT   NOT NULL
    );
    CREATE UNIQUE INDEX archives_one_per_project ON archives(project_id);
    """
}

private func rowText(_ row: [String: SQLValue], _ column: String) throws -> String {
  guard case .text(let value)? = row[column] else {
    throw RegistryError(message: "missing text column '\(column)'")
  }
  return value
}

private func rowOptionalText(_ row: [String: SQLValue], _ column: String) -> String? {
  guard case .text(let value)? = row[column] else {
    return nil
  }
  return value
}

private func rowInt(_ row: [String: SQLValue], _ column: String) throws -> Int64 {
  guard case .int(let value)? = row[column] else {
    throw RegistryError(message: "missing integer column '\(column)'")
  }
  return value
}

private func iso8601(_ date: Date) -> String {
  ISO8601DateFormatter().string(from: date)
}

private func date(fromISO8601 text: String) throws -> Date {
  guard let date = ISO8601DateFormatter().date(from: text) else {
    throw RegistryError(message: "invalid ISO-8601 timestamp '\(text)'")
  }
  return date
}

private func slug(_ state: ProjectState) -> String {
  switch state {
  case .active:
    return "active"
  case .dormant:
    return "dormant"
  }
}

private func state(fromSlug slug: String) throws -> ProjectState {
  switch slug {
  case "active":
    return .active
  case "dormant":
    return .dormant
  default:
    throw RegistryError(message: "invalid project state '\(slug)'")
  }
}

private func slug(_ ecosystem: ProjectEcosystem) -> String {
  switch ecosystem {
  case .node:
    return "node"
  case .python:
    return "python"
  case .rust:
    return "rust"
  case .dotnet:
    return "dotnet"
  case .go:
    return "go"
  case .unknown:
    return "unknown"
  }
}

private func ecosystem(fromSlug slug: String) -> ProjectEcosystem {
  switch slug {
  case "node":
    return .node
  case "python":
    return .python
  case "rust":
    return .rust
  case "dotnet":
    return .dotnet
  case "go":
    return .go
  default:
    return .unknown
  }
}
