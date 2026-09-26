import Foundation
import Testing

@testable import DormantCore

@Suite struct ProcessRunnerTests {
  private let sh = URL(fileURLWithPath: "/bin/sh")

  @Test("captures stdout and exit code on success")
  func success() throws {
    let result = try ProcessRunner().run(executable: sh, arguments: ["-c", "echo hello"])
    #expect(result.exitCode == 0)
    #expect(result.stdout == "hello\n")
    #expect(result.stderr == "")
  }

  @Test("captures stderr and non-zero exit code")
  func failure() throws {
    let result = try ProcessRunner().run(
      executable: sh,
      arguments: ["-c", "echo boom >&2; exit 3"])
    #expect(result.exitCode == 3)
    #expect(result.stdout == "")
    #expect(result.stderr == "boom\n")
  }

  @Test("runs in the given directory with the given environment")
  func cwdAndEnvironment() throws {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("DormantProcessTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try Data("marker\n".utf8).write(to: dir.appendingPathComponent("marker.txt"))

    let result = try ProcessRunner().run(
      executable: sh,
      arguments: ["-c", "test -f marker.txt && echo found; echo $DORMANT_TEST"],
      cwd: dir,
      environment: ["DORMANT_TEST": "value"])
    #expect(result.stdout == "found\nvalue\n")
    #expect(result.exitCode == 0)
  }

  @Test("captures output larger than the pipe buffer")
  func largeOutput() throws {
    let result = try ProcessRunner().run(
      executable: sh,
      arguments: ["-c", "i=0; while [ $i -lt 10000 ]; do echo line-$i; i=$((i+1)); done"])
    #expect(result.exitCode == 0)
    #expect(result.stdout.count > 65536)
    #expect(result.stdout.hasPrefix("line-0\n"))
    #expect(result.stdout.hasSuffix("line-9999\n"))
  }

  @Test("streams chunks incrementally while capturing the full result")
  func incrementalOutput() throws {
    let stdoutChunks = StreamedChunks()
    let stderrChunks = StreamedChunks()
    let result = try ProcessRunner().run(
      executable: sh,
      arguments: ["-c", "echo one; echo two >&2"],
      onStdout: { stdoutChunks.append($0) },
      onStderr: { stderrChunks.append($0) })
    #expect(result.stdout == "one\n")
    #expect(result.stderr == "two\n")
    #expect(stdoutChunks.string() == "one\n")
    #expect(stderrChunks.string() == "two\n")
  }

  @Test("throws when the executable does not exist")
  func missingExecutable() {
    #expect(throws: (any Error).self) {
      try ProcessRunner().run(executable: URL(fileURLWithPath: "/nonexistent/tool"))
    }
  }

  @Test("cancel terminates a running command and refuses new ones")
  func cancellation() async throws {
    let runner = ProcessRunner()
    let task = Task.detached {
      try runner.run(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "sleep 5"])
    }
    try await Task.sleep(nanoseconds: 200_000_000)
    runner.cancel()
    do {
      _ = try await task.value
      Issue.record("expected the run to be cancelled")
    } catch {
      #expect(error as? ProcessRunnerError == ProcessRunnerError.cancelled)
    }
    #expect(throws: ProcessRunnerError.cancelled) {
      try runner.run(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "echo hi"])
    }
  }

  @Test("cancel before run prevents launch")
  func cancelBeforeRun() {
    let runner = ProcessRunner()
    runner.cancel()
    #expect(throws: ProcessRunnerError.cancelled) {
      try runner.run(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "echo hi"])
    }
  }
}

private final class StreamedChunks: @unchecked Sendable {
  private let lock = NSLock()
  private var data = Data()

  func append(_ chunk: Data) {
    lock.lock()
    data.append(chunk)
    lock.unlock()
  }

  func string() -> String {
    lock.lock()
    defer { lock.unlock() }
    return String(decoding: data, as: UTF8.self)
  }
}
