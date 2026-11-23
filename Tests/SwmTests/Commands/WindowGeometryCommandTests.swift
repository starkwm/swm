import Testing

@testable import Swm
@testable import SwmLib

@Suite("WindowGeometryCommand")
struct WindowGeometryCommandTests {
  @Test(
    "parseAsRoot: defaults to relative and preserves IPC geometry and window selection",
    arguments: ["move", "resize"]
  )
  func parseAsRootDefaultsToRelativeAndPreservesIPCGeometryAndWindowSelection(
    action: String
  ) throws {
    let cases: [([String], WindowSelection, NumericChange<IntPair>)] = [
      (["20", "0"], .focused, .relative(IntPair(20, 0))),
      (["--absolute", "1200", "800"], .focused, .absolute(IntPair(1200, 800))),
      (["--window", "recent", "20", "0"], .recent, .relative(IntPair(20, 0))),
      (["-20", "0"], .focused, .relative(IntPair(-20, 0))),
      (["20", "-10"], .focused, .relative(IntPair(20, -10))),
      (["-20", "-10"], .focused, .relative(IntPair(-20, -10))),
      (["-20", "--window", "42", "10"], .id(42), .relative(IntPair(-20, 10))),
      (["20", "--window=recent", "-10"], .recent, .relative(IntPair(20, -10))),
      (["-20", "--absolute", "10"], .focused, .absolute(IntPair(-20, 10))),
      (["20", "-10", "--absolute", "--window", "42"], .id(42), .absolute(IntPair(20, -10))),
      (["--absolute", "--window", "recent", "-20", "-10"], .recent, .absolute(IntPair(-20, -10))),
      (["--window", "42", "--absolute", "--", "-20", "10"], .id(42), .absolute(IntPair(-20, 10))),
      (["--absolute", "0", "25"], .focused, .absolute(IntPair(0, 25))),
      (["40", "0"], .focused, .relative(IntPair(40, 0))),
    ]
    for (values, selection, change) in cases {
      let command = try #require(
        Arguments.parseAsRoot(Arguments.resolve(["window", action] + values)) as? any DaemonCommand
      )
      let expected: IPCCommand =
        action == "move"
        ? .window(.move(selection, change))
        : .window(.resize(selection, change))
      #expect(command.ipcCommand == expected)
    }
  }

  @Test(
    "parseAsRoot: rejects replaced syntax, non-integers, and missing or extra values",
    arguments: ["move", "resize"]
  )
  func parseAsRootRejectsReplacedSyntaxNonIntegersAndMissingOrExtraValues(action: String) {
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
}
