import CoreGraphics
import Testing

@testable import SwmLib

@MainActor
@Suite("SpaceCommandHandler")
struct SpaceCommandHandlerTests {
  @Test("dispatch: activates a Space without requiring a tracked active Space")
  func dispatchActivatesASpaceWithoutRequiringATrackedActiveSpace() async {
    let spaces = Spaces(activeSpaceID: nil)
    var selectedIndex: Int?
    let handler = SpaceCommandHandler(
      spaces: spaces,
      tiling: makeTestTiling(spaces: spaces),
      activateSpace: { selectedIndex = $0 }
    )

    let response = await handler.dispatch(request(command: "--activate", args: ["2"]))

    #expect(response.ok && response.message == "ok")
    #expect(response.id == "request-id")
    #expect(selectedIndex == 2)
  }

  @Test("dispatch: activation failures remain failures")
  func dispatchActivationFailuresRemainFailures() async {
    let spaces = Spaces(activeSpaceID: 42)
    let handler = SpaceCommandHandler(
      spaces: spaces,
      tiling: makeTestTiling(spaces: spaces),
      activateSpace: { _ in throw SpaceActivationBridgeError.unavailable }
    )

    let response = await handler.dispatch(request(command: "--activate", args: ["1"]))
    #expect(!response.ok)
    #expect(response.errorCode == .internalError)
    #expect(response.message == SpaceActivationBridgeError.unavailable.description)
  }

  @Test(
    "dispatch: activation rejects missing, extra, and invalid indexes",
    arguments: [
      [], ["1", "2"], ["0"], ["-1"], ["next"], ["18446744073709551615"], ["--space", "1"],
    ]
  )
  func dispatchActivationRejectsMissingExtraAndInvalidIndexes(args: [String]) async {
    let spaces = Spaces(activeSpaceID: 42)
    let handler = SpaceCommandHandler(
      spaces: spaces,
      tiling: makeTestTiling(spaces: spaces),
      activateSpace: { _ in Issue.record("unexpected activation") }
    )

    let response = await handler.dispatch(request(command: "--activate", args: args))
    #expect(response.errorCode == .invalidRequest)
  }

  @Test("dispatch: applies absolute and relative padding with clamping")
  func dispatchAppliesAbsoluteAndRelativePaddingWithClamping() async {
    let spaces = Spaces(activeSpaceID: 42)
    let handler = handler(spaces: spaces)
    #expect(await handler.dispatch(request(command: "--padding", args: ["abs:20:20:20:20"])).ok)
    #expect(await handler.dispatch(request(command: "--padding", args: ["rel:10:0:-5:-5"])).ok)
    #expect(
      spaces.settings(for: 42).padding == SpacePadding(top: 30, bottom: 20, left: 15, right: 15)
    )
    #expect(await handler.dispatch(request(command: "--padding", args: ["abs:-1:1:-2:2"])).ok)
    #expect(spaces.settings(for: 42).padding == SpacePadding(top: 0, bottom: 1, left: 0, right: 2))
    #expect(await handler.dispatch(request(command: "--padding", args: ["rel:-10:-10:-10:-10"])).ok)
    #expect(spaces.settings(for: 42).padding == .zero)
    #expect(spaces.settings(for: 43) == .defaults)
  }

  @Test("dispatch: applies absolute and relative gaps only to the active Space")
  func dispatchAppliesAbsoluteAndRelativeGapsOnlyToTheActiveSpace() async {
    let spaces = Spaces(activeSpaceID: 42)
    let handler = handler(spaces: spaces)
    #expect(await handler.dispatch(request(command: "--gap", args: ["abs:0"])).ok)
    let relative = await handler.dispatch(request(command: "--gap", args: ["rel:10"]))
    #expect(relative.ok && relative.message == "ok")
    #expect(spaces.settings(for: 42).gap == 10)
    #expect(await handler.dispatch(request(command: "--gap", args: ["abs:-1"])).ok)
    #expect(spaces.settings(for: 42).gap == 0)
    #expect(await handler.dispatch(request(command: "--gap", args: ["rel:-10"])).ok)
    #expect(spaces.settings(for: 42).gap == 0)
    #expect(spaces.settings(for: 43) == .defaults)
  }

  @Test("dispatch: updates layout controls")
  func dispatchUpdatesLayoutControls() async {
    let spaces = Spaces(activeSpaceID: 42)
    var bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let tiling = Tiling(
      snapshot: {
        TilingReconciliationSnapshot(
          windows: [
            TilingWindowSnapshot(
              id: 1,
              displayID: "display",
              subrole: "AXStandardWindow",
              isMinimized: false,
              isMovable: true,
              isResizable: true
            ),
            TilingWindowSnapshot(
              id: 2,
              displayID: "display",
              subrole: "AXStandardWindow",
              isMinimized: false,
              isMovable: true,
              isResizable: true
            ),
          ],
          topology: SpaceTopology(
            spacesByID: [
              42: SpaceTopologyDescriptor(id: 42, displayID: "display", type: .normal)
            ],
            visibleSpaceIDByDisplayID: ["display": 42],
            spaceIDsByWindowID: [1: [42], 2: [42]],
            displaysByID: [
              "display": SpaceTopologyDisplay(
                visibleFrame: bounds
              )
            ]
          )
        )
      },
      spaces: spaces
    )
    tiling.initialize()
    let handler = SpaceCommandHandler(
      spaces: spaces,
      tiling: tiling
    )

    let ratio = await handler.dispatch(request(command: "--master-ratio", args: ["abs:0.6"]))
    let relativeRatio = await handler.dispatch(
      request(command: "--master-ratio", args: ["rel:0.1"])
    )
    let placement = await handler.dispatch(request(command: "--master-placement", args: ["bottom"]))
    let cycledPlacement = await handler.dispatch(
      request(command: "--master-placement", args: ["next"])
    )
    let preserve = await handler.dispatch(request(command: "--preserve-split", args: ["on"]))
    let layout = await handler.dispatch(request(command: "--layout", args: ["master"]))

    #expect(ratio.ok)
    #expect(relativeRatio.ok)
    #expect(placement.ok && placement.message == "bottom")
    #expect(cycledPlacement.ok && cycledPlacement.message == "left")
    #expect(preserve.ok && preserve.message == "on")
    #expect(layout.ok)
    #expect(
      tiling.layoutPlan(for: layoutID(42))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 700, height: 800),
            2: CGRect(x: 700, y: 0, width: 300, height: 800),
          ])
        )
    )

    #expect(
      (await handler.dispatch(request(command: "--layout", args: ["monocle"]))).message == "monocle"
    )
    #expect(tiling.layoutPlan(for: layoutID(42)) == .layout(.frames([1: bounds, 2: bounds])))
    #expect(
      (await handler.dispatch(request(command: "--layout", args: ["float"]))).message == "float"
    )
    #expect(tiling.layoutPlan(for: layoutID(42)) == .disabled)
    #expect(
      (await handler.dispatch(request(command: "--layout", args: ["dwindle"]))).message == "dwindle"
    )
    bounds.size.width = 400
    tiling.reconcile()
    #expect(
      tiling.layoutPlan(for: layoutID(42))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 200, height: 800),
            2: CGRect(x: 200, y: 0, width: 200, height: 800),
          ])
        )
    )
  }

  @Test("dispatch: rejects malformed arguments")
  func dispatchRejectsMalformedArguments() async {
    let handler = handler(spaces: Spaces(activeSpaceID: 42))

    let responses = [
      await handler.dispatch(request(command: "--layout", args: [])),
      await handler.dispatch(request(command: "--layout", args: ["unknown"])),
      await handler.dispatch(request(command: "--padding", args: ["abs:1:2:3"])),
      await handler.dispatch(request(command: "--padding", args: ["rel:1:2:x:4"])),
      await handler.dispatch(request(command: "--gap", args: ["abs"])),
      await handler.dispatch(request(command: "--gap", args: ["rel:x"])),
      await handler.dispatch(request(command: "--master-ratio", args: ["0.6"])),
      await handler.dispatch(request(command: "--master-placement", args: ["center"])),
      await handler.dispatch(request(command: "--preserve-split", args: ["maybe"])),
    ]

    #expect(responses.allSatisfy { !$0.ok && $0.errorCode == .invalidRequest })
  }

  @Test(
    "dispatch: names the accepted form of malformed values",
    arguments: [
      ("--gap", "6", "space gap", "abs:<points> or rel:<points>, such as rel:4"),
      (
        "--padding", "abs:1:2:3", "space padding",
        "abs|rel:<top>:<bottom>:<left>:<right>, such as abs:8:8:8:8"
      ),
      (
        "--master-ratio", "0.6", "space master-ratio",
        "abs:<ratio> or rel:<ratio>, such as rel:0.05"
      ),
    ]
  )
  func dispatchNamesTheAcceptedFormOfMalformedValues(
    command: String,
    value: String,
    context: String,
    form: String
  ) async {
    let response = await handler(spaces: Spaces(activeSpaceID: 42)).dispatch(
      request(command: command, args: [value])
    )
    #expect(response.message == "invalid \(context) value: \(value); expected \(form)")
  }

  @Test(
    "dispatch: rejects unsupported Space commands",
    arguments: [
      ("--unknown", [String]()), ("--toggle", ["tiling"]), ("--focus", ["recent"]),
    ]
  )
  func dispatchRejectsUnsupportedSpaceCommands(command: String, args: [String]) async {
    let response = await handler(spaces: Spaces(activeSpaceID: 42)).dispatch(
      request(command: command, args: args)
    )
    #expect(!response.ok)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "unsupported space command: \(command)")
  }

  @Test(
    "dispatch: rejects overflow without changing settings",
    arguments: [
      ("--gap", "1", "gap", false), ("--gap", "1", "gap", true),
      ("--padding", "1:-1:-1:-1", "padding", true),
      ("--padding", "-1:1:-1:-1", "padding", true),
      ("--padding", "-1:-1:1:-1", "padding", true),
      ("--padding", "-1:-1:-1:1", "padding", true),
    ]
  )
  func dispatchRejectsOverflowWithoutChangingSettings(
    command: String,
    delta: String,
    setting: String,
    existingOverride: Bool
  ) async {
    let spaces = Spaces(activeSpaceID: 42)
    spaces.updateAllSettings { settings in
      settings.gap = Int.max
      settings.padding = SpacePadding(top: Int.max, bottom: Int.max, left: Int.max, right: Int.max)
    }
    if existingOverride { spaces.setGap(Int.max, for: 42) }
    let handler = handler(spaces: spaces)
    let previous = spaces.settings(for: 42)
    let response = await handler.dispatch(request(command: command, args: ["rel:\(delta)"]))
    #expect(!response.ok)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "space \(setting) adjustment overflows integer range")
    #expect(spaces.settings(for: 42) == previous)
    #expect(spaces.settings(for: 43) == previous)
  }

  @Test("dispatch: accepts integer extremes without overflowing intermediate adjustments")
  func dispatchAcceptsIntegerExtremesWithoutOverflowingIntermediateAdjustments() async {
    let spaces = Spaces(activeSpaceID: 42)
    let handler = handler(spaces: spaces)
    #expect(
      await handler.dispatch(
        request(command: "--padding", args: ["abs:\(Int.max):\(Int.max):\(Int.max):\(Int.max)"])
      ).ok
    )
    #expect(
      await handler.dispatch(
        request(command: "--padding", args: ["rel:\(Int.min):-1:0:\(-Int.max)"])
      ).ok
    )
    #expect(
      spaces.settings(for: 42).padding
        == SpacePadding(top: 0, bottom: Int.max - 1, left: Int.max, right: 0)
    )
    #expect(await handler.dispatch(request(command: "--gap", args: ["abs:\(Int.max)"])).ok)
    #expect(await handler.dispatch(request(command: "--gap", args: ["rel:\(Int.min)"])).ok)
    #expect(spaces.settings(for: 42).gap == 0)
    #expect(await handler.dispatch(request(command: "--gap", args: ["rel:\(Int.max)"])).ok)
    #expect(spaces.settings(for: 42).gap == Int.max)
    #expect(spaces.settings(for: 43) == .defaults)
  }

  @Test("dispatch: updates a selected space by index")
  func dispatchUpdatesASelectedSpaceByIndex() async {
    let spaces = Spaces(activeSpaceID: 1)
    let handler = SpaceCommandHandler(
      spaces: spaces,
      tiling: makeTestTiling(spaces: spaces),
      spaceIDProvider: { [1, 2] }
    )

    let response = await handler.dispatch(
      request(command: "--gap", args: ["--space", "2", "abs:10"])
    )

    #expect(response.ok)
    #expect(spaces.settings(for: 1).gap == 0)
    #expect(spaces.settings(for: 2).gap == 10)
  }

  @Test("dispatch: rejects invalid space indexes")
  func dispatchRejectsInvalidSpaceIndexes() async {
    let spaces = Spaces(activeSpaceID: 1)
    let handler = SpaceCommandHandler(
      spaces: spaces,
      tiling: makeTestTiling(spaces: spaces),
      spaceIDProvider: { [1, 2] }
    )

    let missing = await handler.dispatch(request(command: "--gap", args: ["--space"]))
    let negative = await handler.dispatch(
      request(command: "--gap", args: ["--space", "0", "abs:10"])
    )
    let outOfRange = await handler.dispatch(
      request(command: "--gap", args: ["--space", "3", "abs:10"])
    )

    #expect(missing.errorCode == .invalidRequest)
    #expect(negative.errorCode == .invalidRequest)
    #expect(outOfRange.errorCode == .invalidRequest)
    #expect(outOfRange.message == "space index out of range: 3")
  }

  @Test("dispatch: rejects active-space mutation without active space")
  func dispatchRejectsActiveSpaceMutationWithoutActiveSpace() async {
    let handler = handler(spaces: Spaces(activeSpaceID: nil))
    let response = await handler.dispatch(request(command: "--gap", args: ["abs:10"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "no active space")
  }

  private func request(command: String, args: [String]) -> IPCRequest {
    IPCRequest(id: "request-id", domain: .space, command: command, args: args)
  }

  private func layoutID(_ spaceID: UInt64) -> TilingLayoutID {
    TilingLayoutID(spaceID: spaceID, displayID: "display")
  }

  private func handler(spaces: Spaces) -> SpaceCommandHandler {
    SpaceCommandHandler(
      spaces: spaces,
      tiling: makeTestTiling(spaces: spaces)
    )
  }
}
