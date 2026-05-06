import CoreGraphics
import Testing

@testable import SwmLib

@Suite("WindowCommandHandler")
struct WindowCommandHandlerTests {
  @Test("dispatch: rejects malformed focus arguments")
  func dispatchRejectsMalformedFocusArguments() {
    let handler = WindowCommandHandler(windowManager: WindowManager(workspace: Workspace()))

    let missing = handler.dispatch(request(command: "--focus", args: []))
    let extra = handler.dispatch(request(command: "--focus", args: ["1", "2"]))

    #expect(missing.ok == false)
    #expect(missing.errorCode == .invalidRequest)
    #expect(missing.message == "invalid window focus arguments")
    #expect(extra.ok == false)
    #expect(extra.errorCode == .invalidRequest)
    #expect(extra.message == "invalid window focus arguments")
  }

  @Test("dispatch: rejects invalid focus target")
  func dispatchRejectsInvalidFocusTarget() {
    let handler = WindowCommandHandler(windowManager: WindowManager(workspace: Workspace()))

    let response = handler.dispatch(request(command: "--focus", args: ["nope"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "invalid window focus target: nope")
  }

  @Test("dispatch: rejects missing recent focus target")
  func dispatchRejectsMissingRecentFocusTarget() {
    let handler = WindowCommandHandler(windowManager: WindowManager(workspace: Workspace()))

    let response = handler.dispatch(request(command: "--focus", args: ["recent"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "no recent window")
  }

  @Test("dispatch: rejects missing numeric window target")
  func dispatchRejectsMissingNumericWindowTarget() {
    let handler = WindowCommandHandler(windowManager: WindowManager(workspace: Workspace()))

    let response = handler.dispatch(request(command: "--focus", args: ["42"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "window not found: 42")
  }

  private func request(command: String, args: [String]) -> IPCRequest {
    IPCRequest(id: "request-id", domain: .window, command: command, args: args)
  }
}
