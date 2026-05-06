import Testing

@testable import SwmLib

@Suite("WindowCommandHandler")
struct WindowCommandHandlerTests {
  @Test("dispatch: rejects malformed single-target action arguments")
  func dispatchRejectsMalformedSingleTargetActionArguments() {
    let handler = handler()

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
    let handler = handler()

    for action in ["focus", "minimize", "unminimize"] {
      let response = handler.dispatch(request(command: "--\(action)", args: ["nope"]))

      #expect(response.ok == false)
      #expect(response.errorCode == .invalidRequest)
      #expect(response.message == "invalid window \(action) target: nope")
    }
  }

  @Test("dispatch: rejects missing recent single-target action target")
  func dispatchRejectsMissingRecentSingleTargetActionTarget() {
    let handler = handler()

    for action in ["focus", "minimize", "unminimize"] {
      let response = handler.dispatch(request(command: "--\(action)", args: ["recent"]))

      #expect(response.ok == false)
      #expect(response.errorCode == .invalidRequest)
      #expect(response.message == "no recent window")
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
      let extra = handler.dispatch(request(command: "--\(action)", args: ["abs:1:2", "extra"]))

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

  @Test("dispatch: rejects geometry action without focused window")
  func dispatchRejectsGeometryActionWithoutFocusedWindow() {
    let handler = handler()

    for action in ["move", "resize"] {
      let response = handler.dispatch(request(command: "--\(action)", args: ["abs:100:200"]))

      #expect(response.ok == false)
      #expect(response.errorCode == .invalidRequest)
      #expect(response.message == "no focused window")
    }
  }

  @Test("dispatch: rejects geometry action with invalid window selector")
  func dispatchRejectsGeometryActionWithInvalidWindowSelector() {
    let handler = handler()

    for action in ["move", "resize"] {
      let response = handler.dispatch(
        request(command: "--\(action)", args: ["--window", "nope", "rel:100:-200"])
      )

      #expect(response.ok == false)
      #expect(response.errorCode == .invalidRequest)
      #expect(response.message == "invalid window selector: nope")
    }
  }

  private func request(command: String, args: [String]) -> IPCRequest {
    IPCRequest(id: "request-id", domain: .window, command: command, args: args)
  }

  private func handler() -> WindowCommandHandler {
    WindowCommandHandler(
      windowManager: WindowManager(workspace: Workspace(), focusedWindowID: nil)
    )
  }
}
