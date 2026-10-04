import CoreGraphics
import Testing

@testable import SwmLib

@MainActor
@Suite("Tiling")
struct TilingScrollingTests {
  @Test(
    "init: a refused width adjusts strip geometry once and keeps the requested fraction"
  )
  func refusedWidth() throws {
    var frames: [CGWindowID: CGRect] = [1: CGRect(x: 0, y: 0, width: 600, height: 800)]
    let reconciler = WindowFrameReconciler(
      currentFrame: { frames[$0] },
      frameMutation: { id, target, _ in
        frames[id] = target
        return .success
      },
      automaticallySchedule: false
    )
    let tiling = makeTiling(frameReconciler: reconciler)
    tiling.initialize()
    tiling.setLayout(.scrolling, for: 10)
    let target = try #require(frames[1])
    frames[1]?.size.width = 600

    reconciler.onFrameDeliveryFailed(1, target, frames[1])

    #expect(frames[1]?.width == 600)
    let layout = try #require(tiling.layoutSnapshots().first { $0.spaceID == 10 })
    #expect(layout.columns.first?.width == 0.5)
    #expect(layout.columns.first?.frame?.width == 600)
    #expect(layout.constraint == nil)
  }

  @Test("shutdown: restores pre-scrolling frames after parking and is idempotent")
  func shutdownRestoration() {
    let originals: [CGWindowID: CGRect] = [
      1: CGRect(x: 20, y: 30, width: 400, height: 300),
      2: CGRect(x: 50, y: 60, width: 400, height: 300),
      3: CGRect(x: 80, y: 90, width: 400, height: 300),
    ]
    var frames = originals
    let reconciler = WindowFrameReconciler(
      currentFrame: { frames[$0] },
      frameMutation: { id, target, _ in
        frames[id] = target
        return .success
      },
      automaticallySchedule: false
    )
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]],
      frameReconciler: reconciler
    )
    tiling.initialize()
    tiling.setLayout(.scrolling, for: 10)
    #expect(frames[3]?.minX == 999)

    tiling.shutdown()
    tiling.shutdown()

    #expect(frames == originals)
    #expect(reconciler.isIdle)
  }

  @Test("reconcile: keeps widths and inserts after focus while new defaults affect new columns")
  func insertionAndWidths() throws {
    var windows = [window(id: 1), window(id: 2), window(id: 3)]
    let tiling = makeTiling(
      windows: { windows },
      memberships: { [1: [10], 2: [10], 3: [10], 4: [10]] }
    )
    tiling.initialize()
    tiling.setLayout(.scrolling, for: 10)
    #expect(tiling.changeColumnWidth(.absolute(1), for: 2) == 1)
    tiling.setScrollingColumnWidth(1.0 / 3)
    tiling.windowDidFocus(1)

    windows.append(window(id: 4))
    tiling.reconcileAndReflowVisibleSpaces()

    let layout = try #require(tiling.layoutSnapshots().first { $0.spaceID == 10 })
    #expect(layout.columns.map(\.window) == [1, 4, 2, 3])
    #expect(layout.columns.map(\.width) == [0.5, 1.0 / 3, 1, 0.5])
  }

  @Test("reconcile: retains parked ownership even when physical display facts disappear")
  func parkedOwnership() throws {
    var snapshots = [window(id: 1), window(id: 2), window(id: 3)]
    let tiling = makeTiling(windows: { snapshots }, memberships: { [1: [10], 2: [10], 3: [10]] })
    tiling.initialize()
    tiling.setLayout(.scrolling, for: 10)
    snapshots[2].displayID = nil

    tiling.reconcileAndReflowVisibleSpaces()

    let layout = try #require(tiling.layoutSnapshots().first { $0.spaceID == 10 })
    #expect(layout.columns.last?.isOmitted == false)
    #expect(layout.columns.last?.isParked == true)
    #expect(tiling.scrollingNeighbor(of: 2, in: .right) == 3)

    tiling.releaseScrollingWindow(3)
    tiling.reconcile()
    let released = try #require(tiling.layoutSnapshots().first { $0.spaceID == 10 })
    #expect(released.columns.last?.isOmitted == true)
  }

  @Test("reconcile: retains native fullscreen columns and restores them on return")
  func fullscreenReturn() throws {
    var memberships: [CGWindowID: Set<UInt64>] = [1: [10], 2: [10], 3: [10]]
    let tiling = makeTiling(
      windows: { [window(id: 1), window(id: 2), window(id: 3)] },
      memberships: { memberships }
    )
    tiling.initialize()
    tiling.setLayout(.scrolling, for: 10)
    tiling.changeColumnWidth(.absolute(2.0 / 3), for: 2)

    memberships[2] = [12]
    tiling.reconcileAndReflowVisibleSpaces()
    let fullscreen = try #require(tiling.layoutSnapshots().first { $0.spaceID == 10 })
    #expect(fullscreen.columns[1].isOmitted)
    #expect(fullscreen.columns[1].width == 2.0 / 3)

    memberships[2] = [10]
    tiling.reconcileAndReflowVisibleSpaces()
    let returned = try #require(tiling.layoutSnapshots().first { $0.spaceID == 10 })
    #expect(!returned.columns[1].isOmitted)
    #expect(returned.columns[1].width == 2.0 / 3)
  }

  @Test("reconcile: independent shared-Space displays retain column widths during a drag transfer")
  func sharedSpaceTransfer() throws {
    var frames: [CGWindowID: CGRect] = [1: CGRect(x: 0, y: 0, width: 400, height: 300)]
    var displayID = "a"
    let reconciler = WindowFrameReconciler(
      currentFrame: { frames[$0] },
      frameMutation: { id, target, _ in
        frames[id] = target
        return .success
      },
      automaticallySchedule: false
    )
    let spaces = Spaces(activeSpaceID: nil)
    let tiling = Tiling(
      snapshot: {
        TilingReconciliationSnapshot(
          windows: [window(id: 1, displayID: displayID)],
          topology: SpaceTopology(
            spacesByID: [10: SpaceTopologyDescriptor(id: 10, displayID: "Main", type: .normal)],
            visibleSpaceIDByDisplayID: ["Main": 10],
            spaceIDsByWindowID: [1: [10]],
            displaysByID: [
              "a": SpaceTopologyDisplay(
                visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
              ),
              "b": SpaceTopologyDisplay(
                visibleFrame: CGRect(x: 1_000, y: 0, width: 800, height: 800)
              ),
            ]
          )
        )
      },
      spaces: spaces,
      frameReconciler: reconciler
    )
    tiling.initialize()
    tiling.setLayoutForSpaces(.scrolling)
    tiling.changeColumnWidth(.absolute(2.0 / 3), for: 1)

    reconciler.beginInteraction(for: 1)
    frames[1] = CGRect(x: 1_100, y: 20, width: 400, height: 300)
    displayID = "b"
    reconciler.endInteractions()

    let layouts = tiling.layoutSnapshots()
    #expect(layouts.first { $0.displayID == "a" }?.columns.isEmpty == true)
    let destination = try #require(layouts.first { $0.displayID == "b" })
    #expect(destination.columns.first?.window == 1)
    #expect(destination.columns.first?.width == 2.0 / 3)
    #expect(frames[1]?.minX == 1_000)
  }

  @Test("setLayout: defaults set before enabling scrolling size the initial columns")
  func initialWidthDefault() throws {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2)],
      memberships: [1: [10], 2: [10]]
    )
    tiling.initialize()
    tiling.setScrollingColumnWidth(2.0 / 3)

    tiling.setLayout(.scrolling, for: 10)

    let layout = try #require(tiling.layoutSnapshots().first { $0.spaceID == 10 })
    #expect(layout.columns.map(\.width) == [2.0 / 3, 2.0 / 3])
  }

  @Test("setLayout: retains scrolling order and widths through other layouts")
  func layoutSwitching() throws {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.scrolling, for: 10)
    tiling.changeColumnWidth(.absolute(1), for: 3)
    #expect(tiling.swapWindow(3, in: .left))

    tiling.setLayout(.dwindle, for: 10)
    tiling.setLayout(.scrolling, for: 10)

    let layout = try #require(tiling.layoutSnapshots().first { $0.spaceID == 10 })
    #expect(layout.columns.map(\.window) == [1, 3, 2])
    #expect(layout.columns.map(\.width) == [0.5, 1, 0.5])
  }

  @Test("scrollingNeighbor: stops at strip edges and skips minimized and floating windows")
  func logicalNavigation() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2, isMinimized: true), window(id: 3), window(id: 4)],
      memberships: [1: [10], 2: [10], 3: [10], 4: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.scrolling, for: 10)
    tiling.setWindowLayout(.float, for: 3)

    #expect(tiling.scrollingNeighbor(of: 1, in: .right) == 4)
    #expect(tiling.scrollingNeighbor(of: 4, in: .right) == nil)
    #expect(tiling.scrollingNeighbor(of: 1, in: .left) == nil)
    #expect(tiling.scrollingNeighbor(of: 1, in: .up) == nil)
    #expect(tiling.cycledWindowID(from: 4, in: .next) == 1)
    #expect(tiling.cycledWindowID(from: 1, in: .prev) == 4)
    #expect(tiling.swapWindowInOrder(1, in: .prev))
    #expect(tiling.scrollingNeighbor(of: 4, in: .right) == 1)
  }

  @Test("prepareForFocus: reveals distant columns and centerColumn centers either end")
  func revealAndCenter() throws {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.scrolling, for: 10)

    #expect(tiling.prepareForFocus(3))
    var layout = try #require(tiling.layoutSnapshots().first { $0.spaceID == 10 })
    #expect(layout.viewportOffset == 500)
    #expect(layout.columns.last?.isParked == false)
    #expect(tiling.centerColumn(for: 1))
    layout = try #require(tiling.layoutSnapshots().first { $0.spaceID == 10 })
    #expect(layout.viewportOffset == -250)

    tiling.setScrollingFocusFit(.center)
    tiling.windowDidFocus(3)
    layout = try #require(tiling.layoutSnapshots().first { $0.spaceID == 10 })
    #expect(layout.viewportOffset == 750)
  }

  @Test("layoutSnapshots: queries do not change the viewport")
  func readOnlySnapshots() throws {
    let tiling = makeTiling()
    tiling.initialize()
    tiling.setLayout(.scrolling, for: 10)
    tiling.centerColumn(for: 1)

    let first = try #require(tiling.layoutSnapshots().first { $0.spaceID == 10 })
    let second = try #require(tiling.layoutSnapshots().first { $0.spaceID == 10 })

    #expect(first.viewportOffset == second.viewportOffset)
    #expect(first.columns.first?.frame == second.columns.first?.frame)
    #expect(!tiling.centerColumn(for: 99))
    #expect(tiling.changeColumnWidth(.absolute(0.5), for: 99) == nil)
  }

  @Test("setWindowLayout: floating a parked window restores its frame")
  func floatingRestoration() {
    let original = CGRect(x: 80, y: 90, width: 400, height: 300)
    var frames: [CGWindowID: CGRect] = [1: original, 2: original, 3: original]
    let reconciler = WindowFrameReconciler(
      currentFrame: { frames[$0] },
      frameMutation: { id, target, _ in
        frames[id] = target
        return .success
      },
      automaticallySchedule: false
    )
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]],
      frameReconciler: reconciler
    )
    tiling.initialize()
    tiling.setLayout(.scrolling, for: 10)

    #expect(tiling.setWindowLayout(.float, for: 3))
    #expect(frames[3] == original)
    #expect(tiling.setWindowLayout(.tile, for: 3))
    #expect(frames[3]?.minX == 999)

    tiling.setLayout(.float, for: 10)
    #expect(frames.values.allSatisfy { $0 == original })
  }
}
