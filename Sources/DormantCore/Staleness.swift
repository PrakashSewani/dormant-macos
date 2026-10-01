import Foundation

public enum Staleness {
  public static let staleAfterDays = 30

  public static func isStale(lastCommit: Date?, now: Date = Date()) -> Bool {
    guard let lastCommit else { return false }
    return now.timeIntervalSince(lastCommit) > TimeInterval(staleAfterDays * 86_400)
  }
}
