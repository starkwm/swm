import CoreGraphics
import Testing

@testable import SwmLib

@MainActor
@Suite("TilingManager")
struct TilingManagerTests {
  @Test("start: excludes ineligible windows from disabled Space geometry")
  func startExcludesIneligibleWindowsFromDisabledSpaceGeometry() {
    let manager = makeManager(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10, 11], 3: []]
    )

    manager.start()

    #expect(manager.isEnabled(for: 10) == false)
    #expect(manager.layoutMode(for: 10) == .masterStack)
    #expect(manager.layoutPlan(for: layoutID(10)) == .disabled)
    #expect(manager.setEnabled(true, for: 10))
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
    manager.setEnabled(true, for: 10)
    manager.windowDidFocus(1)

    windows.append(window(id: 3))
    memberships[2] = [11]
    memberships[3] = [10]
    manager.reconcile()

    #expect(manager.isEnabled(for: 10))
    #expect(manager.isEnabled(for: 11) == false)
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

  @Test("setLayoutMode: retains dwindle selection and plans its geometry")
  func setLayoutModeRetainsDwindleSelectionAndPlansItsGeometry() {
    let manager = makeManager(
      windows: [window(id: 1), window(id: 2), window(id: 3), window(id: 4)],
      memberships: [1: [10], 2: [10], 3: [10], 4: [10]]
    )
    manager.start()

    #expect(manager.layoutMode(for: 10) == .master)
    #expect(manager.setLayoutMode(.dwindle, for: 10))
    #expect(manager.setLayoutMode(.dwindle, for: 99) == false)
    manager.setEnabled(true, for: 10)

    #expect(manager.layoutMode(for: 10) == .dwindle)
    #expect(
      manager.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 800),
            2: CGRect(x: 500, y: 0, width: 500, height: 400),
            3: CGRect(x: 500, y: 400, width: 250, height: 400),
            4: CGRect(x: 750, y: 400, width: 250, height: 400),
          ])
        )
    )

    manager.reconcile()

    #expect(manager.layoutMode(for: 10) == .dwindle)
  }

  @Test("dwindle: a new window splits the focused leaf")
  func dwindleNewWindowSplitsFocusedLeaf() {
    var windows = [window(id: 1), window(id: 2), window(id: 3)]
    let manager = makeManager(
      windows: { windows },
      memberships: { [1: [10], 2: [10], 3: [10], 4: [10]] }
    )
    manager.start()
    manager.setLayoutMode(.dwindle, for: 10)
    manager.setEnabled(true, for: 10)
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
    manager.setEnabled(true, for: 10)

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

  @Test("layoutPlan: requires a visible Space")
  func layoutPlanRequiresVisibleSpace() {
    let hiddenManager = makeManager(visibleSpaceID: 11)
    hiddenManager.start()
    hiddenManager.setEnabled(true, for: 10)

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

    #expect(manager.setEnabled(true, for: 10))
    #expect(manager.isEnabled(for: 10))
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

    #expect(manager.setLayoutMode(.dwindle, for: 10))
    #expect(manager.layoutMode(for: 10) == .dwindle)
  }

  private func makeManager(
    windows: [TilingWindowSnapshot] = [window(id: 1)],
    memberships: [CGWindowID: Set<UInt64>] = [1: [10]],
    visibleSpaceID: UInt64 = 10
  ) -> TilingManager {
    makeManager(
      windows: { windows },
      memberships: { memberships },
      visibleSpaceID: visibleSpaceID
    )
  }

  private func makeManager(
    windows: @escaping () -> [TilingWindowSnapshot],
    memberships: @escaping () -> [CGWindowID: Set<UInt64>],
    visibleSpaceID: UInt64 = 10
  ) -> TilingManager {
    let spaceManager = SpaceManager(activeSpaceID: nil)
    return TilingManager(
      snapshot: {
        TilingReconciliationSnapshot(
          windows: windows(),
          topology: SpaceTopology(
            spacesByID: [
              10: SpaceTopologyDescriptor(id: 10, displayID: "display", type: .normal),
              11: SpaceTopologyDescriptor(id: 11, displayID: "display", type: .normal),
            ],
            visibleSpaceIDByDisplayID: ["display": visibleSpaceID],
            spaceIDsByWindowID: memberships(),
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
  }

  private func makeSharedSpaceManager(
    windows: @escaping () -> [TilingWindowSnapshot]
  ) -> TilingManager {
    let spaceManager = SpaceManager(activeSpaceID: nil)
    return TilingManager(
      snapshot: {
        let windows = windows()
        return TilingReconciliationSnapshot(
          windows: windows,
          topology: SpaceTopology(
            spacesByID: [
              10: SpaceTopologyDescriptor(id: 10, displayID: "Main", type: .normal),
              11: SpaceTopologyDescriptor(id: 11, displayID: "Main", type: .normal),
            ],
            visibleSpaceIDByDisplayID: ["Main": 10],
            spaceIDsByWindowID: Dictionary(
              uniqueKeysWithValues: windows.map { ($0.id, Set([UInt64(10)])) }
            ),
            displaysByID: [
              "display-a": SpaceTopologyDisplay(
                visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
              ),
              "display-b": SpaceTopologyDisplay(
                visibleFrame: CGRect(x: 1_000, y: 0, width: 800, height: 800)
              ),
            ]
          )
        )
      },
      spaceManager: spaceManager
    )
  }
}

private func layoutID(
  _ spaceID: UInt64,
  displayID: String = "display"
) -> SpaceLayoutID {
  SpaceLayoutID(spaceID: spaceID, displayID: displayID)
}

private func window(
  id: CGWindowID,
  displayID: String? = "display",
  isMinimized: Bool = false
) -> TilingWindowSnapshot {
  TilingWindowSnapshot(
    id: id,
    displayID: displayID,
    subrole: "AXStandardWindow",
    isMinimized: isMinimized,
    isMovable: true,
    isResizable: true
  )
}
