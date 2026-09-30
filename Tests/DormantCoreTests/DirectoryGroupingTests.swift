import Foundation
import Testing

@testable import DormantCore

@Suite struct DirectoryGroupingTests {
  private func directory(_ path: String) -> DirectoryRecord {
    DirectoryRecord(
      id: path,
      name: (path as NSString).lastPathComponent,
      path: path,
      createdAt: Date(timeIntervalSince1970: 0),
      lastScannedAt: nil
    )
  }

  @Test func picksDeepestContainingDirectory() {
    let directories = [directory("/u/p/Work"), directory("/u/p/Work/api")]
    let forApiApp = DirectoryGrouping.deepestDirectory(
      for: "/u/p/Work/api/app", in: directories)
    #expect(forApiApp?.path == "/u/p/Work/api")
    let forWeb = DirectoryGrouping.deepestDirectory(for: "/u/p/Work/web", in: directories)
    #expect(forWeb?.path == "/u/p/Work")
  }

  @Test func prefixMatchesWholePathSegments() {
    let directories = [directory("/u/p/Work")]
    #expect(DirectoryGrouping.deepestDirectory(for: "/u/p/Workshop/app", in: directories) == nil)
    #expect(DirectoryGrouping.deepestDirectory(for: "/u/p/other", in: directories) == nil)
    let exact = DirectoryGrouping.deepestDirectory(for: "/u/p/Work", in: directories)
    #expect(exact?.path == "/u/p/Work")
  }

  @Test func nilWithoutDirectories() {
    #expect(DirectoryGrouping.deepestDirectory(for: "/u/p/Work/app", in: []) == nil)
  }
}
