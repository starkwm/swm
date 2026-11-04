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
    for target in ["1", "3", "next", "prev", "previous"] {
      for selector in [[], ["--window", "123"], ["--window=recent"]] {
        for option in [["--\(mode)", target], ["--\(mode)=\(target)"]] {
          for values in [selector + option, option + selector] {
            var command = try #require(
              Arguments.parseAsRoot(Arguments.resolve(["window", "move"] + values))
                as? WindowCommand.Move
            )
            let selected = selector.isEmpty ? [] : [selector.count == 1 ? "recent" : "123"]
            var sent = false
            try command.run(
              send: { domain, args in
                Client.send(domain: domain, args: args) { request in
                  sent = true
                  #expect(request.domain == .window)
                  #expect(request.command == "--\(mode)")
                  #expect(request.args == selected + [target])
                  return .acknowledged(id: request.id)
                }
              },
              output: output,
              errors: output
            )
            #expect(sent)
          }
        }
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

  @Test("removed public transfer subcommands fail", arguments: ["display", "space"])
  func rejectsRemovedSubcommands(subcommand: String) {
    for values in [["next"], ["--window", "123", "2"]] {
      #expect(throws: (any Error).self) {
        try Arguments.parseAsRoot(["window", subcommand] + values)
      }
      #expect(throws: (any Error).self) {
        try Arguments.resolve(["window", subcommand] + values)
      }
    }
  }
}
