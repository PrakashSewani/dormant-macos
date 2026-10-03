import AppKit
import DormantCore
import SwiftUI

struct MenuBarContentView: View {
  @Environment(\.openWindow) private var openWindow
  @State private var projects: [ProjectRecord] = []
  @State private var finderExtensionState: FinderExtensionState?

  var body: some View {
    Group {
      Section("Projects") {
        if projects.isEmpty {
          Text("No projects yet")
        } else {
          ForEach(projects) { record in
            if record.state == .dormant {
              Button("Restore \(record.name)…") {
                ActionPresenter.shared.present(
                  action: .restore, fileURL: URL(fileURLWithPath: record.path))
              }
            } else {
              Button("Open \(record.name)") {
                ActionPresenter.shared.present(
                  action: .open, fileURL: URL(fileURLWithPath: record.path))
              }
            }
          }
        }
      }
      Divider()
      if finderExtensionState == .disabled {
        Button("Enable Finder Extension") {
          ActionPresenter.shared.enableFinderExtension()
        }
        Divider()
      }
      Button("Open Dormant") {
        openWindow(id: "main")
        NSApp.activate()
      }
      Divider()
      Button("Quit") {
        NSApp.terminate(nil)
      }
    }
    .onAppear {
      projects = Self.load()
      Task {
        finderExtensionState = await Task.detached { FinderExtension().state() }.value
      }
    }
  }

  init() {
    _projects = State(initialValue: Self.load())
  }

  private static func load() -> [ProjectRecord] {
    var loaded: [ProjectRecord] = []
    if let registry = try? Registry(path: DormantPaths().registry) {
      loaded = (try? registry.allProjects()) ?? []
    }
    return
      loaded
      .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
      .prefix(10)
      .map { $0 }
  }
}
