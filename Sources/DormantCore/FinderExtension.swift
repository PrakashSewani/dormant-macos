import Foundation

public enum FinderExtensionState: Sendable, Equatable {
  case enabled
  case disabled
  case unknown
}

public struct FinderExtension: Sendable {
  public static let identifier = "com.dormant.Dormant.Finder"

  private let pluginkit: URL
  private let runner: ProcessRunner

  public init(
    pluginkit: URL = URL(fileURLWithPath: "/usr/bin/pluginkit"),
    runner: ProcessRunner = ProcessRunner()
  ) {
    self.pluginkit = pluginkit
    self.runner = runner
  }

  public func state() -> FinderExtensionState {
    guard
      let result = try? runner.run(
        executable: pluginkit, arguments: ["-m", "-i", Self.identifier]),
      result.exitCode == 0
    else {
      return .unknown
    }
    return Self.parseState(result.stdout)
  }

  @discardableResult
  public func enable(appex: URL?) -> FinderExtensionState {
    if let appex {
      _ = try? runner.run(executable: pluginkit, arguments: ["-a", appex.path])
    }
    _ = try? runner.run(executable: pluginkit, arguments: ["-e", "use", "-i", Self.identifier])
    return state()
  }

  static func parseState(_ output: String) -> FinderExtensionState {
    for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
      guard line.contains(Self.identifier) else { continue }
      return line.hasPrefix("+") ? .enabled : .disabled
    }
    return .unknown
  }
}
