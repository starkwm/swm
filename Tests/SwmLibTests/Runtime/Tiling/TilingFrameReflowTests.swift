import CoreGraphics
import Testing

@testable import SwmLib

@MainActor
@Suite("Tiling frame reflow")
struct TilingFrameReflowTests {
  @Test("animation: paired completion notifications do not rescan or cancel other windows")
  func completionNotificationsPreserveOtherAnimations() {
    var frames: [CGWindowID: CGRect] = [
      1: CGRect(x: 0, y: 0, width: 400, height: 300),
      2: CGRect(x: 500, y: 100, width: 300, height: 200),
    ]
    var snapshots = 0
    let reconciler = WindowFrameReconciler(
      currentFrame: { frames[$0] },
      frameMutation: { id, target, _ in
        frames[id] = target
        return .success
      },
      reduceMotion: { false }
    )
    let tiling = makeTiling(
      windows: {
        snapshots += 1
        return [window(id: 1), window(id: 2)]
      },
      memberships: { [1: [10], 2: [10]] },
      frameReconciler: reconciler
    )
    tiling.initialize()
    let initialSnapshots = snapshots
    let start = ContinuousClock.now
    let firstTarget = CGRect(x: 500, y: 100, width: 300, height: 200)
    let secondTarget = CGRect(x: 0, y: 0, width: 400, height: 300)
    reconciler.animationDuration = 0.18
    reconciler.apply([1: firstTarget], at: start)
    reconciler.animationDuration = 0.3
    reconciler.apply([2: secondTarget], at: start)
    reconciler.advanceAnimations(at: start.advanced(by: .milliseconds(180)))

    // A combined move and resize can deliver more than one notification at the final frame.
    tiling.windowFrameDidChange(1)
    tiling.windowFrameDidChange(1)
    tiling.windowFrameDidChange(1)

    #expect(snapshots == initialSnapshots)
    #expect(reconciler.frames(for: [2])[2] == secondTarget)
    reconciler.advanceAnimations(at: start.advanced(by: .milliseconds(300)))
    #expect(frames[2] == secondTarget)

    // A real user move after completion must still reach reconciliation immediately.
    frames[1]?.origin.x += 50
    tiling.windowFrameDidChange(1)
    #expect(snapshots == initialSnapshots + 1)
  }

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
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2)],
      memberships: [1: [10], 2: [10]],
      frameReconciler: frameReconciler
    )
    tiling.initialize()

    #expect(tiling.swapWindow(1, in: .right))
    #expect(
      framesByWindowID
        == [
          1: CGRect(x: 500, y: 100, width: 300, height: 200),
          2: CGRect(x: 0, y: 0, width: 400, height: 300),
        ]
    )
    #expect(tiling.swapWindow(1, in: .right) == false)
  }
}
