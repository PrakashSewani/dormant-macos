import Foundation

public enum PatternScope: Sendable, Equatable {
  case anywhereInProject
  case manifestSibling
  case projectRoot
}

public enum ManifestMatcher: Sendable, Equatable {
  case exact(String)
  case suffix(String)

  public func matches(fileName: String) -> Bool {
    let lowered = fileName.lowercased()
    switch self {
    case .exact(let name):
      return lowered == name
    case .suffix(let suffix):
      return lowered.count > suffix.count && lowered.hasSuffix(suffix)
    }
  }
}

public struct RegenerablePattern: Sendable, Equatable {
  public let name: String
  public let isSuffix: Bool
  public let scope: PatternScope

  public init(name: String, isSuffix: Bool, scope: PatternScope) {
    self.name = name
    self.isSuffix = isSuffix
    self.scope = scope
  }

  public func matches(fileName: String) -> Bool {
    if isSuffix {
      return fileName.count > name.count && fileName.hasSuffix(name)
    }
    return fileName == name
  }

  var descriptor: String {
    isSuffix ? "*" + name : name
  }
}

public struct ClassificationRule: Sendable {
  public let ecosystem: ProjectEcosystem
  public let detectionManifests: [ManifestMatcher]
  public let siblingAnchors: [ManifestMatcher]
  public let patterns: [RegenerablePattern]

  public init(
    ecosystem: ProjectEcosystem,
    detectionManifests: [ManifestMatcher],
    siblingAnchors: [ManifestMatcher],
    patterns: [RegenerablePattern]
  ) {
    self.ecosystem = ecosystem
    self.detectionManifests = detectionManifests
    self.siblingAnchors = siblingAnchors
    self.patterns = patterns
  }

  func detects(fileName: String) -> Bool {
    detectionManifests.contains { $0.matches(fileName: fileName) }
  }

  func anchors(fileName: String) -> Bool {
    siblingAnchors.contains { $0.matches(fileName: fileName) }
  }
}

public enum ClassificationRules {
  public static let all: [ClassificationRule] = [
    ClassificationRule(
      ecosystem: .node,
      detectionManifests: [.exact("package.json")],
      siblingAnchors: [.exact("package.json")],
      patterns: [
        RegenerablePattern(name: "node_modules", isSuffix: false, scope: .anywhereInProject),
        RegenerablePattern(name: ".next", isSuffix: false, scope: .manifestSibling),
        RegenerablePattern(name: ".nuxt", isSuffix: false, scope: .manifestSibling),
        RegenerablePattern(name: ".turbo", isSuffix: false, scope: .manifestSibling),
        RegenerablePattern(name: ".svelte-kit", isSuffix: false, scope: .manifestSibling),
        RegenerablePattern(name: ".parcel-cache", isSuffix: false, scope: .manifestSibling),
        RegenerablePattern(name: "dist", isSuffix: false, scope: .manifestSibling),
        RegenerablePattern(name: "build", isSuffix: false, scope: .manifestSibling),
        RegenerablePattern(name: "coverage", isSuffix: false, scope: .manifestSibling),
        RegenerablePattern(name: ".cache", isSuffix: false, scope: .manifestSibling),
      ]
    ),
    ClassificationRule(
      ecosystem: .python,
      detectionManifests: [.exact("pyproject.toml"), .exact("requirements.txt")],
      siblingAnchors: [.exact("pyproject.toml"), .exact("requirements.txt")],
      patterns: [
        RegenerablePattern(name: "__pycache__", isSuffix: false, scope: .anywhereInProject),
        RegenerablePattern(name: ".venv", isSuffix: false, scope: .anywhereInProject),
        RegenerablePattern(name: ".pytest_cache", isSuffix: false, scope: .anywhereInProject),
        RegenerablePattern(name: ".mypy_cache", isSuffix: false, scope: .anywhereInProject),
        RegenerablePattern(name: ".ruff_cache", isSuffix: false, scope: .anywhereInProject),
        RegenerablePattern(name: ".tox", isSuffix: false, scope: .anywhereInProject),
        RegenerablePattern(name: "venv", isSuffix: false, scope: .projectRoot),
        RegenerablePattern(name: ".egg-info", isSuffix: true, scope: .manifestSibling),
        RegenerablePattern(name: "build", isSuffix: false, scope: .manifestSibling),
        RegenerablePattern(name: "dist", isSuffix: false, scope: .manifestSibling),
        RegenerablePattern(name: ".coverage", isSuffix: false, scope: .manifestSibling),
      ]
    ),
    ClassificationRule(
      ecosystem: .rust,
      detectionManifests: [.exact("cargo.toml")],
      siblingAnchors: [.exact("cargo.toml")],
      patterns: [
        RegenerablePattern(name: "target", isSuffix: false, scope: .manifestSibling)
      ]
    ),
    ClassificationRule(
      ecosystem: .dotnet,
      detectionManifests: [ManifestMatcher.suffix(".csproj"), ManifestMatcher.suffix(".sln")],
      siblingAnchors: [ManifestMatcher.suffix(".csproj")],
      patterns: [
        RegenerablePattern(name: "bin", isSuffix: false, scope: .manifestSibling),
        RegenerablePattern(name: "obj", isSuffix: false, scope: .manifestSibling),
      ]
    ),
    ClassificationRule(
      ecosystem: .go,
      detectionManifests: [.exact("go.mod")],
      siblingAnchors: [.exact("go.mod")],
      patterns: []
    ),
  ]

  public static let discoverySkipNames: Set<String> = Set(
    all.flatMap { rule in
      rule.patterns.filter { !$0.isSuffix }.map { $0.name }
    } + [".git"]
  )

  static func patternID(rule: ClassificationRule, pattern: RegenerablePattern) -> String {
    "\(rule.ecosystem.slug):\(pattern.descriptor)"
  }

  static func pattern(withID id: String) -> (ClassificationRule, RegenerablePattern)? {
    for rule in all {
      for pattern in rule.patterns where patternID(rule: rule, pattern: pattern) == id {
        return (rule, pattern)
      }
    }
    return nil
  }
}
