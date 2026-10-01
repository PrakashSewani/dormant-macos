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
  @Published private(set) var staleIDs: Set<String> = []
  @Published private(set) var savings: SavingsReport?
  @Published private(set) var idleCandidates: [ProjectRecord] = []

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
    computeSavings()
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
      let computed = await Task.detached { () -> (sizes: [String: String], staleIDs: Set<String>) in
        var sizes: [String: String] = [:]
        var staleIDs: Set<String> = []
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
              sizes[row.id] = Bytes.format(archive.size)
            }
          } else {
            sizes[row.id] = Bytes.format(SizeAccounting.totalBytes(at: url))
            if let record = row.record,
              case .repository(let status) = GitInspector().check(root: url),
              Staleness.isStale(lastCommit: status.committerDate)
            {
              staleIDs.insert(record.id)
            }
          }
        }
        return (sizes, staleIDs)
      }.value
      sizeTexts = computed.sizes
      staleIDs = computed.staleIDs
    }
  }

  private static func flatten(_ rows: [ProjectRow]) -> [ProjectRow] {
    rows + rows.flatMap { flatten($0.children ?? []) }
  }

  private func computeSavings() {
    let records = projects
    Task {
      let result = await Task.detached { () -> (SavingsReport, [ProjectRecord]) in
        (Savings.report(for: records), IdleSuggestions.candidates(in: records))
      }.value
      savings = result.0
      idleCandidates = result.1
    }
  }
}

struct ProjectListView: View {
  @StateObject private var model = ProjectListModel()
  @State private var selection: Set<String> = []
  @State private var searchText = ""
  @Environment(\.openWindow) private var openWindow

  private var filteredRows: [ProjectRow] {
    let query = searchText.trimmingCharacters(in: .whitespaces)
    guard !query.isEmpty else { return model.rows }
    return model.rows.compactMap { row in
      if row.title.localizedCaseInsensitiveContains(query)
        || row.path.localizedCaseInsensitiveContains(query)
      {
        return row
      }
      guard let children = row.children else { return nil }
      let matching = children.filter {
        $0.title.localizedCaseInsensitiveContains(query)
          || $0.path.localizedCaseInsensitiveContains(query)
      }
      guard !matching.isEmpty else { return nil }
      return ProjectRow(
        id: row.id, title: row.title, path: row.path, record: row.record, children: matching)
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      if let savings = model.savings, !savings.entries.isEmpty {
        HStack(spacing: UIConstants.buttonSpacing) {
          Label(
            "\(Bytes.format(savings.totalBytes)) reclaimable across "
              + "\(savings.entries.count) projects",
            systemImage: "internaldrive"
          )
          .font(.callout)
          Spacer()
          Button("Clean All…", systemImage: "sparkles") {
            ActionPresenter.shared.startCleanAll(records: model.projects)
          }
          .frame(minWidth: UIConstants.toolbarButtonMinWidth)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .padding(12)
      }
      if !model.idleCandidates.isEmpty {
        HStack(spacing: UIConstants.buttonSpacing) {
          Label(
            "\(model.idleCandidates.count) projects idle for over "
              + "\(Staleness.staleAfterDays) days",
            systemImage: "moon.zzz"
          )
          .font(.callout)
          .foregroundStyle(.secondary)
          Spacer()
          Button("Review…", systemImage: "archivebox") {
            ActionPresenter.shared.reviewIdleCandidates(model.idleCandidates)
          }
          .frame(minWidth: UIConstants.toolbarButtonMinWidth)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
      }
      if model.rows.isEmpty {
        VStack(spacing: 12) {
          Image(systemName: "folder.badge.questionmark")
            .font(.system(size: 42))
            .foregroundStyle(.secondary)
          Text("No projects yet.").font(.headline)
          Text("Use Scan to find projects under a folder like ~/Projects.")
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        Table(filteredRows, children: \.children, selection: $selection) {
          TableColumn("Name") { row in
            HStack(spacing: 6) {
              if let record = row.record {
                Image(systemName: ecosystemSymbol(record.ecosystem))
                  .foregroundStyle(.secondary)
                StateBadge(record: record, isStale: model.staleIDs.contains(record.id))
                Text(record.name)
              } else {
                Image(systemName: "folder.fill")
                  .foregroundStyle(.secondary)
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
            Button("Open", systemImage: "play.fill") { act(.open, ids) }
            Button("Clean…", systemImage: "sparkles") { act(.clean, ids) }
            Button("Archive…", systemImage: "archivebox.fill") { act(.archive, ids) }
            Button("Restore…", systemImage: "arrow.counterclockwise") { act(.restore, ids) }
            Divider()
            Button("Project Info", systemImage: "info.circle") { act(.projectInfo, ids) }
            Button("Open Repository", systemImage: "globe") { act(.openRepository, ids) }
          }
        }
      }
    }
    .frame(minWidth: 720, minHeight: 360)
    .toolbar {
      ToolbarItemGroup {
        Button("Scan…", systemImage: "folder.badge.plus") { chooseRoots() }
          .frame(minWidth: UIConstants.toolbarButtonMinWidth)
        Button("Refresh", systemImage: "arrow.clockwise") { model.refresh() }
          .frame(minWidth: UIConstants.toolbarButtonMinWidth)
      }
    }
    .searchable(text: $searchText, prompt: "Search projects")
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

  private func ecosystemSymbol(_ ecosystem: ProjectEcosystem) -> String {
    switch ecosystem {
    case .node: return "hexagon"
    case .python: return "leaf"
    case .rust: return "gearshape.2"
    case .dotnet: return "square.grid.3x3"
    case .go: return "gauge"
    case .unknown: return "shippingbox"
    }
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
  var isStale: Bool = false

  var body: some View {
    let (text, color) = badge
    Text(text)
      .font(.caption2)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .foregroundStyle(color)
      .glassEffect(.regular.tint(color), in: .capsule)
  }

  private var badge: (String, Color) {
    if record.state == .dormant { return ("Dormant", .orange) }
    if !FileManager.default.fileExists(atPath: record.path) { return ("Missing", .red) }
    if isStale { return ("Stale", .gray) }
    return ("Active", .green)
  }
}
