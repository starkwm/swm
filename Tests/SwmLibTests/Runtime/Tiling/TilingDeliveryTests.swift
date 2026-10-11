import AppKit
import Testing

@testable import SwmLib

extension TilingTests {
  @Test("windowFrameDidChange: suppresses failed settlement feedback")
  func windowFrameDidChangeSuppressesFailedSettlementFeedback() async throws {
    let app = AnimationTestApp(processID: 1)
    app.clampWrites = true
    let reconciler = makeDeliveryReconciler(app)
    var snapshots = 0
    let tiling = makeTiling(
      windows: {
        snapshots += 1
        return [window(id: 1)]
      },
      memberships: { [1: [10]] },
      frameReconciler: reconciler
    )
    tiling.initialize()
    let before = snapshots
    reconciler.apply([1: animationFrame(100)])
    try await waitForAnimation { reconciler.isIdle }
    for _ in 0..<10 { tiling.windowFrameDidChange(1) }
    #expect(snapshots == before)
    #expect(app.writeCount == 2)
  }
}
