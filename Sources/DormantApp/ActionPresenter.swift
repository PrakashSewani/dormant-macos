import AppKit
import DormantCore
import SwiftUI

extension Notification.Name {
  static let dormantDataChanged = Notification.Name("dormant.dataChanged")
}

@MainActor
final class ActionPresenter: NSObject, NSWindowDelegate {
  static let shared = ActionPresenter()

  private var dialogWindow: NSWindow?

  func present(action: DormantAction, fileURL: URL) {
    switch action {
    case .open:
      open(fileURL)
    case .clean:
      startClean(fileURL)
    case .archive:
      startArchive(fileURL)
    case .restore:
      startRestore(fileURL)
    case .projectInfo:
      startProjectInfo(fileURL)
    case .openRepository:
      openRepository(fileURL)
    }
  }

  private func startClean(_ root: URL) {
    Task {
      let plan = await Task.detached { CleanEngine().plan(root: root) }.value
      guard !plan.items.isEmpty else {
        showAlert(
          title: "Nothing to clean",
          message: "No regenerable development state found in \(root.lastPathComponent)."
        )
        return
      }
      showDialog(title: "Clean \(root.lastPathComponent)") {
        CleanPreviewDialog(
          plan: plan,
          onConfirm: {
            self.closeDialog()
            self.runClean(plan: plan)
          },
          onCancel: { self.closeDialog() }
        )
      }
    }
  }

  private func runClean(plan: CleanPlan) {
    Task {
      let result = await Task.detached { CleanEngine().execute(plan: plan) }.value
      NotificationCenter.default.post(name: .dormantDataChanged, object: nil)
      let reclaimed = plan.items
        .filter { result.removed.contains($0.relativePath) }
        .reduce(0) { $0 + $1.sizeBytes }
      var message =
        "Removed \(result.removed.count) regenerable path(s), reclaiming \(Bytes.format(reclaimed))."
      if !result.failures.isEmpty {
        let left = result.failures.map { $0.relativePath }.joined(separator: ", ")
        message += "\n\(result.failures.count) path(s) were left in place: \(left)"
      }
      showAlert(title: "Clean finished", message: message)
    }
  }

  private func startArchive(_ root: URL) {
    Task {
      let record = await Task.detached { () -> ProjectRecord? in
        let registry = try? Registry(path: DormantPaths().registry)
        guard let registry else { return nil }
        return try? Scanner(registry: registry).register(projectAt: root)
      }.value
      guard let record else {
        showAlert(
          title: "Not a project",
          message: "Dormant could not recognize \(root.lastPathComponent) as a project."
        )
        return
      }
      let prep = await Task.detached { () -> (ArchiveWarning?, Int) in
        let engine = ArchiveEngine()
        return (engine.gitWarning(root: root), CleanEngine().plan(root: root).totalReclaim)
      }.value
      showDialog(title: "Archive \(record.name)") {
        ArchiveConfirmDialog(
          name: record.name,
          warning: prep.0,
          reclaimBytes: prep.1,
          archiveLocation: DormantPaths().store.path,
          onConfirm: {
            self.closeDialog()
            self.runArchive(record: record)
          },
          onCancel: { self.closeDialog() }
        )
      }
    }
  }

  private func runArchive(record: ProjectRecord) {
    Task {
      do {
        let outcome = try await Task.detached { () -> ArchiveOutcome in
          let registry = try Registry(path: DormantPaths().registry)
          return try ArchiveEngine().archive(project: record, registry: registry)
        }.value
        NotificationCenter.default.post(name: .dormantDataChanged, object: nil)
        var message =
          "Archived \(record.name) to \(outcome.storePath.path) "
          + "(\(Bytes.format(outcome.archiveSizeBytes)))."
        if !outcome.workingCopyRemoved {
          message +=
            "\nThe archive is verified and stored, but the working copy at \(record.path) "
            + "could not be removed."
        }
        showAlert(title: "Archive finished", message: message)
      } catch {
        NotificationCenter.default.post(name: .dormantDataChanged, object: nil)
        showAlert(title: "Archive failed", message: "\(error)")
      }
    }
  }

  private func startRestore(_ fileURL: URL) {
    Task {
      guard let record = findRecord(path: fileURL.path) else {
        showAlert(
          title: "Unknown project",
          message: "There is no Dormant registry entry for \(fileURL.path)."
        )
        return
      }
      let hasArchive = (try? archiveRow(for: record)) != nil
      guard hasArchive else {
        showAlert(
          title: "No archive",
          message: "\(record.name) has no archive to restore from."
        )
        return
      }
      showDialog(title: "Restore \(record.name)") {
        RestoreDialog(
          record: record,
          onConfirm: { destination in
            self.closeDialog()
            self.runRestore(record: record, destination: destination)
          },
          onCancel: { self.closeDialog() }
        )
      }
    }
  }

  private func runRestore(record: ProjectRecord, destination: URL?) {
    Task {
      do {
        let restored = try await Task.detached { () -> URL in
          let registry = try Registry(path: DormantPaths().registry)
          let outcome = try RestoreEngine().restore(
            project: record,
            registry: registry,
            to: destination
          )
          return outcome.destination
        }.value
        NotificationCenter.default.post(name: .dormantDataChanged, object: nil)
        let commands = InstallCommands.detect(projectAt: restored)
        guard !commands.isEmpty else {
          showAlert(
            title: "Restore finished",
            message: "Project restored to \(restored.path). No dependency commands detected."
          )
          return
        }
        showDialog(title: "Install dependencies") {
          InstallCommandsDialog(
            commands: commands,
            root: restored,
            onFinish: { self.closeDialog() }
          )
        }
      } catch {
        NotificationCenter.default.post(name: .dormantDataChanged, object: nil)
        showAlert(title: "Restore failed", message: "\(error)")
      }
    }
  }

  private func startProjectInfo(_ fileURL: URL) {
    Task {
      let info = await Task.detached { ProjectInfo.load(path: fileURL.path) }.value
      showDialog(title: "Project Info") {
        ProjectInfoView(info: info, onClose: { self.closeDialog() })
      }
    }
  }

  private func open(_ fileURL: URL) {
    let template = UserDefaults.standard.string(forKey: "editorCommand") ?? ""
    let trimmed = template.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else {
      NSWorkspace.shared.open(fileURL)
      return
    }
    let parts = trimmed.split(separator: " ").map(String.init)
    let executable = parts.first ?? ""
    var arguments = parts.dropFirst().map {
      $0.replacingOccurrences(of: "{path}", with: fileURL.path)
    }
    if !trimmed.contains("{path}") {
      arguments.append(fileURL.path)
    }
    Task.detached {
      _ = try? ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [executable] + arguments
      )
    }
  }

  private func openRepository(_ fileURL: URL) {
    Task {
      let record = await Task.detached { () -> ProjectRecord? in
        let registry = try? Registry(path: DormantPaths().registry)
        guard let registry else { return nil }
        if let existing = try? registry.project(path: fileURL.path) {
          return existing
        }
        return try? Scanner(registry: registry).register(projectAt: fileURL)
      }.value
      guard let remote = record?.gitRemote, let webURL = webRepositoryURL(from: remote) else {
        showAlert(
          title: "No repository",
          message: "This project has no git remote to open in the browser."
        )
        return
      }
      NSWorkspace.shared.open(webURL)
    }
  }

  private func webRepositoryURL(from remote: String) -> URL? {
    var text = remote
    if text.hasPrefix("git@") {
      let trimmed = text.dropFirst("git@".count)
      guard let colon = trimmed.firstIndex(of: ":") else { return nil }
      let host = trimmed[..<colon]
      var path = String(trimmed[trimmed.index(after: colon)...])
      if path.hasSuffix(".git") { path = String(path.dropLast(4)) }
      return URL(string: "https://\(host)/\(path)")
    }
    if text.hasPrefix("ssh://") {
      text = String(text.dropFirst("ssh://".count))
      if let at = text.firstIndex(of: "@") {
        text = String(text[text.index(after: at)...])
      }
    }
    guard text.hasPrefix("http://") || text.hasPrefix("https://") else { return nil }
    if text.hasSuffix(".git") { text = String(text.dropLast(4)) }
    return URL(string: text)
  }

  private func findRecord(path: String) -> ProjectRecord? {
    guard let registry = try? Registry(path: DormantPaths().registry) else { return nil }
    return try? registry.project(path: path)
  }

  private func archiveRow(for record: ProjectRecord) throws -> ArchiveRecord? {
    let registry = try Registry(path: DormantPaths().registry)
    return try registry.archive(projectID: record.id)
  }

  private func showDialog<C: View>(title: String, @ViewBuilder content: () -> C) {
    closeDialog()
    let hosting = NSHostingController(rootView: content())
    let window = NSWindow(contentViewController: hosting)
    window.title = title
    window.styleMask = [.titled, .closable]
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.center()
    window.makeKeyAndOrderFront(nil)
    dialogWindow = window
  }

  func windowWillClose(_ notification: Notification) {
    dialogWindow = nil
  }

  private func closeDialog() {
    dialogWindow?.close()
    dialogWindow = nil
  }

  private func showAlert(title: String, message: String) {
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle: "OK")
    alert.runModal()
  }
}
