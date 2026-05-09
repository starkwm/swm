import Testing

@testable import SwmLib

@Suite("ConfigCommandHandler")
struct ConfigCommandHandlerTests {
  @Test("dispatch: rejects malformed window-gap arguments")
  func dispatchRejectsMalformedWindowGapArguments() {
    let handler = ConfigCommandHandler(spaceManager: SpaceManager(activeSpaceID: nil))
    let missing = handler.dispatch(request(command: "window-gap", args: []))
    let extra = handler.dispatch(request(command: "window-gap", args: ["10", "20"]))

    #expect(missing.ok == false)
    #expect(missing.errorCode == .invalidRequest)
    #expect(missing.message == "invalid config window-gap arguments")
    #expect(extra.ok == false)
    #expect(extra.errorCode == .invalidRequest)
    #expect(extra.message == "invalid config window-gap arguments")
  }

  @Test("dispatch: rejects invalid window-gap value")
  func dispatchRejectsInvalidWindowGapValue() {
    let handler = ConfigCommandHandler(spaceManager: SpaceManager(activeSpaceID: nil))
    let response = handler.dispatch(request(command: "window-gap", args: ["wide"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "invalid config window-gap value: wide")
  }

  @Test("dispatch: rejects malformed padding command arguments")
  func dispatchRejectsMalformedPaddingCommandArguments() {
    let handler = ConfigCommandHandler(spaceManager: SpaceManager(activeSpaceID: nil))
    let missing = handler.dispatch(request(command: "top-padding", args: []))
    let extra = handler.dispatch(request(command: "top-padding", args: ["10", "20"]))

    #expect(missing.ok == false)
    #expect(missing.errorCode == .invalidRequest)
    #expect(missing.message == "invalid config top-padding arguments")
    #expect(extra.ok == false)
    #expect(extra.errorCode == .invalidRequest)
    #expect(extra.message == "invalid config top-padding arguments")
  }

  @Test("dispatch: rejects invalid padding command value")
  func dispatchRejectsInvalidPaddingCommandValue() {
    let handler = ConfigCommandHandler(spaceManager: SpaceManager(activeSpaceID: nil))
    let response = handler.dispatch(request(command: "right-padding", args: ["wide"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "invalid config right-padding value: wide")
  }

  private func request(command: String, args: [String]) -> IPCRequest {
    IPCRequest(id: "request-id", domain: .config, command: command, args: args)
  }
}
