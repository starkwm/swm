import Testing

@testable import SwmLib

@Suite("Unsupported command handlers")
struct UnsupportedCommandHandlerTests {
  @Test("dispatch: config rejects unsupported commands")
  func dispatchConfigRejectsUnsupportedCommands() {
    let response = ConfigCommandHandler().dispatch(
      request(domain: .config, command: "set")
    )

    #expect(response.id == "request-id")
    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "unsupported config command: set")
  }

  @Test("dispatch: display rejects unsupported commands")
  func dispatchDisplayRejectsUnsupportedCommands() {
    let response = DisplayCommandHandler(displayManager: DisplayManager()).dispatch(
      request(domain: .display, command: "focus")
    )

    #expect(response.id == "request-id")
    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "unsupported display command: focus")
  }

  private func request(domain: MessageDomain, command: String) -> IPCRequest {
    IPCRequest(id: "request-id", domain: domain, command: command, args: [])
  }
}
