import AppKit
import DormantCore
import SwiftUI

enum Bytes {
  static func format(_ count: Int) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
  }
}

struct ProjectRow: Identifiable {
  let id: String
  let title: String
  let path: String
  let record: ProjectRecord?
  var children: [ProjectRow]?
}

@MainActor
final class ProjectListModel: ObservableObject {
  @Published private(set) var rows: [ProjectRow] = []
  @Published private(set) var projects: [ProjectRecord] = []
  @Published private(set) var sizeTexts: [String: String] = [:]

  func refresh() {
    var projectRows: [ProjectRecord] = []
    var directoryRows: [DirectoryRecord] = []
    if let registry = try? Registry(path: DormantPaths().registry) {
      projectRows = (try? registry.allProjects()) ?? []
      directoryRows = (try? registry.allDirectories()) ?? []
    }
    projects = projectRows
    rows = Self.buildRows(directories: directoryRows, projects: projectRows)
    computeSizes()
  }

  func scan(roots: [URL]) {
    Task {
      await Task.detached {
        if let registry = try? Registry(path: DormantPaths().registry) {
          let scanner = Scanner(registry: registry)
          for root in roots {
            _ = try? scanner.importDirectory(at: root)
          }
        }
      }.value
      NotificationCenter.default.post(name: .dormantDataChanged, object: nil)
    }
  }

  func project(for id: String?) -> ProjectRecord? {
    guard let id else { return nil }
    return projects.first { $0.id == id }
  }

  private static func buildRows(
    directories: [DirectoryRecord],
    projects: [ProjectRecord]
  ) -> [ProjectRow] {
    var grouped: [String: [ProjectRecord]] = [:]
    var ungrouped: [ProjectRecord] = []
    for project in projects {
      if let directory = DirectoryGrouping.deepestDirectory(for: project.path, in: directories) {
        grouped[directory.path, default: []].append(project)
      } else {
        ungrouped.append(project)
      }
    }
    var result: [ProjectRow] = []
    for directory in directories.sorted(by: Self.alphabetical) {
      let children = (grouped[directory.path] ?? []).sorted(by: Self.alphabetical).map {
        Self.projectRow($0)
      }
      result.append(
        ProjectRow(
          id: "dir:\(directory.path)",
          title: directory.name,
          path: directory.path,
          record: nil,
          children: children.isEmpty ? nil : children
        )
      )
    }
    result += ungrouped.sorted(by: Self.alphabetical).map { Self.projectRow($0) }
    return result
  }

  private static func projectRow(_ record: ProjectRecord) -> ProjectRow {
    ProjectRow(id: record.id, title: record.name, path: record.path, record: record, children: nil)
  }

  private static func alphabetical(_ lhs: ProjectRecord, _ rhs: ProjectRecord) -> Bool {
    lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
  }

  private static func alphabetical(_ lhs: DirectoryRecord, _ rhs: DirectoryRecord) -> Bool {
    lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
  }

  private func computeSizes() {
    let pending = Self.flatten(rows)
    Task {
      let computed = await Task.detached { () -> [String: String] in
        var result: [String: String] = [:]
        var registry: Registry?
        do {
          registry = try Registry(path: DormantPaths().registry)
        } catch {
          registry = nil
        }
        for row in pending {
          let url = URL(fileURLWithPath: row.path)
          if let record = row.record, record.state == .dormant {
            if let archive = try? registry?.archive(projectID: record.id) {
              result[row.id] = Bytes.format(archive.size)
            }
          } else {
            result[row.id] = Bytes.format(SizeAccounting.totalBytes(at: url))
          }
        }
        return result
      }.value
      sizeTexts = computed
    }
  }

  private static func flatten(_ rows: [ProjectRow]) -> [ProjectRow] {
    rows + rows.flatMap { flatten($0.children ?? []) }
  }
}

struct ProjectListView: View {
  @StateObject private var model = ProjectListModel()
  @State private var selection: Set<String> = []
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    VStack(spacing: 0) {
      if model.rows.isEmpty {
        VStack(spacing: 8) {
          Text("No projects yet.").font(.headline)
          Text("Use Scan to find projects under a folder like ~/Projects.")
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        Table(model.rows, children: \.children, selection: $selection) {
          TableColumn("Name") { row in
            HStack(spacing: 6) {
              if let record = row.record {
                StateBadge(record: record)
                Text(record.name)
              } else {
                Image(systemName: "folder")
                Text(row.title).fontWeight(.semibold)
              }
            }
          }
          TableColumn("Path") { row in
            Text(row.path)
              .lineLimit(1)
              .truncationMode(.middle)
          }
          .width(min: 180)
          TableColumn("Ecosystem") { row in
            Text(row.record?.ecosystem.slug ?? "")
          }
          .width(80)
          TableColumn("State") { row in
            Text(row.record.map { stateText($0) } ?? "")
          }
          .width(80)
          TableColumn("Size") { row in
            Text(model.sizeTexts[row.id] ?? "…")
          }
          .width(80)
        }
        .contextMenu(forSelectionType: String.self) { ids in
          if model.project(for: ids.first) != nil {
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
    }
    .frame(minWidth: 720, minHeight: 360)
    .toolbar {
      ToolbarItemGroup {
        Button("Scan…") { chooseRoots() }
        Button("Refresh") { model.refresh() }
      }
    }
    .onAppear {
      ActionPresenter.shared.openMain = { path in
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
        if let path {
          selection = ["dir:\(path)"]
        }
      }
      if let pending = ActionPresenter.shared.takePendingSelection() {
        selection = ["dir:\(pending)"]
      }
      model.refresh()
    }
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
