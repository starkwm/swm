import CoreGraphics
import Testing

@testable import SwmLib

@MainActor
@Suite("TilingManager window controls")
struct TilingManagerWindowControlTests {
  @Test("master controls: swap a selected window with master")
  func masterControlsSwapSelectedWindowWithMaster() {
    let manager = makeManager(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    manager.start()
    manager.setLayout(.master, for: 10)

    #expect(manager.swapWindowWithMaster(3))
    #expect(manager.swapWindowWithMaster(99) == false)
    #expect(
      manager.layoutPlan(for: layoutID(10))
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
    let manager = makeManager(
      windows: [window(id: 1, isMinimized: true), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    manager.start()
    manager.setLayout(.master, for: 10)

    #expect(manager.masterWindowID(inLayoutContaining: 3) == 2)
    #expect(manager.setWindowLayout(.float, for: 2))
    #expect(manager.masterWindowID(inLayoutContaining: 3) == 3)

    manager.setLayout(.dwindle, for: 10)
    #expect(manager.masterWindowID(inLayoutContaining: 3) == nil)
  }

  @Test("directional swap: exchanges neighbouring windows in master")
  func directionalSwapExchangesMasterNeighbors() {
    let manager = makeManager(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    manager.start()
    manager.setLayout(.master, for: 10)

    #expect(manager.swapWindow(2, in: .down))
    #expect(manager.swapWindow(2, in: .down) == false)
    #expect(
      manager.layoutPlan(for: layoutID(10))
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
    let manager = makeManager(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    manager.start()
    manager.setLayout(.dwindle, for: 10)

    #expect(manager.swapWindow(2, in: .down))
    #expect(manager.swapWindow(99, in: .left) == false)
    #expect(
      manager.layoutPlan(for: layoutID(10))
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
    let manager = makeManager(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    manager.start()
    manager.setLayout(.master, for: 10)
    let initialPlan = manager.layoutPlan(for: layoutID(10))

    #expect(manager.setWindowLayout(.float, for: 2))
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

    #expect(manager.setWindowLayout(.tile, for: 2))
    #expect(manager.layoutPlan(for: layoutID(10)) == initialPlan)
  }

  @Test("window layout: toggle alternates floating participation")
  func windowLayoutToggleAlternatesParticipation() {
    let manager = makeManager(
      windows: [window(id: 1), window(id: 2)],
      memberships: [1: [10], 2: [10]]
    )
    manager.start()
    manager.setLayout(.master, for: 10)
    let tiledPlan = manager.layoutPlan(for: layoutID(10))

    #expect(manager.setWindowLayout(.toggle, for: 2))
    #expect(
      manager.layoutPlan(for: layoutID(10))
        == .layout(.frames([1: CGRect(x: 0, y: 0, width: 1_000, height: 800)]))
    )

    #expect(manager.setWindowLayout(.toggle, for: 2))
    #expect(manager.layoutPlan(for: layoutID(10)) == tiledPlan)
  }

  @Test("window cycle: follows layout order, wraps, and skips unavailable windows")
  func windowCycleFollowsAvailableLayoutOrder() {
    let manager = makeManager(
      windows: [window(id: 1), window(id: 2), window(id: 3, isMinimized: true)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    manager.start()
    manager.setLayout(.dwindle, for: 10)

    #expect(manager.cycledWindowID(from: 1, in: .next) == 2)
    #expect(manager.cycledWindowID(from: 2, in: .next) == 1)
    #expect(manager.cycledWindowID(from: 1, in: .prev) == 2)

    #expect(manager.setWindowLayout(.float, for: 2))
    #expect(manager.cycledWindowID(from: 1, in: .next) == nil)
  }

  @Test("window swap cycle: exchanges adjacent leaves and wraps")
  func windowSwapCycleExchangesAdjacentLeaves() {
    let manager = makeManager(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    manager.start()
    manager.setLayout(.master, for: 10)

    #expect(manager.swapWindowInOrder(1, in: .prev))
    #expect(
      manager.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            3: CGRect(x: 0, y: 0, width: 500, height: 800),
            2: CGRect(x: 500, y: 0, width: 500, height: 400),
            1: CGRect(x: 500, y: 400, width: 500, height: 400),
          ])
        )
    )

    manager.setLayout(.float, for: 10)
    #expect(manager.swapWindowInOrder(1, in: .next) == false)
  }

  @Test("window layout: floating the insertion anchor excludes it from focused insertion")
  func windowLayoutFloatingInsertionAnchor() {
    var windows = [window(id: 1), window(id: 2), window(id: 3)]
    let manager = makeManager(
      windows: { windows },
      memberships: { [1: [10], 2: [10], 3: [10], 4: [10]] }
    )
    manager.start()
    manager.setLayout(.dwindle, for: 10)
    manager.windowDidFocus(1)

    #expect(manager.setWindowLayout(.float, for: 1))
    windows.append(window(id: 4))
    manager.reconcile()

    #expect(
      manager.layoutPlan(for: layoutID(10))
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
