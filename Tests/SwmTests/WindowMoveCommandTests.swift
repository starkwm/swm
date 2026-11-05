import Darwin
import Testing

@testable import Swm
@testable import SwmLib

@Suite("Window move CLI")
struct WindowMoveCommandTests {
  @Test(
    "transfers preserve targets and selectors in existing IPC",
    arguments: ["display", "space"]
  )
  func routesTransfers(mode: String) throws {
    let output = try #require(tmpfile())
    defer { fclose(output) }
    let cases: [([String], [String])] = [
      (["--\(mode)", "next"], ["next"]),
      (["--\(mode)=2", "--window", "123"], ["123", "2"]),
      (["--window=recent", "--\(mode)", "prev"], ["recent", "prev"]),
    ]
    for (values, expected) in cases {
      var command = try #require(
        Arguments.parseAsRoot(Arguments.resolve(["window", "move"] + values))
          as? WindowCommand.Move
      )
      var sent = false
      try command.run(
        send: { domain, args in
          Client.send(domain: domain, args: args) { request in
            sent = true
            #expect(request.domain == .window)
            #expect(request.command == "--\(mode)")
            #expect(request.args == expected)
            return .acknowledged(id: request.id)
          }
        },
        output: output,
        errors: output
      )
      #expect(sent)
    }
  }

  @Test("reports conflicting modes before incomplete coordinates")
  func reportsConflictingModes() {
    for values in [["--display", "next", "5"], ["-20", "--space", "3"]] {
      #expect {
        try Arguments.parseAsRoot(Arguments.resolve(["window", "move"] + values))
      } throws: { error in
        Arguments.message(for: error).contains("Choose exactly one mode")
      }
    }
  }

  @Test("rejects conflicting modes, incomplete coordinates, and transfer absolute flags")
  func rejectsInvalidModes() {
    for values in [
      [], ["--absolute"], ["1"], ["--display"], ["--space"],
      ["--display", "next", "--space", "3"], ["--display=2", "--space=3"],
      ["1", "2", "--display", "next"], ["--space=3", "-20", "0"],
      ["--display", "next", "1"], ["-20", "--space", "3"],
      ["--absolute", "--display", "next"], ["--space=3", "--absolute"],
      ["--display", "--window", "123"], ["--space", "--absolute"],
      ["--display", "0"], ["--space=-1"], ["--display=recent"], ["--space=current"],
      ["--display=left"], ["--space", "fullscreen"], ["--display=next", "--window"],
    ] {
      #expect(throws: (any Error).self) {
        try Arguments.parseAsRoot(Arguments.resolve(["window", "move"] + values))
      }
    }
  }
}
