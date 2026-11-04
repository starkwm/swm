import Testing

@testable import Swm

@Suite("Window geometry CLI")
struct WindowGeometryCommandTests {
  @Test(
    "defaults to relative and preserves IPC geometry and window selection",
    arguments: ["move", "resize"]
  )
  func translatesGeometry(action: String) throws {
    let cases: [([String], [String])] = [
      (["20", "0"], ["rel:20:0"]),
      (["--absolute", "1200", "800"], ["abs:1200:800"]),
      (["--window", "recent", "20", "0"], ["recent", "rel:20:0"]),
      (["-20", "0"], ["rel:-20:0"]),
      (["20", "-10"], ["rel:20:-10"]),
      (["-20", "-10"], ["rel:-20:-10"]),
      (["-20", "--window", "42", "10"], ["42", "rel:-20:10"]),
      (["20", "--window=recent", "-10"], ["recent", "rel:20:-10"]),
      (["--window=123", "-20", "-10"], ["123", "rel:-20:-10"]),
      (["--window=recent", "--absolute", "-20", "-10"], ["recent", "abs:-20:-10"]),
      (["-20", "--absolute", "10"], ["abs:-20:10"]),
      (["20", "-10", "--absolute", "--window", "42"], ["42", "abs:20:-10"]),
      (["--absolute", "--window", "recent", "-20", "-10"], ["recent", "abs:-20:-10"]),
      (["--window", "42", "--absolute", "--", "-20", "10"], ["42", "abs:-20:10"]),
      (["--absolute", "0", "25"], ["abs:0:25"]),
      (["40", "0"], ["rel:40:0"]),
    ]
    for (values, expected) in cases {
      let command = try #require(
        Arguments.parseAsRoot(Arguments.resolve(["window", action] + values)) as? any IPCCommand
      )
      #expect(command.commandArguments == ["--\(action)"] + expected)
      #expect(type(of: command).domain == .window)
    }
  }

  @Test(
    "rejects replaced syntax, non-integers, and missing or extra values",
    arguments: ["move", "resize"]
  )
  func rejectsInvalidGeometry(action: String) {
    for values in [
      [], ["20"], ["20", "0", "10"], ["abs:0:25"], ["rel:-20:0"],
      ["abs:0:25", "0"], ["rel:40:0", "0"], ["wide", "0"], ["1.5", "0"],
      ["20", "nan"], ["--absolute", "0"], ["--window"],
      ["20", "0", "--unknown"], ["--", "-20", "--absolute", "0"],
    ] {
      #expect(throws: (any Error).self) {
        try Arguments.parseAsRoot(Arguments.resolve(["window", action] + values))
      }
    }
  }

  @Test("grid retains encoded cell syntax")
  func gridRetainsCellSyntax() throws {
    let command = try #require(
      Arguments.parseAsRoot(
        Arguments.resolve([
          "window", "grid", "--window", "recent", "2:1:1:0:1:1",
        ])
      ) as? WindowCommand.Grid
    )
    #expect(command.commandArguments == ["--grid", "recent", "2:1:1:0:1:1"])
  }
}
