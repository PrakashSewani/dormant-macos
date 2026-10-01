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
    VStack(alignment: .leading, spacing: UIConstants.dialogSpacing) {
      Text(info.name).font(.headline)
      Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
        row("mappin.and.ellipse", "Location", info.path)
        row("power", "State", info.stateText)
        row("cube", "Ecosystem", info.ecosystemText)
        row("link", "Remote", info.remoteText)
        row("arrow.triangle.branch", "Branch", info.branchText)
        row("clock", "Last commit", info.lastCommitText)
        row("checkmark.circle", "Git status", info.gitStatusText)
        row("internaldrive", "Local size", info.localSizeText)
        row("folder", "Core size", info.coreSizeText)
        row("sparkles", "Regenerable size", info.regenerableSizeText)
        row("archivebox", "Archive size", info.archiveSizeText)
      }
      HStack(spacing: UIConstants.buttonSpacing) {
        Spacer()
        Button("Close", action: onClose)
          .keyboardShortcut(.defaultAction)
          .buttonStyle(.borderedProminent)
          .dialogButton()
      }
    }
    .padding(UIConstants.dialogPadding)
    .frame(minWidth: UIConstants.dialogMinWidth)
  }

  private func row(_ symbol: String, _ label: String, _ value: String) -> some View {
    GridRow {
      Label(label, systemImage: symbol)
        .foregroundStyle(.secondary)
        .gridColumnAlignment(.trailing)
      Text(value)
        .textSelection(.enabled)
    }
  }
}
