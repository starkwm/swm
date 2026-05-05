import Testing

@testable import SwmLib

@Suite("WindowCommandHandler")
struct WindowCommandHandlerTests {
  @Test("dispatch: accepts recent focus target")
  func dispatchAcceptsRecentFocusTarget() {
    let manager = WindowManager(workspace: Workspace())
    manager.focusedWindowDidChange(to: 1)
    manager.focusedWindowDidChange(to: 2)
    let handler = WindowCommandHandler(windowManager: manager)

    let response = handler.dispatch(request(args: ["recent"]))

    #expect(response.ok)
    #expect(response.message == "focused window: 1")
    #expect(manager.lastFocusWindowRequest == FocusWindowRequest(id: 1, source: "recent"))
  }

  @Test("dispatch: accepts window ID focus target")
  func dispatchAcceptsWindowIDFocusTarget() {
    let manager = WindowManager(workspace: Workspace())
    manager.addKnownWindowID(42)
    let handler = WindowCommandHandler(windowManager: manager)

    let response = handler.dispatch(request(args: ["42"]))

    #expect(response.ok)
    #expect(response.message == "focused window: 42")
    #expect(manager.lastFocusWindowRequest == FocusWindowRequest(id: 42, source: "42"))
  }

  @Test("dispatch: rejects malformed focus arguments")
  func dispatchRejectsMalformedFocusArguments() {
    let manager = WindowManager(workspace: Workspace())
    let handler = WindowCommandHandler(windowManager: manager)

    let responses = [
      handler.dispatch(request(args: [])),
      handler.dispatch(request(args: ["1", "extra"])),
      handler.dispatch(request(args: ["unknown"])),
      handler.dispatch(request(args: ["0"])),
      handler.dispatch(request(args: ["-1"])),
      handler.dispatch(request(args: ["42"])),
      handler.dispatch(request(args: ["recent"])),
    ]

    #expect(responses.allSatisfy { !$0.ok && $0.errorCode == .invalidRequest })
  }

  @Test("dispatch: rejects unsupported window commands")
  func dispatchRejectsUnsupportedWindowCommands() {
    let response = WindowCommandHandler(windowManager: WindowManager(workspace: Workspace()))
      .dispatch(IPCRequest(id: "request-id", domain: .window, command: "--unknown", args: []))

    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "unsupported window command: --unknown")
  }

  private func request(args: [String]) -> IPCRequest {
    IPCRequest(id: "request-id", domain: .window, command: "--focus", args: args)
  }
}
