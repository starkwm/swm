import Testing

@testable import SwmLib

@Suite("IPCCommandDispatcher")
struct IPCCommandDispatcherTests {
  @Test("dispatch: returns unsupported command for unsupported domains")
  func dispatchReturnsUnsupportedCommandForUnsupportedDomains() {
    let dispatcher = IPCCommandDispatcher(
      spaceManager: SpaceManager(activeSpaceIDResolver: { nil })
    )
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

    #expect(response.ok)
    #expect(windowManager.lastFocusWindowRequest == FocusWindowRequest(id: 42, source: "42"))
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

    #expect(response.ok)
    #expect(
      windowManager.lastMoveWindowRequest
        == MoveWindowRequest(id: 42, mode: .absolute, x: 100, y: 200)
    )
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

    #expect(response.ok)
    #expect(
      windowManager.lastResizeWindowRequest
        == ResizeWindowRequest(id: 100, mode: .absolute, width: 500, height: 800)
    )
  }

  @Test("dispatch: dispatches space commands")
  func dispatchDispatchesSpaceCommands() {
    let spaceManager = SpaceManager(activeSpaceIDResolver: { nil })
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

  @Test("dispatch: dispatches space focus commands")
  func dispatchDispatchesSpaceFocusCommands() {
    let activeSpaceIDResolver = ActiveSpaceIDSequence([1, 2])
    let spaceManager = SpaceManager(activeSpaceIDResolver: activeSpaceIDResolver.next)
    spaceManager.activeSpaceDidChange()
    let dispatcher = IPCCommandDispatcher(spaceManager: spaceManager, activeSpaceID: { 2 })
    let request = IPCRequest(
      id: "request-id",
      domain: .space,
      command: "--focus",
      args: ["recent"]
    )

    let response = dispatcher.dispatch(request)

    #expect(response.ok)
    #expect(
      spaceManager.lastFocusSpaceRequest
        == FocusSpaceRequest(id: 1, index: nil, source: "recent")
    )
  }

  @Test("dispatch: dispatches display commands")
  func dispatchDispatchesDisplayCommands() {
    let displayIDResolver = ActiveDisplayIDSequence(["display-0", "display-1"])
    let displayManager = DisplayManager(activeDisplayIDResolver: displayIDResolver.next)
    displayManager.activeDisplayDidChange()
    let dispatcher = IPCCommandDispatcher(displayManager: displayManager)
    let request = IPCRequest(
      id: "request-id",
      domain: .display,
      command: "--focus",
      args: ["recent"]
    )

    let response = dispatcher.dispatch(request)

    #expect(response.ok)
    #expect(
      displayManager.lastFocusDisplayRequest
        == FocusDisplayRequest(
          id: "display-0",
          index: nil,
          source: "recent"
        )
    )
  }
}

private final class ActiveDisplayIDSequence: @unchecked Sendable {
  private var values: [String?]

  init(_ values: [String?]) {
    self.values = values
  }

  func next() -> String? {
    guard !values.isEmpty else { return nil }

    return values.removeFirst()
  }
}

private final class ActiveSpaceIDSequence: @unchecked Sendable {
  private var values: [UInt64?]

  init(_ values: [UInt64?]) {
    self.values = values
  }

  func next() -> UInt64? {
    guard !values.isEmpty else { return nil }

    return values.removeFirst()
  }
}
