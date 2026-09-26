import Testing

@testable import DormantCore

@Suite struct ClassifierTests {
  @Test(
    "known manifests map to ecosystems",
    arguments: zip(
      [
        "package.json", "pyproject.toml", "requirements.txt", "Cargo.toml", "App.csproj",
        "App.sln", "go.mod",
      ],
      [ProjectEcosystem.node, .python, .python, .rust, .dotnet, .dotnet, .go]
    )
  )
  func knownManifests(name: String, expected: ProjectEcosystem) {
    #expect(Classifier().ecosystem(forManifestNamed: name) == expected)
  }

  @Test(
    "unknown manifests map to unknown",
    arguments: ["README.md", "Gemfile", "setup.py", "pom.xml", "Makefile", ""]
  )
  func unknownManifests(name: String) {
    #expect(Classifier().ecosystem(forManifestNamed: name) == .unknown)
  }
}
