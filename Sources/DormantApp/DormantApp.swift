import AppKit
import SwiftUI

@main
struct DormantApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    MenuBarExtra("Dormant", image: "Mark") {
      MenuBarContentView()
    }
    Window("Dormant", id: "main") {
      ProjectListView()
    }
  }
}
