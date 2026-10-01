import Foundation
import Testing

@testable import DormantCore

@Suite struct SizeAccountingTests {
  @Test func sumsNestedRegularFiles() throws {
    let project = try TempProject()
    defer { project.destroy() }
    try project.file("a.txt", byteCount: 5)
    try project.file("sub/b.txt", byteCount: 3)
    try project.directory("empty")

    #expect(SizeAccounting.totalBytes(at: project.root) == 8)
  }

  @Test func symlinksAreNotFollowed() throws {
    let target = try TempProject()
    defer { target.destroy() }
    let project = try TempProject()
    defer { project.destroy() }
    try target.file("big.bin", byteCount: 100)
    try project.file("real.bin", byteCount: 10)
    try project.symlink("link.bin", to: target.root.appendingPathComponent("big.bin"))
    try project.symlink("link-dir", to: target.root)

    #expect(SizeAccounting.totalBytes(at: project.root) == 10)
  }

  @Test func missingPathsCountZero() {
    let missing = FileManager.default.temporaryDirectory
      .appendingPathComponent("dormant-missing-\(UUID().uuidString)")
    #expect(SizeAccounting.totalBytes(at: missing) == 0)
  }
}
