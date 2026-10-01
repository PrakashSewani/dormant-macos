import Foundation
import Testing

@testable import DormantCore

@Suite struct StalenessTests {
  @Test func freshCommitIsNotStale() {
    let now = Date()
    #expect(!Staleness.isStale(lastCommit: now.addingTimeInterval(-86_400 * 10), now: now))
  }

  @Test func commitBeyondThresholdIsStale() {
    let now = Date()
    #expect(Staleness.isStale(lastCommit: now.addingTimeInterval(-86_400 * 31), now: now))
  }

  @Test func exactlyAtThresholdIsNotStale() {
    let now = Date()
    #expect(!Staleness.isStale(lastCommit: now.addingTimeInterval(-86_400 * 30), now: now))
  }

  @Test func missingDateIsNotStale() {
    #expect(!Staleness.isStale(lastCommit: nil))
  }
}
