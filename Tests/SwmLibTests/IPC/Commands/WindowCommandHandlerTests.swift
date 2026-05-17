import Testing

@testable import SwmLib

@Suite("WindowCommandHandler")
struct WindowCommandHandlerTests {
  @Test("dispatch: rejects malformed single-target action arguments")
  func dispatchRejectsMalformedSingleTargetActionArguments() {
    let handler = handler()

    for action in ["focus", "minimize", "unminimize"] {
      let extra = handler.dispatch(request(command: "--\(action)", args: ["1", "2"]))

      #expect(extra.ok == false)
      #expect(extra.errorCode == .invalidRequest)
      #expect(extra.message == "invalid window \(action) arguments")
    }
  }

  @Test("dispatch: rejects invalid single-target action target")
  func dispatchRejectsInvalidSingleTargetActionTarget() {
    let handler = handler()

    for action in ["focus", "minimize", "unminimize"] {
      let response = handler.dispatch(request(command: "--\(action)", args: ["nope"]))

      #expect(response.ok == false)
      #expect(response.errorCode == .invalidRequest)
      #expect(response.message == "invalid window selector: nope")
    }
  }

  @Test("dispatch: rejects missing numeric single-target action target")
  func dispatchRejectsMissingNumericSingleTargetActionTarget() {
    let handler = handler()

    for action in ["focus", "minimize", "unminimize"] {
      let response = handler.dispatch(request(command: "--\(action)", args: ["42"]))

      #expect(response.ok == false)
      #expect(response.errorCode == .invalidRequest)
      #expect(response.message == "window not found: 42")
    }
  }

  @Test("dispatch: rejects malformed geometry action arguments")
  func dispatchRejectsMalformedGeometryActionArguments() {
    let handler = handler()

    for action in ["move", "resize"] {
      let missing = handler.dispatch(request(command: "--\(action)", args: []))
      let extra = handler.dispatch(
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
  func dispatchRejectsInvalidGeometryActionValue() {
    let handler = handler()

    for action in ["move", "resize"] {
      let response = handler.dispatch(request(command: "--\(action)", args: ["rel:100:x"]))

      #expect(response.ok == false)
      #expect(response.errorCode == .invalidRequest)
      #expect(response.message == "invalid window \(action) value: rel:100:x")
    }
  }

  @Test("dispatch: rejects geometry action with invalid window selector")
  func dispatchRejectsGeometryActionWithInvalidWindowSelector() {
    let handler = handler()

    for action in ["move", "resize"] {
      let response = handler.dispatch(
        request(command: "--\(action)", args: ["nope", "rel:100:-200"])
      )

      #expect(response.ok == false)
      #expect(response.errorCode == .invalidRequest)
      #expect(response.message == "invalid window selector: nope")
    }
  }

  @Test("dispatch: rejects malformed display arguments")
  func dispatchRejectsMalformedDisplayArguments() {
    let handler = handler()
    let missing = handler.dispatch(request(command: "--display", args: []))
    let extra = handler.dispatch(request(command: "--display", args: ["1", "next", "extra"]))

    #expect(missing.ok == false)
    #expect(missing.errorCode == .invalidRequest)
    #expect(missing.message == "invalid window display arguments")
    #expect(extra.ok == false)
    #expect(extra.errorCode == .invalidRequest)
    #expect(extra.message == "invalid window display arguments")
  }

  @Test("dispatch: rejects invalid display value")
  func dispatchRejectsInvalidDisplayValue() {
    let handler = handler()
    let response = handler.dispatch(request(command: "--display", args: ["sideways"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "invalid window display value: sideways")
  }

  @Test("dispatch: rejects malformed grid arguments")
  func dispatchRejectsMalformedGridArguments() {
    let handler = handler()
    let missing = handler.dispatch(request(command: "--grid", args: []))
    let extra = handler.dispatch(request(command: "--grid", args: ["1", "1:2:3:4:5:6", "extra"]))

    #expect(missing.ok == false)
    #expect(missing.errorCode == .invalidRequest)
    #expect(missing.message == "invalid window grid arguments")
    #expect(extra.ok == false)
    #expect(extra.errorCode == .invalidRequest)
    #expect(extra.message == "invalid window grid arguments")
  }

  @Test("dispatch: rejects invalid grid value")
  func dispatchRejectsInvalidGridValue() {
    let handler = handler()
    let response = handler.dispatch(request(command: "--grid", args: ["1:3:0:0:2:x"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "invalid window grid value: 1:3:0:0:2:x")
  }

  @Test("dispatch: rejects grid with invalid window selector")
  func dispatchRejectsGridWithInvalidWindowSelector() {
    let handler = handler()
    let response = handler.dispatch(request(command: "--grid", args: ["nope", "3:1:0:0:2:1"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "invalid window selector: nope")
  }

  private func request(command: String, args: [String]) -> IPCRequest {
    IPCRequest(id: "request-id", domain: .window, command: command, args: args)
  }

  private func handler(
    windowManager: WindowManager = WindowManager(workspace: Workspace())
  ) -> WindowCommandHandler {
    WindowCommandHandler(
      windowManager: windowManager,
      spaceManager: SpaceManager(activeSpaceID: nil)
    )
  }
}

@Suite("WindowDisplayTarget")
struct WindowDisplayTargetTests {
  @Test("init: accepts relative and indexed targets")
  func initAcceptsRelativeAndIndexedTargets() {
    #expect(WindowDisplayTarget(argument: "next") != nil)
    #expect(WindowDisplayTarget(argument: "prev") != nil)
    #expect(WindowDisplayTarget(argument: "previous") != nil)
    #expect(WindowDisplayTarget(argument: "1") != nil)
  }

  @Test("init: rejects invalid targets")
  func initRejectsInvalidTargets() {
    #expect(WindowDisplayTarget(argument: "primary") == nil)
    #expect(WindowDisplayTarget(argument: "secondary") == nil)
    #expect(WindowDisplayTarget(argument: "recent") == nil)
    #expect(WindowDisplayTarget(argument: "0") == nil)
    #expect(WindowDisplayTarget(argument: "-1") == nil)
    #expect(WindowDisplayTarget(argument: "x") == nil)
  }
}
