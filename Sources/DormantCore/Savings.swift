import Foundation

public struct SavingsReport: Sendable, Equatable {
  public struct Entry: Sendable, Equatable, Identifiable {
    public let projectID: String
    public let name: String
    public let path: String
    public let reclaimBytes: Int

    public var id: String { projectID }

    public init(projectID: String, name: String, path: String, reclaimBytes: Int) {
      self.projectID = projectID
      self.name = name
      self.path = path
      self.reclaimBytes = reclaimBytes
    }
  }

  public let entries: [Entry]

  public init(entries: [Entry]) {
    self.entries = entries
  }

  public var totalBytes: Int {
    entries.reduce(0) { $0 + $1.reclaimBytes }
  }
}

public enum Savings {
  public static func report(for records: [ProjectRecord]) -> SavingsReport {
    let fm = FileManager.default
    var entries: [SavingsReport.Entry] = []
    for record in records {
      guard record.state == .active, fm.fileExists(atPath: record.path) else { continue }
      let reclaim = CleanEngine().plan(root: URL(fileURLWithPath: record.path)).totalReclaim
      if reclaim > 0 {
        entries.append(
          SavingsReport.Entry(
            projectID: record.id, name: record.name, path: record.path, reclaimBytes: reclaim))
      }
    }
    return SavingsReport(entries: entries.sorted { $0.reclaimBytes > $1.reclaimBytes })
  }
}
