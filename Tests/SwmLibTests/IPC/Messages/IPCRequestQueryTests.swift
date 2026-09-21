import Testing

@testable import SwmLib

@Suite("IPCRequest query")
struct IPCRequestQueryTests {
  @Test("accepts plural query flags", arguments: ["--displays", "--spaces", "--windows"])
  func pluralFlags(flag: String) throws {
    let request = try IPCRequest.make(domain: .query, arguments: [flag])
    #expect(request.domain == .query)
    #expect(request.command == flag)
    #expect(request.args == [])
  }

  @Test(
    "defaults singular queries to focused selection",
    arguments: ["--display", "--space", "--window"]
  )
  func singularDefaults(flag: String) throws {
    let request = try IPCRequest.make(domain: .query, arguments: [flag])
    #expect(request.domain == .query)
    #expect(request.command == flag + "s")
    #expect(request.args == [flag])
  }

  @Test(
    "preserves explicit selectors",
    arguments: [
      (["--windows", "--display"], "--windows", ["--display"]),
      (["--spaces", "--window", "42"], "--spaces", ["--window", "42"]),
      (["--display", "1"], "--displays", ["--display", "1"]),
      (["--space", "2"], "--spaces", ["--space", "2"]),
      (["--window", "42"], "--windows", ["--window", "42"]),
    ]
  )
  func explicitSelectors(arguments: [String], command: String, args: [String]) throws {
    let request = try IPCRequest.make(domain: .query, arguments: arguments)
    #expect(request.command == command)
    #expect(request.args == args)
  }

  @Test(
    "rejects malformed queries with the expected error",
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
  func malformedQuery(arguments: [String], message: String) {
    #expect(throws: IPCCommandError.invalidRequest(message)) {
      try IPCRequest.make(domain: .query, arguments: arguments)
    }
  }
}
