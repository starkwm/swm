import Testing

@testable import SwmLib

@Suite("IPCCommandDispatcher")
struct IPCCommandDispatcherTests {
  @Test("dispatch: returns unsupported command for unsupported domains")
  func dispatchReturnsUnsupportedCommandForUnsupportedDomains() {
    let dispatcher = IPCCommandDispatcher(spaceManager: SpaceManager())
    let request = IPCRequest(
      id: "request-id",
      domain: .window,
      command: "focus",
      args: []
    )

    let response = dispatcher.dispatch(request)

    #expect(response.id == "request-id")
    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "unsupported window command: focus")
  }

  @Test("dispatch: dispatches window commands")
  func dispatchDispatchesWindowCommands() {
    let windowManager = WindowManager(workspace: Workspace())
    windowManager.addKnownWindowID(42)
    let dispatcher = IPCCommandDispatcher(windowManager: windowManager)
    let request = IPCRequest(
      id: "request-id",
      domain: .window,
      command: "--focus",
      args: ["42"]
    )

    let response = dispatcher.dispatch(request)

    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "window focus is not implemented")
  }

  @Test("dispatch: dispatches window move commands")
  func dispatchDispatchesWindowMoveCommands() {
    let windowManager = WindowManager(workspace: Workspace())
    windowManager.focusedWindowDidChange(to: 42)
    let dispatcher = IPCCommandDispatcher(windowManager: windowManager)
    let request = IPCRequest(
      id: "request-id",
      domain: .window,
      command: "--move",
      args: ["abs:100:200"]
    )

    let response = dispatcher.dispatch(request)

    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "window move is not implemented")
  }

  @Test("dispatch: dispatches selected window resize commands")
  func dispatchDispatchesSelectedWindowResizeCommands() {
    let windowManager = WindowManager(workspace: Workspace())
    windowManager.addKnownWindowID(100)
    let dispatcher = IPCCommandDispatcher(windowManager: windowManager)
    let request = IPCRequest(
      id: "request-id",
      domain: .window,
      command: "--resize",
      args: ["--window", "100", "abs:500:800"]
    )

    let response = dispatcher.dispatch(request)

    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "window resize is not implemented")
  }

  @Test("dispatch: dispatches space commands")
  func dispatchDispatchesSpaceCommands() {
    let spaceManager = SpaceManager()
    let dispatcher = IPCCommandDispatcher(
      spaceManager: spaceManager,
      activeSpaceID: { 42 }
    )
    let request = IPCRequest(
      id: "request-id",
      domain: .space,
      command: "--gap",
      args: ["abs:10"]
    )

    let response = dispatcher.dispatch(request)

    #expect(response.id == "request-id")
    #expect(response.ok)
    #expect(spaceManager.settings(for: 42).gap == 10)
  }

}
