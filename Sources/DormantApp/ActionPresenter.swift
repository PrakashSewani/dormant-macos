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
  private var pendingSelection: String?

  var openMain: ((String?) -> Void)?

  func takePendingSelection() -> String? {
    defer { pendingSelection = nil }
    return pendingSelection
  }

  func present(action: DormantAction, fileURL: URL) {
    switch action {
    case .open:
      Task { _ = await resolveRecord(for: fileURL) }
      open(fileURL)
    case .clean:
      startClean(fileURL)
    case .archive:
      startArchive(fileURL)
    case .restore:
      startRestore(fileURL)
    case .importFolder:
      startImport(fileURL)
    case .openDirectory:
      startOpenDirectory(fileURL)
    case .gitClone:
      startGitClone(fileURL)
    case .projectInfo:
      startProjectInfo(fileURL)
    case .openRepository:
      openRepository(fileURL)
    }
  }

  func setUpFinderExtensionIfNeeded() {
    let defaults = UserDefaults.standard
    guard !defaults.bool(forKey: Self.finderExtensionKey) else { return }
    let appex = Self.finderExtensionAppex
    Task {
      let outcome = await Task.detached {
        () -> (wasEnabled: Bool, state: FinderExtensionState) in
        let finder = FinderExtension()
        let wasEnabled = finder.state() == .enabled
        guard !wasEnabled else { return (true, .enabled) }
        return (false, finder.enable(appex: appex))
      }.value
      guard outcome.state == .enabled else {
        if !defaults.bool(forKey: Self.finderExtensionFallbackKey) {
          defaults.set(true, forKey: Self.finderExtensionFallbackKey)
          showFinderExtensionFallback()
        }
        return
      }
      defaults.set(true, forKey: Self.finderExtensionKey)
      if !outcome.wasEnabled {
        showFinderExtensionEnabled()
      }
    }
  }

  func enableFinderExtension() {
    let appex = Self.finderExtensionAppex
    Task {
      let state = await Task.detached { FinderExtension().enable(appex: appex) }.value
      guard state == .enabled else {
        showFinderExtensionFallback()
        return
      }
      UserDefaults.standard.set(true, forKey: Self.finderExtensionKey)
      showFinderExtensionEnabled()
    }
  }

  private func startClean(_ root: URL) {
    Task {
      _ = await resolveRecord(for: root)
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

  func startCleanAll(records: [ProjectRecord]) {
    Task {
      let report = await Task.detached { Savings.report(for: records) }.value
      guard !report.entries.isEmpty else {
        showAlert(
          title: "Nothing to clean",
          message: "No regenerable development state found in the listed projects."
        )
        return
      }
      showDialog(title: "Clean All") {
        CleanAllDialog(
          report: report,
          onConfirm: {
            self.closeDialog()
            self.runCleanAll(entries: report.entries)
          },
          onCancel: { self.closeDialog() }
        )
      }
    }
  }

  private func runCleanAll(entries: [SavingsReport.Entry]) {
    Task {
      let outcome = await Task.detached { () -> (removed: Int, reclaimed: Int, failures: Int) in
        var removed = 0
        var reclaimed = 0
        var failures = 0
        for entry in entries {
          let engine = CleanEngine()
          let plan = engine.plan(root: URL(fileURLWithPath: entry.path))
          let result = engine.execute(plan: plan)
          removed += result.removed.count
          failures += result.failures.count
          reclaimed += plan.items
            .filter { result.removed.contains($0.relativePath) }
            .reduce(0) { $0 + $1.sizeBytes }
        }
        return (removed, reclaimed, failures)
      }.value
      NotificationCenter.default.post(name: .dormantDataChanged, object: nil)
      var message =
        "Removed \(outcome.removed) regenerable path(s), reclaiming "
        + "\(Bytes.format(outcome.reclaimed))."
      if outcome.failures > 0 {
        message += "\n\(outcome.failures) path(s) were left in place."
      }
      showAlert(title: "Clean All finished", message: message)
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
      guard let record = await resolveRecord(for: fileURL) else {
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

  private func startImport(_ fileURL: URL) {
    Task {
      do {
        let report = try await Task.detached { () -> ScanReport in
          let registry = try Registry(path: DormantPaths().registry)
          return try Scanner(registry: registry).importDirectory(at: fileURL)
        }.value
        NotificationCenter.default.post(name: .dormantDataChanged, object: nil)
        let total = report.added.count + report.updated.count + report.reappeared.count
        guard total > 0 else {
          showAlert(
            title: "Nothing to import",
            message: "No project found in \(fileURL.lastPathComponent)."
          )
          return
        }
        showAlert(
          title: "Import finished",
          message:
            "\(report.added.count) added, \(report.updated.count) updated, "
            + "\(report.reappeared.count) re-activated in \(fileURL.lastPathComponent)."
        )
      } catch {
        showAlert(title: "Import failed", message: "\(error)")
      }
    }
  }

  private func startOpenDirectory(_ fileURL: URL) {
    Task {
      do {
        _ = try await Task.detached { () -> ScanReport in
          let registry = try Registry(path: DormantPaths().registry)
          return try Scanner(registry: registry).importDirectory(at: fileURL)
        }.value
        NotificationCenter.default.post(name: .dormantDataChanged, object: nil)
        let path = fileURL.standardizedFileURL.path
        if let openMain {
          openMain(path)
        } else {
          pendingSelection = path
          NSApp.activate(ignoringOtherApps: true)
        }
      } catch {
        showAlert(title: "Open Directory failed", message: "\(error)")
      }
    }
  }

  func reviewIdleCandidates(_ candidates: [ProjectRecord]) {
    guard !candidates.isEmpty else { return }
    showDialog(title: "Idle Projects") {
      IdleReviewDialog(
        candidates: candidates,
        onArchive: { record in
          self.closeDialog()
          self.present(action: .archive, fileURL: URL(fileURLWithPath: record.path))
        },
        onClose: { self.closeDialog() }
      )
    }
  }

  private func startGitClone(_ folder: URL) {
    showDialog(title: "Git Clone") {
      GitCloneDialog(
        folder: folder,
        onConfirm: { remote in
          self.closeDialog()
          self.runGitClone(remote: remote, into: folder)
        },
        onCancel: { self.closeDialog() }
      )
    }
  }

  private func runGitClone(remote: String, into folder: URL) {
    Task {
      do {
        let destination = try await Task.detached { () -> URL in
          let destination = try CloneEngine().clone(remote: remote, into: folder)
          if let registry = try? Registry(path: DormantPaths().registry) {
            _ = try? Scanner(registry: registry).register(projectAt: destination)
          }
          return destination
        }.value
        NotificationCenter.default.post(name: .dormantDataChanged, object: nil)
        open(destination)
      } catch {
        showAlert(title: "Clone failed", message: "\(error)")
      }
    }
  }

  private func startProjectInfo(_ fileURL: URL) {
    Task {
      _ = await resolveRecord(for: fileURL)
      let info = await Task.detached { ProjectInfo.load(path: fileURL.path) }.value
      showDialog(title: "Project Info") {
        ProjectInfoView(info: info, onClose: { self.closeDialog() })
      }
    }
  }

  private func open(_ fileURL: URL) {
    guard
      let code = ToolLocator.url(
        for: "code",
        extraDirectories: ToolLocator.visualStudioCodeDirectories
      )
    else {
      showAlert(
        title: "Visual Studio Code not found",
        message:
          "Dormant opens projects with `code .` (VS Code), but the `code` command "
          + "was not found in any known install location."
      )
      return
    }
    Task {
      do {
        let result = try await Task.detached { () -> ProcessResult in
          try ProcessRunner().run(executable: code, arguments: ["."], cwd: fileURL)
        }.value
        if result.exitCode != 0 {
          showAlert(
            title: "Open failed",
            message: "code exited with status \(result.exitCode).\n\(result.stderr)"
          )
        }
      } catch {
        showAlert(title: "Open failed", message: "\(error)")
      }
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

  private func resolveRecord(for fileURL: URL) async -> ProjectRecord? {
    let record = await Task.detached { () -> ProjectRecord? in
      guard let registry = try? Registry(path: DormantPaths().registry) else { return nil }
      if let registered = try? Scanner(registry: registry).register(projectAt: fileURL) {
        return registered
      }
      return try? registry.project(path: fileURL.path)
    }.value
    NotificationCenter.default.post(name: .dormantDataChanged, object: nil)
    return record
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

  private static let finderExtensionKey = "finderExtension.autoEnabled"
  private static let finderExtensionFallbackKey = "finderExtension.fallbackShown"

  private static var finderExtensionAppex: URL? {
    Bundle.main.builtInPlugInsURL?.appendingPathComponent("DormantFinder.appex")
  }

  private func showFinderExtensionEnabled() {
    showAlert(
      title: "Finder extension enabled",
      message: "Right-click any folder in Finder for Dormant actions — Clean, Archive, "
        + "Restore, and more. If the \"Dormant ▸\" submenu does not appear right away, "
        + "restart Finder.")
  }

  private func showFinderExtensionFallback() {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = "Enable the Finder extension in System Settings"
    alert.informativeText =
      "Dormant could not turn on its Finder extension. Open System Settings → General → "
      + "Login Items & Extensions, enable Dormant under Finder extensions, then restart "
      + "Finder. Dormant keeps trying on its own."
    alert.addButton(withTitle: "Open System Settings")
    alert.addButton(withTitle: "Later")
    if alert.runModal() == .alertFirstButtonReturn,
      let settings = URL(
        string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
          + "?extensionPointIdentifier=com.apple.FinderSync")
    {
      NSWorkspace.shared.open(settings)
    }
  }
}
