import CoreGraphics
import Testing

@testable import SwmLib

@MainActor
@Suite("ConfigCommandHandler")
struct ConfigCommandHandlerTests {
  @Test("dispatch: layout updates current and future Spaces")
  func dispatchLayoutUpdatesCurrentAndFutureSpaces() {
    let spaceManager = SpaceManager(activeSpaceID: nil)
    var spaceIDs = Set([UInt64(10), UInt64(11)])
    let tilingManager = TilingManager(
      snapshot: {
        TilingReconciliationSnapshot(
          windows: [],
          topology: SpaceTopology(
            spacesByID: Dictionary(
              uniqueKeysWithValues: spaceIDs.map {
                ($0, SpaceTopologyDescriptor(id: $0, displayID: "display", type: .normal))
              }
            ),
            visibleSpaceIDByDisplayID: ["display": 10],
            spaceIDsByWindowID: [:],
            displaysByID: [
              "display": SpaceTopologyDisplay(
                visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
              )
            ]
          )
        )
      },
      spaceManager: spaceManager
    )
    tilingManager.start()
    let handler = ConfigCommandHandler(
      spaceManager: spaceManager,
      tilingManager: tilingManager
    )

    let dwindle = handler.dispatch(request(command: "layout", args: ["dwindle"]))

    #expect(dwindle.ok)
    #expect(dwindle.message == "dwindle")
    #expect(tilingManager.layoutPlan(for: layoutID(10)) == .layout(.frames([:])))
    #expect(tilingManager.layoutPlan(for: layoutID(11)) == .notVisible)

    spaceIDs.insert(12)
    tilingManager.reconcile()

    #expect(tilingManager.layoutPlan(for: layoutID(12)) == .notVisible)

    let float = handler.dispatch(request(command: "layout", args: ["float"]))

    #expect(float.ok)
    #expect(float.message == "float")
    #expect(tilingManager.layoutPlan(for: layoutID(10)) == .disabled)
    #expect(tilingManager.layoutPlan(for: layoutID(11)) == .disabled)
    #expect(tilingManager.layoutPlan(for: layoutID(12)) == .disabled)

    spaceIDs.insert(13)
    tilingManager.reconcile()

    #expect(tilingManager.layoutPlan(for: layoutID(13)) == .disabled)

    let master = handler.dispatch(request(command: "layout", args: ["master"]))

    #expect(master.ok)
    #expect(master.message == "master")
    #expect(tilingManager.layoutPlan(for: layoutID(10)) == .layout(.frames([:])))
    #expect(tilingManager.layoutPlan(for: layoutID(11)) == .notVisible)
    #expect(tilingManager.layoutPlan(for: layoutID(12)) == .notVisible)
    #expect(tilingManager.layoutPlan(for: layoutID(13)) == .notVisible)
  }

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

  @Test("dispatch: accepts layout controls")
  func dispatchAcceptsLayoutControls() {
    let handler = handler(spaceManager: SpaceManager(activeSpaceID: nil))

    let ratio = handler.dispatch(request(command: "master-ratio", args: ["0.65"]))
    let placement = handler.dispatch(request(command: "master-placement", args: ["top"]))
    let preserve = handler.dispatch(request(command: "preserve-split", args: ["true"]))

    #expect(ratio.ok)
    #expect(placement.ok && placement.message == "top")
    #expect(preserve.ok && preserve.message == "on")
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

  @Test("dispatch: rejects invalid layout commands")
  func dispatchRejectsInvalidLayoutCommands() {
    let handler = handler(spaceManager: SpaceManager(activeSpaceID: nil))
    let missing = handler.dispatch(request(command: "layout", args: []))
    let extra = handler.dispatch(request(command: "layout", args: ["master", "dwindle"]))
    let unknown = handler.dispatch(request(command: "layout", args: ["columns"]))

    #expect(missing.ok == false)
    #expect(missing.errorCode == .invalidRequest)
    #expect(missing.message == "invalid config layout arguments")
    #expect(extra.ok == false)
    #expect(extra.errorCode == .invalidRequest)
    #expect(extra.message == "invalid config layout arguments")
    #expect(unknown.ok == false)
    #expect(unknown.errorCode == .invalidRequest)
    #expect(unknown.message == "invalid config layout: columns")
  }

  @Test("dispatch: rejects invalid layout control values")
  func dispatchRejectsInvalidLayoutControlValues() {
    let handler = handler(spaceManager: SpaceManager(activeSpaceID: nil))
    let responses = [
      handler.dispatch(request(command: "master-ratio", args: ["wide"])),
      handler.dispatch(request(command: "master-placement", args: ["center"])),
      handler.dispatch(request(command: "preserve-split", args: ["maybe"])),
    ]

    #expect(responses.allSatisfy { !$0.ok && $0.errorCode == .invalidRequest })
  }

  private func request(command: String, args: [String]) -> IPCRequest {
    IPCRequest(id: "request-id", domain: .config, command: command, args: args)
  }

  private func layoutID(_ spaceID: UInt64) -> TilingLayoutID {
    TilingLayoutID(spaceID: spaceID, displayID: "display")
  }

  private func handler(spaceManager: SpaceManager) -> ConfigCommandHandler {
    ConfigCommandHandler(
      spaceManager: spaceManager,
      tilingManager: makeTestTilingManager(spaceManager: spaceManager)
    )
  }
}
