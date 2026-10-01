import Foundation
import Testing

@testable import DormantCore

@Suite struct SavingsTests {
  private func record(
    _ id: String, name: String, path: String, state: ProjectState = .active
  ) -> ProjectRecord {
    ProjectRecord(
      id: id, name: name, path: path, ecosystem: .node, state: state, gitRemote: nil,
      createdAt: Date(), updatedAt: Date(), lastScannedAt: nil)
  }

  @Test func reportSortsBiggestFirstAndSums() throws {
    let small = try TempProject()
    defer { small.destroy() }
    try small.file("package.json", contents: "{}")
    try small.file("node_modules/a.js", byteCount: 5)

    let big = try TempProject()
    defer { big.destroy() }
    try big.file("package.json", contents: "{}")
    try big.file("node_modules/a.js", byteCount: 50)

    let report = Savings.report(for: [
      record("small", name: "small", path: small.root.path),
      record("big", name: "big", path: big.root.path),
    ])

    #expect(report.entries.map { $0.projectID } == ["big", "small"])
    #expect(report.entries.map { $0.reclaimBytes } == [50, 5])
    #expect(report.totalBytes == 55)
  }

  @Test func reportSkipsDormantAndCleanProjects() throws {
    let clean = try TempProject()
    defer { clean.destroy() }
    try clean.file("package.json", contents: "{}")
    try clean.file("src/keep.txt", byteCount: 10)

    let dormant = try TempProject()
    defer { dormant.destroy() }
    try dormant.file("package.json", contents: "{}")
    try dormant.file("node_modules/a.js", byteCount: 5)

    let missing = record("missing", name: "missing", path: clean.root.path + "-gone")

    let report = Savings.report(for: [
      record("clean", name: "clean", path: clean.root.path),
      record("dormant", name: "dormant", path: dormant.root.path, state: .dormant),
      missing,
    ])

    #expect(report.entries.isEmpty)
    #expect(report.totalBytes == 0)
  }
}
