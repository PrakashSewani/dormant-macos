import Foundation
import SQLite3

enum SQLValue {
  case null
  case int(Int64)
  case text(String)
  case double(Double)
}

struct RegistryError: Error, Sendable, LocalizedError {
  let message: String

  var errorDescription: String? { message }
}

final class SQLiteDB {
  private let handle: OpaquePointer

  init(path: String) throws {
    var database: OpaquePointer?
    let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
    guard sqlite3_open_v2(path, &database, flags, nil) == SQLITE_OK, let opened = database else {
      let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "unable to open \(path)"
      if let database {
        sqlite3_close_v2(database)
      }
      throw RegistryError(message: message)
    }
    handle = opened
    do {
      try exec("PRAGMA journal_mode=WAL")
      try exec("PRAGMA foreign_keys=ON")
      try exec("PRAGMA busy_timeout=2000")
    } catch {
      sqlite3_close_v2(opened)
      throw error
    }
  }

  deinit {
    sqlite3_close_v2(handle)
  }

  func exec(_ sql: String) throws {
    var errorMessage: UnsafeMutablePointer<CChar>?
    if sqlite3_exec(handle, sql, nil, nil, &errorMessage) != SQLITE_OK {
      let message =
        errorMessage.map { String(cString: $0) } ?? String(cString: sqlite3_errmsg(handle))
      sqlite3_free(errorMessage)
      throw RegistryError(message: message)
    }
  }

  func run(_ sql: String, binds: [SQLValue] = []) throws {
    let statement = try prepared(sql, binds: binds)
    defer { sqlite3_finalize(statement) }
    let result = sqlite3_step(statement)
    guard result == SQLITE_DONE || result == SQLITE_ROW else {
      throw RegistryError(message: String(cString: sqlite3_errmsg(handle)))
    }
  }

  func query(_ sql: String, binds: [SQLValue] = []) throws -> [[String: SQLValue]] {
    let statement = try prepared(sql, binds: binds)
    defer { sqlite3_finalize(statement) }
    var rows: [[String: SQLValue]] = []
    while true {
      switch sqlite3_step(statement) {
      case SQLITE_ROW:
        var row: [String: SQLValue] = [:]
        for index in 0..<sqlite3_column_count(statement) {
          row[String(cString: sqlite3_column_name(statement, index))] = columnValue(
            at: index, in: statement)
        }
        rows.append(row)
      case SQLITE_DONE:
        return rows
      default:
        throw RegistryError(message: String(cString: sqlite3_errmsg(handle)))
      }
    }
  }

  func transaction<T>(_ body: () throws -> T) throws -> T {
    try exec("BEGIN IMMEDIATE")
    do {
      let value = try body()
      try exec("COMMIT")
      return value
    } catch {
      try? exec("ROLLBACK")
      throw error
    }
  }

  private func prepared(_ sql: String, binds: [SQLValue]) throws -> OpaquePointer {
    var statement: OpaquePointer?
    let result = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
    guard result == SQLITE_OK, let prepared = statement else {
      throw RegistryError(message: String(cString: sqlite3_errmsg(handle)))
    }
    for (offset, value) in binds.enumerated() {
      let index = Int32(offset + 1)
      let bindResult: Int32
      switch value {
      case .null:
        bindResult = sqlite3_bind_null(prepared, index)
      case .int(let int):
        bindResult = sqlite3_bind_int64(prepared, index, int)
      case .double(let double):
        bindResult = sqlite3_bind_double(prepared, index, double)
      case .text(let text):
        bindResult = sqlite3_bind_text(prepared, index, text, -1, sqliteTransient)
      }
      guard bindResult == SQLITE_OK else {
        sqlite3_finalize(prepared)
        throw RegistryError(message: String(cString: sqlite3_errmsg(handle)))
      }
    }
    return prepared
  }

  private func columnValue(at index: Int32, in statement: OpaquePointer) -> SQLValue {
    switch sqlite3_column_type(statement, index) {
    case SQLITE_INTEGER:
      return .int(sqlite3_column_int64(statement, index))
    case SQLITE_FLOAT:
      return .double(sqlite3_column_double(statement, index))
    case SQLITE_TEXT:
      return .text(String(cString: sqlite3_column_text(statement, index)))
    default:
      return .null
    }
  }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
