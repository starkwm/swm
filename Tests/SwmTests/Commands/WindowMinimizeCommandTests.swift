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
    let omitted: [(String?, WindowSelection)] = action == "minimize" ? [(nil, .focused)] : []
    let targets: [(String?, WindowSelection)] =
      omitted + [
        ("recent", .recent),
        ("1", .id(1)),
        ("123", .id(123)),
        ("4294967295", .id(4_294_967_295)),
      ]
    for (target, expectedSelection) in targets {
      let values = target.map { [$0] } ?? []
      let command = try #require(
        Arguments.parseAsRoot(Arguments.resolve(["window", action] + values)) as? any DaemonCommand
      )
      let expected: IPCCommand =
        action == "minimize"
        ? .window(.minimize(expectedSelection))
        : .window(.unminimize(expectedSelection))
      let result = Client.send(command.ipcCommand) { request in
        #expect(request.command == expected)
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
    let cases: [(String, [String], IPCCommand)] = [
      (
        "move", ["--window", "recent", "20", "0"],
        .window(.move(.recent, .relative(IntPair(20, 0))))
      ),
      (
        "resize", ["--window", "123", "40", "0"],
        .window(.resize(.id(123), .relative(IntPair(40, 0))))
      ),
      ("swap", ["--window", "recent", "left"], .window(.swap(.recent, .left))),
      ("swap", ["--window", "123", "master"], .window(.swapWithMaster(.id(123)))),
    ]
    for (action, values, expected) in cases {
      let command = try #require(
        Arguments.parseAsRoot(Arguments.resolve(["window", action] + values)) as? any DaemonCommand
      )
      #expect(command.ipcCommand == expected)
    }
  }
}
