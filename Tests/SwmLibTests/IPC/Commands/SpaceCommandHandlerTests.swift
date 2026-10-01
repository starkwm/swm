import CoreGraphics
import Testing

@testable import SwmLib

@MainActor
@Suite("SpaceCommandHandler")
struct SpaceCommandHandlerTests {
  @Test("dispatch: activates a Space without requiring a tracked active Space")
  func activatesSpace() async {
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
  func activationFailure() async {
    let spaces = Spaces(activeSpaceID: 42)
    let handler = SpaceCommandHandler(
      spaces: spaces,
      tiling: makeTestTiling(spaces: spaces),
      activateSpace: { _ in throw SpaceActivationBridgeError.unavailable }
    )

    let response = await handler.dispatch(request(command: "--activate", args: ["0"]))
    #expect(!response.ok)
    #expect(response.errorCode == .internalError)
    #expect(response.message == SpaceActivationBridgeError.unavailable.description)
  }

  @Test(
    "dispatch: activation rejects missing, extra, and invalid indexes",
    arguments: [[], ["0", "1"], ["-1"], ["next"], ["18446744073709551615"], ["--space", "1"]]
  )
  func invalidActivation(args: [String]) async {
    let spaces = Spaces(activeSpaceID: 42)
    let handler = SpaceCommandHandler(
      spaces: spaces,
      tiling: makeTestTiling(spaces: spaces),
      activateSpace: { _ in Issue.record("unexpected activation") }
    )

    let response = await handler.dispatch(request(command: "--activate", args: args))
    #expect(response.errorCode == .invalidRequest)
  }

  @Test("dispatch: selects floating or automatic layout for the active Space")
  func dispatchSelectsLayout() async {
    let spaces = Spaces(activeSpaceID: 42)
    let tiling = makeTestTiling(
      spaces: spaces,
      topology: SpaceTopology(
        spacesByID: [
          42: SpaceTopologyDescriptor(id: 42, displayID: "display", type: .normal)
        ],
        visibleSpaceIDByDisplayID: ["display": 42],
        spaceIDsByWindowID: [:],
        displaysByID: [
          "display": SpaceTopologyDisplay(
            visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
          )
        ]
      )
    )
    tiling.initialize()
    let handler = SpaceCommandHandler(
      spaces: spaces,
      tiling: tiling
    )

    let dwindle = await handler.dispatch(request(command: "--layout", args: ["dwindle"]))

    #expect(dwindle.ok)
    #expect(dwindle.message == "dwindle")
    #expect(tiling.layoutPlan(for: layoutID(42)) == .layout(.frames([:])))

    let master = await handler.dispatch(request(command: "--layout", args: ["master"]))

    #expect(master.ok)
    #expect(master.message == "master")
    #expect(tiling.layoutPlan(for: layoutID(42)) == .layout(.frames([:])))

    let monocle = await handler.dispatch(request(command: "--layout", args: ["monocle"]))

    #expect(monocle.ok)
    #expect(monocle.message == "monocle")
    #expect(tiling.layoutPlan(for: layoutID(42)) == .layout(.frames([:])))

    let float = await handler.dispatch(request(command: "--layout", args: ["float"]))

    #expect(float.ok)
    #expect(float.message == "float")
    #expect(tiling.layoutPlan(for: layoutID(42)) == .disabled)
  }

  @Test("dispatch: accepts padding commands")
  func dispatchAcceptsPaddingCommands() async throws {
    let spaces = Spaces(activeSpaceID: 42)
    let handler = handler(spaces: spaces)

    let absolute = await handler.dispatch(request(command: "--padding", args: ["abs:20:20:20:20"]))
    let relative = await handler.dispatch(request(command: "--padding", args: ["rel:10:0:-5:-5"]))

    #expect(absolute.ok)
    #expect(relative.ok)
    #expect(absolute.message == "ok")
    #expect(relative.message == "ok")

    #expect(
      spaces.settings(for: 42).padding == SpacePadding(top: 30, bottom: 20, left: 15, right: 15)
    )
  }

  @Test("dispatch: accepts gap commands")
  func dispatchAcceptsGapCommands() async throws {
    let spaces = Spaces(activeSpaceID: 42)
    let handler = handler(spaces: spaces)

    let absolute = await handler.dispatch(request(command: "--gap", args: ["abs:0"]))
    let relative = await handler.dispatch(request(command: "--gap", args: ["rel:10"]))

    #expect(absolute.ok)
    #expect(relative.ok)
    #expect(absolute.message == "ok")
    #expect(relative.message == "ok")

    #expect(spaces.settings(for: 42).gap == 10)
  }

  @Test("dispatch: updates layout controls")
  func dispatchUpdatesLayoutControls() async {
    let spaces = Spaces(activeSpaceID: 42)
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
                visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
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
    "dispatch rejects unsupported space commands",
    arguments: [
      ("--unknown", [String]()), ("--toggle", ["tiling"]), ("--focus", ["recent"]),
    ]
  )
  func unsupportedCommands(command: String, args: [String]) async {
    let response = await handler(spaces: Spaces(activeSpaceID: 42)).dispatch(
      request(command: command, args: args)
    )
    #expect(!response.ok)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "unsupported space command: \(command)")
  }

  @Test(
    "overflow returns invalid request and leaves all settings unchanged",
    arguments: [
      ("--gap", "abs:\(Int.max)", "rel:1", "gap"),
      ("--padding", "abs:10:20:30:\(Int.max)", "rel:1:1:1:1", "padding"),
    ]
  )
  func overflow(command: String, absolute: String, relative: String, setting: String) async {
    let spaces = Spaces(activeSpaceID: 42)
    let handler = handler(spaces: spaces)
    #expect(await handler.dispatch(request(command: command, args: [absolute])).ok)
    let previous = spaces.settings(for: 42)
    let response = await handler.dispatch(request(command: command, args: [relative]))
    #expect(!response.ok)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "space \(setting) adjustment overflows integer range")
    #expect(spaces.settings(for: 42) == previous)
    #expect(spaces.settings(for: 43) == .defaults)
  }

  @Test("dispatch: updates active space only")
  func dispatchUpdatesActiveSpaceOnly() async {
    let spaces = Spaces(activeSpaceID: 2)
    let handler = handler(spaces: spaces)

    _ = await handler.dispatch(request(command: "--gap", args: ["abs:10"]))

    #expect(spaces.settings(for: 1).gap == 0)
    #expect(spaces.settings(for: 2).gap == 10)
  }

  @Test("dispatch: updates a selected space by index")
  func dispatchUpdatesSelectedSpaceByIndex() async {
    let spaces = Spaces(activeSpaceID: 1)
    let handler = SpaceCommandHandler(
      spaces: spaces,
      tiling: makeTestTiling(spaces: spaces),
      spaceIDProvider: { [1, 2] }
    )

    let response = await handler.dispatch(
      request(command: "--gap", args: ["--space", "1", "abs:10"])
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
      request(command: "--gap", args: ["--space", "-1", "abs:10"])
    )
    let outOfRange = await handler.dispatch(
      request(command: "--gap", args: ["--space", "2", "abs:10"])
    )

    #expect(missing.errorCode == .invalidRequest)
    #expect(negative.errorCode == .invalidRequest)
    #expect(outOfRange.errorCode == .invalidRequest)
    #expect(outOfRange.message == "space index out of range: 2")
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
