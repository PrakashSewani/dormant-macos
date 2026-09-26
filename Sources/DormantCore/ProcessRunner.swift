import Foundation

public struct ProcessResult: Sendable {
  public let exitCode: Int32
  public let stdout: String
  public let stderr: String
}

public enum ProcessRunnerError: Error, Equatable, Sendable {
  case cancelled
}

public final class ProcessRunner: @unchecked Sendable {
  private let lock = NSLock()
  private var process: Process?
  private var cancelled = false

  public init() {}

  public func run(
    executable: URL,
    arguments: [String] = [],
    cwd: URL? = nil,
    environment: [String: String]? = nil,
    onStdout: (@Sendable (Data) -> Void)? = nil,
    onStderr: (@Sendable (Data) -> Void)? = nil
  ) throws -> ProcessResult {
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()

    lock.lock()
    if cancelled {
      lock.unlock()
      throw ProcessRunnerError.cancelled
    }
    let process = Process()
    process.executableURL = executable
    process.arguments = arguments
    process.currentDirectoryURL = cwd
    process.environment = environment
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    self.process = process
    lock.unlock()

    do {
      try process.run()
    } catch {
      clear(process)
      throw error
    }
    if isCancelled {
      process.terminate()
    }

    let stdout = OutputAccumulator()
    let stderr = OutputAccumulator()
    let group = DispatchGroup()
    group.enter()
    DispatchQueue.global().async {
      Self.drain(stdoutPipe.fileHandleForReading, into: stdout, onChunk: onStdout)
      group.leave()
    }
    group.enter()
    DispatchQueue.global().async {
      Self.drain(stderrPipe.fileHandleForReading, into: stderr, onChunk: onStderr)
      group.leave()
    }

    process.waitUntilExit()
    group.wait()
    clear(process)

    if isCancelled {
      throw ProcessRunnerError.cancelled
    }
    return ProcessResult(
      exitCode: process.terminationStatus,
      stdout: stdout.string(),
      stderr: stderr.string())
  }

  public func cancel() {
    lock.lock()
    cancelled = true
    let process = self.process
    lock.unlock()
    if process?.isRunning == true {
      process?.terminate()
    }
  }

  private var isCancelled: Bool {
    lock.lock()
    defer { lock.unlock() }
    return cancelled
  }

  private func clear(_ process: Process) {
    lock.lock()
    if self.process === process {
      self.process = nil
    }
    lock.unlock()
  }

  private static func drain(
    _ handle: FileHandle,
    into accumulator: OutputAccumulator,
    onChunk: (@Sendable (Data) -> Void)?
  ) {
    while true {
      let chunk = handle.availableData
      if chunk.isEmpty {
        return
      }
      accumulator.append(chunk)
      onChunk?(chunk)
    }
  }
}

private final class OutputAccumulator: @unchecked Sendable {
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
