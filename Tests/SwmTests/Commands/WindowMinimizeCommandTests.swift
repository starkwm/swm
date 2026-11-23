import Testing

@testable import Swm
@testable import SwmLib

@Suite("WindowMinimizeCommand")
struct WindowMinimizeCommandTests {
  @Test(
    "parseAsRoot: explicit targets, and minimize's omitted target, preserve daemon IPC selection",
    arguments: ["minimize", "unminimize"]
  )
  func parseAsRootExplicitTargetsAndMinimizesOmittedTargetPreserveDaemonIPCSelection(
    action: String
  ) throws {
    let omitted: [String?] = action == "minimize" ? [nil] : []
    for target in omitted + ["recent", "1", "123", "4294967295"] {
      let values = target.map { [$0] } ?? []
      let command = try #require(
        Arguments.parseAsRoot(Arguments.resolve(["window", action] + values)) as? any IPCCommand
      )
      let result = Client.send(domain: command.requestDomain, args: command.commandArguments) {
        request in
        #expect(request.domain == .window)
        #expect(request.command == "--\(action)")
        #expect(request.args == values)
        return .acknowledged(id: request.id)
      }
      #expect(result.ok)
    }
  }

  @Test("parseAsRoot: unminimize requires a target because a minimized window is never focused")
  func parseAsRootUnminimizeRequiresATargetBecauseAMinimizedWindowIsNeverFocused() {
    #expect(throws: (any Error).self) {
      try Arguments.parseAsRoot(Arguments.resolve(["window", "unminimize"]))
    }
  }

  @Test(
    "parseAsRoot: rejects invalid targets, extra targets, removed selectors, and toggle flags",
    arguments: ["minimize", "unminimize"]
  )
  func parseAsRootRejectsInvalidTargetsExtraTargetsRemovedSelectorsAndToggleFlags(action: String) {
    for values in [
      ["0"], ["-1"], ["4294967296"], ["1.5"], ["unknown"], [""],
      ["left"], ["right"], ["up"], ["down"], ["master"], ["next"], ["prev"], ["toggle"],
      ["recent", "123"], ["--window", "recent"], ["--window", "123"],
      ["--window=recent"], ["--window=123"], ["123", "--window", "recent"],
      ["--toggle"], ["--", "-1"],
    ] {
      #expect(throws: (any Error).self) {
        try Arguments.parseAsRoot(Arguments.resolve(["window", action] + values))
      }
    }
  }

  @Test("parseAsRoot: other window commands retain --window selection")
  func parseAsRootOtherWindowCommandsRetainWindowSelection() throws {
    let cases: [(String, [String], [String])] = [
      ("move", ["--window", "recent", "20", "0"], ["--move", "recent", "rel:20:0"]),
      ("resize", ["--window", "123", "40", "0"], ["--resize", "123", "rel:40:0"]),
      ("swap", ["--window", "recent", "left"], ["--swap", "recent", "left"]),
      ("swap", ["--window", "123", "master"], ["--swap-with-master", "123"]),
    ]
    for (action, values, expected) in cases {
      let command = try #require(
        Arguments.parseAsRoot(Arguments.resolve(["window", action] + values)) as? any IPCCommand
      )
      #expect(command.commandArguments == expected)
    }
  }
}
