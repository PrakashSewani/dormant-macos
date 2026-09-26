import AppKit
import SwiftUI

struct MainView: View {
  var body: some View {
    Text("Projects will appear here.")
      .frame(minWidth: 320, minHeight: 200)
      .onOpenURL { _ in
        NSApp.activate()
      }
  }
}
