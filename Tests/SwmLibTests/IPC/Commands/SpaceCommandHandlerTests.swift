import CoreGraphics
import Testing

@testable import SwmLib

@MainActor
@Suite("SpaceCommandHandler")
struct SpaceCommandHandlerTests {
  @Test("dispatch: accepts toggle commands")
  func dispatchAcceptsToggleCommands() throws {
    let manager = SpaceManager(activeSpaceID: 42)
    let handler = handler(spaceManager: manager)

    let padding = handler.dispatch(request(command: "--toggle", args: ["padding"]))
    let gap = handler.dispatch(request(command: "--toggle", args: ["gap"]))

    #expect(padding.ok)
    #expect(gap.ok)
    #expect(padding.message == "ok")
    #expect(gap.message == "ok")
    #expect(manager.settings(for: 42).paddingEnabled == false)
    #expect(manager.settings(for: 42).gapEnabled == false)
  }

  @Test("dispatch: explicitly toggles automatic tiling for the active Space")
  func dispatchExplicitlyTogglesAutomaticTiling() {
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

    let enabled = handler.dispatch(request(command: "--toggle", args: ["tiling"]))
    let disabled = handler.dispatch(request(command: "--toggle", args: ["tiling"]))

    #expect(enabled.ok)
    #expect(enabled.message == "on")
    #expect(disabled.ok)
    #expect(disabled.message == "off")
    #expect(tilingManager.isEnabled(for: 42) == false)
  }

  @Test("dispatch: selects the automatic layout for the active Space")
  func dispatchSelectsAutomaticLayout() {
    let spaceManager = SpaceManager(activeSpaceID: 42)
    let tilingManager = TilingManager(
      snapshot: {
        TilingReconciliationSnapshot(
          windows: [],
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
      },
      spaceManager: spaceManager
    )
    tilingManager.start()
    let handler = SpaceCommandHandler(
      spaceManager: spaceManager,
      tilingManager: tilingManager
    )

    let dwindle = handler.dispatch(request(command: "--layout", args: ["dwindle"]))

    #expect(dwindle.ok)
    #expect(dwindle.message == "dwindle")
    #expect(tilingManager.layoutMode(for: 42) == .dwindle)

    let master = handler.dispatch(request(command: "--layout", args: ["master"]))

    #expect(master.ok)
    #expect(master.message == "master")
    #expect(tilingManager.layoutMode(for: 42) == .master)
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

  @Test("dispatch: rejects malformed arguments")
  func dispatchRejectsMalformedArguments() {
    let handler = handler(spaceManager: SpaceManager(activeSpaceID: 42))

    let responses = [
      handler.dispatch(request(command: "--toggle", args: [])),
      handler.dispatch(request(command: "--toggle", args: ["unknown"])),
      handler.dispatch(request(command: "--layout", args: [])),
      handler.dispatch(request(command: "--layout", args: ["unknown"])),
      handler.dispatch(request(command: "--padding", args: ["abs:1:2:3"])),
      handler.dispatch(request(command: "--padding", args: ["rel:1:2:x:4"])),
      handler.dispatch(request(command: "--gap", args: ["abs"])),
      handler.dispatch(request(command: "--gap", args: ["rel:x"])),
    ]

    #expect(responses.allSatisfy { !$0.ok && $0.errorCode == .invalidRequest })
  }

  @Test("dispatch: rejects unsupported space commands")
  func dispatchRejectsUnsupportedSpaceCommands() {
    let handler = handler(spaceManager: SpaceManager(activeSpaceID: 42))
    let response = handler.dispatch(request(command: "--unknown", args: []))

    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "unsupported space command: --unknown")
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

  private func handler(spaceManager: SpaceManager) -> SpaceCommandHandler {
    SpaceCommandHandler(
      spaceManager: spaceManager,
      tilingManager: makeTestTilingManager(spaceManager: spaceManager)
    )
  }
}
