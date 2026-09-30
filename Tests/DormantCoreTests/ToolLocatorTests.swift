import Foundation
import Testing

@testable import DormantCore

@Suite struct ToolLocatorTests {
  @Test func findsToolInToolManagerDirectory() throws {
    let home = try TempProject()
    defer { home.destroy() }
    try executable(named: "uv", at: ".local/bin", in: home)

    let url = ToolLocator.url(for: "uv", home: home.root)

    #expect(url == home.root.appendingPathComponent(".local/bin/uv"))
  }

  @Test func nvmSearchesNewestNodeFirst() throws {
    let home = try TempProject()
    defer { home.destroy() }
    try executable(named: "npm", at: ".nvm/versions/node/v20.11.1/bin", in: home)
    try executable(named: "npm", at: ".nvm/versions/node/v24.19.0/bin", in: home)

    let url = try #require(ToolLocator.url(for: "npm", home: home.root))

    #expect(url.path.contains("v24.19.0"))
  }

  @Test func extraDirectoriesTakePrecedence() throws {
    let home = try TempProject()
    defer { home.destroy() }
    let extra = home.root.appendingPathComponent("extra")
    try executable(named: "code", at: "extra", in: home)

    let url = ToolLocator.url(for: "code", home: home.root, extraDirectories: [extra])

    #expect(url == extra.appendingPathComponent("code"))
  }

  @Test func nonExecutableFileIsNotFound() throws {
    let home = try TempProject()
    defer { home.destroy() }
    try home.file(".local/bin/uv")

    #expect(ToolLocator.url(for: "uv", home: home.root) == nil)
  }

  @Test func unknownToolIsNotFound() throws {
    let home = try TempProject()
    defer { home.destroy() }

    #expect(ToolLocator.url(for: "dormant-no-such-tool-xyz", home: home.root) == nil)
  }

  @Test func notFoundMessageNamesToolAndSearchedDirectories() throws {
    let home = try TempProject()
    defer { home.destroy() }
    try home.directory(".local/bin")

    let message = ToolLocator.notFoundMessage(for: "dormant-no-such-tool-xyz", home: home.root)

    #expect(message.contains("dormant-no-such-tool-xyz"))
    #expect(message.contains(".local/bin"))
    #expect(message.contains("/usr/bin"))
  }
}

private func executable(named name: String, at directory: String, in project: TempProject) throws {
  let relative = "\(directory)/\(name)"
  try project.file(relative, contents: "#!/bin/sh\nexit 0\n")
  try FileManager.default.setAttributes(
    [.posixPermissions: 0o755],
    ofItemAtPath: project.root.appendingPathComponent(relative).path
  )
}
