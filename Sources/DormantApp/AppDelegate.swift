import AppKit
import DormantCore

final class AppDelegate: NSObject, NSApplicationDelegate {
  func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
      guard let parsed = DormantURL.parse(url) else { continue }
      NSApp.activate(ignoringOtherApps: true)
      ActionPresenter.shared.present(action: parsed.action, fileURL: parsed.fileURL)
    }
  }
}
