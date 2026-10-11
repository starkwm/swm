import Testing

@testable import SwmLib

@MainActor
@Suite("DisplayCommandHandler")
struct DisplayCommandHandlerTests {
  @Test("dispatch: display rejects unsupported commands")
  func dispatchDisplayRejectsUnsupportedCommands() {
    let response = DisplayCommandHandler().dispatch(
      IPCRequest(id: "request-id", domain: .display, command: "focus", args: [])
    )

    #expect(response.id == "request-id")
    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "unsupported display command: focus")
  }
}
