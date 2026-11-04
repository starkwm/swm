import ArgumentParser
import Testing

@testable import Swm

@Suite("Window grid CLI")
struct WindowGridCommandTests {
  @Test("translates cells and window selection to IPC")
  func translatesPlacement() throws {
    let cases: [([String], [String])] = [
      (["2", "1", "0", "0", "1", "1"], ["2:1:0:0:1:1"]),
      (["3", "2", "1", "0", "2", "2"], ["3:2:1:0:2:2"]),
      (["--window", "recent", "2", "1", "1", "0", "1", "1"], ["recent", "2:1:1:0:1:1"]),
      (["2", "1", "--window=42", "1", "0", "1", "1"], ["42", "2:1:1:0:1:1"]),
      (["2", "1", "0", "0", "1", "1", "--window", "42"], ["42", "2:1:0:0:1:1"]),
      // The daemon clamps out-of-range cells, so the CLI passes them through.
      (["3", "2", "-1", "99", "0", "-2"], ["3:2:-1:99:0:-2"]),
      (["3", "2", "-1", "--window", "recent", "-2", "99", "99"], ["recent", "3:2:-1:-2:99:99"]),
      (["--window=recent", "--", "3", "2", "-1", "-2", "1", "1"], ["recent", "3:2:-1:-2:1:1"]),
    ]
    for (values, expected) in cases {
      let command = try #require(
        Arguments.parseAsRoot(Arguments.resolve(["window", "grid"] + values)) as? WindowCommand.Grid
      )
      #expect(command.commandArguments == ["--grid"] + expected)
      #expect(WindowCommand.Grid.domain == .window)
    }
  }

  @Test("rejects non-integers and missing or extra cells")
  func rejectsInvalidPlacement() {
    let valid = ["2", "1", "0", "0", "1", "1"]
    var cases = (0..<6).map { Array(valid.prefix($0)) }
    cases += [
      valid + ["1"], valid + ["--unknown"], valid + ["--window"],
    ]
    for index in valid.indices {
      for invalid in ["cell", "1.5", "999999999999999999999999999999"] {
        var values = valid
        values[index] = invalid
        cases.append(values)
      }
    }
    for values in cases {
      #expect(throws: (any Error).self) {
        try Arguments.parseAsRoot(Arguments.resolve(["window", "grid"] + values))
      }
    }
  }

  @Test("rejects nonpositive row and column counts before IPC")
  func rejectsNonpositiveCounts() {
    for counts in [["0", "1"], ["2", "0"], ["-2", "1"], ["2", "-1"]] {
      #expect(throws: (any Error).self) {
        try Arguments.parseAsRoot(
          Arguments.resolve(["window", "grid"] + counts + ["0", "0", "1", "1"])
        )
      }
    }
  }

  @Test("help lists grid arguments and examples")
  func helpDocumentsPositionals() {
    let help = WindowCommand.Grid.helpMessage()
    #expect(help.contains("<columns> <rows> <x> <y> <width> <height>"))
    #expect(help.contains("swm window grid 2 1 0 0 1 1"))
    #expect(help.contains("--window"))
  }
}
