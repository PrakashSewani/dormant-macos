import AppKit
import DormantCore
import SwiftUI

struct DialogScaffold<Content: View>: View {
  let title: String
  let icon: String
  let okTitle: String
  var okEnabled: Bool = true
  let onConfirm: () -> Void
  let onCancel: () -> Void
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: UIConstants.dialogSpacing) {
      Label(title, systemImage: icon)
        .font(.headline)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
      content
      HStack(spacing: UIConstants.buttonSpacing) {
        Spacer()
        Button("Cancel", action: onCancel)
          .keyboardShortcut(.cancelAction)
          .dialogButton()
        Button(okTitle, action: onConfirm)
          .keyboardShortcut(.defaultAction)
          .buttonStyle(.borderedProminent)
          .dialogButton()
          .disabled(!okEnabled)
      }
    }
    .padding(UIConstants.dialogPadding)
    .frame(minWidth: UIConstants.dialogMinWidth)
  }
}

struct CleanPreviewDialog: View {
  let plan: CleanPlan
  let onConfirm: () -> Void
  let onCancel: () -> Void

  var body: some View {
    DialogScaffold(
      title: "Reclaim \(Bytes.format(plan.totalReclaim))?",
      icon: "sparkles",
      okTitle: "Clean",
      onConfirm: onConfirm,
      onCancel: onCancel
    ) {
      VStack(alignment: .leading, spacing: 8) {
        Text(
          "These regenerable paths will be removed permanently — "
            + "nothing is archived. Everything else is kept:"
        )
        .fixedSize(horizontal: false, vertical: true)
        Text(
          "To make the project work again afterwards, rebuild this state with its "
            + "own dependency commands (for example cargo build or npm install)."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        ScrollView {
          VStack(alignment: .leading, spacing: 4) {
            ForEach(plan.items, id: \.relativePath) { item in
              HStack {
                Text(item.relativePath)
                Spacer()
                Text(Bytes.format(item.sizeBytes)).foregroundStyle(.secondary)
              }
              .font(.system(.body, design: .monospaced))
            }
          }
        }
        .frame(maxHeight: 220)
        Text("Total: \(Bytes.format(plan.totalReclaim))")
          .font(.headline)
      }
    }
  }
}

struct ArchiveConfirmDialog: View {
  let name: String
  let warning: ArchiveWarning?
  let reclaimBytes: Int
  let archiveLocation: String
  let onConfirm: () -> Void
  let onCancel: () -> Void

  var body: some View {
    DialogScaffold(
      title: "Archive \(name)?",
      icon: "archivebox.fill",
      okTitle: "Archive",
      onConfirm: onConfirm,
      onCancel: onCancel
    ) {
      VStack(alignment: .leading, spacing: 8) {
        if let warning {
          if warning.gitStateUnknown {
            Label(
              "Git state could not be checked. Uncommitted changes may exist.",
              systemImage: "exclamationmark.triangle"
            )
            .foregroundStyle(.orange)
          } else {
            Label(
              "Uncommitted changes: \(warning.modifiedCount) modified, "
                + "\(warning.untrackedCount) untracked. Nothing is discarded — "
                + "everything remaining is preserved inside the archive.",
              systemImage: "exclamationmark.triangle"
            )
            .foregroundStyle(.orange)
          }
        }
        Text(
          "Regenerable development state (\(Bytes.format(reclaimBytes))) is removed first, "
            + "then everything that remains is compressed into \(archiveLocation). "
            + "The working copy is removed only after the archive is verified."
        )
        .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

struct RestoreDialog: View {
  let record: ProjectRecord
  let onConfirm: (URL?) -> Void
  let onCancel: () -> Void

  @State private var useCustomDestination = false
  @State private var customPath = ""

  var body: some View {
    DialogScaffold(
      title: "Restore \(record.name)?",
      icon: "arrow.counterclockwise",
      okTitle: "Restore",
      onConfirm: confirmSelection,
      onCancel: onCancel
    ) {
      VStack(alignment: .leading, spacing: 8) {
        Toggle("Restore to a different folder", isOn: $useCustomDestination)
        if useCustomDestination {
          TextField("Destination path", text: $customPath)
            .textFieldStyle(.roundedBorder)
        } else {
          Text("Destination: \(record.path)")
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Text(
          "The archive is verified after extraction, then removed. "
            + "Dependency commands are shown before anything runs."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func confirmSelection() {
    if useCustomDestination && !customPath.isEmpty {
      onConfirm(URL(fileURLWithPath: customPath))
    } else {
      onConfirm(nil)
    }
  }
}

struct GitCloneDialog: View {
  let folder: URL
  let onConfirm: (String) -> Void
  let onCancel: () -> Void

  @State private var remoteText = ""

  private var remote: String? {
    CloneEngine.normalizedRemote(remoteText)
  }

  private var previewName: String? {
    remote.flatMap { CloneEngine.folderName(fromRemote: $0) }
  }

  var body: some View {
    DialogScaffold(
      title: "Git Clone into \(folder.lastPathComponent)",
      icon: "arrow.down.circle",
      okTitle: "Clone",
      okEnabled: remote != nil && previewName != nil,
      onConfirm: confirmSelection,
      onCancel: onCancel
    ) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Repository URL")
        TextField("https://github.com/user/repo.git", text: $remoteText)
          .textFieldStyle(.roundedBorder)
        if let previewName {
          Text("Clones into \(folder.path)/\(previewName), then opens in VS Code.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        } else {
          Text("Enter an https, ssh, or git@ repository URL.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private func confirmSelection() {
    if let remote {
      onConfirm(remote)
    }
  }
}

struct CleanAllDialog: View {
  let report: SavingsReport
  let onConfirm: () -> Void
  let onCancel: () -> Void

  var body: some View {
    DialogScaffold(
      title: "Reclaim \(Bytes.format(report.totalBytes)) across \(report.entries.count) projects?",
      icon: "sparkles",
      okTitle: "Clean All",
      onConfirm: onConfirm,
      onCancel: onCancel
    ) {
      VStack(alignment: .leading, spacing: 8) {
        Text(
          "Regenerable paths will be removed permanently — "
            + "nothing is archived. Everything else is kept:"
        )
        .fixedSize(horizontal: false, vertical: true)
        ScrollView {
          VStack(alignment: .leading, spacing: 4) {
            ForEach(report.entries) { entry in
              HStack {
                Text(entry.name)
                Spacer()
                Text(Bytes.format(entry.reclaimBytes)).foregroundStyle(.secondary)
              }
              .font(.system(.body, design: .monospaced))
            }
          }
        }
        .frame(maxHeight: 220)
        Text("Total: \(Bytes.format(report.totalBytes))")
          .font(.headline)
      }
    }
  }
}

struct IdleReviewDialog: View {
  let candidates: [ProjectRecord]
  let onArchive: (ProjectRecord) -> Void
  let onClose: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: UIConstants.dialogSpacing) {
      Label("Idle projects", systemImage: "moon.zzz")
        .font(.headline)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
      Text(
        "No commit in over \(Staleness.staleAfterDays) days. Nothing is archived "
          + "automatically — Archive runs the standard, reviewed flow per project."
      )
      .font(.caption)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
      ScrollView {
        VStack(alignment: .leading, spacing: 6) {
          ForEach(candidates) { record in
            HStack(spacing: UIConstants.buttonSpacing) {
              VStack(alignment: .leading, spacing: 2) {
                Text(record.name)
                Text(record.path)
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Button("Archive…", systemImage: "archivebox.fill") {
                onArchive(record)
              }
              .dialogButton()
            }
          }
        }
      }
      .frame(maxHeight: 260)
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
}

@MainActor
final class InstallRunModel: ObservableObject {
  @Published var log = ""
  @Published var running = false
  @Published var failure: InstallFailure?

  func start(commands: [InstallCommand], root: URL) {
    running = true
    Task.detached {
      let result = InstallRunner().run(commands, in: root) { chunk in
        Task { @MainActor in
          self.log += chunk
        }
      }
      await MainActor.run {
        self.failure = result.failure
        self.running = false
      }
    }
  }
}

struct InstallCommandsDialog: View {
  let commands: [InstallCommand]
  let root: URL
  let onFinish: () -> Void

  @StateObject private var run = InstallRunModel()

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Install dependencies").font(.headline)
      if !run.running && run.failure == nil {
        Text("This will run, in order, in \(root.path):")
        VStack(alignment: .leading, spacing: 6) {
          ForEach(Array(commands.enumerated()), id: \.offset) { _, command in
            VStack(alignment: .leading, spacing: 2) {
              Text(command.display)
                .font(.system(.body, design: .monospaced))
              Text(command.reason)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
      if run.running || !run.log.isEmpty {
        ScrollView {
          Text(run.log)
            .font(.system(.caption, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
        .frame(minHeight: 180, maxHeight: 320)
      }
      if let failure = run.failure {
        Label(
          "Failed: \(failure.command.display) (exit \(failure.status)). "
            + "\(failure.notRun.count) command(s) were not run.",
          systemImage: "xmark.circle"
        )
        .foregroundStyle(.red)
        .fixedSize(horizontal: false, vertical: true)
      }
      HStack(spacing: UIConstants.buttonSpacing) {
        Spacer()
        if run.running {
          ProgressView().controlSize(.small)
        } else if run.failure == nil && run.log.isEmpty {
          Button("Cancel", action: onFinish)
            .keyboardShortcut(.cancelAction)
            .dialogButton()
          Button("Run") {
            run.start(commands: commands, root: root)
          }
          .keyboardShortcut(.defaultAction)
          .buttonStyle(.borderedProminent)
          .dialogButton()
        } else {
          Button("Close", action: onFinish)
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .dialogButton()
        }
      }
    }
    .padding(UIConstants.dialogPadding)
    .frame(minWidth: 520)
  }
}
