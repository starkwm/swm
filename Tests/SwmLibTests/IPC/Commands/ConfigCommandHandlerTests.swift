import Testing

@testable import SwmLib

@MainActor
@Suite("ConfigCommandHandler")
struct ConfigCommandHandlerTests {
  @Test("dispatch: window gap updates defaults and overrides")
  func dispatchWindowGapUpdatesDefaultsAndOverrides() {
    let manager = SpaceManager(activeSpaceID: nil)
    manager.setGap(5, for: 1)
    let handler = handler(spaceManager: manager)

    let response = handler.dispatch(request(command: "window-gap", args: ["12"]))

    #expect(response.ok)
    #expect(manager.settings(for: 1).gap == 12)
    #expect(manager.settings(for: 2).gap == 12)
  }

  @Test("dispatch: padding updates defaults and preserves other override sides")
  func dispatchPaddingUpdatesDefaultsAndPreservesOtherOverrideSides() {
    let manager = SpaceManager(activeSpaceID: nil)
    manager.setPadding(
      SpacePadding(top: 1, bottom: 2, left: 3, right: 4),
      for: 1
    )
    let handler = handler(spaceManager: manager)

    let response = handler.dispatch(request(command: "top-padding", args: ["10"]))

    #expect(response.ok)
    #expect(manager.settings(for: 1).padding == SpacePadding(top: 10, bottom: 2, left: 3, right: 4))
    #expect(manager.settings(for: 2).padding == SpacePadding(top: 10, bottom: 0, left: 0, right: 0))
  }

  @Test("dispatch: rejects malformed window-gap arguments")
  func dispatchRejectsMalformedWindowGapArguments() {
    let handler = handler(spaceManager: SpaceManager(activeSpaceID: nil))
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
    let handler = handler(spaceManager: SpaceManager(activeSpaceID: nil))
    let response = handler.dispatch(request(command: "window-gap", args: ["wide"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "invalid config window-gap value: wide")
  }

  @Test("dispatch: rejects malformed padding command arguments")
  func dispatchRejectsMalformedPaddingCommandArguments() {
    let handler = handler(spaceManager: SpaceManager(activeSpaceID: nil))
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
    let handler = handler(spaceManager: SpaceManager(activeSpaceID: nil))
    let response = handler.dispatch(request(command: "right-padding", args: ["wide"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "invalid config right-padding value: wide")
  }

  private func request(command: String, args: [String]) -> IPCRequest {
    IPCRequest(id: "request-id", domain: .config, command: command, args: args)
  }

  private func handler(spaceManager: SpaceManager) -> ConfigCommandHandler {
    ConfigCommandHandler(
      spaceManager: spaceManager,
      tilingManager: makeTestTilingManager(spaceManager: spaceManager)
    )
  }
}
