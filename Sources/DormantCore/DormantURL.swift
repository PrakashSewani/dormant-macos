import Foundation

public enum DormantAction: String, CaseIterable, Sendable {
  case open
  case clean
  case archive
  case restore
  case projectInfo = "project-info"
  case openRepository = "open-repository"
}

public enum DormantURL {
  public static func parse(_ url: URL) -> (action: DormantAction, fileURL: URL)? {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      components.scheme?.lowercased() == "dormant",
      let host = components.host,
      let action = DormantAction(rawValue: host),
      let pathValue = components.queryItems?.first(where: { $0.name == "path" })?.value,
      let fileURL = URL(string: pathValue),
      fileURL.isFileURL
    else {
      return nil
    }
    return (action, fileURL)
  }
}
