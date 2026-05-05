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
