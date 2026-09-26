import AppKit
import FinderSync

final class FinderSync: FIFinderSync {
  override init() {
    super.init()
    FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
  }

  override func menu(for menuKind: FIMenuKind) -> NSMenu {
    let menu = NSMenu(title: "Dormant")
    menu.addItem(makeItem(title: "Open", action: #selector(open(_:))))
    menu.addItem(makeItem(title: "Clean", action: #selector(clean(_:))))
    menu.addItem(makeItem(title: "Archive", action: #selector(archive(_:))))
    menu.addItem(makeItem(title: "Restore", action: #selector(restore(_:))))
    menu.addItem(makeItem(title: "Project Info", action: #selector(projectInfo(_:))))
    menu.addItem(makeItem(title: "Open Repository", action: #selector(openRepository(_:))))
    return menu
  }

  private func makeItem(title: String, action: Selector) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
    item.target = self
    return item
  }

  @objc private func open(_ sender: Any?) {
    route(action: "open")
  }

  @objc private func clean(_ sender: Any?) {
    route(action: "clean")
  }

  @objc private func archive(_ sender: Any?) {
    route(action: "archive")
  }

  @objc private func restore(_ sender: Any?) {
    route(action: "restore")
  }

  @objc private func projectInfo(_ sender: Any?) {
    route(action: "project-info")
  }

  @objc private func openRepository(_ sender: Any?) {
    route(action: "open-repository")
  }

  private func route(action: String) {
    guard let path = selectedURL() else { return }
    NSWorkspace.shared.open(dormantURL(action: action, path: path))
  }

  private func selectedURL() -> URL? {
    let controller = FIFinderSyncController.default()
    return controller.selectedItemURLs()?.first ?? controller.targetedURL()
  }

  private func dormantURL(action: String, path: URL) -> URL {
    var components = URLComponents()
    components.scheme = "dormant"
    components.host = action
    components.queryItems = [URLQueryItem(name: "path", value: path.absoluteString)]
    return components.url!
  }
}
