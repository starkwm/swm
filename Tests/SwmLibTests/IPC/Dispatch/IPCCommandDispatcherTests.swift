import Testing

@testable import SwmLib

@Suite("IPCCommandDispatcher")
struct IPCCommandDispatcherTests {
  @Test("dispatch: returns unsupported command for unsupported domains")
  func dispatchReturnsUnsupportedCommandForUnsupportedDomains() {
    let dispatcher = IPCCommandDispatcher()
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
}
