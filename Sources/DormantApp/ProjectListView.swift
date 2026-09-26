import AppKit
import DormantCore
import SwiftUI

enum Bytes {
  static func format(_ count: Int) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
  }
}

@MainActor
final class ProjectListModel: ObservableObject {
  @Published private(set) var projects: [ProjectRecord] = []
  @Published private(set) var sizeTexts: [String: String] = [:]

  func refresh() {
    var rows: [ProjectRecord] = []
    if let registry = try? Registry(path: DormantPaths().registry) {
      rows = (try? registry.allProjects()) ?? []
    }
    projects = rows.sorted {
      $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
    computeSizes(for: rows)
  }

  func scan(roots: [URL]) {
    Task {
      await Task.detached {
        if let registry = try? Registry(path: DormantPaths().registry) {
          _ = try? Scanner(registry: registry).scan(roots: roots)
        }
      }.value
      NotificationCenter.default.post(name: .dormantDataChanged, object: nil)
    }
  }

  private func computeSizes(for rows: [ProjectRecord]) {
    Task {
      let computed = await Task.detached { () -> [String: String] in
        var result: [String: String] = [:]
        var registry: Registry?
        do {
          registry = try Registry(path: DormantPaths().registry)
        } catch {
          registry = nil
        }
        for row in rows {
          if row.state == .dormant {
            if let archive = try? registry?.archive(projectID: row.id) {
              result[row.id] = Bytes.format(archive.size)
            }
          } else {
            let bytes = SizeAccounting.totalBytes(at: URL(fileURLWithPath: row.path))
            result[row.id] = Bytes.format(bytes)
          }
        }
        return result
      }.value
      sizeTexts = computed
    }
  }
}

struct ProjectListView: View {
  @StateObject private var model = ProjectListModel()
  @State private var selection: Set<String> = []
  @State private var showSettings = false

  var body: some View {
    VStack(spacing: 0) {
      if model.projects.isEmpty {
        VStack(spacing: 8) {
          Text("No projects yet.").font(.headline)
          Text("Use Scan to find projects under a folder like ~/Projects.")
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        Table(model.projects, selection: $selection) {
          TableColumn("Name") { record in
            HStack(spacing: 6) {
              StateBadge(record: record)
              Text(record.name)
            }
          }
          TableColumn("Path") { record in
            Text(record.path)
              .lineLimit(1)
              .truncationMode(.middle)
          }
          .width(min: 180)
          TableColumn("Ecosystem") { record in
            Text(record.ecosystem.slug)
          }
          .width(80)
          TableColumn("State") { record in
            Text(stateText(record))
          }
          .width(80)
          TableColumn("Size") { record in
            Text(model.sizeTexts[record.id] ?? "…")
          }
          .width(80)
        }
        .contextMenu(forSelectionType: String.self) { ids in
          Button("Open") { act(.open, ids) }
          Button("Clean…") { act(.clean, ids) }
          Button("Archive…") { act(.archive, ids) }
          Button("Restore…") { act(.restore, ids) }
          Divider()
          Button("Project Info") { act(.projectInfo, ids) }
          Button("Open Repository") { act(.openRepository, ids) }
        }
      }
    }
    .frame(minWidth: 720, minHeight: 360)
    .toolbar {
      ToolbarItemGroup {
        Button("Scan…") { chooseRoots() }
        Button("Refresh") { model.refresh() }
        Button("Settings…") { showSettings = true }
      }
    }
    .sheet(isPresented: $showSettings) {
      SettingsView(onClose: { showSettings = false })
    }
    .onAppear { model.refresh() }
    .onReceive(NotificationCenter.default.publisher(for: .dormantDataChanged)) { _ in
      model.refresh()
    }
  }

  private func act(_ action: DormantAction, _ ids: Set<String>) {
    guard let id = ids.first,
      let record = model.projects.first(where: { $0.id == id })
    else { return }
    ActionPresenter.shared.present(action: action, fileURL: URL(fileURLWithPath: record.path))
  }

  private func stateText(_ record: ProjectRecord) -> String {
    if record.state == .dormant { return "Dormant" }
    return FileManager.default.fileExists(atPath: record.path) ? "Active" : "Missing"
  }

  private func chooseRoots() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = true
    panel.prompt = "Scan"
    panel.message = "Choose the folders that contain your projects."
    if panel.runModal() == .OK {
      model.scan(roots: panel.urls)
    }
  }
}

struct StateBadge: View {
  let record: ProjectRecord

  var body: some View {
    let (text, color) = badge
    Text(text)
      .font(.caption2)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(color.opacity(0.2))
      .foregroundStyle(color)
      .clipShape(Capsule())
  }

  private var badge: (String, Color) {
    if record.state == .dormant { return ("Dormant", .orange) }
    if !FileManager.default.fileExists(atPath: record.path) { return ("Missing", .red) }
    return ("Active", .green)
  }
}

struct SettingsView: View {
  let onClose: () -> Void
  @AppStorage("editorCommand") private var editorCommand = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Settings").font(.headline)
      Text("Editor command")
        .font(.subheadline)
      Text(
        "Used by the Open action. Use {path} for the project path, "
          + "for example: cursor {path}. Leave empty to open the project folder in Finder."
      )
      .font(.caption)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
      TextField("cursor {path}", text: $editorCommand)
        .textFieldStyle(.roundedBorder)
        .frame(width: 360)
      HStack {
        Spacer()
        Button("Done", action: onClose)
          .keyboardShortcut(.defaultAction)
          .controlSize(.large)
          .buttonStyle(.borderedProminent)
      }
    }
    .padding(20)
    .frame(minWidth: 440)
  }
}
