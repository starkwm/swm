import CoreGraphics
import Testing

@testable import SwmLib

extension TilingTests {
  @Test("reconcile: applies placement once per matching action change and window lifetime")
  func reconcileAppliesPlacementOncePerMatchingActionChangeAndWindowLifetime() throws {
    var candidate = window(id: 1)
    candidate.title = "Projects"
    var candidates = [candidate]
    var placements = [WindowRulePlacement]()
    let tiling = makeTiling(
      windows: { candidates },
      memberships: { [1: [10]] },
      rulePlacement: { placement, _, _ in
        placements.append(placement)
        return .applied
      }
    )
    try tiling.addRule(
      WindowRule.parse(arguments: ["label=grid", "title=^Projects$", "grid=2:1:1:0:1:1"])
    )
    #expect(placements.count == 1)
    tiling.reconcile()
    tiling.windowFrameDidChange(1)
    #expect(placements.count == 1)
    try tiling.addRule(WindowRule.parse(arguments: ["label=override", "grid=1:1:0:0:1:1"]))
    #expect(placements.count == 2)
    try tiling.removeRule(selector: "override")
    #expect(placements.count == 3)
    candidates[0].title = "Other"
    tiling.reconcile()
    #expect(placements.count == 3)
    candidates[0].title = "Projects"
    tiling.reconcile()
    #expect(placements.count == 4)
    candidates = []
    tiling.reconcile()
    candidates = [candidate]
    tiling.reconcile()
    #expect(placements.count == 5)
    try tiling.removeRule(selector: "grid")
    #expect(placements.count == 5)
  }

  @Test("reconcile: defers grids until floating and transfers tiled windows")
  func reconcileDefersGridsUntilFloatingAndTransfersTiledWindows() throws {
    var placements = [WindowRulePlacement]()
    let tiling = makeTiling(rulePlacement: { placement, _, _ in
      placements.append(placement)
      return .applied
    })
    tiling.initialize()
    tiling.setLayout(.master, for: 10)
    try tiling.addRule(WindowRule.parse(arguments: ["grid=2:1:1:0:1:1", "display=1"]))
    #expect(placements == [WindowRulePlacement(display: .index(1))])
    try tiling.addRule(WindowRule.parse(arguments: ["manage=off"]))
    #expect(placements.count == 2)
    #expect(placements.last?.grid != nil)
    tiling.reconcile()
    #expect(placements.count == 2)
    #expect(tiling.setWindowLayout(.tile, for: 1))
    try tiling.addRule(WindowRule.parse(arguments: ["grid=1:1:0:0:1:1"]))
    #expect(placements.count == 2)
    #expect(placements.last?.display == nil)
  }

  @Test("reconcile: retries deferred placement and stops after failure")
  func reconcileRetriesDeferredPlacementAndStopsAfterFailure() throws {
    var attempts = 0
    var result = WindowRulePlacementResult.deferred
    let tiling = makeTiling(rulePlacement: { _, _, _ in
      attempts += 1
      return result
    })
    try tiling.addRule(WindowRule.parse(arguments: ["grid=1:1:0:0:1:1"]))
    #expect(attempts == 1)
    tiling.reconcile()
    #expect(attempts == 2)
    result = .failed
    tiling.reconcile()
    #expect(attempts == 3)
    tiling.reconcile()
    #expect(attempts == 3)
  }

  @Test("reconcile: defers placement for unavailable windows")
  func reconcileDefersPlacementForUnavailableWindows() throws {
    var candidates = [window(id: 1, isMinimized: true)]
    var membership: Set<UInt64> = [10]
    var calls = 0
    let tiling = makeTiling(
      windows: { candidates },
      memberships: { [1: membership] },
      rulePlacement: { _, _, _ in
        calls += 1
        return .applied
      }
    )
    try tiling.addRule(WindowRule.parse(arguments: ["display=1"]))
    #expect(calls == 0)
    candidates = [window(id: 1)]
    membership = [12]
    tiling.reconcile()
    #expect(calls == 0)
    membership = [10]
    tiling.reconcile()
    #expect(calls == 1)
  }

  @Test("reconcile: refreshes transfer membership and grids floating destinations")
  func reconcileRefreshesTransferMembershipAndGridsFloatingDestinations() throws {
    var currentDisplay = "left"
    var currentSpace: UInt64 = 10
    var displayIDs = ["left"]
    var placements = [WindowRulePlacement]()
    let tiling = Tiling(
      snapshot: {
        TilingReconciliationSnapshot(
          windows: [window(id: 1, displayID: currentDisplay), window(id: 2, displayID: "left")],
          topology: SpaceTopology(
            spacesByID: [
              10: SpaceTopologyDescriptor(id: 10, displayID: "left", type: .normal),
              11: SpaceTopologyDescriptor(id: 11, displayID: "right", type: .normal),
            ],
            visibleSpaceIDByDisplayID: ["left": 10, "right": 11],
            spaceIDsByWindowID: [1: [currentSpace], 2: [10]],
            displaysByID: [
              "left": SpaceTopologyDisplay(
                visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
              ),
              "right": SpaceTopologyDisplay(
                visibleFrame: CGRect(x: 1_000, y: 0, width: 1_000, height: 800)
              ),
            ]
          )
        )
      },
      spaces: Spaces(activeSpaceID: nil),
      rulePlacement: { placement, id, destination in
        if id == 1 {
          #expect(destination == layoutID(11, displayID: "right"))
          placements.append(placement)
          if placement.display != nil {
            currentDisplay = "right"
            currentSpace = 11
          }
        }
        return .applied
      },
      ruleDisplayIDs: { displayIDs }
    )
    tiling.initialize()
    tiling.setLayout(.master, for: 11)
    try tiling.addRule(WindowRule.parse(arguments: ["display=2", "grid=2:1:1:0:1:1"]))
    #expect(placements.isEmpty)
    displayIDs.append("right")
    tiling.reconcileAndReflowVisibleSpaces()
    #expect(placements == [WindowRulePlacement(display: .index(2))])
    #expect(
      tiling.layoutPlan(for: layoutID(11, displayID: "right"))
        == .layout(
          .frames([
            1: CGRect(x: 1_000, y: 0, width: 1_000, height: 800)
          ])
        )
    )
    tiling.setLayout(.master, for: 10)
    #expect(
      tiling.layoutPlan(for: layoutID(10, displayID: "left"))
        == .layout(
          .frames([
            2: CGRect(x: 0, y: 0, width: 1_000, height: 800)
          ])
        )
    )
    try tiling.addRule(WindowRule.parse(arguments: ["manage=off"]))
    #expect(placements.count == 2)
    #expect(placements.last?.grid != nil)
    #expect(placements.last?.display == nil)
    // Moving the window manually back must not replay the display action.
    currentDisplay = "left"
    currentSpace = 10
    tiling.reconcile()
    #expect(placements.count == 2)
  }

  @Test("reconcile: defers a previous grid after transfer to a tiled layout")
  func reconcileDefersAPreviousGridAfterTransferToATiledLayout() throws {
    var placements = [WindowRulePlacement]()
    let tiling = makeTiling(rulePlacement: { placement, _, _ in
      placements.append(placement)
      return .applied
    })
    try tiling.addRule(WindowRule.parse(arguments: ["grid=2:1:1:0:1:1"]))
    #expect(placements.count == 1)
    tiling.setLayout(.master, for: 10)
    try tiling.addRule(WindowRule.parse(arguments: ["display=1"]))
    #expect(placements.count == 2)
    #expect(placements.last?.grid == nil)
    try tiling.addRule(WindowRule.parse(arguments: ["manage=off"]))
    #expect(placements.count == 3)
    #expect(placements.last?.grid != nil)
    #expect(placements.last?.display == nil)
  }
}
