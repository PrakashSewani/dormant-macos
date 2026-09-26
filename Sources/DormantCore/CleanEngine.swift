import Foundation

public struct CleanItem: Sendable {
  public let relativePath: String
  public let name: String
  public let sizeBytes: Int
  public let matchedRule: String
}

public struct CleanPlan: Sendable {
  public let root: URL
  public let items: [CleanItem]

  public var totalReclaim: Int {
    items.reduce(0) { $0 + $1.sizeBytes }
  }
}

public struct CleanFailure: Sendable {
  public let relativePath: String
  public let message: String
}

public struct CleanResult: Sendable {
  public let removed: [String]
  public let failures: [CleanFailure]
}

public struct CleanEngine {
  private let classifier: Classifier

  public init(classifier: Classifier = Classifier()) {
    self.classifier = classifier
  }

  public func plan(root: URL) -> CleanPlan {
    let classification = classifier.classify(projectAt: root)
    let items = classification.regenerable
      .map {
        CleanItem(
          relativePath: $0.relativePath,
          name: $0.url.lastPathComponent,
          sizeBytes: $0.sizeBytes,
          matchedRule: $0.matchedRule
        )
      }
      .sorted { $0.relativePath < $1.relativePath }
    return CleanPlan(root: root.standardizedFileURL, items: items)
  }

  public func execute(plan: CleanPlan) -> CleanResult {
    var removed: [String] = []
    var failures: [CleanFailure] = []
    for item in plan.items {
      let url = plan.root.appendingPathComponent(item.relativePath).standardizedFileURL
      let path = RegenerablePath(
        url: url,
        relativePath: item.relativePath,
        matchedRule: item.matchedRule,
        sizeBytes: item.sizeBytes
      )
      guard classifier.revalidate(path, projectAt: plan.root) else {
        failures.append(
          CleanFailure(
            relativePath: item.relativePath,
            message: "no longer classified as regenerable; left in place"
          )
        )
        continue
      }
      do {
        try FileManager.default.removeItem(at: url)
        removed.append(item.relativePath)
      } catch {
        failures.append(
          CleanFailure(relativePath: item.relativePath, message: error.localizedDescription)
        )
      }
    }
    return CleanResult(removed: removed, failures: failures)
  }
}
