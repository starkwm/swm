import CoreGraphics
import Testing

@testable import SwmLib

@Suite("SpaceLifecycleHandler")
@MainActor
struct SpaceLifecycleHandlerTests {
  @Test("refresh: reconciles layouts and removes stale settings without changing focus history")
  func refresh() {
    let spaces = Spaces(activeSpaceID: 33)
    spaces.activeSpaceDidChange(to: 11)
    spaces.setGap(20, for: 99)
    var visibleFrame = CGRect(x: 0, y: 0, width: 1_000, height: 800)
    let tiling = Tiling(
      snapshot: {
        TilingReconciliationSnapshot(
          windows: [window(id: 1)],
          topology: SpaceTopology(
            spacesByID: [
              11: SpaceTopologyDescriptor(id: 11, displayID: "display", type: .normal)
            ],
            visibleSpaceIDByDisplayID: ["display": 11],
            spaceIDsByWindowID: [1: [11]],
            displaysByID: ["display": SpaceTopologyDisplay(visibleFrame: visibleFrame)]
          )
        )
      },
      spaces: spaces
    )
    tiling.initialize()
    #expect(tiling.setLayout(.master, for: 11))
    #expect(tiling.layoutPlan(for: layoutID(11)) == .layout(.frames([1: visibleFrame])))
    let handler = SpaceLifecycleHandler(
      spaces: spaces,
      windows: Windows(workspace: Workspace(), focusedWindowID: nil),
      tiling: tiling
    )

    visibleFrame.size.width = 800
    handler.refresh(spaceIDs: [11, 33])

    #expect(tiling.layoutPlan(for: layoutID(11)) == .layout(.frames([1: visibleFrame])))
    #expect(spaces.settings(for: 99) == .defaults)
    #expect(spaces.currentActiveSpaceID == 11)
    #expect(spaces.lastActiveSpaceID == 33)
  }
}
