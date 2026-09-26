import AppKit
import SwiftUI

@main
struct DormantApp: App {
  var body: some Scene {
    MenuBarExtra("Dormant", systemImage: "leaf") {
      MenuBarContentView()
    }
    Window("Dormant", id: "main") {
      MainView()
    }
  }
}
