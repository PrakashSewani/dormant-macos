import Foundation

public struct InstallCommand: Sendable, Equatable {
  public let executable: String
  public let arguments: [String]
  public let reason: String

  public var display: String {
    ([executable] + arguments).joined(separator: " ")
  }
}

public enum InstallCommands {
  public static func detect(projectAt root: URL) -> [InstallCommand] {
    let names = fileNames(in: root)
    var commands: [InstallCommand] = []
    commands += nodeCommands(names)
    commands += pythonCommands(names, root: root)
    if names.contains("cargo.toml") {
      commands.append(
        InstallCommand(executable: "cargo", arguments: ["build"], reason: "Cargo.toml present")
      )
    }
    if names.contains(where: { $0.hasSuffix(".csproj") || $0.hasSuffix(".sln") }) {
      commands.append(
        InstallCommand(executable: "dotnet", arguments: ["restore"], reason: "project file present")
      )
    }
    if names.contains("go.mod") {
      commands.append(
        InstallCommand(
          executable: "go",
          arguments: ["mod", "download"],
          reason: "go.mod present"
        )
      )
    }
    return commands
  }

  private static func nodeCommands(_ names: Set<String>) -> [InstallCommand] {
    if names.contains("pnpm-lock.yaml") {
      return [InstallCommand(executable: "pnpm", arguments: ["install"], reason: "pnpm-lock.yaml")]
    }
    if names.contains("yarn.lock") {
      return [InstallCommand(executable: "yarn", arguments: ["install"], reason: "yarn.lock")]
    }
    if names.contains("bun.lockb") || names.contains("bun.lock") {
      return [InstallCommand(executable: "bun", arguments: ["install"], reason: "bun lockfile")]
    }
    if names.contains("package-lock.json") {
      return [
        InstallCommand(
          executable: "npm",
          arguments: ["install"],
          reason: "package-lock.json present"
        )
      ]
    }
    if names.contains("package.json") {
      return [
        InstallCommand(executable: "npm", arguments: ["install"], reason: "package.json present")
      ]
    }
    return []
  }

  private static func pythonCommands(_ names: Set<String>, root: URL) -> [InstallCommand] {
    if names.contains("uv.lock") {
      return [InstallCommand(executable: "uv", arguments: ["sync"], reason: "uv.lock present")]
    }
    if names.contains("poetry.lock") {
      return [
        InstallCommand(executable: "poetry", arguments: ["install"], reason: "poetry.lock present")
      ]
    }
    if names.contains("requirements.txt") {
      return venvCommands(root: root) + [
        InstallCommand(
          executable: ".venv/bin/python",
          arguments: ["-m", "pip", "install", "-r", "requirements.txt"],
          reason: "requirements.txt present"
        )
      ]
    }
    if names.contains("pyproject.toml") {
      return venvCommands(root: root) + [
        InstallCommand(
          executable: ".venv/bin/python",
          arguments: ["-m", "pip", "install", "-e", "."],
          reason: "pyproject.toml present"
        )
      ]
    }
    return []
  }

  private static func venvCommands(root: URL) -> [InstallCommand] {
    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(
      atPath: root.appendingPathComponent(".venv").path,
      isDirectory: &isDirectory
    )
    if exists && isDirectory.boolValue {
      return []
    }
    return [
      InstallCommand(
        executable: "python3",
        arguments: ["-m", "venv", ".venv"],
        reason: ".venv is missing"
      )
    ]
  }

  private static func fileNames(in root: URL) -> Set<String> {
    let fm = FileManager.default
    let children = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
    var names = Set<String>()
    for child in children {
      let attrs = try? FileManager.default.attributesOfItem(atPath: child.path)
      if (attrs?[.type] as? FileAttributeType) == .typeRegular {
        names.insert(child.lastPathComponent.lowercased())
      }
    }
    return names
  }
}

public struct InstallFailure: Sendable {
  public let command: InstallCommand
  public let status: Int32
  public let stderr: String
  public let notRun: [InstallCommand]
}

public struct InstallResult: Sendable {
  public let completed: [InstallCommand]
  public let failure: InstallFailure?
}

public struct InstallRunner {
  private let processRunner: ProcessRunner

  public init(processRunner: ProcessRunner = ProcessRunner()) {
    self.processRunner = processRunner
  }

  public func run(
    _ commands: [InstallCommand],
    in root: URL,
    onOutput: (@Sendable (String) -> Void)? = nil
  ) -> InstallResult {
    var completed: [InstallCommand] = []
    for (index, command) in commands.enumerated() {
      let notRun = Array(commands.dropFirst(index + 1))
      guard let executable = Self.resolve(command.executable, root: root) else {
        return InstallResult(
          completed: completed,
          failure: InstallFailure(
            command: command,
            status: 127,
            stderr: Self.notFoundMessage(for: command.executable, root: root),
            notRun: notRun
          )
        )
      }
      do {
        let result = try processRunner.run(
          executable: executable,
          arguments: command.arguments,
          cwd: root,
          onStdout: { onOutput?(String(decoding: $0, as: UTF8.self)) },
          onStderr: { onOutput?(String(decoding: $0, as: UTF8.self)) }
        )
        guard result.exitCode == 0 else {
          return InstallResult(
            completed: completed,
            failure: InstallFailure(
              command: command,
              status: result.exitCode,
              stderr: result.stderr,
              notRun: notRun
            )
          )
        }
        completed.append(command)
      } catch {
        return InstallResult(
          completed: completed,
          failure: InstallFailure(
            command: command,
            status: -1,
            stderr: "\(error)",
            notRun: notRun
          )
        )
      }
    }
    return InstallResult(completed: completed, failure: nil)
  }

  private static func resolve(_ name: String, root: URL) -> URL? {
    guard name.contains("/") else {
      return ToolLocator.url(for: name)
    }
    let url = name.hasPrefix("/") ? URL(fileURLWithPath: name) : root.appendingPathComponent(name)
    return FileManager.default.isExecutableFile(atPath: url.path) ? url.standardizedFileURL : nil
  }

  private static func notFoundMessage(for name: String, root: URL) -> String {
    guard name.contains("/") else {
      return ToolLocator.notFoundMessage(for: name)
    }
    return "'\(name)' was not found under \(root.path)"
  }
}
