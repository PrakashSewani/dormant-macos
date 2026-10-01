import Foundation
import Testing

@testable import DormantCore

@Suite struct InstallCommandsTests {
  @Test(
    "detection table",
    arguments: zip(
      [
        ["pnpm-lock.yaml", "package.json"],
        ["yarn.lock", "package.json"],
        ["bun.lockb", "package.json"],
        ["package-lock.json", "package.json"],
        ["package.json"],
        ["uv.lock", "pyproject.toml"],
        ["poetry.lock", "pyproject.toml"],
        ["requirements.txt"],
        ["pyproject.toml"],
        ["Cargo.toml"],
        ["App.csproj"],
        ["go.mod"],
        ["package.json", "Cargo.toml", "go.mod"],
        [String](),
      ],
      [
        ["pnpm install"],
        ["yarn install"],
        ["bun install"],
        ["npm install"],
        ["npm install"],
        ["uv sync"],
        ["poetry install"],
        ["python3 -m venv .venv", ".venv/bin/python -m pip install -r requirements.txt"],
        ["python3 -m venv .venv", ".venv/bin/python -m pip install -e ."],
        ["cargo build"],
        ["dotnet restore"],
        ["go mod download"],
        ["npm install", "cargo build", "go mod download"],
        [String](),
      ]
    )
  )
  func detectionTable(files: [String], expected: [String]) throws {
    let project = try TempProject()
    defer { project.destroy() }
    for file in files {
      try project.file(file, contents: "")
    }

    let commands = InstallCommands.detect(projectAt: project.root)

    #expect(commands.map { $0.display } == expected)
  }

  @Test func existingVenvIsNotRecreated() throws {
    let project = try TempProject()
    defer { project.destroy() }
    try project.file("requirements.txt", contents: "")
    try project.directory(".venv")

    let commands = InstallCommands.detect(projectAt: project.root)

    let expected = [".venv/bin/python -m pip install -r requirements.txt"]
    #expect(commands.map { $0.display } == expected)
  }

  @Test func reasonsStateTheTriggeringFile() throws {
    let project = try TempProject()
    defer { project.destroy() }
    try project.file("pnpm-lock.yaml", contents: "")

    let command = try #require(InstallCommands.detect(projectAt: project.root).first)

    #expect(command.reason == "pnpm-lock.yaml")
    #expect(command.executable == "pnpm")
    #expect(command.arguments == ["install"])
  }

  @Test func runnerRunsSequentiallyAndStopsOnFailure() throws {
    let project = try TempProject()
    defer { project.destroy() }
    let first = InstallCommand(executable: "/bin/sh", arguments: ["-c", "echo hello"], reason: "t")
    let failing = InstallCommand(executable: "/bin/sh", arguments: ["-c", "exit 3"], reason: "t")
    let never = InstallCommand(executable: "/bin/sh", arguments: ["-c", "echo no"], reason: "t")

    let result = InstallRunner().run([first, failing, never], in: project.root)

    #expect(result.completed == [first])
    #expect(result.failure?.status == 3)
    #expect(result.failure?.command == failing)
    #expect(result.failure?.notRun == [never])
  }

  @Test func runnerStreamsOutput() throws {
    let project = try TempProject()
    defer { project.destroy() }
    let box = OutputBox()
    let command = InstallCommand(
      executable: "/bin/sh", arguments: ["-c", "echo hello"], reason: "t"
    )

    let result = InstallRunner().run([command], in: project.root) { box.append($0) }

    #expect(result.failure == nil)
    #expect(result.completed == [command])
    #expect(box.value.contains("hello"))
  }

  @Test func bareNameResolvesThroughToolLocator() throws {
    let project = try TempProject()
    defer { project.destroy() }
    let command = InstallCommand(executable: "sh", arguments: ["-c", "echo hello"], reason: "t")

    let result = InstallRunner().run([command], in: project.root)

    #expect(result.failure == nil)
    #expect(result.completed == [command])
  }

  @Test func missingToolFailsWith127AndStops() throws {
    let project = try TempProject()
    defer { project.destroy() }
    let missing = InstallCommand(
      executable: "dormant-no-such-tool-xyz", arguments: ["install"], reason: "t"
    )
    let never = InstallCommand(executable: "/bin/sh", arguments: ["-c", "echo no"], reason: "t")

    let result = InstallRunner().run([missing, never], in: project.root)

    #expect(result.completed.isEmpty)
    #expect(result.failure?.status == 127)
    #expect(result.failure?.command == missing)
    #expect(result.failure?.notRun == [never])
    #expect(result.failure?.stderr.contains("dormant-no-such-tool-xyz") == true)
    #expect(result.failure?.stderr.contains("Searched") == true)
  }

  @Test func relativeExecutableResolvesUnderProjectRoot() throws {
    let project = try TempProject()
    defer { project.destroy() }
    let command = InstallCommand(
      executable: ".venv/bin/python", arguments: ["--version"], reason: "t"
    )

    let result = InstallRunner().run([command], in: project.root)

    #expect(result.completed.isEmpty)
    #expect(result.failure?.status == 127)
    #expect(result.failure?.stderr.contains(".venv/bin/python") == true)
    #expect(result.failure?.stderr.contains(project.root.path) == true)
  }
}

private final class OutputBox: @unchecked Sendable {
  private let lock = NSLock()
  private var text = ""

  func append(_ chunk: String) {
    lock.lock()
    text += chunk
    lock.unlock()
  }

  var value: String {
    lock.lock()
    defer { lock.unlock() }
    return text
  }
}
