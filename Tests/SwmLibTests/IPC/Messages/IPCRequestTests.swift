import Testing

@testable import SwmLib

@Suite("IPCRequest")
struct IPCRequestTests {
  @Test(
    "make preserves command arguments",
    arguments: [
      (CommandDomain.window, ["focus", "main display"]),
      (.window, ["--move", "recent", "abs:100:200"]),
      (.window, ["--resize", "100", "abs:500:800"]),
      (.window, ["--grid", "3:1:0:0:2:1"]),
      (.window, ["--grid", "recent", "3:1:0:0:2:1"]),
      (.signal, ["--add", "event=window-focused", "action=echo"]),
    ]
  )
  func makePreservesArguments(domain: CommandDomain, arguments: [String]) throws {
    let request = try IPCRequest.make(domain: domain, arguments: arguments)
    #expect(request.version == IPCRequest.currentVersion)
    #expect(request.domain == domain)
    #expect(request.command == arguments[0])
    #expect(request.args == Array(arguments.dropFirst()))
  }

  @Test("make: requires command")
  func makeRequiresCommand() {
    do {
      _ = try IPCRequest.make(domain: .config, arguments: [])
      Issue.record("Expected missing command error")
    } catch let error as IPCCommandError {
      #expect(error.description == "missing command for config")
      #expect(error.errorCode == .invalidRequest)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test("validateVersion: rejects unsupported versions")
  func validateVersionRejectsUnsupportedVersions() {
    let request = IPCRequest(
      version: IPCRequest.currentVersion + 1,
      domain: .window,
      command: "--focus",
      args: []
    )

    do {
      try request.validateVersion()
      Issue.record("Expected unsupported version error")
    } catch let error as IPCCommandError {
      #expect(error.errorCode == .invalidRequest)
      #expect(error.message == "unsupported IPC request version: 2; expected 1")
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }
}
