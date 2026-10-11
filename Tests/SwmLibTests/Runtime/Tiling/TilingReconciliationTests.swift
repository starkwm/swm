import CoreGraphics
import Testing

@testable import SwmLib

extension TilingTests {
  @Test("initialize: excludes ineligible windows from disabled Space geometry")
  func initializeExcludesIneligibleWindowsFromDisabledSpaceGeometry() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10, 11], 3: []]
    )

    tiling.initialize()

    #expect(tiling.layoutPlan(for: layoutID(10)) == .disabled)
    #expect(tiling.setLayout(.master, for: 10))
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(.frames([1: CGRect(x: 0, y: 0, width: 1_000, height: 800)]))
    )
  }

  @Test("reconcile: preserves surviving order and enablement across migration")
  func reconcilePreservesSurvivingOrderAndEnablementAcrossMigration() {
    var windows = [window(id: 1), window(id: 2)]
    var memberships: [CGWindowID: Set<UInt64>] = [1: [10], 2: [10]]
    let tiling = makeTiling(
      windows: { windows },
      memberships: { memberships }
    )
    tiling.initialize()
    tiling.setLayout(.master, for: 10)
    tiling.windowDidFocus(1)

    windows.append(window(id: 3))
    memberships[2] = [11]
    memberships[3] = [10]
    tiling.reconcile()

    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 800),
            3: CGRect(x: 500, y: 0, width: 500, height: 800),
          ])
        )
    )
    #expect(tiling.layoutPlan(for: layoutID(11)) == .disabled)
  }

  @Test(
    "reconcile: preserves order and settings across batched removals"
  )
  func reconcilePreservesOrderAndSettingsAcrossBatchedRemovals() {
    var candidates = (1...6).map { window(id: CGWindowID($0)) }
    let tiling = makeTiling(
      windows: { candidates },
      memberships: {
        Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, Set([UInt64(10)])) })
      }
    )
    tiling.initialize()
    #expect(tiling.setLayout(.master, for: 10))
    #expect(tiling.changeMasterRatio(.absolute(0.65), for: 10))
    #expect(tiling.swapWindowWithMaster(4))
    tiling.windowDidFocus(3)

    candidates = [
      window(id: 1, isMinimized: true), window(id: 3), window(id: 4), window(id: 7), window(id: 8),
    ]
    tiling.reconcile()
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            4: CGRect(x: 0, y: 0, width: 650, height: 800),
            3: CGRect(x: 650, y: 0, width: 350, height: 267),
            7: CGRect(x: 650, y: 267, width: 350, height: 266),
            8: CGRect(x: 650, y: 533, width: 350, height: 267),
          ])
        )
    )

    candidates[0] = window(id: 1)
    tiling.reconcile()
    #expect(tiling.cycledWindowID(from: 4, in: .next) == 3)
    #expect(tiling.cycledWindowID(from: 3, in: .next) == 7)
    #expect(tiling.cycledWindowID(from: 7, in: .next) == 8)
    #expect(tiling.cycledWindowID(from: 8, in: .next) == 1)
    #expect(tiling.cycledWindowID(from: 1, in: .next) == 4)

    candidates = [window(id: 9)]
    tiling.reconcile()
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            9: CGRect(x: 0, y: 0, width: 1000, height: 800)
          ])
        )
    )
  }

  @Test("reconcile: a new window splits the focused leaf")
  func reconcileANewWindowSplitsTheFocusedLeaf() {
    var windows = [window(id: 1), window(id: 2), window(id: 3)]
    let tiling = makeTiling(
      windows: { windows },
      memberships: { [1: [10], 2: [10], 3: [10], 4: [10]] }
    )
    tiling.initialize()
    tiling.setLayout(.dwindle, for: 10)
    tiling.windowDidFocus(1)

    windows.append(window(id: 4))
    tiling.reconcile()

    #expect(
      tiling.layoutPlan(for: layoutID(10))
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
    let tiling = makeTiling(windows: { windows }, memberships: { [1: [10], 2: [10]] })
    tiling.initialize()
    tiling.setLayout(.master, for: 10)

    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(.frames([1: CGRect(x: 0, y: 0, width: 1_000, height: 800)]))
    )

    windows[1] = window(id: 2, isMinimized: false)
    tiling.reconcile()

    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 800),
            2: CGRect(x: 500, y: 0, width: 500, height: 800),
          ])
        )
    )
  }

  @Test("reconcile: preserves native-fullscreen leaves at their prior position")
  func reconcilePreservesNativeFullscreenLeavesAtTheirPriorPosition() {
    let windows = [window(id: 1), window(id: 2), window(id: 3)]
    var memberships: [CGWindowID: Set<UInt64>] = [1: [10], 2: [10], 3: [10]]
    let tiling = makeTiling(windows: { windows }, memberships: { memberships })
    tiling.initialize()
    tiling.setLayout(.master, for: 10)
    tiling.windowDidFocus(3)
    let initialPlan = tiling.layoutPlan(for: layoutID(10))

    memberships[1] = [12]
    tiling.reconcile()
    memberships[1] = [10]
    tiling.reconcile()

    #expect(tiling.layoutPlan(for: layoutID(10)) == initialPlan)
  }

  @Test("reconcile: preserves state while display ownership is unresolved")
  func reconcilePreservesStateWhileDisplayOwnershipIsUnresolved() {
    let windows = [window(id: 1), window(id: 2), window(id: 3)]
    var windowServerDisplayID = "display"
    let spaces = Spaces(activeSpaceID: nil)
    let tiling = Tiling(
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
      spaces: spaces
    )
    tiling.initialize()
    tiling.setLayout(.dwindle, for: 10)
    let initialPlan = tiling.layoutPlan(for: layoutID(10))

    windowServerDisplayID = "stale-display"
    tiling.reconcile()

    windowServerDisplayID = "display"
    tiling.reconcile()

    #expect(tiling.layoutPlan(for: layoutID(10)) == initialPlan)
  }

  @Test("reconcile: tiles and migrates windows independently per monitor")
  func reconcileTilesAndMigratesWindowsIndependentlyPerMonitor() {
    var windows = [
      window(id: 1, displayID: "display-a"),
      window(id: 2, displayID: "display-a"),
      window(id: 3, displayID: "display-b"),
    ]
    let tiling = makeSharedSpaceTiling(windows: { windows })
    tiling.initialize()

    #expect(tiling.setLayout(.master, for: 10))
    #expect(
      tiling.layoutPlan(for: layoutID(10, displayID: "display-a"))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 800),
            2: CGRect(x: 500, y: 0, width: 500, height: 800),
          ])
        )
    )
    #expect(
      tiling.layoutPlan(for: layoutID(10, displayID: "display-b"))
        == .layout(.frames([3: CGRect(x: 1_000, y: 0, width: 800, height: 800)]))
    )

    windows[1] = window(id: 2, displayID: "display-b")
    tiling.reconcile()

    #expect(
      tiling.layoutPlan(for: layoutID(10, displayID: "display-a"))
        == .layout(.frames([1: CGRect(x: 0, y: 0, width: 1_000, height: 800)]))
    )
    #expect(
      tiling.layoutPlan(for: layoutID(10, displayID: "display-b"))
        == .layout(
          .frames([
            3: CGRect(x: 1_000, y: 0, width: 400, height: 800),
            2: CGRect(x: 1_400, y: 0, width: 400, height: 800),
          ])
        )
    )

    #expect(tiling.setLayout(.dwindle, for: 10))
  }

  @Test("reconcile: a new monitor inherits the layout selection")
  func reconcileANewMonitorInheritsTheLayoutSelection() {
    var displays = [
      "display-a": SpaceTopologyDisplay(
        visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
      )
    ]
    let tiling = makeSharedSpaceTiling(windows: { [] }, displays: { displays })
    tiling.initialize()
    tiling.setLayout(.dwindle, for: 10)

    displays["display-b"] = SpaceTopologyDisplay(
      visibleFrame: CGRect(x: 1_000, y: 0, width: 800, height: 800)
    )
    tiling.reconcile()

    #expect(
      tiling.layoutPlan(for: layoutID(10, displayID: "display-b")) == .layout(.frames([:]))
    )
  }

  @Test(
    "windowDidFocus: retains pending focus unless a newer focus event supersedes it",
    arguments: [false, true]
  )
  func windowDidFocusRetainsPendingFocusUnlessANewerFocusEventSupersedesIt(focusChanged: Bool) {
    var windows = [window(id: 1)]
    var memberships: [CGWindowID: Set<UInt64>] = [1: [10]]
    let tiling = makeTiling(windows: { windows }, memberships: { memberships })
    tiling.initialize()
    tiling.setLayout(.dwindle, for: 10)
    tiling.windowDidFocus(1)

    windows.append(window(id: 2))
    tiling.reconcile()
    tiling.windowDidFocus(2)
    tiling.reconcile()
    if focusChanged {
      tiling.windowDidFocus(1)
    }

    memberships[2] = [10]
    tiling.reconcile()
    windows.append(window(id: 3))
    memberships[3] = [10]
    tiling.reconcile()

    let expectedFrames: [CGWindowID: CGRect] =
      focusChanged
      ? [
        1: CGRect(x: 0, y: 0, width: 500, height: 400),
        3: CGRect(x: 0, y: 400, width: 500, height: 400),
        2: CGRect(x: 500, y: 0, width: 500, height: 800),
      ]
      : [
        1: CGRect(x: 0, y: 0, width: 500, height: 800),
        2: CGRect(x: 500, y: 0, width: 500, height: 400),
        3: CGRect(x: 500, y: 400, width: 500, height: 400),
      ]
    #expect(tiling.layoutPlan(for: layoutID(10)) == .layout(.frames(expectedFrames)))
  }

  @Test("layoutPlan: requires a visible Space")
  func layoutPlanRequiresAVisibleSpace() {
    let hiddenTiling = makeTiling(visibleSpaceID: 11)
    hiddenTiling.initialize()
    hiddenTiling.setLayout(.master, for: 10)

    #expect(hiddenTiling.layoutPlan(for: layoutID(10)) == .notVisible)
  }

  @Test("membership polling: reflows without lifecycle events")
  func membershipPollingReflowsWithoutLifecycleEvents() async throws {
    let windows = [window(id: 1), window(id: 2), window(id: 3)]
    var memberships: [CGWindowID: Set<UInt64>] = [1: [10], 2: [10], 3: [11]]
    var framesByWindowID: [CGWindowID: CGRect] = [
      1: .zero,
      2: .zero,
      3: .zero,
    ]
    let frameReconciler = WindowFrameReconciler(
      currentFrame: { framesByWindowID[$0] },
      frameMutation: { windowID, targetFrame, _ in
        framesByWindowID[windowID] = targetFrame
        return .success
      }
    )
    let tiling = makeTiling(
      windows: { windows },
      memberships: { memberships },
      frameReconciler: frameReconciler
    )
    tiling.initialize()
    tiling.setLayout(.master, for: 10)
    tiling.windowFrameDidChange(2)

    memberships[2] = [11]
    for _ in 0..<100 where framesByWindowID[1]?.width != 1_000 {
      try await Task.sleep(for: .milliseconds(10))
    }

    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(.frames([1: CGRect(x: 0, y: 0, width: 1_000, height: 800)]))
    )
    #expect(framesByWindowID[1] == CGRect(x: 0, y: 0, width: 1_000, height: 800))

    framesByWindowID[3] = CGRect(x: 100, y: 100, width: 300, height: 300)
    memberships[3] = [10]
    for _ in 0..<100 where framesByWindowID[3]?.origin.x != 500 {
      try await Task.sleep(for: .milliseconds(10))
    }

    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 800),
            3: CGRect(x: 500, y: 0, width: 500, height: 800),
          ])
        )
    )
    #expect(framesByWindowID[3] == CGRect(x: 500, y: 0, width: 500, height: 800))
  }
}
