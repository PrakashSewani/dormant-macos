import DormantCore
import SwiftUI

struct ProjectInfo: Sendable {
  let name: String
  let path: String
  let stateText: String
  let ecosystemText: String
  let remoteText: String
  let branchText: String
  let lastCommitText: String
  let gitStatusText: String
  let localSizeText: String
  let coreSizeText: String
  let regenerableSizeText: String
  let archiveSizeText: String

  static func load(path: String) -> ProjectInfo {
    let url = URL(fileURLWithPath: path).standardizedFileURL
    var record: ProjectRecord?
    var archiveSize: Int?
    if let registry = try? Registry(path: DormantPaths().registry) {
      record = try? registry.project(path: url.path)
      if let row = try? registry.archive(projectID: record?.id ?? "") {
        archiveSize = row.size
      }
    }
    let exists = FileManager.default.fileExists(atPath: url.path)

    var remoteText = "—"
    var branchText = "—"
    var lastCommitText = "—"
    var gitStatusText = "Not a git repository"
    switch GitInspector().check(root: url) {
    case .repository(let status):
      remoteText = status.remote ?? "(none)"
      branchText = status.branch ?? "—"
      if let head = status.head {
        lastCommitText = String(head.prefix(8))
      }
      if status.isDirty {
        gitStatusText = "\(status.modifiedCount) modified, \(status.untrackedCount) untracked"
      } else {
        gitStatusText = "Clean"
      }
    case .unavailable:
      gitStatusText = "Git unavailable"
    case .notARepository:
      break
    }

    var localSize = 0
    var regenerableSize = 0
    if exists {
      localSize = SizeAccounting.totalBytes(at: url)
      regenerableSize = CleanEngine().plan(root: url).totalReclaim
    }

    let stateText: String
    if record?.state == .dormant {
      stateText = "Dormant"
    } else if record != nil && !exists {
      stateText = "Missing"
    } else {
      stateText = "Active"
    }

    return ProjectInfo(
      name: record?.name ?? url.lastPathComponent,
      path: record?.path ?? url.path,
      stateText: stateText,
      ecosystemText: record?.ecosystem.slug ?? "unknown",
      remoteText: remoteText,
      branchText: branchText,
      lastCommitText: lastCommitText,
      gitStatusText: gitStatusText,
      localSizeText: exists ? Bytes.format(localSize) : "—",
      coreSizeText: exists ? Bytes.format(max(0, localSize - regenerableSize)) : "—",
      regenerableSizeText: exists ? Bytes.format(regenerableSize) : "—",
      archiveSizeText: archiveSize.map { Bytes.format($0) } ?? "—"
    )
  }
}

struct ProjectInfoView: View {
  let info: ProjectInfo
  let onClose: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(info.name).font(.headline)
      Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
        row("Location", info.path)
        row("State", info.stateText)
        row("Ecosystem", info.ecosystemText)
        row("Remote", info.remoteText)
        row("Branch", info.branchText)
        row("Last commit", info.lastCommitText)
        row("Git status", info.gitStatusText)
        row("Local size", info.localSizeText)
        row("Core size", info.coreSizeText)
        row("Regenerable size", info.regenerableSizeText)
        row("Archive size", info.archiveSizeText)
      }
      HStack {
        Spacer()
        Button("Close", action: onClose)
          .keyboardShortcut(.defaultAction)
          .controlSize(.large)
          .buttonStyle(.borderedProminent)
      }
    }
    .padding(20)
    .frame(minWidth: 440)
  }

  private func row(_ label: String, _ value: String) -> some View {
    GridRow {
      Text(label)
        .foregroundStyle(.secondary)
        .gridColumnAlignment(.trailing)
      Text(value)
        .textSelection(.enabled)
    }
  }
}
