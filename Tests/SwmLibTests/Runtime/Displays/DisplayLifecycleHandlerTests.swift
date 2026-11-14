import CoreGraphics
import Testing

@testable import SwmLib

@Suite("DisplayLifecycleHandler")
@MainActor
struct DisplayLifecycleHandlerTests {
  @Test(
    "reconfiguration: retargets layouts to the new display geometry",
    arguments: [
      DisplayEvent.added(2), .removed(2), .moved(1), .resized(1),
    ]
  )
  func reconfigurationRetargetsLayoutsToTheNewDisplayGeometry(
    event: DisplayEvent
  ) async throws {
    let app = AnimationTestApp(processID: 1)
    let reconciler = makeTestReconciler(app)
    var bounds = CGRect(x: 0, y: 0, width: 1_000, height: 800)
    let tiling = makeTiling(
      windows: { [window(id: 1)] },
      memberships: { [1: [10]] },
      displayBounds: { bounds },
      frameReconciler: reconciler
    )
    tiling.initialize()
    tiling.setLayout(.master, for: 10)
    reconciler.animationDuration = 1
    reconciler.apply([1: CGRect(x: 100, y: 0, width: 100, height: 100)])
    try await waitForAnimation { reconciler.isAnimating(1) }

    bounds = CGRect(x: 0, y: 0, width: 1_200, height: 900)
    DisplayLifecycleHandler(displays: Displays(), tiling: tiling).handle(event)

    #expect(tiling.layoutPlan(for: layoutID(10)) == [1: bounds])
    #expect(reconciler.frames(for: [1])[1] == bounds)
  }

  @Test("changed: reconciles the layout")
  func changedReconcilesTheLayout() {
    var snapshots = 0
    let tiling = makeTiling(
      windows: {
        snapshots += 1
        return [window(id: 1)]
      },
      memberships: { [1: [10]] }
    )

    DisplayLifecycleHandler(displays: Displays(), tiling: tiling).handle(.changed)

    #expect(snapshots == 1)
  }
}
