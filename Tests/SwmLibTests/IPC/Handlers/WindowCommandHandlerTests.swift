import Testing

@testable import SwmLib

@Suite("WindowCommandHandler")
struct WindowCommandHandlerTests {
  @Test("dispatch: rejects malformed single-target action arguments")
  func dispatchRejectsMalformedSingleTargetActionArguments() {
    let handler = WindowCommandHandler(windowManager: WindowManager(workspace: Workspace()))

    for action in ["focus", "minimize", "unminimize"] {
      let missing = handler.dispatch(request(command: "--\(action)", args: []))
      let extra = handler.dispatch(request(command: "--\(action)", args: ["1", "2"]))

      #expect(missing.ok == false)
      #expect(missing.errorCode == .invalidRequest)
      #expect(missing.message == "invalid window \(action) arguments")
      #expect(extra.ok == false)
      #expect(extra.errorCode == .invalidRequest)
      #expect(extra.message == "invalid window \(action) arguments")
    }
  }

  @Test("dispatch: rejects invalid single-target action target")
  func dispatchRejectsInvalidSingleTargetActionTarget() {
    let handler = WindowCommandHandler(windowManager: WindowManager(workspace: Workspace()))

    for action in ["focus", "minimize", "unminimize"] {
      let response = handler.dispatch(request(command: "--\(action)", args: ["nope"]))

      #expect(response.ok == false)
      #expect(response.errorCode == .invalidRequest)
      #expect(response.message == "invalid window \(action) target: nope")
    }
  }

  @Test("dispatch: rejects missing recent single-target action target")
  func dispatchRejectsMissingRecentSingleTargetActionTarget() {
    let handler = WindowCommandHandler(windowManager: WindowManager(workspace: Workspace()))

    for action in ["focus", "minimize", "unminimize"] {
      let response = handler.dispatch(request(command: "--\(action)", args: ["recent"]))

      #expect(response.ok == false)
      #expect(response.errorCode == .invalidRequest)
      #expect(response.message == "no recent window")
    }
  }

  @Test("dispatch: rejects missing numeric single-target action target")
  func dispatchRejectsMissingNumericSingleTargetActionTarget() {
    let handler = WindowCommandHandler(windowManager: WindowManager(workspace: Workspace()))

    for action in ["focus", "minimize", "unminimize"] {
      let response = handler.dispatch(request(command: "--\(action)", args: ["42"]))

      #expect(response.ok == false)
      #expect(response.errorCode == .invalidRequest)
      #expect(response.message == "window not found: 42")
    }
  }

  @Test("dispatch: rejects malformed move arguments")
  func dispatchRejectsMalformedMoveArguments() {
    let handler = WindowCommandHandler(windowManager: WindowManager(workspace: Workspace()))

    let missing = handler.dispatch(request(command: "--move", args: []))
    let extra = handler.dispatch(request(command: "--move", args: ["abs:1:2", "extra"]))

    #expect(missing.ok == false)
    #expect(missing.errorCode == .invalidRequest)
    #expect(missing.message == "invalid window move arguments")
    #expect(extra.ok == false)
    #expect(extra.errorCode == .invalidRequest)
    #expect(extra.message == "invalid window move arguments")
  }

  @Test("dispatch: rejects invalid move value")
  func dispatchRejectsInvalidMoveValue() {
    let handler = WindowCommandHandler(windowManager: WindowManager(workspace: Workspace()))

    let response = handler.dispatch(request(command: "--move", args: ["rel:100:x"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "invalid window move value: rel:100:x")
  }

  @Test("dispatch: rejects move without focused window")
  func dispatchRejectsMoveWithoutFocusedWindow() {
    let handler = WindowCommandHandler(windowManager: WindowManager(workspace: Workspace()))

    let response = handler.dispatch(request(command: "--move", args: ["abs:100:200"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "no focused window")
  }

  @Test("dispatch: rejects move with invalid window selector")
  func dispatchRejectsMoveWithInvalidWindowSelector() {
    let handler = WindowCommandHandler(windowManager: WindowManager(workspace: Workspace()))

    let response = handler.dispatch(
      request(command: "--move", args: ["--window", "nope", "rel:100:-200"])
    )

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "invalid window selector: nope")
  }

  private func request(command: String, args: [String]) -> IPCRequest {
    IPCRequest(id: "request-id", domain: .window, command: command, args: args)
  }
}
