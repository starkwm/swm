import Foundation
import Testing

@testable import SwmLib

@Suite("Config")
struct ConfigTests {
  @Test("exec: rejects missing file")
  func execRejectsMissingFile() throws {
    let directory = try TemporaryDirectory()
    let path = directory.url.appending(path: "missing").path()

    do {
      try Config.exec(path: path)
      Issue.record("Expected missing config to fail")
    } catch ConfigError.fileDoesNotExist {
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test("exec: adds owner execute permission")
  func execAddsOwnerExecutePermission() throws {
    let directory = try TemporaryDirectory()
    let script = try directory.makeScript(
      name: "swmrc",
      contents: """
        #!/bin/sh
        exit 0
        """,
      permissions: 0o640
    )

    try Config.exec(path: script.path())

    #expect(try permissions(of: script) == 0o740)
  }

  @Test("exec: runs already executable file and waits")
  func execRunsAlreadyExecutableFileAndWaits() throws {
    let directory = try TemporaryDirectory()
    let marker = directory.url.appending(path: "marker")
    let script = try directory.makeScript(
      name: "swmrc",
      contents: """
        #!/bin/sh
        exit 0
        """,
      permissions: 0o700
    )

    try Config.exec(path: script.path()) { path in
      #expect(path == script.path())
      try "done".write(to: marker, atomically: true, encoding: .utf8)
    }

    let markerContents = try String(contentsOf: marker, encoding: .utf8)
    #expect(markerContents == "done")
  }

  @Test("exec: rejects invalid executable")
  func execRejectsInvalidExecutable() throws {
    let directory = try TemporaryDirectory()
    let script = try directory.makeScript(
      name: "swmrc",
      contents: "not a valid executable",
      permissions: 0o700
    )

    do {
      try Config.exec(path: script.path())
      Issue.record("Expected invalid executable to fail")
    } catch ConfigError.unableToExecute {
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test("exec: rejects non-zero exit")
  func execRejectsNonZeroExit() throws {
    let directory = try TemporaryDirectory()
    let script = try directory.makeScript(
      name: "swmrc",
      contents: """
        #!/bin/sh
        exit 7
        """,
      permissions: 0o700
    )

    do {
      try Config.exec(path: script.path())
      Issue.record("Expected non-zero exit to fail")
    } catch ConfigError.configurationFailed(let status) {
      #expect(status == 7)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  private func permissions(of url: URL) throws -> UInt16 {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path())
    let permissions = try #require(attributes[.posixPermissions] as? NSNumber)
    return permissions.uint16Value & 0o777
  }
}

@Suite("ConfigError")
struct ConfigErrorTests {
  @Test("description: describes failures")
  func descriptionDescribesFailures() {
    #expect(ConfigError.fileDoesNotExist.description == "configuration file does not exist")
    #expect(
      ConfigError.unableToMakeExecutable.description
        == "unable to mark the configuration file as executable"
    )
    #expect(ConfigError.unableToExecute.description == "unable to execute the configuration file")
    #expect(
      ConfigError.configurationFailed(status: 7).description
        == "configuration file exited with status 7"
    )
  }
}

private final class TemporaryDirectory {
  let url: URL

  init() throws {
    url = FileManager.default.temporaryDirectory
      .appending(path: "swm-config-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  }

  deinit {
    try? FileManager.default.removeItem(at: url)
  }

  func makeScript(name: String, contents: String, permissions: Int) throws -> URL {
    let url = url.appending(path: name)
    try contents.write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.posixPermissions: NSNumber(value: permissions)],
      ofItemAtPath: url.path()
    )
    return url
  }
}
