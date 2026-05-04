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
}
