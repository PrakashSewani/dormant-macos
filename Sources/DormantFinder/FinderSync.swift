import AppKit
import FinderSync

final class FinderSync: FIFinderSync {
  override init() {
    super.init()
    FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
  }

  override func menu(for menuKind: FIMenuKind) -> NSMenu {
    let menu = NSMenu(title: "")
    let root = NSMenuItem(title: "Dormant", action: nil, keyEquivalent: "")
    let submenu = NSMenu(title: "Dormant")
    if menuKind == .contextualMenuForContainer {
      submenu.addItem(
        makeItem(title: "Open Directory in Dormant", action: #selector(openDirectory(_:)))
      )
    } else {
      submenu.addItem(makeItem(title: "Clean", action: #selector(clean(_:))))
      submenu.addItem(makeItem(title: "Archive", action: #selector(archive(_:))))
      submenu.addItem(makeItem(title: "Restore", action: #selector(restore(_:))))
      submenu.addItem(
        makeItem(title: "Import Folder in Dormant", action: #selector(importFolder(_:)))
      )
    }
    root.submenu = submenu
    menu.addItem(root)
    return menu
  }

  private func makeItem(title: String, action: Selector) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
    item.target = self
    return item
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

  @objc private func importFolder(_ sender: Any?) {
    route(action: "import")
  }

  @objc private func openDirectory(_ sender: Any?) {
    route(action: "open-directory")
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
