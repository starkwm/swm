import Foundation
import Testing

@testable import SwmLib

@Suite("IPCRequest")
struct IPCRequestTests {
  @Test(
    "make: preserves command arguments",
    arguments: [
      (CommandDomain.window, ["focus", "main display"]),
      (.window, ["--move", "recent", "abs:100:200"]),
      (.window, ["--resize", "100", "abs:500:800"]),
      (.window, ["--grid", "3:1:0:0:2:1"]),
      (.window, ["--grid", "recent", "3:1:0:0:2:1"]),
      (.signal, ["--add", "event=window-focused", "action=echo"]),
    ]
  )
  func makePreservesCommandArguments(domain: CommandDomain, arguments: [String]) throws {
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

  @Test("make: accepts plural query flags", arguments: ["--displays", "--spaces", "--windows"])
  func makeAcceptsPluralQueryFlags(flag: String) throws {
    let request = try IPCRequest.make(domain: .query, arguments: [flag])
    #expect(request.domain == .query)
    #expect(request.command == flag)
    #expect(request.args == [])
  }

  @Test(
    "make: defaults singular queries to focused selection",
    arguments: ["--display", "--space", "--window"]
  )
  func makeDefaultsSingularQueriesToFocusedSelection(flag: String) throws {
    let request = try IPCRequest.make(domain: .query, arguments: [flag])
    #expect(request.domain == .query)
    #expect(request.command == flag + "s")
    #expect(request.args == [flag])
  }

  @Test(
    "make: preserves explicit query selectors",
    arguments: [
      (["--windows", "--display"], "--windows", ["--display"]),
      (["--spaces", "--window", "42"], "--spaces", ["--window", "42"]),
      (["--display", "1"], "--displays", ["--display", "1"]),
      (["--space", "2"], "--spaces", ["--space", "2"]),
      (["--window", "42"], "--windows", ["--window", "42"]),
    ]
  )
  func makePreservesExplicitQuerySelectors(arguments: [String], command: String, args: [String])
    throws
  {
    let request = try IPCRequest.make(domain: .query, arguments: arguments)
    #expect(request.command == command)
    #expect(request.args == args)
  }

  @Test(
    "make: rejects malformed queries with exact diagnostics",
    arguments: [
      ([], "exactly one query flag is required"),
      (["--displays", "--windows"], "exactly one query flag is required"),
      (["displays"], "unsupported query argument: displays"),
      (["--windows", "--display", "--space"], "only one query selector is allowed"),
      (["--windows", "--display", "1", "2"], "query selector accepts at most one value"),
      (["--windows", "--display", "0"], "query display selector value must be a positive integer"),
      (
        ["--windows", "--space", "-1"], "query space selector value must be a non-negative integer"
      ),
      (["--windows", "--window", "abc"], "query window selector value must be a window id"),
    ]
  )
  func makeRejectsMalformedQueriesWithExactDiagnostics(arguments: [String], message: String) {
    #expect(throws: IPCCommandError.invalidRequest(message)) {
      try IPCRequest.make(domain: .query, arguments: arguments)
    }
  }

  @Test("encode/decode: preserves the legacy request schema")
  func encodeDecodePreservesTheLegacyRequestSchema() throws {
    let fixture =
      #"{"args":["main display","--title=A window with spaces"],"command":"focus","domain":"window","id":"request-id","version":1}"#
    let request = IPCRequest(
      id: "request-id",
      domain: .window,
      command: "focus",
      args: ["main display", "--title=A window with spaces"]
    )
    #expect(try wireJSON(request) == fixture)
    #expect(try JSONDecoder().decode(IPCRequest.self, from: Data(fixture.utf8)) == request)
  }

  private func wireJSON(_ value: some Encodable) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return String(decoding: try encoder.encode(value), as: UTF8.self)
  }
}
