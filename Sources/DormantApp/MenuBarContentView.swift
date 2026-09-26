import AppKit
import SwiftUI

struct MenuBarContentView: View {
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Button("Open Dormant") {
      openWindow(id: "main")
      NSApp.activate()
    }
    Divider()
    Button("Quit") {
      NSApp.terminate(nil)
    }
  }
}
