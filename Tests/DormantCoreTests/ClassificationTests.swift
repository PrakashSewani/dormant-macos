import Foundation
import Testing

@testable import DormantCore

@Suite struct ClassificationTests {
  private func matchedPaths(_ classification: ProjectClassification) -> Set<String> {
    Set(classification.regenerable.map { $0.relativePath })
  }

  @Test func nodeScopesMatchAnywhereAndManifestSiblingOnly() throws {
    let project = try TempProject()
    defer { project.destroy() }
    try project.file("package.json", contents: "{}")
    try project.file("node_modules/leftpad/index.js", contents: "x")
    try project.file("sub/node_modules/x.js", contents: "x")
    try project.directory(".next")
    try project.directory("dist")
    try project.directory("sub/dist")
    try project.directory("docs/build")

    let classification = Classifier().classify(projectAt: project.root)

    #expect(classification.ecosystems == [.node])
    #expect(
      matchedPaths(classification) == ["node_modules", "sub/node_modules", ".next", "dist"]
    )
  }

  @Test func rustTargetOnlyBesideItsManifest() throws {
    let project = try TempProject()
    defer { project.destroy() }
    try project.file("crates/foo/Cargo.toml", contents: "")
    try project.directory("crates/foo/target/debug")
    try project.directory("assets/target")

    let classification = Classifier().classify(projectAt: project.root)

    #expect(classification.ecosystems == [.rust])
    #expect(matchedPaths(classification) == ["crates/foo/target"])
  }

  @Test func dotnetBinObjNeedAProjectFileNotJustASolution() throws {
    let project = try TempProject()
    defer { project.destroy() }
    try project.file("src/App/App.csproj", contents: "")
    try project.directory("src/App/bin")
    try project.directory("src/App/obj")
    try project.file("sln-only/Solution.sln", contents: "")
    try project.directory("sln-only/bin")

    let classification = Classifier().classify(projectAt: project.root)

    #expect(classification.ecosystems == [.dotnet])
    #expect(matchedPaths(classification) == ["src/App/bin", "src/App/obj"])
  }

  @Test func pythonScopes() throws {
    let project = try TempProject()
    defer { project.destroy() }
    try project.file("pyproject.toml", contents: "")
    try project.directory(".venv")
    try project.directory("sub/.venv")
    try project.directory("venv")
    try project.directory("sub/venv")
    try project.directory("pkg.egg-info")
    try project.directory("other/pkg.egg-info")
    try project.directory("src/pkg/__pycache__")

    let classification = Classifier().classify(projectAt: project.root)

    #expect(classification.ecosystems == [.python])
    #expect(
      matchedPaths(classification)
        == [".venv", "sub/.venv", "venv", "pkg.egg-info", "src/pkg/__pycache__"]
    )
  }

  @Test func multiEcosystemProjectsUseTheUnionOfRules() throws {
    let project = try TempProject()
    defer { project.destroy() }
    try project.file("package.json", contents: "{}")
    try project.file("Cargo.toml", contents: "")
    try project.directory("node_modules")
    try project.directory("target")

    let classification = Classifier().classify(projectAt: project.root)

    #expect(classification.ecosystems == [.node, .rust])
    #expect(matchedPaths(classification) == ["node_modules", "target"])
  }

  @Test func goProjectsReclaimNothing() throws {
    let project = try TempProject()
    defer { project.destroy() }
    try project.file("go.mod", contents: "")
    try project.directory("vendor")
    try project.directory("src")

    let classification = Classifier().classify(projectAt: project.root)

    #expect(classification.ecosystems == [.go])
    #expect(classification.regenerable.isEmpty)
  }

  @Test func unknownProjectsReclaimNothing() throws {
    let project = try TempProject()
    defer { project.destroy() }
    try project.file("README.md", contents: "# hi")
    try project.directory("dist")

    let classification = Classifier().classify(projectAt: project.root)

    #expect(classification.ecosystems == [.unknown])
    #expect(classification.regenerable.isEmpty)
  }

  @Test func gitAndCoreFilesAreNeverRegenerable() throws {
    let project = try TempProject()
    defer { project.destroy() }
    try project.file("package.json", contents: "{}")
    try project.file("src/main.js", contents: "")
    try project.file("README.md", contents: "")
    try project.directory(".git/hooks")
    try project.file(".git/config", contents: "")
    try project.directory(".git/node_modules")

    let classification = Classifier().classify(projectAt: project.root)

    #expect(matchedPaths(classification).isEmpty)
  }

  @Test func symlinksAreMatchedButNeverTraversed() throws {
    let target = try TempProject()
    defer { target.destroy() }
    let project = try TempProject()
    defer { project.destroy() }
    try target.file("outside/node_modules/big.js", contents: "x")
    try project.file("package.json", contents: "{}")
    try project.symlink("node_modules", to: target.root.appendingPathComponent("outside"))
    try project.symlink("ghost", to: target.root)
    try project.file("ghost/node_modules/hidden.js", contents: "x")

    let classification = Classifier().classify(projectAt: project.root)

    #expect(matchedPaths(classification) == ["node_modules"])
    let link = try #require(classification.regenerable.first)
    #expect(link.sizeBytes == 0)
  }

  @Test func revalidationAcceptsMintedPathsAndRejectsTamperedOnes() throws {
    let project = try TempProject()
    defer { project.destroy() }
    try project.file("package.json", contents: "{}")
    try project.directory("node_modules")
    try project.directory("dist")

    let classifier = Classifier()
    let classification = classifier.classify(projectAt: project.root)
    #expect(matchedPaths(classification) == ["node_modules", "dist"])
    for path in classification.regenerable {
      #expect(classifier.revalidate(path, projectAt: project.root))
    }

    let nodeModules = try #require(
      classification.regenerable.first { $0.relativePath == "node_modules" }
    )

    let wrongRelative = RegenerablePath(
      url: nodeModules.url,
      relativePath: "somewhere/else",
      matchedRule: nodeModules.matchedRule,
      sizeBytes: 0
    )
    #expect(!classifier.revalidate(wrongRelative, projectAt: project.root))

    try project.file("src/keep.txt", contents: "keep")
    let wrongRule = RegenerablePath(
      url: project.root.appendingPathComponent("src"),
      relativePath: "src",
      matchedRule: "node:node_modules",
      sizeBytes: 0
    )
    #expect(!classifier.revalidate(wrongRule, projectAt: project.root))

    let outside = RegenerablePath(
      url: URL(fileURLWithPath: "/etc/node_modules"),
      relativePath: "node_modules",
      matchedRule: "node:node_modules",
      sizeBytes: 0
    )
    #expect(!classifier.revalidate(outside, projectAt: project.root))
  }

  @Test func revalidationRejectsPathsReachedThroughSymlinkedParents() throws {
    let target = try TempProject()
    defer { target.destroy() }
    let project = try TempProject()
    defer { project.destroy() }
    try target.directory("node_modules")
    try project.file("package.json", contents: "{}")
    try project.symlink("link", to: target.root)

    let escaped = RegenerablePath(
      url: project.root.appendingPathComponent("link/node_modules"),
      relativePath: "link/node_modules",
      matchedRule: "node:node_modules",
      sizeBytes: 0
    )
    #expect(!Classifier().revalidate(escaped, projectAt: project.root))
  }

  @Test func revalidationReChecksScopeAgainstLiveTree() throws {
    let project = try TempProject()
    defer { project.destroy() }
    try project.file("package.json", contents: "{}")
    try project.directory("dist")

    let classifier = Classifier()
    let classification = classifier.classify(projectAt: project.root)
    let dist = try #require(classification.regenerable.first { $0.relativePath == "dist" })
    #expect(classifier.revalidate(dist, projectAt: project.root))

    try FileManager.default.removeItem(at: project.root.appendingPathComponent("package.json"))
    #expect(!classifier.revalidate(dist, projectAt: project.root))
  }

  @Test func sizesAndTotalsCountRegularFilesOnly() throws {
    let project = try TempProject()
    defer { project.destroy() }
    try project.file("package.json", contents: "{}")
    try project.file("node_modules/a.js", byteCount: 5)
    try project.file("node_modules/nested/b.js", byteCount: 3)

    let classification = Classifier().classify(projectAt: project.root)

    let nodeModules = try #require(classification.regenerable.first)
    #expect(nodeModules.sizeBytes == 8)
    #expect(classification.totalRegenerableBytes == 8)
  }
}
