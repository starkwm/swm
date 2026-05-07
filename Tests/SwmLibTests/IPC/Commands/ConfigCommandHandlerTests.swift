import Testing

@testable import SwmLib

@Suite("ConfigCommandHandler")
struct ConfigCommandHandlerTests {
  @Test("dispatch: window_gap sets gap for every space")
  func dispatchWindowGapSetsGapForEverySpace() {
    let manager = SpaceManager()
    let handler = ConfigCommandHandler(
      spaceManager: manager,
      spaces: {
        [
          Space(id: 1, type: .normal),
          Space(id: 2, type: .normal),
          Space(id: 3, type: .fullscreen),
        ]
      }
    )

    let response = handler.dispatch(request(command: "window_gap", args: ["12"]))

    #expect(response.ok)
    #expect(response.message == "ok")
    #expect(manager.settings(for: 1).gap == 12)
    #expect(manager.settings(for: 2).gap == 12)
    #expect(manager.settings(for: 3).gap == 12)
  }

  @Test("dispatch: window_gap clamps negative values")
  func dispatchWindowGapClampsNegativeValues() {
    let manager = SpaceManager()
    let handler = ConfigCommandHandler(
      spaceManager: manager,
      spaces: {
        [Space(id: 1, type: .normal)]
      }
    )

    let response = handler.dispatch(request(command: "window_gap", args: ["-4"]))

    #expect(response.ok)
    #expect(manager.settings(for: 1).gap == 0)
  }

  @Test("dispatch: rejects malformed window_gap arguments")
  func dispatchRejectsMalformedWindowGapArguments() {
    let handler = ConfigCommandHandler(spaceManager: SpaceManager(), spaces: { [] })
    let missing = handler.dispatch(request(command: "window_gap", args: []))
    let extra = handler.dispatch(request(command: "window_gap", args: ["10", "20"]))

    #expect(missing.ok == false)
    #expect(missing.errorCode == .invalidRequest)
    #expect(missing.message == "invalid config window_gap arguments")
    #expect(extra.ok == false)
    #expect(extra.errorCode == .invalidRequest)
    #expect(extra.message == "invalid config window_gap arguments")
  }

  @Test("dispatch: rejects invalid window_gap value")
  func dispatchRejectsInvalidWindowGapValue() {
    let handler = ConfigCommandHandler(spaceManager: SpaceManager(), spaces: { [] })
    let response = handler.dispatch(request(command: "window_gap", args: ["wide"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "invalid config window_gap value: wide")
  }

  @Test("dispatch: padding commands set one side for every space")
  func dispatchPaddingCommandsSetOneSideForEverySpace() {
    let manager = SpaceManager()
    let handler = ConfigCommandHandler(
      spaceManager: manager,
      spaces: {
        [
          Space(id: 1, type: .normal),
          Space(id: 2, type: .normal),
        ]
      }
    )

    _ = handler.dispatch(request(command: "top_padding", args: ["10"]))
    _ = handler.dispatch(request(command: "bottom_padding", args: ["20"]))
    _ = handler.dispatch(request(command: "left_padding", args: ["30"]))
    let response = handler.dispatch(request(command: "right_padding", args: ["40"]))

    #expect(response.ok)
    #expect(response.message == "ok")
    #expect(manager.settings(for: 1).padding == SpacePadding(top: 10, bottom: 20, left: 30, right: 40))
    #expect(manager.settings(for: 2).padding == SpacePadding(top: 10, bottom: 20, left: 30, right: 40))
  }

  @Test("dispatch: padding commands preserve other sides")
  func dispatchPaddingCommandsPreserveOtherSides() {
    let manager = SpaceManager()
    manager.setPadding(SpacePadding(top: 1, bottom: 2, left: 3, right: 4), for: 1)
    let handler = ConfigCommandHandler(
      spaceManager: manager,
      spaces: {
        [Space(id: 1, type: .normal)]
      }
    )

    let response = handler.dispatch(request(command: "left_padding", args: ["30"]))

    #expect(response.ok)
    #expect(manager.settings(for: 1).padding == SpacePadding(top: 1, bottom: 2, left: 30, right: 4))
  }

  @Test("dispatch: padding commands clamp negative values")
  func dispatchPaddingCommandsClampNegativeValues() {
    let manager = SpaceManager()
    manager.setPadding(SpacePadding(top: 1, bottom: 2, left: 3, right: 4), for: 1)
    let handler = ConfigCommandHandler(
      spaceManager: manager,
      spaces: {
        [Space(id: 1, type: .normal)]
      }
    )

    let response = handler.dispatch(request(command: "top_padding", args: ["-10"]))

    #expect(response.ok)
    #expect(manager.settings(for: 1).padding == SpacePadding(top: 0, bottom: 2, left: 3, right: 4))
  }

  @Test("dispatch: rejects malformed padding command arguments")
  func dispatchRejectsMalformedPaddingCommandArguments() {
    let handler = ConfigCommandHandler(spaceManager: SpaceManager(), spaces: { [] })
    let missing = handler.dispatch(request(command: "top_padding", args: []))
    let extra = handler.dispatch(request(command: "top_padding", args: ["10", "20"]))

    #expect(missing.ok == false)
    #expect(missing.errorCode == .invalidRequest)
    #expect(missing.message == "invalid config top_padding arguments")
    #expect(extra.ok == false)
    #expect(extra.errorCode == .invalidRequest)
    #expect(extra.message == "invalid config top_padding arguments")
  }

  @Test("dispatch: rejects invalid padding command value")
  func dispatchRejectsInvalidPaddingCommandValue() {
    let handler = ConfigCommandHandler(spaceManager: SpaceManager(), spaces: { [] })
    let response = handler.dispatch(request(command: "right_padding", args: ["wide"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "invalid config right_padding value: wide")
  }

  private func request(command: String, args: [String]) -> IPCRequest {
    IPCRequest(id: "request-id", domain: .config, command: command, args: args)
  }
}
