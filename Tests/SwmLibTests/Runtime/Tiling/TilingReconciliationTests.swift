import CoreGraphics
import Testing

@testable import SwmLib

@MainActor
@Suite("Tiling reconciliation")
struct TilingManagerReconciliationTests {
  @Test("start: excludes ineligible windows from disabled Space geometry")
  func startExcludesIneligibleWindowsFromDisabledSpaceGeometry() {
    let manager = makeManager(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10, 11], 3: []]
    )

    manager.start()

    #expect(manager.layoutPlan(for: layoutID(10)) == .disabled)
    #expect(manager.setLayout(.master, for: 10))
    #expect(
      manager.layoutPlan(for: layoutID(10))
        == .layout(.frames([1: CGRect(x: 0, y: 0, width: 1_000, height: 800)]))
    )
  }

  @Test("reconcile: preserves surviving order and enablement across migration")
  func reconcilePreservesSurvivingOrderAndEnablementAcrossMigration() {
    var windows = [window(id: 1), window(id: 2)]
    var memberships: [CGWindowID: Set<UInt64>] = [1: [10], 2: [10]]
    let manager = makeManager(
      windows: { windows },
      memberships: { memberships }
    )
    manager.start()
    manager.setLayout(.master, for: 10)
    manager.windowDidFocus(1)

    windows.append(window(id: 3))
    memberships[2] = [11]
    memberships[3] = [10]
    manager.reconcile()

    #expect(
      manager.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 800),
            3: CGRect(x: 500, y: 0, width: 500, height: 800),
          ])
        )
    )
    #expect(manager.layoutPlan(for: layoutID(11)) == .disabled)
  }

  @Test("dwindle: a new window splits the focused leaf")
  func dwindleNewWindowSplitsFocusedLeaf() {
    var windows = [window(id: 1), window(id: 2), window(id: 3)]
    let manager = makeManager(
      windows: { windows },
      memberships: { [1: [10], 2: [10], 3: [10], 4: [10]] }
    )
    manager.start()
    manager.setLayout(.dwindle, for: 10)
    manager.windowDidFocus(1)

    windows.append(window(id: 4))
    manager.reconcile()

    #expect(
      manager.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 400),
            4: CGRect(x: 0, y: 400, width: 500, height: 400),
            2: CGRect(x: 500, y: 0, width: 500, height: 400),
            3: CGRect(x: 500, y: 400, width: 500, height: 400),
          ])
        )
    )
  }

  @Test("reconcile: preserves minimized leaves but omits them from geometry")
  func reconcilePreservesMinimizedLeavesButOmitsThemFromGeometry() {
    var windows = [window(id: 1), window(id: 2, isMinimized: true)]
    let manager = makeManager(windows: { windows }, memberships: { [1: [10], 2: [10]] })
    manager.start()
    manager.setLayout(.master, for: 10)

    #expect(
      manager.layoutPlan(for: layoutID(10))
        == .layout(.frames([1: CGRect(x: 0, y: 0, width: 1_000, height: 800)]))
    )

    windows[1] = window(id: 2, isMinimized: false)
    manager.reconcile()

    #expect(
      manager.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 800),
            2: CGRect(x: 500, y: 0, width: 500, height: 800),
          ])
        )
    )
  }

  @Test("reconcile: preserves native-fullscreen leaves at their prior position")
  func reconcilePreservesNativeFullscreenLeafPosition() {
    let windows = [window(id: 1), window(id: 2), window(id: 3)]
    var memberships: [CGWindowID: Set<UInt64>] = [1: [10], 2: [10], 3: [10]]
    let manager = makeManager(windows: { windows }, memberships: { memberships })
    manager.start()
    manager.setLayout(.master, for: 10)
    manager.windowDidFocus(3)
    let initialPlan = manager.layoutPlan(for: layoutID(10))

    memberships[1] = [12]
    manager.reconcile()
    memberships[1] = [10]
    manager.reconcile()

    #expect(manager.layoutPlan(for: layoutID(10)) == initialPlan)
  }

  @Test("reconcile: preserves state while display ownership is unresolved")
  func reconcilePreservesStateWhileDisplayOwnershipIsUnresolved() {
    let windows = [window(id: 1), window(id: 2), window(id: 3)]
    var windowServerDisplayID = "display"
    let spaceManager = Spaces(activeSpaceID: nil)
    let manager = Tiling(
      snapshot: {
        TilingReconciliationSnapshot(
          windows: windows,
          topology: SpaceTopology(
            spacesByID: [
              10: SpaceTopologyDescriptor(
                id: 10,
                displayID: windowServerDisplayID,
                type: .normal
              )
            ],
            visibleSpaceIDByDisplayID: [windowServerDisplayID: 10],
            spaceIDsByWindowID: [1: [10], 2: [10], 3: [10]],
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
    manager.start()
    manager.setLayout(.dwindle, for: 10)
    let initialPlan = manager.layoutPlan(for: layoutID(10))

    windowServerDisplayID = "stale-display"
    manager.reconcile()

    windowServerDisplayID = "display"
    manager.reconcile()

    #expect(manager.layoutPlan(for: layoutID(10)) == initialPlan)
  }

  @Test("layoutPlan: requires a visible Space")
  func layoutPlanRequiresVisibleSpace() {
    let hiddenManager = makeManager(visibleSpaceID: 11)
    hiddenManager.start()
    hiddenManager.setLayout(.master, for: 10)

    #expect(hiddenManager.layoutPlan(for: layoutID(10)) == .notVisible)
  }

  @Test("shared Space: tiles and migrates windows independently per monitor")
  func sharedSpaceTilesAndMigratesWindowsIndependentlyPerMonitor() {
    var windows = [
      window(id: 1, displayID: "display-a"),
      window(id: 2, displayID: "display-a"),
      window(id: 3, displayID: "display-b"),
    ]
    let manager = makeSharedSpaceManager(windows: { windows })
    manager.start()

    #expect(manager.setLayout(.master, for: 10))
    #expect(
      manager.layoutPlan(for: layoutID(10, displayID: "display-a"))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 800),
            2: CGRect(x: 500, y: 0, width: 500, height: 800),
          ])
        )
    )
    #expect(
      manager.layoutPlan(for: layoutID(10, displayID: "display-b"))
        == .layout(.frames([3: CGRect(x: 1_000, y: 0, width: 800, height: 800)]))
    )

    windows[1] = window(id: 2, displayID: "display-b")
    manager.reconcile()

    #expect(
      manager.layoutPlan(for: layoutID(10, displayID: "display-a"))
        == .layout(.frames([1: CGRect(x: 0, y: 0, width: 1_000, height: 800)]))
    )
    #expect(
      manager.layoutPlan(for: layoutID(10, displayID: "display-b"))
        == .layout(
          .frames([
            3: CGRect(x: 1_000, y: 0, width: 400, height: 800),
            2: CGRect(x: 1_400, y: 0, width: 400, height: 800),
          ])
        )
    )

    #expect(manager.setLayout(.dwindle, for: 10))
  }

  @Test("shared Space: a new monitor inherits the layout selection")
  func sharedSpaceNewMonitorInheritsState() {
    var displays = [
      "display-a": SpaceTopologyDisplay(
        visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
      )
    ]
    let manager = makeSharedSpaceManager(windows: { [] }, displays: { displays })
    manager.start()
    manager.setLayout(.dwindle, for: 10)

    displays["display-b"] = SpaceTopologyDisplay(
      visibleFrame: CGRect(x: 1_000, y: 0, width: 800, height: 800)
    )
    manager.reconcile()

    #expect(
      manager.layoutPlan(for: layoutID(10, displayID: "display-b")) == .layout(.frames([:]))
    )
  }
}
