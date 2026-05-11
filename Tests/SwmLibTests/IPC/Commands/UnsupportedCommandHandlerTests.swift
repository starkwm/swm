import Testing

@testable import SwmLib

@Suite("Unsupported command handlers")
struct UnsupportedCommandHandlerTests {
  @Test("dispatch: config rejects unsupported commands")
  func dispatchConfigRejectsUnsupportedCommands() {
    let response = ConfigCommandHandler(spaceManager: SpaceManager()).dispatch(
      request(domain: .config, command: "set")
    )

    #expect(response.id == "request-id")
    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "unsupported config command: set")
  }

  @Test("dispatch: display rejects unsupported commands")
  func dispatchDisplayRejectsUnsupportedCommands() {
    let response = DisplayCommandHandler().dispatch(
      request(domain: .display, command: "focus")
    )

    #expect(response.id == "request-id")
    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "unsupported display command: focus")
  }

  @Test("dispatch: signal rejects unsupported commands")
  func dispatchSignalRejectsUnsupportedCommands() {
    let response = SignalCommandHandler().dispatch(
      request(domain: .signal, command: "add")
    )

    #expect(response.id == "request-id")
    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "unsupported signal command: add")
  }

  private func request(domain: MessageDomain, command: String) -> IPCRequest {
    IPCRequest(id: "request-id", domain: domain, command: command, args: [])
  }
}
