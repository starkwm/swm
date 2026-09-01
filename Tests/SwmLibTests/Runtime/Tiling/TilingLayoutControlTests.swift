import CoreGraphics
import Testing

@testable import SwmLib

@MainActor
@Suite("Tiling layout controls")
struct TilingLayoutControlTests {
  @Test("setLayout: gives every tiled window the complete visible bounds in monocle")
  func setLayoutPlansMonocleGeometry() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()

    #expect(tiling.setLayout(.monocle, for: 10))
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            2: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            3: CGRect(x: 0, y: 0, width: 1_000, height: 800),
          ])
        )
    )
  }

  @Test("setLayout: retains dwindle selection and plans its geometry")
  func setLayoutRetainsDwindleSelectionAndPlansItsGeometry() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3), window(id: 4)],
      memberships: [1: [10], 2: [10], 3: [10], 4: [10]]
    )
    tiling.initialize()

    #expect(tiling.setLayout(.dwindle, for: 10))
    #expect(tiling.setLayout(.dwindle, for: 99) == false)

    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 800),
            2: CGRect(x: 500, y: 0, width: 500, height: 400),
            3: CGRect(x: 500, y: 400, width: 250, height: 400),
            4: CGRect(x: 750, y: 400, width: 250, height: 400),
          ])
        )
    )

    tiling.reconcile()

    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 800),
            2: CGRect(x: 500, y: 0, width: 500, height: 400),
            3: CGRect(x: 500, y: 400, width: 250, height: 400),
            4: CGRect(x: 750, y: 400, width: 250, height: 400),
          ])
        )
    )
  }

  @Test("master controls: update ratio and placement for a Space")
  func masterControlsUpdateRatioAndPlacement() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.master, for: 10)

    #expect(tiling.changeMasterRatio(.absolute(0.6), for: 10))
    #expect(tiling.setMasterPlacement(.right, for: 10))
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 400, y: 0, width: 600, height: 800),
            2: CGRect(x: 0, y: 0, width: 400, height: 400),
            3: CGRect(x: 0, y: 400, width: 400, height: 400),
          ])
        )
    )
  }

  @Test("master controls: cycle placement clockwise and counter-clockwise")
  func masterControlsCyclePlacement() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2)],
      memberships: [1: [10], 2: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.master, for: 10)

    #expect(tiling.cycleMasterPlacement(.next, for: 10) == .top)
    #expect(tiling.cycleMasterPlacement(.prev, for: 10) == .left)
  }

  @Test("dwindle controls: adjust a window's nearest split")
  func dwindleControlsAdjustNearestSplit() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.dwindle, for: 10)

    #expect(tiling.changeDwindleSplitRatio(.relative(0.2), for: 1) == 0.7)
    #expect(tiling.changeDwindleSplitRatio(.absolute(0.4), for: 99) == nil)
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 700, height: 800),
            2: CGRect(x: 700, y: 0, width: 300, height: 400),
            3: CGRect(x: 700, y: 400, width: 300, height: 400),
          ])
        )
    )
  }

  @Test("dwindle controls: toggle and retain the nearest dynamic split")
  func dwindleControlsToggleAndRetainNearestDynamicSplit() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.dwindle, for: 10)

    #expect(tiling.toggleDwindleSplit(for: 2))
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 800),
            2: CGRect(x: 500, y: 0, width: 250, height: 800),
            3: CGRect(x: 750, y: 0, width: 250, height: 800),
          ])
        )
    )

    #expect(tiling.toggleDwindleSplit(for: 2))
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 800),
            2: CGRect(x: 500, y: 0, width: 500, height: 400),
            3: CGRect(x: 500, y: 400, width: 500, height: 400),
          ])
        )
    )
  }

  @Test("dwindle controls: swap the nearest sibling subtrees")
  func dwindleControlsSwapNearestSiblingSubtrees() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.dwindle, for: 10)

    #expect(tiling.swapDwindleSplit(for: 2))
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 800),
            3: CGRect(x: 500, y: 0, width: 500, height: 400),
            2: CGRect(x: 500, y: 400, width: 500, height: 400),
          ])
        )
    )
  }

  @Test("global controls: apply layout settings to current and future Spaces")
  func globalControlsApplyLayoutSettingsToCurrentAndFutureSpaces() {
    var spaceIDs = Set([UInt64(10)])
    var visibleSpaceID = UInt64(10)
    var visibleFrame = CGRect(x: 0, y: 0, width: 1_000, height: 800)
    let spaces = Spaces(activeSpaceID: nil)
    let tiling = Tiling(
      snapshot: {
        TilingReconciliationSnapshot(
          windows: [window(id: 1), window(id: 2)],
          topology: SpaceTopology(
            spacesByID: Dictionary(
              uniqueKeysWithValues: spaceIDs.map {
                ($0, SpaceTopologyDescriptor(id: $0, displayID: "display", type: .normal))
              }
            ),
            visibleSpaceIDByDisplayID: ["display": visibleSpaceID],
            spaceIDsByWindowID: [1: [visibleSpaceID], 2: [visibleSpaceID]],
            displaysByID: [
              "display": SpaceTopologyDisplay(
                visibleFrame: visibleFrame
              )
            ]
          )
        )
      },
      spaces: spaces
    )
    tiling.initialize()

    tiling.setLayoutForSpaces(.master)
    tiling.setMasterRatioForAllSpaces(0.65)
    tiling.setMasterPlacementForAllSpaces(.bottom)
    tiling.setSplitDirectionPreservationForAllSpaces(true)

    let expectedPlan = TilingLayoutPlan.layout(
      .frames([
        1: CGRect(x: 0, y: 280, width: 1_000, height: 520),
        2: CGRect(x: 0, y: 0, width: 1_000, height: 280),
      ])
    )
    #expect(tiling.layoutPlan(for: layoutID(10)) == expectedPlan)

    spaceIDs.insert(11)
    visibleSpaceID = 11
    tiling.reconcile()

    #expect(tiling.layoutPlan(for: layoutID(11)) == expectedPlan)

    tiling.setLayout(.dwindle, for: 11)
    visibleFrame = CGRect(x: 0, y: 0, width: 600, height: 1_000)
    tiling.reconcile()

    #expect(
      tiling.layoutPlan(for: layoutID(11))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 300, height: 1_000),
            2: CGRect(x: 300, y: 0, width: 300, height: 1_000),
          ])
        )
    )
  }
}
