import CoreGraphics
import Testing

@testable import SwmLib

@MainActor
@Suite("SpaceCommandHandler")
struct SpaceCommandHandlerTests {
  @Test("dispatch: selects floating or automatic layout for the active Space")
  func dispatchSelectsLayout() {
    let spaceManager = SpaceManager(activeSpaceID: 42)
    let tilingManager = makeTestTilingManager(
      spaceManager: spaceManager,
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
    tilingManager.start()
    let handler = SpaceCommandHandler(
      spaceManager: spaceManager,
      tilingManager: tilingManager
    )

    let dwindle = handler.dispatch(request(command: "--layout", args: ["dwindle"]))

    #expect(dwindle.ok)
    #expect(dwindle.message == "dwindle")
    #expect(tilingManager.layoutPlan(for: layoutID(42)) == .layout(.frames([:])))

    let master = handler.dispatch(request(command: "--layout", args: ["master"]))

    #expect(master.ok)
    #expect(master.message == "master")
    #expect(tilingManager.layoutPlan(for: layoutID(42)) == .layout(.frames([:])))

    let monocle = handler.dispatch(request(command: "--layout", args: ["monocle"]))

    #expect(monocle.ok)
    #expect(monocle.message == "monocle")
    #expect(tilingManager.layoutPlan(for: layoutID(42)) == .layout(.frames([:])))

    let float = handler.dispatch(request(command: "--layout", args: ["float"]))

    #expect(float.ok)
    #expect(float.message == "float")
    #expect(tilingManager.layoutPlan(for: layoutID(42)) == .disabled)
  }

  @Test("dispatch: accepts padding commands")
  func dispatchAcceptsPaddingCommands() throws {
    let manager = SpaceManager(activeSpaceID: 42)
    let handler = handler(spaceManager: manager)

    let absolute = handler.dispatch(request(command: "--padding", args: ["abs:20:20:20:20"]))
    let relative = handler.dispatch(request(command: "--padding", args: ["rel:10:0:-5:-5"]))

    #expect(absolute.ok)
    #expect(relative.ok)
    #expect(absolute.message == "ok")
    #expect(relative.message == "ok")

    #expect(
      manager.settings(for: 42).padding == SpacePadding(top: 30, bottom: 20, left: 15, right: 15)
    )
  }

  @Test("dispatch: accepts gap commands")
  func dispatchAcceptsGapCommands() throws {
    let manager = SpaceManager(activeSpaceID: 42)
    let handler = handler(spaceManager: manager)

    let absolute = handler.dispatch(request(command: "--gap", args: ["abs:0"]))
    let relative = handler.dispatch(request(command: "--gap", args: ["rel:10"]))

    #expect(absolute.ok)
    #expect(relative.ok)
    #expect(absolute.message == "ok")
    #expect(relative.message == "ok")

    #expect(manager.settings(for: 42).gap == 10)
  }

  @Test("dispatch: updates layout controls")
  func dispatchUpdatesLayoutControls() {
    let spaceManager = SpaceManager(activeSpaceID: 42)
    let tilingManager = TilingManager(
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
      spaceManager: spaceManager
    )
    tilingManager.start()
    let handler = SpaceCommandHandler(
      spaceManager: spaceManager,
      tilingManager: tilingManager
    )

    let ratio = handler.dispatch(request(command: "--master-ratio", args: ["abs:0.6"]))
    let relativeRatio = handler.dispatch(request(command: "--master-ratio", args: ["rel:0.1"]))
    let placement = handler.dispatch(request(command: "--master-placement", args: ["bottom"]))
    let cycledPlacement = handler.dispatch(
      request(command: "--master-placement", args: ["next"])
    )
    let preserve = handler.dispatch(request(command: "--preserve-split", args: ["on"]))
    let layout = handler.dispatch(request(command: "--layout", args: ["master"]))

    #expect(ratio.ok)
    #expect(relativeRatio.ok)
    #expect(placement.ok && placement.message == "bottom")
    #expect(cycledPlacement.ok && cycledPlacement.message == "left")
    #expect(preserve.ok && preserve.message == "on")
    #expect(layout.ok)
    #expect(
      tilingManager.layoutPlan(for: layoutID(42))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 700, height: 800),
            2: CGRect(x: 700, y: 0, width: 300, height: 800),
          ])
        )
    )
  }

  @Test("dispatch: rejects malformed arguments")
  func dispatchRejectsMalformedArguments() {
    let handler = handler(spaceManager: SpaceManager(activeSpaceID: 42))

    let responses = [
      handler.dispatch(request(command: "--layout", args: [])),
      handler.dispatch(request(command: "--layout", args: ["unknown"])),
      handler.dispatch(request(command: "--padding", args: ["abs:1:2:3"])),
      handler.dispatch(request(command: "--padding", args: ["rel:1:2:x:4"])),
      handler.dispatch(request(command: "--gap", args: ["abs"])),
      handler.dispatch(request(command: "--gap", args: ["rel:x"])),
      handler.dispatch(request(command: "--master-ratio", args: ["0.6"])),
      handler.dispatch(request(command: "--master-placement", args: ["center"])),
      handler.dispatch(request(command: "--preserve-split", args: ["maybe"])),
    ]

    #expect(responses.allSatisfy { !$0.ok && $0.errorCode == .invalidRequest })
  }

  @Test("dispatch: rejects unsupported space commands")
  func dispatchRejectsUnsupportedSpaceCommands() {
    let handler = handler(spaceManager: SpaceManager(activeSpaceID: 42))
    let unknown = handler.dispatch(request(command: "--unknown", args: []))
    let toggle = handler.dispatch(request(command: "--toggle", args: ["tiling"]))

    #expect(unknown.ok == false)
    #expect(unknown.errorCode == .unsupportedCommand)
    #expect(unknown.message == "unsupported space command: --unknown")
    #expect(toggle.ok == false)
    #expect(toggle.errorCode == .unsupportedCommand)
    #expect(toggle.message == "unsupported space command: --toggle")
  }

  @Test("dispatch: rejects focus command as unsupported")
  func dispatchRejectsFocusCommandAsUnsupported() {
    let handler = handler(spaceManager: SpaceManager(activeSpaceID: 42))
    let response = handler.dispatch(request(command: "--focus", args: ["recent"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "unsupported space command: --focus")
  }

  @Test("dispatch: updates active space only")
  func dispatchUpdatesActiveSpaceOnly() {
    let manager = SpaceManager(activeSpaceID: 2)
    let handler = handler(spaceManager: manager)

    _ = handler.dispatch(request(command: "--gap", args: ["abs:10"]))

    #expect(manager.settings(for: 1).gap == 0)
    #expect(manager.settings(for: 2).gap == 10)
  }

  @Test("dispatch: rejects active-space mutation without active space")
  func dispatchRejectsActiveSpaceMutationWithoutActiveSpace() {
    let handler = handler(spaceManager: SpaceManager(activeSpaceID: nil))
    let response = handler.dispatch(request(command: "--gap", args: ["abs:10"]))

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

  private func handler(spaceManager: SpaceManager) -> SpaceCommandHandler {
    SpaceCommandHandler(
      spaceManager: spaceManager,
      tilingManager: makeTestTilingManager(spaceManager: spaceManager)
    )
  }
}
