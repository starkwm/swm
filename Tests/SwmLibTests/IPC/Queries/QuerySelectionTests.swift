import CoreGraphics
import Testing

@testable import SwmLib

@Suite("QuerySelection")
struct QuerySelectionTests {
  @Test(
    "parse: reads at most one selector",
    arguments: [
      ([], QuerySelection.none),
      (["--display"], .display(nil)),
      (["--display", "1"], .display(1)),
      (["--space"], .space(nil)),
      (["--space", "2"], .space(2)),
      (["--window"], .window(nil)),
      (["--window", "42"], .window(42)),
    ]
  )
  func parseReadsAtMostOneSelector(arguments: [String], selection: QuerySelection) throws {
    #expect(try QuerySelection.parse(arguments: arguments) == selection)
  }

  @Test(
    "parse: rejects malformed selectors with exact diagnostics",
    arguments: [
      (["displays"], "unsupported query argument: displays"),
      (["--windows"], "unsupported query argument: --windows"),
      (["--display", "--space"], "only one query selector is allowed"),
      (["--display", "1", "2"], "query selector accepts at most one value"),
      (["--display", "0"], "query display selector value must be a positive integer"),
      (["--space", "0"], "query space selector value must be a positive integer"),
      (["--window", "abc"], "query window selector value must be a window id"),
    ]
  )
  func parseRejectsMalformedSelectorsWithExactDiagnostics(arguments: [String], message: String) {
    #expect(throws: IPCCommandError.invalidRequest(message)) {
      try QuerySelection.parse(arguments: arguments)
    }
  }
}
