import Foundation
import Testing

@testable import DormantCore

@Suite struct CleanEngineTests {
  @Test func planListsOnlyRegenerablePathsWithSizes() throws {
    let project = try TempProject()
    defer { project.destroy() }
    try project.file("package.json", contents: "{}")
    try project.file("node_modules/a.js", byteCount: 5)
    try project.file("dist/b.js", byteCount: 3)
    try project.file("src/keep.txt", byteCount: 10)

    let plan = CleanEngine().plan(root: project.root)

    #expect(plan.items.map { $0.relativePath } == ["dist", "node_modules"])
    #expect(plan.totalReclaim == 8)
  }

  @Test func executeRemovesExactlyThePlan() throws {
    let project = try TempProject()
    defer { project.destroy() }
    try project.file("package.json", contents: "{}")
    try project.file("node_modules/a.js", byteCount: 5)
    try project.file("dist/b.js", byteCount: 3)
    try project.file("src/keep.txt", byteCount: 10)
    let engine = CleanEngine()

    let result = engine.execute(plan: engine.plan(root: project.root))

    #expect(result.removed == ["dist", "node_modules"])
    #expect(result.failures.isEmpty)
    let fm = FileManager.default
    #expect(!fm.fileExists(atPath: project.root.appendingPathComponent("dist").path))
    #expect(!fm.fileExists(atPath: project.root.appendingPathComponent("node_modules").path))
    #expect(fm.fileExists(atPath: project.root.appendingPathComponent("package.json").path))
    #expect(fm.fileExists(atPath: project.root.appendingPathComponent("src/keep.txt").path))
  }

  @Test func tamperedPlansAreRejectedAndReported() throws {
    let project = try TempProject()
    defer { project.destroy() }
    try project.file("package.json", contents: "{}")
    try project.file("node_modules/a.js", byteCount: 5)
    try project.file("src/keep.txt", byteCount: 10)
    let engine = CleanEngine()

    let good = CleanItem(
      relativePath: "node_modules",
      name: "node_modules",
      sizeBytes: 5,
      matchedRule: "node:node_modules"
    )
    let tampered = CleanItem(
      relativePath: "src",
      name: "src",
      sizeBytes: 10,
      matchedRule: "node:node_modules"
    )
    let plan = CleanPlan(root: project.root, items: [good, tampered])

    let result = engine.execute(plan: plan)

    #expect(result.removed == ["node_modules"])
    #expect(result.failures.map { $0.relativePath } == ["src"])
    #expect(
      FileManager.default.fileExists(atPath: project.root.appendingPathComponent("src").path)
    )
  }

  @Test func scopeIsRecheckedBeforeRemoval() throws {
    let project = try TempProject()
    defer { project.destroy() }
    try project.file("package.json", contents: "{}")
    try project.directory("dist")
    let engine = CleanEngine()

    let plan = engine.plan(root: project.root)
    #expect(plan.items.map { $0.relativePath } == ["dist"])
    try FileManager.default.removeItem(at: project.root.appendingPathComponent("package.json"))

    let result = engine.execute(plan: plan)

    #expect(result.removed.isEmpty)
    #expect(result.failures.map { $0.relativePath } == ["dist"])
    let distPath = project.root.appendingPathComponent("dist").path
    #expect(FileManager.default.fileExists(atPath: distPath))
  }

  @Test func removingSymlinkedRegenerableLeavesTargetIntact() throws {
    let target = try TempProject()
    defer { target.destroy() }
    let project = try TempProject()
    defer { project.destroy() }
    try target.file("outside/keep.txt", byteCount: 7)
    try project.file("package.json", contents: "{}")
    try project.symlink("node_modules", to: target.root.appendingPathComponent("outside"))
    let engine = CleanEngine()

    let plan = engine.plan(root: project.root)
    #expect(plan.items.map { $0.relativePath } == ["node_modules"])
    #expect(plan.totalReclaim == 0)

    let result = engine.execute(plan: plan)

    #expect(result.removed == ["node_modules"])
    #expect(result.failures.isEmpty)
    #expect(
      FileManager.default.fileExists(
        atPath: target.root.appendingPathComponent("outside/keep.txt").path
      )
    )
  }
}
