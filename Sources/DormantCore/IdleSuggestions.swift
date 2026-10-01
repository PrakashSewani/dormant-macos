import Foundation

public enum IdleSuggestions {
  public static func candidates(
    in records: [ProjectRecord],
    now: Date = Date(),
    gitState: (URL) -> GitState = { GitInspector().check(root: $0) }
  ) -> [ProjectRecord] {
    let fm = FileManager.default
    return records.filter { record in
      guard record.state == .active, fm.fileExists(atPath: record.path) else { return false }
      guard case .repository(let status) = gitState(URL(fileURLWithPath: record.path)) else {
        return false
      }
      return Staleness.isStale(lastCommit: status.committerDate, now: now)
    }
  }
}
