import Darwin
import Testing

@testable import Swm
@testable import SwmLib

@Suite("WindowMoveCommand")
struct WindowMoveCommandTests {
  @Test(
    "parseAsRoot: transfers preserve targets and selectors in existing IPC",
    arguments: ["display", "space"]
  )
  func parseAsRootTransfersPreserveTargetsAndSelectorsInExistingIPC(mode: String) throws {
    let output = try #require(tmpfile())
    defer { fclose(output) }
    let cases: [([String], WindowSelection, CyclicTarget)] = [
      (["--\(mode)", "next"], .focused, .next),
      (["--\(mode)=2", "--window", "123"], .id(123), .index(2)),
      (["--window=recent", "--\(mode)", "prev"], .recent, .previous),
    ]
    for (values, selection, target) in cases {
      var command = try #require(
        Arguments.parseAsRoot(Arguments.resolve(["window", "move"] + values))
          as? WindowCommand.Move
      )
      let expected: IPCCommand =
        mode == "display"
        ? .window(.display(selection, target))
        : .window(.space(selection, target))
      var sent = false
      try command.run(
        send: { ipcCommand in
          Client.send(ipcCommand) { request in
            sent = true
            #expect(request.command == expected)
            return .acknowledged(id: request.id)
          }
        },
        output: output,
        errors: output
      )
      #expect(sent)
    }
  }

  @Test("parseAsRoot: reports conflicting modes before incomplete coordinates")
  func parseAsRootReportsConflictingModesBeforeIncompleteCoordinates() {
    for values in [["--display", "next", "5"], ["-20", "--space", "3"]] {
      #expect {
        try Arguments.parseAsRoot(Arguments.resolve(["window", "move"] + values))
      } throws: { error in
        Arguments.message(for: error).contains("Choose exactly one mode")
      }
    }
  }

  @Test(
    "parseAsRoot: rejects conflicting modes, incomplete coordinates, and transfer absolute flags")
  func parseAsRootRejectsConflictingModesIncompleteCoordinatesAndTransferAbsoluteFlags() {
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
