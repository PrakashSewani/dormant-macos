import Foundation
import Testing

@testable import DormantCore

@Suite struct DormantURLTests {
  @Test(
    "Finder Sync slugs round-trip to actions",
    arguments: zip(
      [
        "open",
        "clean",
        "archive",
        "restore",
        "import",
        "open-directory",
        "project-info",
        "open-repository",
      ],
      [
        DormantAction.open,
        .clean,
        .archive,
        .restore,
        .importFolder,
        .openDirectory,
        .projectInfo,
        .openRepository,
      ]
    )
  )
  func slugRoundTrip(slug: String, action: DormantAction) throws {
    let fileURL = URL(fileURLWithPath: "/Users/test/Projects/example")
    let parsed = try #require(DormantURL.parse(finderSyncURL(action: slug, path: fileURL)))
    #expect(parsed.action == action)
    #expect(parsed.fileURL == fileURL)
  }

  @Test(
    "paths with special characters round-trip",
    arguments: [
      "/Users/test/Projects/plain",
      "/Users/test/Projects/My Project",
      "/Users/test/Projects/café/日本語",
      "/Users/test/Projects/notes #3",
      "/Users/test/Projects/what?really",
      "/Users/test/Projects/100% done",
    ]
  )
  func pathRoundTrip(path: String) throws {
    let fileURL = URL(fileURLWithPath: path)
    let parsed = try #require(DormantURL.parse(finderSyncURL(action: "open", path: fileURL)))
    #expect(parsed.action == .open)
    #expect(parsed.fileURL.absoluteString == fileURL.absoluteString)
  }

  @Test("rejects non-dormant schemes")
  func wrongScheme() {
    let url = URL(string: "https://open?path=file:///Users/test/Projects/example")!
    #expect(DormantURL.parse(url) == nil)
  }

  @Test("rejects unknown actions")
  func unknownAction() {
    let url = URL(string: "dormant://nuke?path=file:///Users/test/Projects/example")!
    #expect(DormantURL.parse(url) == nil)
  }

  @Test("rejects a missing path query item")
  func missingPath() {
    let url = URL(string: "dormant://open")!
    #expect(DormantURL.parse(url) == nil)
  }

  @Test("rejects an empty path query item")
  func emptyPath() {
    let url = URL(string: "dormant://open?path=")!
    #expect(DormantURL.parse(url) == nil)
  }

  @Test("rejects a non-file path")
  func nonFilePath() {
    let https = URL(string: "https://example.com/project")!
    let url = finderSyncURL(action: "open", path: https)
    #expect(DormantURL.parse(url) == nil)
  }

  @Test("rejects a path value that is not a file URL")
  func garbagePath() {
    let url = URL(string: "dormant://open?path=not%20a%20valid%20url")!
    #expect(DormantURL.parse(url) == nil)
  }
}

private func finderSyncURL(action: String, path: URL) -> URL {
  var components = URLComponents()
  components.scheme = "dormant"
  components.host = action
  components.queryItems = [URLQueryItem(name: "path", value: path.absoluteString)]
  return components.url!
}
