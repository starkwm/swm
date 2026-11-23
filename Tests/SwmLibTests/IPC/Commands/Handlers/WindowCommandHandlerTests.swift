import Testing

@testable import SwmLib

@Suite("WindowCommandHandler")
@MainActor
struct WindowCommandHandlerTests {
  @Test("dispatch: rejects missing numeric single-target action target")
  func dispatchRejectsMissingNumericSingleTargetActionTarget() async {
    let handler = handler()
    let commands: [IPCCommand.Window] = [
      .focus(.selected(.id(42))),
      .warp(.selected(.id(42))),
      .minimize(.id(42)),
      .unminimize(.id(42)),
    ]

    for command in commands {
      let response = await handler.dispatch(id: "request-id", command: command)

      #expect(response.ok == false)
      #expect(response.errorCode == .invalidRequest)
      #expect(response.message == "window not found: 42")
    }
  }

  @Test("dispatch: rejects warp when no recent window exists")
  func dispatchRejectsWarpWhenNoRecentWindowExists() async {
    let response = await handler().dispatch(id: "request-id", command: .warp(.selected(.recent)))

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "no recent window")
  }

  @Test(
    "dispatch: rejects an absolute resize to a zero or negative size",
    arguments: [IntPair(0, 100), IntPair(100, 0), IntPair(-1, 100)]
  )
  func dispatchRejectsAnAbsoluteResizeToAZeroOrNegativeSize(size: IntPair) async {
    let response = await handler().dispatch(
      id: "request-id",
      command: .resize(.focused, .absolute(size))
    )

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "window size must be positive: \(size.first)x\(size.second)")
  }

  @Test("dispatch: resolves window selectors before attempting a Space move")
  func dispatchResolvesWindowSelectorsBeforeAttemptingASpaceMove() async {
    let handler = handler()

    let zero = await handler.dispatch(id: "request-id", command: .space(.id(0), .next))
    let missing = await handler.dispatch(id: "request-id", command: .space(.id(42), .index(1)))

    #expect(zero.message == "invalid window selector: 0")
    #expect(missing.message == "window not found: 42")
  }

  private func handler(
    windows: Windows = Windows(workspace: Workspace(), focusedWindowID: nil)
  ) -> WindowCommandHandler {
    let spaces = Spaces(activeSpaceID: nil)
    return WindowCommandHandler(
      windows: windows,
      spaces: spaces,
      tiling: makeTestTiling(spaces: spaces)
    )
  }
}
