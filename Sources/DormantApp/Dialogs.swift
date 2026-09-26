import AppKit
import DormantCore
import SwiftUI

struct DialogScaffold<Content: View>: View {
  let title: String
  let okTitle: String
  let onConfirm: () -> Void
  let onCancel: () -> Void
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(title).font(.headline)
      content
      HStack {
        Spacer()
        Button("Cancel", action: onCancel)
          .keyboardShortcut(.cancelAction)
        Button(okTitle, action: onConfirm)
          .keyboardShortcut(.defaultAction)
          .controlSize(.large)
          .buttonStyle(.borderedProminent)
      }
    }
    .padding(20)
    .frame(minWidth: 440)
  }
}

struct CleanPreviewDialog: View {
  let plan: CleanPlan
  let onConfirm: () -> Void
  let onCancel: () -> Void

  var body: some View {
    DialogScaffold(
      title: "Reclaim \(Bytes.format(plan.totalReclaim))?",
      okTitle: "Clean",
      onConfirm: onConfirm,
      onCancel: onCancel
    ) {
      VStack(alignment: .leading, spacing: 8) {
        Text("These regenerable paths will be removed. Everything else is kept:")
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
      HStack {
        Spacer()
        if run.running {
          ProgressView().controlSize(.small)
        } else if run.failure == nil && run.log.isEmpty {
          Button("Cancel", action: onFinish)
            .keyboardShortcut(.cancelAction)
          Button("Run") {
            run.start(commands: commands, root: root)
          }
          .keyboardShortcut(.defaultAction)
          .controlSize(.large)
          .buttonStyle(.borderedProminent)
        } else {
          Button("Close", action: onFinish)
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
        }
      }
    }
    .padding(20)
    .frame(minWidth: 520)
  }
}
