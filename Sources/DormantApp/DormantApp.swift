import AppKit
import SwiftUI

@main
struct DormantApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    MenuBarExtra("Dormant", systemImage: "leaf") {
      MenuBarContentView()
    }
    Window("Dormant", id: "main") {
      ProjectListView()
    }
  }
}
