import CoreGraphics
import Testing

@testable import SwmLib

@MainActor
@Suite("Tiling frame reflow")
struct TilingManagerFrameReflowTests {
  @Test("directional swap: exchanges complete frames in a floating layout")
  func directionalSwapExchangesFloatingFrames() {
    var framesByWindowID: [CGWindowID: CGRect] = [
      1: CGRect(x: 0, y: 0, width: 400, height: 300),
      2: CGRect(x: 500, y: 100, width: 300, height: 200),
    ]
    let frameReconciler = WindowFrameReconciler(
      currentFrame: { framesByWindowID[$0] },
      frameMutation: { windowID, targetFrame, _ in
        framesByWindowID[windowID] = targetFrame
        return .success
      }
    )
    let manager = makeManager(
      windows: [window(id: 1), window(id: 2)],
      memberships: [1: [10], 2: [10]],
      frameReconciler: frameReconciler
    )
    manager.start()

    #expect(manager.swapWindow(1, in: .right))
    #expect(
      framesByWindowID
        == [
          1: CGRect(x: 500, y: 100, width: 300, height: 200),
          2: CGRect(x: 0, y: 0, width: 400, height: 300),
        ]
    )
    #expect(manager.swapWindow(1, in: .right) == false)
  }
}
