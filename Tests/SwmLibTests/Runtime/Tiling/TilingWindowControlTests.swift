import CoreGraphics
import Testing

@testable import SwmLib

@MainActor
@Suite("Tiling window controls")
struct TilingWindowControlTests {
  @Test("master controls: swap a selected window with master")
  func masterControlsSwapSelectedWindowWithMaster() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.master, for: 10)

    #expect(tiling.swapWindowWithMaster(3))
    #expect(tiling.swapWindowWithMaster(99) == false)
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            3: CGRect(x: 0, y: 0, width: 500, height: 800),
            2: CGRect(x: 500, y: 0, width: 500, height: 400),
            1: CGRect(x: 500, y: 400, width: 500, height: 400),
          ])
        )
    )
  }

  @Test("master controls: find the first available master window")
  func masterControlsFindAvailableMasterWindow() {
    let tiling = makeTiling(
      windows: [window(id: 1, isMinimized: true), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.master, for: 10)

    #expect(tiling.masterWindowID(inLayoutContaining: 3) == 2)
    #expect(tiling.setWindowLayout(.float, for: 2))
    #expect(tiling.masterWindowID(inLayoutContaining: 3) == 3)

    tiling.setLayout(.dwindle, for: 10)
    #expect(tiling.masterWindowID(inLayoutContaining: 3) == nil)
  }

  @Test("directional swap: exchanges neighbouring windows in master")
  func directionalSwapExchangesMasterNeighbors() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.master, for: 10)

    #expect(tiling.swapWindow(2, in: .down))
    #expect(tiling.swapWindow(2, in: .down) == false)
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

  @Test("directional swap: exchanges neighbouring windows in dwindle")
  func directionalSwapExchangesDwindleNeighbors() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.dwindle, for: 10)

    #expect(tiling.swapWindow(2, in: .down))
    #expect(tiling.swapWindow(99, in: .left) == false)
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

  @Test("window layout: float removes a window and tile restores it")
  func windowLayoutFloatsAndRestoresWindow() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.master, for: 10)
    let initialPlan = tiling.layoutPlan(for: layoutID(10))

    #expect(tiling.setWindowLayout(.float, for: 2))
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

    #expect(tiling.setWindowLayout(.tile, for: 2))
    #expect(tiling.layoutPlan(for: layoutID(10)) == initialPlan)
  }

  @Test("window layout: toggle alternates floating participation")
  func windowLayoutToggleAlternatesParticipation() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2)],
      memberships: [1: [10], 2: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.master, for: 10)
    let tiledPlan = tiling.layoutPlan(for: layoutID(10))

    #expect(tiling.setWindowLayout(.toggle, for: 2))
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(.frames([1: CGRect(x: 0, y: 0, width: 1_000, height: 800)]))
    )

    #expect(tiling.setWindowLayout(.toggle, for: 2))
    #expect(tiling.layoutPlan(for: layoutID(10)) == tiledPlan)
  }

  @Test("window cycle: follows layout order, wraps, and skips unavailable windows")
  func windowCycleFollowsAvailableLayoutOrder() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3, isMinimized: true)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.dwindle, for: 10)

    #expect(tiling.cycledWindowID(from: 1, in: .next) == 2)
    #expect(tiling.cycledWindowID(from: 2, in: .next) == 1)
    #expect(tiling.cycledWindowID(from: 1, in: .prev) == 2)

    #expect(tiling.setWindowLayout(.float, for: 2))
    #expect(tiling.cycledWindowID(from: 1, in: .next) == nil)
  }

  @Test("window cycle: resumes on the active Space after the focused window closes")
  func windowCycleResumesAfterFocusedWindowCloses() {
    var windows = [window(id: 1), window(id: 2), window(id: 3), window(id: 4, isMinimized: true)]
    let tiling = makeTiling(
      windows: { windows },
      memberships: { [1: [10], 2: [10], 3: [10], 4: [10]] }
    )
    tiling.initialize()
    tiling.windowDidFocus(1)
    windows.removeAll { $0.id == 1 }
    tiling.reconcile()

    #expect(tiling.cycledWindowID(from: nil, in: .next, fallbackSpaceID: 10) == 2)
    #expect(tiling.cycledWindowID(from: nil, in: .prev, fallbackSpaceID: 10) == 3)
    #expect(tiling.cycledWindowID(from: 1, in: .next, fallbackSpaceID: 10) == 2)
    #expect(tiling.cycledWindowID(from: 2, in: .next) == 3)
    #expect(tiling.cycledWindowID(from: 3, in: .next) == 2)
    #expect(tiling.cycledWindowID(from: nil, in: .next, fallbackSpaceID: 99) == nil)

    windows.removeAll { $0.id == 3 }
    tiling.reconcile()
    #expect(tiling.cycledWindowID(from: nil, in: .next, fallbackSpaceID: 10) == 2)
    #expect(tiling.cycledWindowID(from: 2, in: .next) == nil)

    windows.removeAll { $0.id == 2 }
    tiling.reconcile()
    #expect(tiling.cycledWindowID(from: nil, in: .next, fallbackSpaceID: 10) == nil)
  }

  @Test("window swap cycle: exchanges adjacent leaves and wraps")
  func windowSwapCycleExchangesAdjacentLeaves() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.master, for: 10)

    #expect(tiling.swapWindowInOrder(1, in: .prev))
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            3: CGRect(x: 0, y: 0, width: 500, height: 800),
            2: CGRect(x: 500, y: 0, width: 500, height: 400),
            1: CGRect(x: 500, y: 400, width: 500, height: 400),
          ])
        )
    )

    tiling.setLayout(.float, for: 10)
    #expect(tiling.swapWindowInOrder(1, in: .next) == false)
  }

  @Test("window layout: floating the insertion anchor excludes it from focused insertion")
  func windowLayoutFloatingInsertionAnchor() {
    var windows = [window(id: 1), window(id: 2), window(id: 3)]
    let tiling = makeTiling(
      windows: { windows },
      memberships: { [1: [10], 2: [10], 3: [10], 4: [10]] }
    )
    tiling.initialize()
    tiling.setLayout(.dwindle, for: 10)
    tiling.windowDidFocus(1)

    #expect(tiling.setWindowLayout(.float, for: 1))
    windows.append(window(id: 4))
    tiling.reconcile()

    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            2: CGRect(x: 0, y: 0, width: 500, height: 800),
            3: CGRect(x: 500, y: 0, width: 500, height: 400),
            4: CGRect(x: 500, y: 400, width: 500, height: 400),
          ])
        )
    )
  }
}
