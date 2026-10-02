import Testing

@testable import SwmLib

@Suite("WindowCommandHandler")
@MainActor
struct WindowCommandHandlerTests {
  @Test("dispatch: rejects malformed single-target action arguments")
  func dispatchRejectsMalformedSingleTargetActionArguments() async {
    let handler = handler()

    for action in ["focus", "warp", "minimize", "unminimize"] {
      let extra = await handler.dispatch(request(command: "--\(action)", args: ["1", "2"]))

      #expect(extra.ok == false)
      #expect(extra.errorCode == .invalidRequest)
      #expect(extra.message == "invalid window \(action) arguments")
    }
  }

  @Test("dispatch: rejects invalid single-target action target")
  func dispatchRejectsInvalidSingleTargetActionTarget() async {
    let handler = handler()

    for action in ["focus", "warp", "minimize", "unminimize"] {
      let response = await handler.dispatch(request(command: "--\(action)", args: ["nope"]))

      #expect(response.ok == false)
      #expect(response.errorCode == .invalidRequest)
      #expect(response.message == "invalid window selector: nope")
    }
  }

  @Test("dispatch: rejects missing numeric single-target action target")
  func dispatchRejectsMissingNumericSingleTargetActionTarget() async {
    let handler = handler()

    for action in ["focus", "warp", "minimize", "unminimize"] {
      let response = await handler.dispatch(request(command: "--\(action)", args: ["42"]))

      #expect(response.ok == false)
      #expect(response.errorCode == .invalidRequest)
      #expect(response.message == "window not found: 42")
    }
  }

  @Test("dispatch: rejects warp when no recent window exists")
  func dispatchWarpWithoutRecentWindow() async {
    let response = await handler().dispatch(request(command: "--warp", args: ["recent"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "no recent window")
  }

  @Test("dispatch: rejects malformed geometry action arguments")
  func dispatchRejectsMalformedGeometryActionArguments() async {
    let handler = handler()

    for action in ["move", "resize"] {
      let missing = await handler.dispatch(request(command: "--\(action)", args: []))
      let extra = await handler.dispatch(
        request(command: "--\(action)", args: ["1", "abs:1:2", "extra"])
      )

      #expect(missing.ok == false)
      #expect(missing.errorCode == .invalidRequest)
      #expect(missing.message == "invalid window \(action) arguments")
      #expect(extra.ok == false)
      #expect(extra.errorCode == .invalidRequest)
      #expect(extra.message == "invalid window \(action) arguments")
    }
  }

  @Test("dispatch: rejects invalid geometry action value")
  func dispatchRejectsInvalidGeometryActionValue() async {
    let handler = handler()

    for action in ["move", "resize"] {
      let response = await handler.dispatch(request(command: "--\(action)", args: ["rel:100:x"]))

      #expect(response.ok == false)
      #expect(response.errorCode == .invalidRequest)
      #expect(response.message == "invalid window \(action) value: rel:100:x")
    }
  }

  @Test("dispatch: rejects geometry action with invalid window selector")
  func dispatchRejectsGeometryActionWithInvalidWindowSelector() async {
    let handler = handler()

    for action in ["move", "resize"] {
      let response = await handler.dispatch(
        request(command: "--\(action)", args: ["nope", "rel:100:-200"])
      )

      #expect(response.ok == false)
      #expect(response.errorCode == .invalidRequest)
      #expect(response.message == "invalid window selector: nope")
    }
  }

  @Test("dispatch: rejects malformed display arguments")
  func dispatchRejectsMalformedDisplayArguments() async {
    let handler = handler()
    let missing = await handler.dispatch(request(command: "--display", args: []))
    let extra = await handler.dispatch(request(command: "--display", args: ["1", "next", "extra"]))

    #expect(missing.ok == false)
    #expect(missing.errorCode == .invalidRequest)
    #expect(missing.message == "invalid window display arguments")
    #expect(extra.ok == false)
    #expect(extra.errorCode == .invalidRequest)
    #expect(extra.message == "invalid window display arguments")
  }

  @Test("dispatch: rejects invalid display value")
  func dispatchRejectsInvalidDisplayValue() async {
    let handler = handler()
    let response = await handler.dispatch(request(command: "--display", args: ["sideways"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "invalid window display value: sideways")
  }

  @Test("dispatch: rejects malformed Space movement arguments and invalid targets")
  func dispatchRejectsMalformedSpaceArguments() async {
    let handler = handler()

    for args in [[], ["42", "next", "extra"]] {
      let response = await handler.dispatch(request(command: "--space", args: args))

      #expect(response.errorCode == .invalidRequest)
      #expect(response.message == "invalid window space arguments")
    }

    let response = await handler.dispatch(request(command: "--space", args: ["42", "sideways"]))

    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "invalid window space value: sideways")
  }

  @Test("dispatch: resolves window selectors before attempting a Space move")
  func dispatchSpaceWindowSelectors() async {
    let handler = handler()

    let invalid = await handler.dispatch(request(command: "--space", args: ["nope", "next"]))
    let missing = await handler.dispatch(request(command: "--space", args: ["42", "0"]))

    #expect(invalid.message == "invalid window selector: nope")
    #expect(missing.message == "window not found: 42")
  }

  @Test("dispatch: rejects malformed grid arguments")
  func dispatchRejectsMalformedGridArguments() async {
    let handler = handler()
    let missing = await handler.dispatch(request(command: "--grid", args: []))
    let extra = await handler.dispatch(
      request(command: "--grid", args: ["1", "1:2:3:4:5:6", "extra"])
    )

    #expect(missing.ok == false)
    #expect(missing.errorCode == .invalidRequest)
    #expect(missing.message == "invalid window grid arguments")
    #expect(extra.ok == false)
    #expect(extra.errorCode == .invalidRequest)
    #expect(extra.message == "invalid window grid arguments")
  }

  @Test("dispatch: rejects invalid grid value")
  func dispatchRejectsInvalidGridValue() async {
    let handler = handler()
    let response = await handler.dispatch(request(command: "--grid", args: ["1:3:0:0:2:x"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "invalid window grid value: 1:3:0:0:2:x")
  }

  @Test("dispatch: rejects grid with invalid window selector")
  func dispatchRejectsGridWithInvalidWindowSelector() async {
    let handler = handler()
    let response = await handler.dispatch(
      request(command: "--grid", args: ["nope", "3:1:0:0:2:1"])
    )

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "invalid window selector: nope")
  }

  @Test("dispatch: rejects invalid automatic layout controls")
  func dispatchRejectsInvalidAutomaticLayoutControls() async {
    let handler = handler()
    let layout = await handler.dispatch(request(command: "--layout", args: ["stack"]))
    let ratio = await handler.dispatch(request(command: "--split-ratio", args: ["middle"]))
    let directionalSwap = await handler.dispatch(request(command: "--swap", args: ["sideways"]))
    let cycle = await handler.dispatch(request(command: "--cycle", args: ["sideways"]))
    let cycleSwap = await handler.dispatch(request(command: "--swap-cycle", args: ["sideways"]))
    let masterSwap = await handler.dispatch(
      request(command: "--swap-with-master", args: ["1", "extra"])
    )
    let masterFocus = await handler.dispatch(
      request(command: "--focus-master", args: ["1", "extra"])
    )

    #expect(layout.ok == false && layout.message == "invalid window layout: stack")
    #expect(ratio.ok == false && ratio.message == "invalid window split-ratio value: middle")
    #expect(
      directionalSwap.ok == false
        && directionalSwap.message == "invalid window swap direction: sideways"
    )
    #expect(cycle.ok == false && cycle.message == "invalid window cycle direction: sideways")
    #expect(
      cycleSwap.ok == false
        && cycleSwap.message == "invalid window swap-cycle direction: sideways"
    )
    #expect(
      masterSwap.ok == false
        && masterSwap.message == "invalid window swap-with-master arguments"
    )
    #expect(
      masterFocus.ok == false
        && masterFocus.message == "invalid window focus-master arguments"
    )
  }

  @Test("dispatch: rejects a selector for layout-order cycling")
  func dispatchRejectsCycleSelector() async {
    let response = await handler().dispatch(request(command: "--cycle", args: ["42", "next"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "invalid window cycle arguments")
  }

  @Test("dispatch: rejects a selector for layout-order swapping")
  func dispatchRejectsSwapCycleSelector() async {
    let response = await handler().dispatch(request(command: "--swap-cycle", args: ["42", "next"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "invalid window swap-cycle arguments")
  }

  private func request(command: String, args: [String]) -> IPCRequest {
    IPCRequest(id: "request-id", domain: .window, command: command, args: args)
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
