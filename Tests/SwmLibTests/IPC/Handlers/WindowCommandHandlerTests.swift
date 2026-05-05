import Testing

@testable import SwmLib

@Suite("WindowCommandHandler")
struct WindowCommandHandlerTests {
  @Test("dispatch: rejects recent focus target as unimplemented")
  func dispatchRejectsRecentFocusTargetAsUnimplemented() {
    let manager = WindowManager(workspace: Workspace())
    manager.focusedWindowDidChange(to: 1)
    manager.focusedWindowDidChange(to: 2)
    let handler = WindowCommandHandler(windowManager: manager)

    let response = handler.dispatch(request(command: "--focus", args: ["recent"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "window focus is not implemented")
  }

  @Test("dispatch: rejects window ID focus target as unimplemented")
  func dispatchRejectsWindowIDFocusTargetAsUnimplemented() {
    let manager = WindowManager(workspace: Workspace())
    manager.addKnownWindowID(42)
    let handler = WindowCommandHandler(windowManager: manager)

    let response = handler.dispatch(request(command: "--focus", args: ["42"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "window focus is not implemented")
  }

  @Test("dispatch: rejects malformed focus arguments")
  func dispatchRejectsMalformedFocusArguments() {
    let manager = WindowManager(workspace: Workspace())
    let handler = WindowCommandHandler(windowManager: manager)

    let responses = [
      handler.dispatch(request(command: "--focus", args: [])),
      handler.dispatch(request(command: "--focus", args: ["1", "extra"])),
      handler.dispatch(request(command: "--focus", args: ["unknown"])),
      handler.dispatch(request(command: "--focus", args: ["0"])),
      handler.dispatch(request(command: "--focus", args: ["-1"])),
      handler.dispatch(request(command: "--focus", args: ["42"])),
      handler.dispatch(request(command: "--focus", args: ["recent"])),
    ]

    #expect(responses.allSatisfy { !$0.ok && $0.errorCode == .invalidRequest })
  }

  @Test("dispatch: rejects move commands as unimplemented")
  func dispatchRejectsMoveCommandsAsUnimplemented() {
    let manager = WindowManager(workspace: Workspace())
    manager.focusedWindowDidChange(to: 42)
    let handler = WindowCommandHandler(windowManager: manager)

    let absolute = handler.dispatch(request(command: "--move", args: ["abs:100:200"]))
    let relative = handler.dispatch(request(command: "--move", args: ["rel:100:-200"]))

    #expect([absolute, relative].allSatisfy {
      !$0.ok && $0.errorCode == .unsupportedCommand
        && $0.message == "window move is not implemented"
    })
  }

  @Test("dispatch: rejects selected window move commands as unimplemented")
  func dispatchRejectsSelectedWindowMoveCommandsAsUnimplemented() {
    let manager = WindowManager(workspace: Workspace())
    manager.focusedWindowDidChange(to: 41)
    manager.focusedWindowDidChange(to: 42)
    let handler = WindowCommandHandler(windowManager: manager)

    let response = handler.dispatch(
      request(command: "--move", args: ["--window", "recent", "abs:100:200"])
    )

    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "window move is not implemented")
  }

  @Test("dispatch: rejects resize commands as unimplemented")
  func dispatchRejectsResizeCommandsAsUnimplemented() {
    let manager = WindowManager(workspace: Workspace())
    manager.focusedWindowDidChange(to: 42)
    let handler = WindowCommandHandler(windowManager: manager)

    let absolute = handler.dispatch(request(command: "--resize", args: ["abs:500:800"]))
    let relative = handler.dispatch(request(command: "--resize", args: ["rel:50:-80"]))

    #expect([absolute, relative].allSatisfy {
      !$0.ok && $0.errorCode == .unsupportedCommand
        && $0.message == "window resize is not implemented"
    })
  }

  @Test("dispatch: rejects selected window resize commands as unimplemented")
  func dispatchRejectsSelectedWindowResizeCommandsAsUnimplemented() {
    let manager = WindowManager(workspace: Workspace())
    manager.focusedWindowDidChange(to: 41)
    manager.addKnownWindowID(100)
    let handler = WindowCommandHandler(windowManager: manager)

    let response = handler.dispatch(
      request(command: "--resize", args: ["--window", "100", "abs:500:800"])
    )

    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "window resize is not implemented")
  }

  @Test("dispatch: rejects malformed move and resize arguments")
  func dispatchRejectsMalformedMoveAndResizeArguments() {
    let manager = WindowManager(workspace: Workspace())
    manager.focusedWindowDidChange(to: 42)
    let handler = WindowCommandHandler(windowManager: manager)

    let responses = [
      handler.dispatch(request(command: "--move", args: [])),
      handler.dispatch(request(command: "--move", args: ["abs:100"])),
      handler.dispatch(request(command: "--move", args: ["abs:100:x"])),
      handler.dispatch(request(command: "--move", args: ["set:100:200"])),
      handler.dispatch(request(command: "--move", args: ["rel:100:200", "extra"])),
      handler.dispatch(request(command: "--resize", args: [])),
      handler.dispatch(request(command: "--resize", args: ["abs:500"])),
      handler.dispatch(request(command: "--resize", args: ["abs:500:x"])),
      handler.dispatch(request(command: "--resize", args: ["set:500:800"])),
      handler.dispatch(request(command: "--resize", args: ["rel:500:800", "extra"])),
      handler.dispatch(request(command: "--move", args: ["--window", "missing", "abs:100:200"])),
      handler.dispatch(request(command: "--move", args: ["--window", "0", "abs:100:200"])),
      handler.dispatch(request(command: "--move", args: ["--window", "100", "abs:100:200"])),
      WindowCommandHandler(windowManager: WindowManager(workspace: Workspace()))
        .dispatch(request(command: "--move", args: ["abs:100:200"])),
      WindowCommandHandler(windowManager: WindowManager(workspace: Workspace()))
        .dispatch(request(command: "--resize", args: ["abs:500:800"])),
      WindowCommandHandler(windowManager: WindowManager(workspace: Workspace()))
        .dispatch(request(command: "--resize", args: ["--window", "recent", "abs:500:800"])),
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

  private func request(command: String, args: [String]) -> IPCRequest {
    IPCRequest(id: "request-id", domain: .window, command: command, args: args)
  }
}
