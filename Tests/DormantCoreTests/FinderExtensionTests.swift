import Foundation
import Testing

@testable import DormantCore

@Suite struct FinderExtensionTests {
  @Test("parses the election tag from pluginkit output")
  func parsesElectionTag() {
    let enabled =
      "+    com.dormant.Dormant.Finder(0.1.0)\n"
      + "\t            Path = /Applications/Dormant.app/Contents/PlugIns/DormantFinder.appex\n"
      + "\t            UUID = 1CAFD6BE-7A66-46D9-B126-7E0AA5806057\n"
      + " (1 plug-in)\n"
    #expect(FinderExtension.parseState(enabled) == .enabled)

    let disabled = "-    com.dormant.Dormant.Finder(0.1.0)\n (1 plug-in)\n"
    #expect(FinderExtension.parseState(disabled) == .disabled)

    let notElected = "     com.dormant.Dormant.Finder(0.1.0)\n (1 plug-in)\n"
    #expect(FinderExtension.parseState(notElected) == .disabled)

    #expect(FinderExtension.parseState("  (no matches)\n") == .unknown)
  }

  @Test("state queries pluginkit for the extension identifier")
  func stateQueriesPluginkit() throws {
    let stub = try PluginkitStub()
    defer { stub.destroy() }

    let state = FinderExtension(pluginkit: stub.executable, runner: ProcessRunner()).state()
    #expect(state == .enabled)
    #expect(stub.calls().contains("-m -i com.dormant.Dormant.Finder"))
  }

  @Test("enable registers the appex, elects use, and re-reads the state")
  func enableRunsCommands() throws {
    let stub = try PluginkitStub()
    defer { stub.destroy() }

    let appex = stub.root.appendingPathComponent("DormantFinder.appex")
    let finder = FinderExtension(pluginkit: stub.executable, runner: ProcessRunner())
    let state = finder.enable(appex: appex)

    #expect(state == .enabled)
    let calls = stub.calls()
    #expect(calls.contains("-a \(appex.path)"))
    #expect(calls.contains("-e use -i com.dormant.Dormant.Finder"))
  }

  @Test("enable without an appex skips registration")
  func enableWithoutAppex() throws {
    let stub = try PluginkitStub()
    defer { stub.destroy() }

    let state = FinderExtension(pluginkit: stub.executable, runner: ProcessRunner())
      .enable(appex: nil)

    #expect(state == .enabled)
    let calls = stub.calls()
    #expect(!calls.contains("-a "))
    #expect(calls.contains("-e use -i com.dormant.Dormant.Finder"))
  }

  @Test("reports unknown when pluginkit cannot be run")
  func unknownWithoutPluginkit() {
    let finder = FinderExtension(pluginkit: URL(fileURLWithPath: "/nonexistent/pluginkit"))
    #expect(finder.state() == .unknown)
  }
}

private struct PluginkitStub {
  let root: URL
  let executable: URL
  private let log: URL

  init() throws {
    let project = try TempProject()
    root = project.root
    executable = root.appendingPathComponent("pluginkit-stub")
    log = root.appendingPathComponent("calls.log")
    let script = """
      #!/bin/sh
      echo "$@" >> "\(log.path)"
      if [ "$1" = "-m" ]; then
        echo "+    com.dormant.Dormant.Finder(0.1.0)"
      fi
      exit 0
      """
    try Data(script.utf8).write(to: executable)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
  }

  func calls() -> String {
    (try? String(contentsOf: log, encoding: .utf8)) ?? ""
  }

  func destroy() {
    try? FileManager.default.removeItem(at: root)
  }
}
